import os
import re
import aiohttp
import asyncio
import time
import requests
import configparser
import logging
import argparse
from tqdm import tqdm
from logging.handlers import RotatingFileHandler
from typing import List, Dict, Tuple, Optional
import shutil
import subprocess
import datetime

# Dynamic configuration
config = configparser.ConfigParser()

# Load the config file from the script's directory
script_dir = os.path.dirname(os.path.abspath(__file__))
config_file = os.path.join(script_dir, 'config.ini')

if os.path.exists(config_file):
    print(f"Found config file: {config_file}")
    config.read(config_file)
    print(f"Config sections: {config.sections()}")
else:
    print(f"Config file not found: {config_file}")

# Access the configuration values
try:
    STATIONS_DIR = config['DEFAULT']['stations_dir']
    print(f"Stations Directory: {STATIONS_DIR}")
except KeyError as e:
    print(f"Configuration error: {e}")
    STATIONS_DIR = 'rml-radio/lua/radio/stations'  # Default value

MAX_CONCURRENT_REQUESTS = int(config['DEFAULT'].get('max_concurrent_requests', 5))
API_BASE_URL = config['DEFAULT'].get('api_base_url', 'https://de1.api.radio-browser.info/json')
REQUEST_TIMEOUT = int(config['DEFAULT'].get('request_timeout', 10))
BATCH_DELAY = int(config['DEFAULT'].get('batch_delay', 2))
LOG_FILE = config['DEFAULT'].get('log_file', 'logs/radio_station_manager.log')
VERBOSE = config['DEFAULT'].getboolean('verbose', False)
BACKUP_DIR = os.path.join(script_dir, 'backups')
README_PATH = os.path.join(script_dir, '..', 'README.md')

# Configure logging with rotation
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=5)
logging.basicConfig(handlers=[handler], level=logging.DEBUG if VERBOSE else logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# ANSI color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

# Function to escape special characters for Lua without unnecessary brackets
def escape_lua_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

# Function to clean and format station names
def clean_station_name(name: str) -> str:
    cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
    try:
        cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
    except Exception as e:
        logging.error(f"Error applying title case to name '{name}': {e}")
    logging.debug(f"Cleaned station name: {cleaned_name}")
    return cleaned_name

# Function to clean and format file names
def clean_file_name(name: str) -> str:
    name = re.sub(r'[^\w\s-]', '', name)  # Retain alphanumeric characters, spaces, and hyphens
    name = name.replace(' ', '_')
    logging.debug(f"Cleaned file name: {name}")
    return name.lower()

import asyncio

# Retry logic for fetching stations with exponential backoff
async def fetch_stations_with_retries(session: aiohttp.ClientSession, country_name: str, retries: int = 5) -> List[Dict[str, str]]:
    url = f"{API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
    stations = []
    logging.info(f"Fetching stations for {country_name} from {url}")
    for attempt in range(retries):
        logging.debug(f"Attempt {attempt + 1} to fetch stations for {country_name}")
        try:
            async with session.get(url, timeout=REQUEST_TIMEOUT, ssl=True) as response:
                logging.debug(f"Received response status {response.status} for {country_name}")
                if response.status == 200:
                    data = await response.json()
                    logging.info(f"Successfully fetched stations for {country_name}")
                    return data
                elif response.status == 429:
                    logging.warning(f"Rate limit exceeded (429) for {country_name}. Retrying after backoff...")
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
                elif response.status == 502:
                    logging.warning(f"Bad Gateway (502) for {country_name}. Retrying after a short delay...")
                    await asyncio.sleep(5)  # Fixed delay before retrying
                else:
                    logging.warning(f"Unexpected response ({response.status}) for {country_name}")
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            logging.error(f"Attempt {attempt + 1} failed for {country_name}: {e}")
            if attempt < retries - 1:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff for connection errors
    logging.error(f"Failed to fetch stations for {country_name} after {retries} attempts")
    return stations

# Increase the delay between batches to avoid hitting rate limits
BATCH_DELAY = 5  # Increase delay between requests to reduce the likelihood of 429 errors

# Function to save stations to a Lua file for a specific country, ensuring no duplicates
def save_stations_to_file(country: str, stations: List[Dict[str, str]], backup_dir: str) -> None:
    directory = STATIONS_DIR
    os.makedirs(directory, exist_ok=True)

    cleaned_country_name = clean_file_name(country)
    if cleaned_country_name == "the_united_kingdom_of_great_britain_and_northern_ireland":
        cleaned_country_name = "the_united_kingdom"
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)
    logging.info(f"Saving stations to file {file_path}")

    # Backup the existing file if it exists
    if os.path.exists(file_path):
        shutil.copy(file_path, os.path.join(backup_dir, file_name))
        logging.info(f"Backed up existing file for {country}")

    # Ensure no duplicates by using sets for names and URLs
    unique_names = set()
    unique_urls = set()
    filtered_stations = []

    for station in stations:
        name = clean_station_name(station["name"])
        url = station["url"]

        if name.lower() not in unique_names and url not in unique_urls:
            unique_names.add(name.lower())
            unique_urls.add(url)
            filtered_stations.append({"name": name, "url": url})
            logging.debug(f"Added station: {name} - {url}")

    # Write the filtered stations to the Lua file
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in filtered_stations:
            f.write(f'    {{name = "{escape_lua_string(station["name"])}", url = "{escape_lua_string(station["url"])}"}},\n')
        f.write("}\n\nreturn stations\n")

    logging.info(f"Saved {len(filtered_stations)} stations for {country} to {file_path}")

