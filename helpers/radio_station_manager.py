import os
import re
import aiohttp
import asyncio
import requests
import configparser
import argparse
from tqdm import tqdm
from typing import List, Dict
import subprocess
from asyncio import Semaphore
import platform
import logging
from urllib.parse import urlparse
import aiosqlite
import aiofiles
from aiolimiter import AsyncLimiter
import random
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("radio_station_manager.log"),
        logging.StreamHandler()
    ]
)

# Configuration setup
class Config:
    def __init__(self):
        logging.info("Initializing configuration...")
        self.config = configparser.ConfigParser()
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(script_dir, 'config.ini')
        if os.path.exists(config_file):
            logging.info(f"Reading config file: {config_file}")
            self.config.read(config_file)
        else:
            logging.warning(f"Config file not found: {config_file}. Using default configurations.")
        self.load_defaults()

    def load_defaults(self):
        logging.info("Loading default configuration values...")
        self.STATIONS_DIR = self.config['DEFAULT'].get('stations_dir', 'lua/radio/stations')
        self.MAX_CONCURRENT_REQUESTS = int(self.config['DEFAULT'].get('max_concurrent_requests', 20))
        self.API_BASE_URL = self.config['DEFAULT'].get('api_base_url', 'https://de1.api.radio-browser.info/json')
        self.REQUEST_TIMEOUT = int(self.config['DEFAULT'].get('request_timeout', 5))
        self.BATCH_DELAY = int(self.config['DEFAULT'].get('batch_delay', 2))
        self.README_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'README.md')
        self.GIT_REPO_DIR = self.config['DEFAULT'].get('git_repo_dir', os.getcwd())
        self.MAX_RETRIES = int(self.config['DEFAULT'].get('max_retries', 5))
        self.BACKOFF_FACTOR = float(self.config['DEFAULT'].get('backoff_factor', 0.5))

# Utility functions
class Utils:
    @staticmethod
    def escape_lua_string(s: str) -> str:
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

    @staticmethod
    def clean_station_name(name: str) -> str:
        cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
        try:
            cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
        except Exception as e:
            logging.error(f"Error applying title case to name '{name}': {e}")
        return cleaned_name

    @staticmethod
    def clean_file_name(name: str) -> str:
        name = re.sub(r'[^\w\s-]', '', name)
        name = name.replace(' ', '_')
        return name.lower()

    @staticmethod
    def is_valid_url(url: str) -> bool:
        parsed_url = urlparse(url)
        return all([parsed_url.scheme, parsed_url.netloc]) and len(url) < 2048

    @staticmethod
    async def check_audio_stream(session: aiohttp.ClientSession, url: str) -> bool:
        """
        Check if the provided URL is a valid audio stream using HEAD request first,
        then fallback to GET request if HEAD is not supported.
        Implements exponential backoff with jitter for transient errors.
        """
        if not Utils.is_valid_url(url):
            logging.error(f"Invalid or malformed URL: {url}")
            return False

        try:
            # Attempt a HEAD request first
            async with session.head(url, timeout=3, ssl=True, allow_redirects=True) as response:
                content_type = response.headers.get('Content-Type', '').lower()
                if 'audio' in content_type:
                    logging.info(f"URL {url} is a valid audio stream (HEAD).")
                    return True
                else:
                    logging.warning(f"URL {url} is not an audio stream (HEAD). Content-Type: {content_type}")
                    return False
        except aiohttp.ClientResponseError as e:
            if e.status == 405:  # Method Not Allowed, try GET
                logging.warning(f"HEAD method not allowed for {url}. Falling back to GET.")
                try:
                    async with session.get(url, timeout=5, ssl=True, allow_redirects=True) as response:
                        content_type = response.headers.get('Content-Type', '').lower()
                        if 'audio' in content_type:
                            logging.info(f"URL {url} is a valid audio stream (GET).")
                            return True
                        else:
                            logging.warning(f"URL {url} is not an audio stream (GET). Content-Type: {content_type}")
                            return False
                except Exception as ex:
                    logging.error(f"Error during GET request for URL {url}: {ex}")
                    return False
            elif e.status == 429:  # Rate limit exceeded
                logging.warning(f"Rate limit exceeded (429) for URL {url}.")
                raise  # Propagate to handle rate limiting
            else:
                logging.error(f"HTTP error {e.status} for URL {url}: {e.message}")
                return False
        except aiohttp.ClientError as e:
            logging.error(f"Client error while checking URL {url}: {e}")
            return False
        except asyncio.TimeoutError:
            logging.error(f"Timeout while checking URL: {url}")
            return False
        except aiohttp.TooManyRedirects:
            logging.error(f"Too many redirects for URL: {url}")
            return False
        except Exception as e:
            logging.error(f"Error checking URL {url}: {e}")
            return False

