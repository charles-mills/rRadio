import argparse
import asyncio
import logging
import os
import platform
import re
import subprocess
from configparser import ConfigParser
from dataclasses import dataclass
from typing import List, Dict, Optional

import aiofiles
import aiosqlite
from aiolimiter import AsyncLimiter
from tqdm.asyncio import tqdm
import pyradios
import aiohttp

# -------------------------------
# Configuration Management
# -------------------------------

@dataclass
class Config:
    api_base_url: str
    max_concurrent_requests: int
    rate_limit: float
    rate_limit_period: float
    request_timeout: float
    backoff_factor: float
    stages_dir: str
    readme_path: str
    git_repo_dir: str

    @staticmethod
    def load_config(config_file: str = "config.ini") -> 'Config':
        parser = ConfigParser()
        parser.read(config_file)
        cfg = parser['DEFAULT']
        return Config(
            api_base_url=cfg.get('api_base_url', 'https://api.radio-browser.info/json'),
            max_concurrent_requests=int(cfg.get('max_concurrent_requests', 250)),
            rate_limit=float(cfg.get('rate_limit', 100)),
            rate_limit_period=float(cfg.get('rate_limit_period', 1)),
            request_timeout=float(cfg.get('request_timeout', 10)),
            backoff_factor=float(cfg.get('backoff_factor', 0.5)),
            stages_dir=cfg.get('stages_dir', os.path.join((os.getcwd()), 'lua', 'radio', 'stations')),
            readme_path=cfg.get('readme_path', 'README.md'),
            git_repo_dir=cfg.get('git_repo_dir', '.'),
        )


# -------------------------------
# Utility Functions
# -------------------------------