# Function to remove dead stations
def remove_dead_stations(stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
    logging.info(f"Removing dead stations")
    alive_stations = [station for station in stations if station["url"]]
    logging.info(f"Removed {len(stations) - len(alive_stations)} dead stations")
    return alive_stations

# Fetch and save stations asynchronously with rate limiting
async def fetch_and_save_stations_concurrently():
    countries = get_all_countries()
    logging.info(f"Starting fetch and save for {len(countries)} countries")
    backup_dir = os.path.join(BACKUP_DIR, datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
    os.makedirs(backup_dir, exist_ok=True)

    with tqdm(total=len(countries), desc="Backing up and saving stations") as pbar:
        tasks = []
        async with aiohttp.ClientSession() as session:
            semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)
            for country in countries:
                tasks.append(asyncio.create_task(fetch_and_save_country_stations(session, country, semaphore, backup_dir, pbar)))
            await asyncio.gather(*tasks)
    logging.info("All stations fetched and saved.")

# Fetch and save stations for a single country
async def fetch_and_save_country_stations(session: aiohttp.ClientSession, country: str, semaphore: asyncio.Semaphore, backup_dir: str, pbar: tqdm) -> None:
    logging.info(f"Fetching and saving stations for {country}")
    async with semaphore:
        stations = await fetch_stations_with_retries(session, country)
        stations = remove_dead_stations(stations)
        if stations:
            save_stations_to_file(country, stations, backup_dir)
        await asyncio.sleep(BATCH_DELAY)
    pbar.update(1)

# Get the list of all countries, excluding DPRK
def get_all_countries() -> List[str]:
    logging.info("Fetching list of all countries")
    url = f"{API_BASE_URL}/countries"
    response = requests.get(url, verify=True)  # Ensure SSL certificate verification
    countries = response.json()
    logging.debug(f"Fetched {len(countries)} countries")
    return [country['name'] for country in countries if clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Asynchronous function to check if a radio station is responsive
async def check_station(session: aiohttp.ClientSession, url: str) -> bool:
    logging.debug(f"Checking station URL: {url}")
    try:
        async with session.get(url, timeout=REQUEST_TIMEOUT, ssl=True) as response:
            if response.status == 200:
                logging.debug(f"Station responsive: {url}")
                return True
            else:
                logging.warning(f"NO RESPONSE: {url} responded with status code: {response.status}")
                return False
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        logging.error(f"Could not reach {url}: {e}")
        return False

# Asynchronous function to verify stations concurrently
async def verify_stations_concurrently(session: aiohttp.ClientSession, stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
    logging.info("Verifying stations")
    verified_stations = []
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    async def verify_station(station: Dict[str, str]) -> None:
        async with semaphore:
            if await check_station(session, station["url"]):
                verified_stations.append(station)
                logging.debug(f"Verified station: {station['name']}")

    tasks = [verify_station(station) for station in stations]
    await asyncio.gather(*tasks)

    logging.info(f"Verified {len(verified_stations)} out of {len(stations)} stations")
    return verified_stations

# Verify all stations asynchronously after fetching
async def verify_all_stations():
    logging.info("Starting verification of all stations")
    async with aiohttp.ClientSession() as session:
        for root, dirs, files in os.walk(STATIONS_DIR):
            for file in files:
                if file.endswith(".lua"):
                    file_path = os.path.join(root, file)
                    logging.info(f"Verifying stations in {file_path}")

                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    stations = re.findall(r'\{name\s*=\s*"(.*?)",\s*url\s*=\s*"(.*?)"\}', content)
                    stations = [{"name": name, "url": url} for name, url in stations]

                    verified_stations = await verify_stations_concurrently(session, stations)

                    if not verified_stations:
                        logging.warning(f"No responsive stations found in {file_path}. File will be empty.")
                    else:
                        logging.info(f"{len(verified_stations)} responsive stations found in {file_path}")

                    new_content = "local stations = {\n"
                    for station in verified_stations:
                        new_content += f'    {{name = "{escape_lua_string(station["name"])}", url = "{escape_lua_string(station["url"])}"}},\n'
                    new_content += "}\n\nreturn stations\n"

                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    logging.info(f"Updated {file_path} with responsive stations only.")

# Function to count stations in a file
def count_stations_in_file(file_path: str) -> int:
    count = 0
    logging.debug(f"Counting stations in file {file_path}")
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                count += 1
    logging.info(f"Found {count} stations in {file_path}")
    return count

# Function to count total stations across all files
def count_total_stations(directory: str) -> int:
    logging.info(f"Counting total stations in directory {directory}")
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    logging.info(f"Total stations across all files: {total_stations}")
    return total_stations

# Function to update the README.md file with the current station count
def update_readme_with_station_count(total_stations: int) -> None:
    logging.info(f"Updating README.md with total stations count: {total_stations}")
    readme_path = README_PATH

    if not os.path.exists(readme_path):
        logging.error(f"README.md not found at {readme_path}")
        return

    try:
        # Backup the README file
        backup_readme_path = readme_path + ".bak"
        shutil.copy(readme_path, backup_readme_path)
        logging.info(f"Backup of README.md created at {backup_readme_path}")

        # Prepare the new content with the active stations count at the top
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

        # Write the new content to README.md
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(new_readme_content)

        logging.info(f"Updated README.md with the current station count: {total_stations}")

        # Commit and push the changes to GitHub
        commit_and_push_changes(readme_path, total_stations)
    except Exception as e:
        logging.error(f"Failed to update README.md: {e}")

# Function to commit and push changes to GitHub
def commit_and_push_changes(file_path: str, total_stations: int) -> None:
    logging.info("Committing and pushing changes to GitHub")
    try:
        # Determine the Git repository directory
        repo_dir = os.path.dirname(file_path)
        
        # Ensure that the repository directory is correctly identified
        while not os.path.exists(os.path.join(repo_dir, '.git')):
            repo_dir = os.path.dirname(repo_dir)
            if repo_dir == '/' or repo_dir == '':
                logging.error("Git repository not found.")
                return
        
        # Stage the README.md file
        subprocess.run(["git", "add", file_path], check=True, cwd=repo_dir)
        
        # Commit the changes with a meaningful message
        commit_message = f"Update README.md with {total_stations} radio stations"
        subprocess.run(["git", "commit", "-m", commit_message], check=True, cwd=repo_dir)
        
        # Push the changes to the remote repository
        subprocess.run(["git", "push"], check=True, cwd=repo_dir)

        logging.info(f"Committed and pushed changes to GitHub: {commit_message}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to commit and push changes: {e}")

async def count_and_push_station_count():
    logging.info("Counting total stations and updating README.md")
    total_stations = count_total_stations(STATIONS_DIR)
    print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
    update_readme_with_station_count(total_stations)  # Update README.md after counting

def main_menu(auto_run: bool = False) -> None:
    if auto_run:
        # Automatically run the full rescan, save, and verify
        logging.info("Running full rescan, save, and verify automatically")
        asyncio.run(fetch_and_save_stations_concurrently())
        asyncio.run(verify_all_stations())
        asyncio.run(count_and_push_station_count())
    else:
        while True:
            print(f"\n{Colors.BOLD}--- Radio Station Manager ---{Colors.END}")
            print(f"{Colors.CYAN}1 - Full Rescan, Save, and Verify{Colors.END}")
            print(f"{Colors.CYAN}2 - Just Fetch and Save Stations{Colors.END}")
            print(f"{Colors.CYAN}3 - Verify Stations Only{Colors.END}")
            print(f"{Colors.CYAN}4 - Count Total Stations{Colors.END}")
            print(f"{Colors.CYAN}5 - Exit{Colors.END}")
            choice = input(f"{Colors.BOLD}Select an option: {Colors.END}")

            if choice == '1':
                logging.info("User selected: Full Rescan, Save, and Verify")
                asyncio.run(fetch_and_save_stations_concurrently())
                asyncio.run(verify_all_stations())
                asyncio.run(count_and_push_station_count())
            elif choice == '2':
                logging.info("User selected: Just Fetch and Save Stations")
                asyncio.run(fetch_and_save_stations_concurrently())
                asyncio.run(count_and_push_station_count())
            elif choice == '3':
                logging.info("User selected: Verify Stations Only")
                asyncio.run(verify_all_stations())
                asyncio.run(count_and_push_station_count())
            elif choice == '4':
                logging.info("User selected: Count Total Stations")
                asyncio.run(count_and_push_station_count())
            elif choice == '5':
                logging.info("User selected: Exit")
                print(f"{Colors.YELLOW}Exiting...{Colors.END}")
                break
            else:
                logging.warning("Invalid option selected by user")
                print(f"{Colors.RED}Invalid option. Please try again.{Colors.END}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--verify', action='store_true', help='Verify saved stations')
    parser.add_argument('--count', action='store_true', help='Count total stations')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    if args.auto_run:
        main_menu(auto_run=True)
    else:
        main_menu()
