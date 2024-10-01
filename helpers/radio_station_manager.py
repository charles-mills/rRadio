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
from urllib.parse import urlparse, urlunparse, quote

import aiofiles
import aiohttp
import aiosqlite
from aiolimiter import AsyncLimiter
from rapidfuzz import fuzz
from tqdm.asyncio import tqdm


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
            stages_dir=cfg.get('stages_dir', '/lua/stations'),
            readme_path=cfg.get('readme_path', 'README.md'),
            git_repo_dir=cfg.get('git_repo_dir', '.'),
        )


# -------------------------------
# Utility Functions
# -------------------------------

class Utils:
    @staticmethod
    def clean_file_name(name: str) -> str:
        # Remove or replace characters that are invalid in file names
        return re.sub(r'[\\/*?:"<>|]', "", name)

    @staticmethod
    def clean_station_name(name: str) -> str:
        # Further clean station names if necessary
        return name.strip()

    @staticmethod
    def escape_lua_string(s: str) -> str:
        # Escape quotes and backslashes for Lua strings
        return s.replace("\\", "\\\\").replace('"', '\\"').replace("'", "\\'")

    @staticmethod
    def remove_common_words(name: str) -> str:
        # Remove common words to improve fuzzy matching
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

    async def fetch_stations(
        self,
        session: aiohttp.ClientSession,
        country_name: str,
        retries: int = 5,
        backoff_factor: float = 0.5,
        by_popularity: bool = True
    ) -> List[Dict[str, str]]:
        logging.info(f"Fetching stations for country: {country_name} {'by popularity' if by_popularity else ''}")

        encoded_country_name = quote(country_name)
        if by_popularity:
            url = f"{self.config.api_base_url}/stations/bycountry/{encoded_country_name}?order=clickcount&reverse=true"
        else:
            url = f"{self.config.api_base_url}/stations/bycountry/{encoded_country_name}"

        for attempt in range(1, retries + 1):
            try:
                async with self.limiter:
                    async with self.semaphore:
                        async with session.get(url, timeout=self.config.request_timeout, ssl=True) as response:
                            if response.status == 200:
                                logging.info(f"Successfully fetched stations for {country_name}")
                                return await response.json()
                            elif response.status == 429:
                                logging.warning(f"Rate limit exceeded (429) for {country_name}. Attempt {attempt} of {retries}.")
                                raise aiohttp.ClientResponseError(
                                    status=429,
                                    message="Rate limit exceeded",
                                    request_info=response.request_info,
                                    history=response.history
                                )
                            elif response.status in {502, 503, 504}:
                                logging.warning(f"Server error ({response.status}) for {country_name}. Attempt {attempt} of {retries}.")
                            else:
                                logging.error(f"Unexpected response ({response.status}) for {country_name}")
                                return []
            except aiohttp.ClientResponseError as e:
                if e.status in {429, 502, 503, 504} and attempt < retries:
                    sleep_time = self.config.backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logging.info(f"Sleeping for {sleep_time:.2f} seconds before retrying...")
                    await asyncio.sleep(sleep_time)
                else:
                    logging.error(f"Failed to fetch stations for {country_name} after {retries} attempts.")
                    return []
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                if attempt < retries:
                    sleep_time = self.config.backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logging.info(f"Error fetching stations for {country_name}: {e}. Sleeping for {sleep_time:.2f} seconds before retrying...")
                    await asyncio.sleep(sleep_time)
                else:
                    logging.error(f"Failed to fetch stations for {country_name} after {retries} attempts due to error: {e}")
                    return []
        logging.error(f"Exhausted all retries for {country_name}.")
        return []

    async def check_audio_stream_cached(self, session: aiohttp.ClientSession, url: str) -> bool:
        await self.initialize_cache()

        async with self.cache_db.execute("SELECT is_valid FROM url_cache WHERE url = ?", (url,)) as cursor:
            row = await cursor.fetchone()
            if row:
                logging.info(f"URL {url} found in cache: {row[0]}")
                return bool(row[0])

        # Not in cache, perform verification
        try:
            is_valid = await Utils.check_audio_stream(session, url)
        except aiohttp.ClientResponseError as e:
            if e.status == 429:
                logging.warning(f"Encountered 429 while checking URL {url}. Implementing backoff.")
                # Implement a global delay to respect rate limits
                sleep_time = self.config.backoff_factor * 2 + random.uniform(0, 1)
                logging.info(f"Sleeping for {sleep_time:.2f} seconds due to rate limiting.")
                await asyncio.sleep(sleep_time)
                return await self.check_audio_stream_cached(session, url)  # Retry once after backoff
            else:
                logging.error(f"HTTP error {e.status} for URL {url}: {e.message}")
                is_valid = False
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

    async def save_stations_to_file(self, session: aiohttp.ClientSession, country: str, stations: List[Dict[str, str]]):
        if country.lower() == "the united kingdom of great britain and northern ireland":
            logging.info(f"Reformatting country name '{country}' to 'The United Kingdom'")
            country = "The United Kingdom"

        if not country:
            logging.warning("No country provided for stations. Skipping file creation.")
            return

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

            # Clean and normalize station name
            name = Utils.clean_station_name(raw_name)
            normalized_name = Utils.remove_common_words(name)

            # Parse URL to extract base URL (scheme + netloc + path)
            parsed_url = urlparse(raw_url)
            normalized_netloc = Utils.remove_www_prefix(parsed_url.netloc.lower())
            base_url = urlunparse((
                parsed_url.scheme.lower(),
                normalized_netloc,
                parsed_url.path.rstrip('/'),
                '',  # params
                '',  # query
                ''   # fragment
            ))

            # Fuzzy duplicate check for names
            is_duplicate = False
            for existing_name in unique_names:
                similarity = fuzz.ratio(normalized_name, existing_name)
                logging.debug(f"Fuzzy similarity between '{existing_name}' and '{normalized_name}': {similarity}%")
                if similarity > 85:  # Adjusted threshold
                    logging.info(f"Fuzzy duplicate station name detected. '{name}' is similar to '{existing_name}'. Skipping.")
                    is_duplicate = True
                    break
            if is_duplicate:
                continue

            # Duplicate check for base URLs
            if base_url in unique_base_urls:
                logging.info(f"Duplicate base URL detected. Skipping station: {name} with base URL: {base_url}")
                continue

            # Check if the URL is a valid audio stream using cached method
            is_valid = await self.check_audio_stream_cached(session, raw_url)
            if not is_valid:
                logging.info(f"Skipping station {name} due to invalid audio stream.")
                continue

            # Add to unique sets and filtered list
            unique_names.append(normalized_name)
            unique_base_urls.add(base_url)
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
        """
        Commit and push all changes in the provided list of files with a single commit.
        """
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

    async def fetch_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm, changed_files: List[str]):
        logging.info(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            try:
                stations = await self.fetch_stations(session, country, by_popularity=True)

                if stations:
                    await self.save_stations_to_file(session, country, stations)
                    file_path = os.path.join(self.config.stages_dir, f"{Utils.clean_file_name(country)}.lua")
                    changed_files.append(file_path)
            except Exception as e:
                logging.error(f"Error processing country '{country}': {e}")
            finally:
                pbar.update(1)

    async def fetch_all_stations(self):
        logging.info("Starting to fetch all stations...")
        countries = self.get_all_countries()
        changed_files = []
        with tqdm(total=len(countries), desc="Fetching stations") as pbar:
            connector = aiohttp.TCPConnector(limit_per_host=50)  # Adjusted for higher concurrency per host
            async with aiohttp.ClientSession(connector=connector) as session:
                tasks = [
                    self.fetch_save_stations(session, country, pbar, changed_files)
                    for country in countries
                ]
                await asyncio.gather(*tasks)
        logging.info("All stations fetched and saved.")

        # Commit and push changes after all stations are processed
        if changed_files:
            commit_message = f"Fetched and saved stations for {len(changed_files)} countries"
            await self.commit_and_push_changes(changed_files, commit_message)

    def get_all_countries(self) -> List[str]:
        logging.info("Fetching list of all countries...")
        url = f"{self.config.api_base_url}/countries"
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            countries = response.json()
            logging.info(f"Found {len(countries)} countries.")
            country_names = [
                country['name']
                for country in countries
                if Utils.clean_file_name(country['name']).lower() != "the_democratic_peoples_republic_of_korea"
            ]
            logging.debug(f"Country list: {country_names}")
            return country_names
        except requests.RequestException as e:
            logging.error(f"Failed to fetch countries list: {e}")
            return []

    async def ensure_cache_initialized(self):
        if not self.cache_initialized:
            while not self.cache_initialized:
                await asyncio.sleep(0.1)

    async def update_readme_with_station_count(self, total_stations: int):
        logging.info(f"Updating README.md at {self.config.readme_path} with station count: {total_stations}")
        if not os.path.exists(self.config.readme_path):
            logging.error(f"README.md not found at {self.config.readme_path}")
            return

        try:
            new_readme_content = (
                f"## 🎵 Active Stations: `{total_stations}` 🎵\n\n"
                f"## Description\n"
                f"**rRadio** is a Garry's Mod addon that allows players to listen to their favorite radio stations in-game, either with friends or alone. The stations are regularly fetched via the [Radio Browser API](https://www.radio-browser.info/), and confirmed to be active.\n\n"
                f"## Features\n"
                f"- **Wide Range of Stations**: Access to radio stations from around the world.\n"
                f"- **User-Friendly Interface**: Simple and intuitive UI for easy navigation and station selection.\n"
                f"- **Multiplayer and Singleplayer Support**: Works seamlessly in both modes.\n"
                f"- **Customizable Client-Side Settings**: Personalize the UI to fit your preferences.\n"
                f"- **Adjustable Server-Side Settings**: Modify key values such as audio range and maximum volume.\n\n"
                f"## Installation\n\n"
                f"1. **Download the Addon**: Get the rRadio addon from the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) or clone this repository.\n"
                f"2. **Extract the Files**: Place the extracted addon files into the `addons` folder within your Garry's Mod installation directory.\n"
                f"3. **Enable the Addon**: Launch Garry's Mod and activate the rRadio addon through the Addons menu (if installed via Steam Workshop).\n\n"
                f"## Usage\n\n"
                f"1. **Open the Radio Menu**: Press the designated key (default: `K`) to open the RML Radio menu.\n"
                f"2. **Browse Stations**: Use the mouse to scroll through the list of available radio stations.\n"
                f"3. **Select a Station**: Left-click on a station to start playing it.\n"
                f"4. **Adjust Settings**: Modify the volume and other settings according to your preferences.\n"
                f"5. **Enjoy**: Listen to your favorite radio station while enjoying your Garry's Mod experience!\n"
            )

            async with aiofiles.open(self.config.readme_path, "w", encoding="utf-8") as f:
                await f.write(new_readme_content)

            logging.info(f"Updated README.md with the current station count: {total_stations}")
        except Exception as e:
            logging.error(f"Failed to update README.md: {e}")

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

    async def run_full_scan(self):
        logging.info("Starting full scan: Fetching stations, updating README, and pushing changes.")
        await self.fetch_all_stations()
        await self.update_readme()
        total_stations = await self.count_total_stations()
        await self.update_readme_with_station_count(total_stations)
        changed_files = [self.config.readme_path]
        await self.commit_and_push_changes(changed_files, f"Update README.md with {total_stations} radio stations")

    async def interactive_menu(self):
        while True:
            print("\n--- Radio Station Manager ---")
            print("1 - Fetch and Save Stations")
            print("2 - Count Total Stations and Update README")
            print("3 - Full Rescan, Update README, and Push Changes")
            print("4 - Exit")

            choice = input("Select an option: ")

            if choice == '1':
                await self.fetch_all_stations()
            elif choice == '2':
                await self.update_readme()
            elif choice == '3':
                await self.run_full_scan()
            elif choice == '4':
                logging.info("Exiting...")
                break
            else:
                logging.warning("Invalid option. Please try again.")

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
            logging.info("Interactive mode enabled.")
            await self.interactive_menu()


# -------------------------------
# Helper Functions
# -------------------------------

import random
import requests

async def check_audio_stream(session: aiohttp.ClientSession, url: str) -> bool:
    try:
        async with session.head(url, timeout=10, allow_redirects=True) as response:
            if response.status == 200 and 'audio' in response.headers.get('Content-Type', ''):
                logging.debug(f"Valid audio stream: {url}")
                return True
            else:
                logging.debug(f"Invalid audio stream: {url} with status {response.status}")
                return False
    except Exception as e:
        logging.debug(f"Error checking audio stream {url}: {e}")
        return False

# -------------------------------
# Main Application Logic
# -------------------------------

async def main_async(auto_run=False, fetch=False, count=False):
    logging.info("Starting the Radio Station Manager...")
    config = Config.load_config()
    manager = RadioStationManager(config)

    if auto_run:
        logging.info("Auto-run mode enabled.")
        await manager.run_full_scan()
    else:
        logging.info("Interactive mode enabled.")
        await manager.start(auto_run=auto_run, fetch=fetch, count=count)

def main(auto_run=False, fetch=False, count=False):
    # Setting the appropriate event loop policy based on the platform
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(main_async(auto_run=auto_run, fetch=fetch, count=count))

# -------------------------------
# Command-Line Interface
# -------------------------------

if __name__ == "__main__":
    # Configure Logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        handlers=[
            logging.StreamHandler()
        ]
    )

    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--count', action='store_true', help='Count total stations and update README')
    args = parser.parse_args()

    main(auto_run=args.auto_run, fetch=args.fetch, count=args.count)