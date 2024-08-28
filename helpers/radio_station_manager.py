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
    # Removes specific unwanted symbols but retains others like square brackets
    cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
    try:
        cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
    except Exception as e:
        logging.error(f"Error applying title case to name '{name}': {e}")
    return cleaned_name

# Function to clean and format file names
def clean_file_name(name: str) -> str:
    name = re.sub(r'[^\w\s-]', '', name)  # Retain alphanumeric characters, spaces, and hyphens
    name = name.replace(' ', '_')
    return name.lower()

# Retry logic for fetching stations
async def fetch_stations_with_retries(session: aiohttp.ClientSession, country_name: str, retries: int = 3) -> List[Dict[str, str]]:
    url = f"{API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
    stations = []
    for attempt in range(retries):
        try:
            async with session.get(url, timeout=REQUEST_TIMEOUT, ssl=True) as response:
                if response.status == 200:
                    data = await response.json()
                    return data
                logging.warning(f"Unexpected response ({response.status}) for {country_name}")
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            logging.error(f"Attempt {attempt + 1} failed for {country_name}: {e}")
            if attempt < retries - 1:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
    return stations

# Function to save stations to a Lua file for a specific country
def save_stations_to_file(country: str, stations: List[Dict[str, str]], backup_dir: str) -> None:
    directory = STATIONS_DIR
    os.makedirs(directory, exist_ok=True)

    cleaned_country_name = clean_file_name(country)
    if cleaned_country_name == "the_united_kingdom_of_great_britain_and_northern_ireland":
        cleaned_country_name = "the_united_kingdom"
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)

    # Backup the existing file if it exists
    if os.path.exists(file_path):
        shutil.copy(file_path, os.path.join(backup_dir, file_name))

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            name = escape_lua_string(station["name"])
            url = escape_lua_string(station["url"])
            f.write(f'    {{name = "{name}", url = "{url}"}},\n')
        f.write("}\n\nreturn stations\n")

    logging.info(f"Saved stations for {country or 'Other'} to {file_path}")

    # Validate Lua file
    validate_lua_file(file_path)

# Function to validate Lua files
def validate_lua_file(file_path: str) -> None:
    # Assuming Lua is installed and available in the PATH
    try:
        result = subprocess.run(['lua', '-p', file_path], check=True, capture_output=True, text=True)
        if result.returncode == 0:
            logging.info(f"Lua file {file_path} is valid.")
        else:
            logging.error(f"Lua validation failed for {file_path}: {result.stderr}")
    except Exception as e:
        logging.error(f"Lua validation failed for {file_path}: {e}")

# Function to remove dead stations
def remove_dead_stations(stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
    return [station for station in stations if station["url"]]

# Fetch and save stations asynchronously with rate limiting
async def fetch_and_save_stations_concurrently():
    countries = get_all_countries()
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
    async with semaphore:
        stations = await fetch_stations_with_retries(session, country)
        stations = remove_dead_stations(stations)
        if stations:
            save_stations_to_file(country, stations, backup_dir)
        await asyncio.sleep(BATCH_DELAY)
    pbar.update(1)

# Get the list of all countries, excluding DPRK
def get_all_countries() -> List[str]:
    url = f"{API_BASE_URL}/countries"
    response = requests.get(url, verify=True)  # Ensure SSL certificate verification
    countries = response.json()
    return [country['name'] for country in countries if clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Asynchronous function to check if a radio station is responsive
async def check_station(session: aiohttp.ClientSession, url: str) -> bool:
    try:
        async with session.get(url, timeout=REQUEST_TIMEOUT, ssl=True) as response:
            if response.status == 200:
                return True
            else:
                logging.warning(f"NO RESPONSE: {url} responded with status code: {response.status}")
                return False
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        logging.error(f"Could not reach {url}: {e}")
        return False

# Asynchronous function to verify stations concurrently
async def verify_stations_concurrently(session: aiohttp.ClientSession, stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
    verified_stations = []
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    async def verify_station(station: Dict[str, str]) -> None:
        async with semaphore:
            if await check_station(session, station["url"]):
                verified_stations.append(station)

    tasks = [verify_station(station) for station in stations]
    await asyncio.gather(*tasks)

    return verified_stations

# Verify all stations asynchronously after fetching
async def verify_all_stations():
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
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                count += 1
    return count

# Function to count total stations across all files
def count_total_stations(directory: str) -> int:
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    return total_stations

def main_menu() -> None:
    while True:
        print(f"\n{Colors.BOLD}--- Radio Station Manager ---{Colors.END}")
        print(f"{Colors.CYAN}1 - Full Rescan, Save, and Verify{Colors.END}")
        print(f"{Colors.CYAN}2 - Just Fetch and Save Stations{Colors.END}")
        print(f"{Colors.CYAN}3 - Verify Stations Only{Colors.END}")
        print(f"{Colors.CYAN}4 - Count Total Stations{Colors.END}")
        print(f"{Colors.CYAN}5 - Exit{Colors.END}")
        choice = input(f"{Colors.BOLD}Select an option: {Colors.END}")

        if choice == '1':
            asyncio.run(fetch_and_save_stations_concurrently())
            asyncio.run(verify_all_stations())
        elif choice == '2':
            asyncio.run(fetch_and_save_stations_concurrently())
        elif choice == '3':
            asyncio.run(verify_all_stations())
        elif choice == '4':
            total_stations = count_total_stations(STATIONS_DIR)
            print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
        elif choice == '5':
            print(f"{Colors.YELLOW}Exiting...{Colors.END}")
            break
        else:
            print(f"{Colors.RED}Invalid option. Please try again.{Colors.END}")

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--verify', action='store_true', help='Verify saved stations')
    parser.add_argument('--count', action='store_true', help='Count total stations')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    if args.fetch:
        asyncio.run(fetch_and_save_stations_concurrently())
    elif args.verify:
        asyncio.run(verify_all_stations())
    elif args.count:
        total_stations = count_total_stations(STATIONS_DIR)
        print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
    else:
        main_menu()
