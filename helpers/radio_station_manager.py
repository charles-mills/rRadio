import os
import re
import aiohttp
import asyncio
import requests
import configparser
import argparse
from tqdm import tqdm
from typing import List, Dict, Tuple, Optional
import shutil
import subprocess
import datetime
from asyncio import Semaphore
import platform

# Configuration setup
class Config:
    def __init__(self):
        print("Initializing configuration...")
        self.config = configparser.ConfigParser()
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(script_dir, 'config.ini')
        if os.path.exists(config_file):
            print(f"Reading config file: {config_file}")
            self.config.read(config_file)
        else:
            print(f"Config file not found: {config_file}")
        self.load_defaults()

    def load_defaults(self):
        print("Loading default configuration values...")
        self.STATIONS_DIR = self.config['DEFAULT'].get('stations_dir', 'lua/radio/stations')
        self.MAX_CONCURRENT_REQUESTS = int(self.config['DEFAULT'].get('max_concurrent_requests', 5))
        self.API_BASE_URL = self.config['DEFAULT'].get('api_base_url', 'https://de1.api.radio-browser.info/json')
        self.REQUEST_TIMEOUT = int(self.config['DEFAULT'].get('request_timeout', 10))
        self.BATCH_DELAY = int(self.config['DEFAULT'].get('batch_delay', 5))
        self.README_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'README.md')

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
            print(f"Error applying title case to name '{name}': {e}")
        return cleaned_name

    @staticmethod
    def clean_file_name(name: str) -> str:
        name = re.sub(r'[^\w\s-]', '', name)
        name = name.replace(' ', '_')
        return name.lower()

    @staticmethod
    def validate_lua_file(file_path: str):
        try:
            result = subprocess.run(['lua', '-p', file_path], check=True, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"Lua file {file_path} is valid.")
            else:
                print(f"Lua validation failed for {file_path}: {result.stderr}")
        except Exception as e:
            print(f"Lua validation failed for {file_path}: {e}")