# Radio station management class
class RadioStationManager:
    def __init__(self, config: Config):
        logging.info("Initializing RadioStationManager...")
        self.config = config
        self.semaphore = Semaphore(self.config.MAX_CONCURRENT_REQUESTS)
        # Initialize SQLite cache
        self.cache_initialized = False
        asyncio.create_task(self.initialize_cache())
        # Initialize Git repository flag
        self.git_repo_found = self.check_git_repo()

    async def initialize_cache(self):
        self.cache_db = await aiosqlite.connect('url_cache.db')
        await self.cache_db.execute("""
            CREATE TABLE IF NOT EXISTS url_cache (
                url TEXT PRIMARY KEY,
                is_valid BOOLEAN
            )
        """)
        await self.cache_db.commit()
        self.cache_initialized = True
        logging.info("SQLite cache initialized.")

    def __del__(self):
        if hasattr(self, 'cache_db') and self.cache_db:
            asyncio.create_task(self.cache_db.close())
            logging.info("Closed SQLite cache.")

    def check_git_repo(self) -> bool:
        """
        Check if the specified directory is within a Git repository.
        """
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--is-inside-work-tree"],
                cwd=self.config.GIT_REPO_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True
            )
            is_inside = result.stdout.strip().lower() == 'true'
            if is_inside:
                logging.info(f"Git repository found at {self.config.GIT_REPO_DIR}.")
            else:
                logging.warning(f"No Git repository found at {self.config.GIT_REPO_DIR}. Git operations will be skipped.")
            return is_inside
        except subprocess.CalledProcessError:
            logging.error(f"Git repository not found at {self.config.GIT_REPO_DIR}. Git operations will be skipped.")
            return False

    async def fetch_stations(self, session: aiohttp.ClientSession, country_name: str, retries: int = 5, backoff_factor: float = 0.5, by_popularity: bool = True) -> List[Dict[str, str]]:
        logging.info(f"Fetching stations for country: {country_name} {'by popularity' if by_popularity else ''}")

        if by_popularity:
            url = f"{self.config.API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}?order=clickcount&reverse=true"
        else:
            url = f"{self.config.API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"

        for attempt in range(1, retries + 1):
            try:
                async with session.get(url, timeout=self.config.REQUEST_TIMEOUT, ssl=True) as response:
                    if response.status == 200:
                        logging.info(f"Successfully fetched stations for {country_name}")
                        return await response.json()
                    elif response.status == 429:
                        logging.warning(f"Rate limit exceeded (429) for {country_name}. Attempt {attempt} of {retries}.")
                        raise aiohttp.ClientResponseError(status=429, request_info=response.request_info, history=response.history)
                    elif response.status in {502, 503, 504}:
                        logging.warning(f"Server error ({response.status}) for {country_name}. Attempt {attempt} of {retries}.")
                    else:
                        logging.error(f"Unexpected response ({response.status}) for {country_name}")
                        return []
            except aiohttp.ClientResponseError as e:
                if e.status == 429 and attempt < retries:
                    sleep_time = backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logging.info(f"Sleeping for {sleep_time:.2f} seconds before retrying...")
                    await asyncio.sleep(sleep_time)
                elif e.status in {502, 503, 504} and attempt < retries:
                    sleep_time = backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logging.info(f"Sleeping for {sleep_time:.2f} seconds before retrying...")
                    await asyncio.sleep(sleep_time)
                else:
                    logging.error(f"Failed to fetch stations for {country_name} after {retries} attempts.")
                    return []
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                if attempt < retries:
                    sleep_time = backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logging.info(f"Error fetching stations for {country_name}: {e}. Sleeping for {sleep_time:.2f} seconds before retrying...")
                    await asyncio.sleep(sleep_time)
                else:
                    logging.error(f"Failed to fetch stations for {country_name} after {retries} attempts due to error: {e}")
                    return []
        logging.error(f"Exhausted all retries for {country_name}.")
        return []

    async def check_audio_stream_cached(self, session: aiohttp.ClientSession, url: str) -> bool:
        await self.ensure_cache_initialized()

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
                sleep_time = self.config.BACKOFF_FACTOR * (2 ** 0) + random.uniform(0, 1)
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
        directory = self.config.STATIONS_DIR
        os.makedirs(directory, exist_ok=True)
        cleaned_country_name = Utils.clean_file_name(country)
        file_name = f"{cleaned_country_name}.lua"
        file_path = os.path.join(directory, file_name)

        unique_names = set()
        unique_urls = set()
        filtered_stations = []

        for station in stations:
            raw_name = station.get("name", "").strip()
            raw_url = station.get("url", "").strip()

            # Clean and normalize station name
            name = Utils.clean_station_name(raw_name)
            normalized_name = name.lower()

            # Normalize URL (assuming URLs are case-sensitive)
            url = raw_url

            # Check for duplicates based on name and URL
            if normalized_name in unique_names:
                logging.info(f"Duplicate station name detected. Skipping station: {name}")
                continue
            if url in unique_urls:
                logging.info(f"Duplicate station URL detected. Skipping station: {name} with URL: {url}")
                continue

            # Check if the URL is a valid audio stream using cached method
            is_valid = await self.check_audio_stream_cached(session, url)
            if not is_valid:
                logging.info(f"Skipping station {name} due to invalid audio stream.")
                continue

            # Add to unique sets and filtered list
            unique_names.add(normalized_name)
            unique_urls.add(url)
            filtered_stations.append({"name": name, "url": url})

        # Sort the filtered stations alphabetically by their names
        filtered_stations.sort(key=lambda x: x["name"].lower())

        # Write the sorted and filtered stations to the Lua file asynchronously
        try:
            async with aiofiles.open(file_path, "w", encoding="utf-8") as f:
                await f.write("local stations = {\n")

                for station in filtered_stations:
                    line = f'    {{name = "{Utils.escape_lua_string(station["name"])}", url = "{Utils.escape_lua_string(station["url"])}"}},\n'
                    await f.write(line)

                    # Estimate file size (approximated since aiofiles doesn't support tell())
                    # Alternatively, implement a mechanism to track size if exactness is needed

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
            subprocess.run(["git", "add"] + files, check=True, cwd=self.config.GIT_REPO_DIR)
            # Commit with the provided message
            subprocess.run(["git", "commit", "-m", message], check=True, cwd=self.config.GIT_REPO_DIR)
            # Push changes
            subprocess.run(["git", "push"], check=True, cwd=self.config.GIT_REPO_DIR)
            logging.info(f"Committed and pushed changes: {message}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to commit and push changes: {e}")

    async def fetch_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm, changed_files: List[str]):
        logging.info(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            stations = await self.fetch_stations(session, country, by_popularity=True)

            if stations:
                await self.save_stations_to_file(session, country, stations)
                file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
                changed_files.append(file_path)
            pbar.update(1)

    async def fetch_all_stations(self):
        logging.info("Starting to fetch all stations...")
        countries = self.get_all_countries()
        changed_files = []
        with tqdm(total=len(countries), desc="Fetching stations") as pbar:
            connector = aiohttp.TCPConnector(limit_per_host=50)  # Adjusted for higher concurrency per host
            async with aiohttp.ClientSession(connector=connector) as session:
                tasks = [self.fetch_save_stations(session, country, pbar, changed_files) for country in countries]
                await asyncio.gather(*tasks)
        logging.info("All stations fetched and saved.")

        # Commit and push changes after all stations are processed
        if changed_files:
            commit_message = f"Fetched and saved stations for {len(changed_files)} countries"
            await self.commit_and_push_changes(changed_files, commit_message)

    def get_all_countries(self) -> List[str]:
        logging.info("Fetching list of all countries...")
        url = f"{self.config.API_BASE_URL}/countries"
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            countries = response.json()
            logging.info(f"Found {len(countries)} countries.")
            return [
                country['name']
                for country in countries
                if Utils.clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"
            ]
        except requests.RequestException as e:
            logging.error(f"Failed to fetch countries list: {e}")
            return []

    async def ensure_cache_initialized(self):
        if not self.cache_initialized:
            while not self.cache_initialized:
                await asyncio.sleep(0.1)

# Helper functions
async def count_total_stations(directory: str) -> int:
    logging.info(f"Counting total stations in directory: {directory}")
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += await count_stations_in_file(file_path)
    logging.info(f"Total stations counted: {total_stations}")
    return total_stations

async def count_stations_in_file(file_path: str) -> int:
    count = 0
    try:
        async with aiofiles.open(file_path, 'r', encoding='utf-8') as file:
            async for line in file:
                if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                    count += 1
    except Exception as e:
        logging.error(f"Failed to count stations in file {file_path}: {e}")
    return count

async def update_readme_with_station_count(readme_path: str, total_stations: int):
    logging.info(f"Updating README.md at {readme_path} with station count: {total_stations}")
    if not os.path.exists(readme_path):
        logging.error(f"README.md not found at {readme_path}")
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

        async with aiofiles.open(readme_path, "w", encoding="utf-8") as f:
            await f.write(new_readme_content)

        logging.info(f"Updated README.md with the current station count: {total_stations}")
    except Exception as e:
        logging.error(f"Failed to update README.md: {e}")

# Main application logic
async def main_async(auto_run=False, fetch=False, count=False):
    logging.info("Starting the Radio Station Manager...")
    config = Config()
    manager = RadioStationManager(config)

    # Wait for the cache to initialize
    await manager.initialize_cache()

    if auto_run:
        logging.info("Auto-run mode enabled.")
        changed_files = []
        if fetch:
            logging.info("Fetching stations...")
            await manager.fetch_all_stations()
        if count:
            logging.info("Counting stations and updating README...")
            total_stations = await count_total_stations(config.STATIONS_DIR)
            await update_readme_with_station_count(config.README_PATH, total_stations)
            changed_files.append(config.README_PATH)
            await manager.commit_and_push_changes(changed_files, f"Update README.md with {total_stations} radio stations")
    else:
        logging.info("Interactive mode enabled.")
        while True:
            print("\n--- Radio Station Manager ---")
            print("1 - Fetch and Save Stations")
            print("2 - Count Total Stations and Update README")
            print("3 - Full Rescan, Update README, and Push Changes")
            print("4 - Exit")

            choice = input("Select an option: ")

            if choice == '1':
                await manager.fetch_all_stations()
            elif choice == '2':
                total_stations = await count_total_stations(config.STATIONS_DIR)
                await update_readme_with_station_count(config.README_PATH, total_stations)
            elif choice == '3':
                await manager.fetch_all_stations()
                total_stations = await count_total_stations(config.STATIONS_DIR)
                await update_readme_with_station_count(config.README_PATH, total_stations)
                await manager.commit_and_push_changes([config.README_PATH], f"Update README.md with {total_stations} radio stations")
            elif choice == '4':
                logging.info("Exiting...")
                break
            else:
                logging.warning("Invalid option. Please try again.")

def main(auto_run=False, fetch=False, count=False):
    # Setting the appropriate event loop policy based on the platform
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(main_async(auto_run=auto_run, fetch=fetch, count=count))

# Command-Line Interface
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--count', action='store_true', help='Count total stations and update README')
    args = parser.parse_args()

    main(auto_run=args.auto_run, fetch=args.fetch, count=args.count)