class Utils:
    @staticmethod
    def clean_file_name(name: str) -> str:
        return re.sub(r'[\\/*?:"<>|]', "", name)

    @staticmethod
    def clean_station_name(name: str) -> str:
        return name.strip()

    @staticmethod
    def escape_lua_string(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"').replace("'", "\\'")

    @staticmethod
    def remove_common_words(name: str) -> str:
        common_words = ['radio', 'fm', 'am', 'live', 'online', 'uk', 'the']
        words = name.lower().split()
        filtered_words = [word for word in words if word not in common_words]
        return ' '.join(filtered_words)


# -------------------------------
# Radio Station Manager
# -------------------------------

class RadioStationManager:
    def __init__(self, config: Config):
        self.config = config
        self.semaphore = asyncio.Semaphore(config.max_concurrent_requests)
        self.limiter = AsyncLimiter(config.rate_limit, config.rate_limit_period)
        self.cache_db: Optional[aiosqlite.Connection] = None
        self.cache_initialized = False
        self.git_repo_found = self.check_git_repo()

    def check_git_repo(self) -> bool:
        return os.path.isdir(os.path.join(self.config.git_repo_dir, ".git"))

    async def initialize_cache(self):
        if not self.cache_db:
            self.cache_db = await aiosqlite.connect("url_cache.db")
            await self.cache_db.execute("""
                CREATE TABLE IF NOT EXISTS url_cache (
                    url TEXT PRIMARY KEY,
                    is_valid BOOLEAN
                )
            """)
            await self.cache_db.commit()
            self.cache_initialized = True

    async def fetch_stations(self, country_name: str, by_popularity: bool = True) -> List[Dict[str, str]]:
        """
        Fetch radio stations using the pyradios module for a given country.
        """
        logging.info(f"Fetching stations for country: {country_name} {'by popularity' if by_popularity else ''}")
        
        try:
            # Use pyradios to fetch stations by country and sort by popularity
            stations = await pyradios.get_stations_by_country(country_name, limit=500, sort='clickcount' if by_popularity else None)
            logging.info(f"Successfully fetched {len(stations)} stations for {country_name}")
            return stations
        except Exception as e:
            logging.error(f"Failed to fetch stations for {country_name}: {e}")
            return []

    async def fetch_available_countries(self) -> List[Dict[str, str]]:
        """
        Fetch the list of available countries from Radio Browser API manually.
        """
        logging.info("Fetching available countries...")
        url = f"{self.config.api_base_url}/countries"
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(url, timeout=self.config.request_timeout) as response:
                    if response.status == 200:
                        countries = await response.json()
                        logging.info(f"Found {len(countries)} countries.")
                        return countries
                    else:
                        logging.error(f"Failed to fetch countries: Status {response.status}")
                        return []
            except Exception as e:
                logging.error(f"Failed to fetch countries: {e}")
                return []

    async def check_audio_stream_cached(self, url: str) -> bool:
        await self.initialize_cache()

        async with self.cache_db.execute("SELECT is_valid FROM url_cache WHERE url = ?", (url,)) as cursor:
            row = await cursor.fetchone()
            if row:
                logging.info(f"URL {url} found in cache: {row[0]}")
                return bool(row[0])

        # Not in cache, perform verification
        try:
            is_valid = await pyradios.is_valid_station(url)
        except Exception as e:
            logging.error(f"Error during audio stream check for URL {url}: {e}")
            is_valid = False

        # Store result in cache
        try:
            await self.cache_db.execute(
                "INSERT OR REPLACE INTO url_cache (url, is_valid) VALUES (?, ?)",
                (url, is_valid)
            )
            await self.cache_db.commit()
        except Exception as e:
            logging.error(f"Failed to insert URL {url} into cache: {e}")

        return is_valid

    async def save_stations_to_file(self, country: str, stations: List[Dict[str, str]]):
        if country.lower() == "the united kingdom of great britain and northern ireland":
            logging.info(f"Reformatting country name '{country}' to 'The United Kingdom'")
            country = "The United Kingdom"

        logging.info(f"Saving stations for country: {country}")
        directory = self.config.stages_dir
        os.makedirs(directory, exist_ok=True)
        cleaned_country_name = Utils.clean_file_name(country)
        file_name = f"{cleaned_country_name}.lua"
        file_path = os.path.join(directory, file_name)

        unique_names = []
        unique_base_urls = set()
        filtered_stations = []

        for station in stations:
            raw_name = station.get("name", "").strip()
            raw_url = station.get("url", "").strip()

            if not raw_name or not raw_url:
                logging.warning("Station entry missing name or URL. Skipping.")
                continue

            name = Utils.clean_station_name(raw_name)
            normalized_name = Utils.remove_common_words(name)

            # Check for duplicate names
            if normalized_name in unique_names:
                logging.info(f"Duplicate station name detected: {name}")
                continue

            # Check for valid audio stream using pyradios
            is_valid = await self.check_audio_stream_cached(raw_url)
            if not is_valid:
                logging.info(f"Skipping station {name} due to invalid audio stream.")
                continue

            unique_names.append(normalized_name)
            unique_base_urls.add(raw_url)
            filtered_stations.append({"name": name, "url": raw_url})

        # Sort the filtered stations alphabetically by their names
        filtered_stations.sort(key=lambda x: x["name"].lower())

        # Write the sorted and filtered stations to the Lua file asynchronously
        try:
            async with aiofiles.open(file_path, "w", encoding="utf-8") as f:
                await f.write("local stations = {\n")

                for station in filtered_stations:
                    line = f'    {{name = "{Utils.escape_lua_string(station["name"])}", url = "{Utils.escape_lua_string(station["url"])}"}},\n'
                    await f.write(line)

                await f.write("}\n\nreturn stations\n")
            logging.info(f"Saved {len(filtered_stations)} unique stations for {country} to {file_path}")
        except Exception as e:
            logging.error(f"Failed to write stations to file {file_path}: {e}")

    async def commit_and_push_changes(self, files: List[str], message: str):
        if not self.git_repo_found:
            logging.warning("Git repository not found. Skipping git operations.")
            return

        if not files:
            logging.info("No files to commit.")
            return

        logging.info(f"Committing and pushing changes for {len(files)} files.")
        try:
            # Add all files
            subprocess.run(["git", "add"] + files, check=True, cwd=self.config.git_repo_dir)
            # Commit with the provided message
            subprocess.run(["git", "commit", "-m", message], check=True, cwd=self.config.git_repo_dir)
            # Push changes
            subprocess.run(["git", "push"], check=True, cwd=self.config.git_repo_dir)
            logging.info(f"Committed and pushed changes: {message}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to commit and push changes: {e}")

    async def fetch_save_stations(self, country: str, pbar: tqdm, changed_files: List[str]):
        logging.info(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            try:
                stations = await self.fetch_stations(country, by_popularity=True)

                if stations:
                    await self.save_stations_to_file(country, stations)
                    file_path = os.path.join(self.config.stages_dir, f"{Utils.clean_file_name(country)}.lua")
                    changed_files.append(file_path)
            except Exception as e:
                logging.error(f"Error processing country '{country}': {e}")
            finally:
                pbar.update(1)

    async def fetch_all_stations(self):
        logging.info("Starting to fetch all stations...")
        countries = await self.fetch_available_countries()
        changed_files = []
        with tqdm(total=len(countries), desc="Fetching stations") as pbar:
            async with aiohttp.ClientSession() as session:
                tasks = [
                    self.fetch_save_stations(country['name'], pbar, changed_files)
                    for country in countries
                ]
                await asyncio.gather(*tasks)
        logging.info("All stations fetched and saved.")

        if changed_files:
            commit_message = f"Fetched and saved stations for {len(changed_files)} countries"
            await self.commit_and_push_changes(changed_files, commit_message)

    async def count_total_stations(self) -> int:
        logging.info(f"Counting total stations in directory: {self.config.stages_dir}")
        total_stations = 0
        for filename in os.listdir(self.config.stages_dir):
            if filename.endswith('.lua'):
                file_path = os.path.join(self.config.stages_dir, filename)
                total_stations += await self.count_stations_in_file(file_path)
        logging.info(f"Total stations counted: {total_stations}")
        return total_stations

    async def count_stations_in_file(self, file_path: str) -> int:
        count = 0
        try:
            async with aiofiles.open(file_path, 'r', encoding='utf-8') as file:
                async for line in file:
                    if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                        count += 1
        except Exception as e:
            logging.error(f"Failed to count stations in file {file_path}: {e}")
        return count

    async def update_readme(self):
        total_stations = await self.count_total_stations()
        await self.update_readme_with_station_count(total_stations)

    async def update_readme_with_station_count(self, total_stations: int):
        logging.info(f"Updating README.md with station count: {total_stations}")
        if not os.path.exists(self.config.readme_path):
            logging.error(f"README.md not found at {self.config.readme_path}")
            return

        try:
            new_readme_content = (
                f"## 🎵 Active Stations: `{total_stations}` 🎵\n\n"
                "## Description\n"
                "rRadio is a Garry's Mod addon that allows players to listen to their favorite radio stations in-game.\n"
                "The stations are regularly fetched via the Radio Browser API and confirmed to be active.\n"
            )

            async with aiofiles.open(self.config.readme_path, "w", encoding="utf-8") as f:
                await f.write(new_readme_content)

            logging.info(f"Updated README.md with the current station count: {total_stations}")
        except Exception as e:
            logging.error(f"Failed to update README.md: {e}")

    async def run_full_scan(self):
        logging.info("Starting full scan: Fetching stations, updating README, and pushing changes.")
        await self.fetch_all_stations()
        await self.update_readme()
        total_stations = await self.count_total_stations()
        await self.update_readme_with_station_count(total_stations)
        changed_files = [self.config.readme_path]
        await self.commit_and_push_changes(changed_files, f"Update README.md with {total_stations} radio stations")

    async def start(self, auto_run: bool = False, fetch: bool = False, count: bool = False):
        await self.initialize_cache()
        if auto_run:
            logging.info("Auto-run mode enabled.")
            if fetch:
                logging.info("Fetching stations...")
                await self.fetch_all_stations()
            if count:
                logging.info("Counting stations and updating README...")
                await self.update_readme()
        else:
            await self.run_full_scan()

# -------------------------------
# Command-Line Interface
# -------------------------------

if __name__ == "__main__":
    # Configure Logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        handlers=[logging.StreamHandler()]
    )

    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--count', action='store_true', help='Count total stations and update README')
    args = parser.parse_args()

    # Setting the appropriate event loop policy based on the platform
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(RadioStationManager(Config.load_config()).start(auto_run=args.auto_run, fetch=args.fetch, count=args.count))