# Radio station management class
class RadioStationManager:
    def __init__(self, config: Config):
        print("Initializing RadioStationManager...")
        self.config = config
        self.semaphore = Semaphore(self.config.MAX_CONCURRENT_REQUESTS)

    async def fetch_stations(self, session: aiohttp.ClientSession, country_name: str, retries: int = 5) -> List[Dict[str, str]]:
        print(f"Fetching stations for country: {country_name}")
        url = f"{self.config.API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
        for attempt in range(retries):
            try:
                async with session.get(url, timeout=self.config.REQUEST_TIMEOUT, ssl=True) as response:
                    if response.status == 200:
                        print(f"Successfully fetched stations for {country_name}")
                        return await response.json()
                    elif response.status == 429:
                        print(f"Rate limit exceeded (429) for {country_name}. Retrying...")
                    elif response.status == 502:
                        print(f"Bad Gateway (502) for {country_name}. Retrying...")
                    else:
                        print(f"Unexpected response ({response.status}) for {country_name}")
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                print(f"Attempt {attempt + 1} failed for {country_name}: {e}")
            await asyncio.sleep(2 ** attempt)
        print(f"Failed to fetch stations for {country_name} after {retries} attempts.")
        return []

    def save_stations_to_file(self, country: str, stations: List[Dict[str, str]]):
        print(f"Saving stations for country: {country}")
        directory = self.config.STATIONS_DIR
        os.makedirs(directory, exist_ok=True)
        cleaned_country_name = Utils.clean_file_name(country)
        file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
        file_path = os.path.join(directory, file_name)

        # Use sets to ensure no duplicates
        unique_names = set()
        unique_urls = set()
        filtered_stations = []

        for station in stations:
            name = Utils.clean_station_name(station["name"])
            url = station["url"]
            if name.lower() not in unique_names and url not in unique_urls:
                unique_names.add(name.lower())
                unique_urls.add(url)
                filtered_stations.append({"name": name, "url": url})

        with open(file_path, "w", encoding="utf-8") as f:
            f.write("local stations = {\n")

            for station in filtered_stations:
                line = f'    {{name = "{Utils.escape_lua_string(station["name"])}", url = "{Utils.escape_lua_string(station["url"])}"}},\n'
                f.write(line)

                # Check the current file size
                current_size = f.tell()

                if current_size > 63 * 1024:  # 63KB limit
                    print(f"File size limit reached (63KB). Stopping station addition for {country}.")
                    break

            f.write("}\n\nreturn stations\n")

        print(f"Saved stations for {country or 'Other'} to {file_path}")
        Utils.validate_lua_file(file_path)


    def commit_and_push_changes(self, file_path: str, message: str):
        print(f"Committing and pushing changes for file: {file_path}")
        try:
            repo_dir = os.path.dirname(file_path)
            while not os.path.exists(os.path.join(repo_dir, '.git')):
                repo_dir = os.path.dirname(repo_dir)
                if repo_dir == '/' or repo_dir == '':
                    print("Git repository not found.")
                    return
            subprocess.run(["git", "add", file_path], check=True, cwd=repo_dir)
            subprocess.run(["git", "commit", "-m", message], check=True, cwd=repo_dir)
            subprocess.run(["git", "push"], check=True, cwd=repo_dir)
            print(f"Committed and pushed changes: {message}")
        except subprocess.CalledProcessError as e:
            print(f"Failed to commit and push changes: {e}")

    async def verify_stations(self, session: aiohttp.ClientSession, stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
        print(f"Verifying {len(stations)} stations...")
        verified_stations = []
        tasks = [self.check_and_add_station(session, station, verified_stations) for station in stations]
        await asyncio.gather(*tasks)
        print(f"Verified {len(verified_stations)} stations successfully.")
        return verified_stations

    async def check_and_add_station(self, session: aiohttp.ClientSession, station: Dict[str, str], verified_stations: List[Dict[str, str]]):
        try:
            async with session.get(station["url"], timeout=self.config.REQUEST_TIMEOUT, ssl=True) as response:
                if response.status == 200:
                    verified_stations.append(station)
                else:
                    print(f"Station {station['name']} ({station['url']}) not responsive. Status: {response.status}")
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            print(f"Station {station['name']} ({station['url']}) check failed: {e}")

    async def fetch_all_stations(self):
        print("Starting to fetch all stations...")
        countries = self.get_all_countries()
        with tqdm(total=len(countries), desc="Fetching stations") as pbar:
            async with aiohttp.ClientSession() as session:
                tasks = [self.fetch_save_stations(session, country, pbar) for country in countries]
                await asyncio.gather(*tasks)
        print("All stations fetched and saved.")

    async def fetch_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm):
        print(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            stations = await self.fetch_stations(session, country)
            if stations:
                self.save_stations_to_file(country, stations)
                file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
                self.commit_and_push_changes(file_path, f"Fetched and saved stations for {country}")
            pbar.update(1)

    async def verify_all_stations(self):
        print("Starting to verify all stations...")
        countries = self.get_all_countries()
        with tqdm(total=len(countries), desc="Verifying stations") as pbar:
            async with aiohttp.ClientSession() as session:
                tasks = [self.verify_and_save_stations(session, country, pbar) for country in countries]
                await asyncio.gather(*tasks)
        print("All stations verified and saved.")

    async def verify_and_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm):
        print(f"Verifying and saving stations for {country}...")
        file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
        
        # Check if the file exists before attempting to open it
        if not os.path.exists(file_path):
            print(f"File {file_path} not found. Skipping verification for {country}.")
            pbar.update(1)
            return
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        stations = re.findall(r'\{name\s*=\s*"(.*?)",\s*url\s*=\s*"(.*?)"\}', content)
        stations = [{"name": name, "url": url} for name, url in stations]

        verified_stations = await self.verify_stations(session, stations)
        if verified_stations:
            self.save_stations_to_file(country, verified_stations)
            self.commit_and_push_changes(file_path, f"Verified and saved stations for {country}")
        pbar.update(1)

    def get_all_countries(self) -> List[str]:
        print("Fetching list of all countries...")
        url = f"{self.config.API_BASE_URL}/countries"
        response = requests.get(url, verify=True)
        countries = response.json()
        print(f"Found {len(countries)} countries.")
        return [country['name'] for country in countries if Utils.clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Main application logic
async def main_async(auto_run=False, fetch=False, verify=False, count=False):
    print("Starting the Radio Station Manager...")
    config = Config()
    manager = RadioStationManager(config)

    if auto_run:
        print("Auto-run mode enabled.")
        if fetch:
            print("Fetching stations...")
            await manager.fetch_all_stations()
        if verify:
            print("Verifying stations...")
            await manager.verify_all_stations()
        if count:
            print("Counting stations and updating README...")
            total_stations = count_total_stations(config.STATIONS_DIR)
            update_readme_with_station_count(config.README_PATH, total_stations)
            manager.commit_and_push_changes(config.README_PATH, f"Update README.md with {total_stations} radio stations")
    else:
        print("Interactive mode enabled.")
        while True:
            print("\n--- Radio Station Manager ---")
            print("1 - Fetch and Save Stations")
            print("2 - Verify Stations")
            print("3 - Count Total Stations and Update README")
            print("4 - Full Rescan, Verify, Update README, and Push Changes")
            print("5 - Exit")
            
            choice = input("Select an option: ")

            if choice == '1':
                await manager.fetch_all_stations()
            elif choice == '2':
                await manager.verify_all_stations()
            elif choice == '3':
                total_stations = count_total_stations(config.STATIONS_DIR)
                update_readme_with_station_count(config.README_PATH, total_stations)
            elif choice == '4':
                await manager.fetch_all_stations()
                await manager.verify_all_stations()
                total_stations = count_total_stations(config.STATIONS_DIR)
                update_readme_with_station_count(config.README_PATH, total_stations)
                manager.commit_and_push_changes(config.README_PATH, f"Update README.md with {total_stations} radio stations")
            elif choice == '5':
                print("Exiting...")
                break
            else:
                print("Invalid option. Please try again.")

def main(auto_run=False, fetch=False, verify=False, count=False):
    # Setting the appropriate event loop policy based on the platform
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(main_async(auto_run=auto_run, fetch=fetch, verify=verify, count=count))

# Helper functions
def count_total_stations(directory: str) -> int:
    print(f"Counting total stations in directory: {directory}")
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    print(f"Total stations counted: {total_stations}")
    return total_stations

def count_stations_in_file(file_path: str) -> int:
    count = 0
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                count += 1
    return count

def update_readme_with_station_count(readme_path: str, total_stations: int):
    print(f"Updating README.md at {readme_path} with station count: {total_stations}")
    if not os.path.exists(readme_path):
        print(f"README.md not found at {readme_path}")
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

        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(new_readme_content)

        print(f"Updated README.md with the current station count: {total_stations}")
    except Exception as e:
        print(f"Failed to update README.md: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--verify', action='store_true', help='Verify saved stations')
    parser.add_argument('--count', action='store_true', help='Count total stations and update README')
    args = parser.parse_args()

    main(auto_run=args.auto_run, fetch=args.fetch, verify=args.verify, count=args.count)
