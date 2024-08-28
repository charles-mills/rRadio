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



config = configparser.ConfigParser()

# Set the absolute path to the config.ini file
config_file = 'C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/addons/rml-radio/helpers/config.ini'

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

STATIONS_DIR = config['DEFAULT']['stations_dir']
MAX_CONCURRENT_REQUESTS = int(config['DEFAULT']['max_concurrent_requests'])
API_BASE_URL = config['DEFAULT']['api_base_url']
REQUEST_TIMEOUT = int(config['DEFAULT']['request_timeout'])
BATCH_DELAY = int(config['DEFAULT']['batch_delay'])
LOG_FILE = config['DEFAULT']['log_file']

# Configure logging
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(filename=LOG_FILE, level=logging.INFO,
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

# Function to escape special characters for Lua
def escape_lua_string(s):
    # Remove problematic escape sequences and non-printable characters
    s = re.sub(r'\\[nNrRtT]', '', s)  # Remove \n, \N, \r, \R, \t, \T
    s = re.sub(r'[^\x20-\x7E]', '', s)  # Remove non-ASCII characters
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

# Function to clean and format station names
def clean_station_name(name):
    cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
    try:
        cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
    except Exception as e:
        logging.error(f"Error applying title case to name '{name}': {e}")
    return cleaned_name

# Function to clean and format file names
def clean_file_name(name):
    name = re.sub(r'[^\w\s-]', '', name)
    name = name.replace(' ', '_')
    return name.lower()

# Function to fetch radio stations asynchronously with rate limiting
async def fetch_stations(session, country_name):
    url = f"{API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
    stations = []
    seen_names = set()
    seen_urls = set()

    try:
        async with session.get(url, timeout=REQUEST_TIMEOUT) as response:
            if response.status == 200:
                data = await response.json()
                for station in data:
                    name = escape_lua_string(station.get('name', 'Unknown'))
                    url = escape_lua_string(station.get('url_resolved', ''))
                    cleaned_name = clean_station_name(name)

                    # Check for duplicates
                    if cleaned_name.lower() in seen_names or url in seen_urls:
                        continue
                    
                    stations.append({"name": cleaned_name, "url": url})
                    seen_names.add(cleaned_name.lower())
                    seen_urls.add(url)
            else:
                logging.warning(f"Unexpected content type for {country_name}: {response.headers['Content-Type']}")
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        logging.error(f"Request error occurred for {country_name}: {e}")
    
    return stations

# Function to save stations to a Lua file for a specific country
def save_stations_to_file(country, stations):
    directory = STATIONS_DIR
    os.makedirs(directory, exist_ok=True)

    cleaned_country_name = clean_file_name(country)
    if cleaned_country_name == "the_united_kingdom_of_great_britain_and_northern_ireland":
        cleaned_country_name = "the_united_kingdom"
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            name = escape_lua_string(station["name"])
            url = escape_lua_string(station["url"])
            f.write(f'    {{name = [[{name}]], url = [[{url}]]}},\n')
        f.write("}\n\nreturn stations\n")

    logging.info(f"Saved stations for {country or 'Other'} to {file_path}")

# Function to fetch and save stations asynchronously with rate limiting
async def fetch_and_save_stations():
    countries = get_all_countries()
    async with aiohttp.ClientSession() as session:
        for i, country in enumerate(tqdm(countries, desc="Fetching stations")):
            stations = await fetch_stations(session, country)
            if stations:
                save_stations_to_file(country, stations)
            await asyncio.sleep(BATCH_DELAY)  # Sleep between batches to avoid rate limits

    logging.info("All stations fetched and saved.")

# Function to get the list of all countries, excluding DPRK
def get_all_countries():
    url = f"{API_BASE_URL}/countries"
    response = requests.get(url)
    countries = response.json()
    return [country['name'] for country in countries if clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Asynchronous function to check if a radio station is responsive
async def check_station(session, url):
    try:
        async with session.get(url, timeout=REQUEST_TIMEOUT) as response:
            if response.status == 200:
                return True
            else:
                logging.warning(f"NO RESPONSE: {url} responded with status code: {response.status}")
                return False
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        logging.error(f"Could not reach {url}: {e}")
        return False

# Asynchronous function to verify stations concurrently
async def verify_stations_concurrently(session, stations):
    verified_stations = []
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    async def verify_station(station):
        async with semaphore:
            if await check_station(session, station["url"]):
                verified_stations.append(station)

    tasks = [verify_station(station) for station in stations]
    await asyncio.gather(*tasks)
    
    return verified_stations

# Function to verify all stations asynchronously after fetching
async def verify_all_stations():
    async with aiohttp.ClientSession() as session:
        for root, dirs, files in os.walk(STATIONS_DIR):
            for file in files:
                if file.endswith(".lua"):
                    file_path = os.path.join(root, file)
                    logging.info(f"Verifying stations in {file_path}")
                    
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    stations = re.findall(r'\{name\s*=\s*\[\[(.*?)\]\],\s*url\s*=\s*\[\[(.*?)\]\]\}', content)
                    stations = [{"name": name, "url": url} for name, url in stations]
                    
                    verified_stations = await verify_stations_concurrently(session, stations)

                    if not verified_stations:
                        logging.warning(f"No responsive stations found in {file_path}. File will be empty.")
                    else:
                        logging.info(f"{len(verified_stations)} responsive stations found in {file_path}")

                    new_content = "local stations = {\n"
                    for station in verified_stations:
                        new_content += f'    {{name = [[{escape_lua_string(station["name"])}]], url = [[{escape_lua_string(station["url"])}]]}},\n'
                    new_content += "}\n\nreturn stations\n"

                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    logging.info(f"Updated {file_path} with responsive stations only.")

# Function to count stations in a file
def count_stations_in_file(file_path):
    count = 0
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*\[\[.*?\]\],\s*url\s*=\s*\[\[.*?\]\]\s*},\s*', line):
                count += 1
    return count

# Function to count total stations across all files
def count_total_stations(directory):
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    return total_stations

# Main menu function
def main_menu():
    while True:
        print(f"\n{Colors.BOLD}--- Radio Station Manager ---{Colors.END}")
        print(f"{Colors.CYAN}1 - Full Rescan, Save, and Verify{Colors.END}")
        print(f"{Colors.CYAN}2 - Just Fetch and Save Stations{Colors.END}")
        print(f"{Colors.CYAN}3 - Verify Stations Only{Colors.END}")
        print(f"{Colors.CYAN}4 - Count Total Stations{Colors.END}")
        print(f"{Colors.CYAN}5 - Exit{Colors.END}")
        choice = input(f"{Colors.BOLD}Select an option: {Colors.END}")

        if choice == '1':
            asyncio.run(fetch_and_save_stations())
            asyncio.run(verify_all_stations())
        elif choice == '2':
            asyncio.run(fetch_and_save_stations())
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
    args = parser.parse_args()

    if args.fetch:
        asyncio.run(fetch_and_save_stations())
    elif args.verify:
        asyncio.run(verify_all_stations())
    elif args.count:
        total_stations = count_total_stations(STATIONS_DIR)
        print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
    else:
        main_menu()
