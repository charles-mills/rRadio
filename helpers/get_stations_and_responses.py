import os
import re
import aiohttp
import asyncio
import time
import requests

# Global constants
STATIONS_DIR = "rml-radio/lua/radio/stations"
MAX_CONCURRENT_REQUESTS = 50  # Number of concurrent requests for verification

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
    # Lua escapes backslashes and double quotes
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

# Function to clean and format station names
def clean_station_name(name):
    cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
    try:
        cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
    except Exception as e:
        print(f"Error applying title case to name '{name}': {e}")
    return cleaned_name

# Function to clean and format file names
def clean_file_name(name):
    name = re.sub(r'[^\w\s-]', '', name)
    name = name.replace(' ', '_')
    return name.lower()

# Function to fetch radio stations for a specific country synchronously
def get_radio_stations(country_name):
    url = f"https://de1.api.radio-browser.info/json/stations/bycountry/{country_name.replace(' ', '%20')}"
    stations = []
    seen_names = set()
    seen_urls = set()

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        if response.headers['Content-Type'].startswith('application/json'):
            data = response.json()
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
            print(f"{Colors.YELLOW}WARNING:{Colors.END} Unexpected content type for {country_name}: {response.headers['Content-Type']}")
            print(response.text)
    except requests.exceptions.RequestException as e:
        print(f"{Colors.RED}ERROR:{Colors.END} Request error occurred for {country_name}: {e}")

    return stations

# Function to save stations to a Lua file for a specific country
def save_stations_to_file(country, stations):
    directory = STATIONS_DIR
    os.makedirs(directory, exist_ok=True)

    # Special case renaming
    cleaned_country_name = clean_file_name(country)
    if cleaned_country_name == "the_united_kingdom_of_great_britain_and_northern_ireland":
        cleaned_country_name = "the_united_kingdom"
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            # Write the station data using raw string notation to avoid issues with escape sequences
            f.write(f'    {{name = [[{station["name"]}]], url = [[{station["url"]}]]}},\n')
        f.write("}\n\nreturn stations\n")

    print(f"{Colors.CYAN}Saved stations for {Colors.BOLD}{country or 'Other'}{Colors.END}{Colors.CYAN} to {file_path}{Colors.END}")

# Function to fetch and save stations synchronously
def fetch_and_save_stations_synchronously():
    countries = get_all_countries()
    for country in countries:
        print(f"{Colors.BLUE}Fetching stations for {country}...{Colors.END}")
        stations = get_radio_stations(country)
        if stations:
            save_stations_to_file(country, stations)
        time.sleep(2)  # Sleep for 2 seconds between requests to avoid rate limiting
    print(f"{Colors.GREEN}All stations fetched and saved.{Colors.END}")

# Function to get the list of all countries, excluding DPRK
def get_all_countries():
    url = "https://de1.api.radio-browser.info/json/countries"
    response = requests.get(url)
    countries = response.json()
    return [country['name'] for country in countries if clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Asynchronous function to check if a radio station is responsive
async def check_station(session, url):
    try:
        async with session.get(url, timeout=10) as response:
            if response.status == 200:
                return True
            else:
                print(f"{Colors.RED}NO RESPONSE:{Colors.END} {url} responded with status code: {response.status}")
                return False
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        print(f"{Colors.RED}NO RESPONSE:{Colors.END} Could not reach {url}: {e}")
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
                    print(f"{Colors.BLUE}Verifying stations in {file_path}...{Colors.END}")
                    
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    stations = re.findall(r'\{name\s*=\s*\[\[(.*?)\]\],\s*url\s*=\s*\[\[(.*?)\]\]\}', content)
                    stations = [{"name": name, "url": url} for name, url in stations]
                    
                    verified_stations = await verify_stations_concurrently(session, stations)

                    if not verified_stations:
                        print(f"{Colors.RED}NO RESPONSIVE STATIONS:{Colors.END} No responsive stations found in {file_path}. File will be empty.")
                    else:
                        print(f"{Colors.GREEN}{len(verified_stations)} responsive stations found in {file_path}.{Colors.END}")

                    new_content = "local stations = {\n"
                    for station in verified_stations:
                        new_content += f'    {{name = [[{station["name"]}]], url = [[{station["url"]}]]}},\n'
                    new_content += "}\n\nreturn stations\n"

                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"{Colors.CYAN}Updated {file_path} with responsive stations only.{Colors.END}")

# Main menu function
def main_menu():
    while True:
        print(f"\n{Colors.BOLD}--- Radio Station Manager ---{Colors.END}")
        print(f"{Colors.CYAN}1 - Full Rescan and Verify{Colors.END}")
        print(f"{Colors.CYAN}2 - Verify Stations{Colors.END}")
        print(f"{Colors.CYAN}3 - Count Total Stations{Colors.END}")
        print(f"{Colors.CYAN}4 - Exit{Colors.END}")
        choice = input(f"{Colors.BOLD}Select an option: {Colors.END}")

        if choice == '1':
            fetch_and_save_stations_synchronously()
            asyncio.run(verify_all_stations())
        elif choice == '2':
            asyncio.run(verify_all_stations())
        elif choice == '3':
            total_stations = count_total_stations(STATIONS_DIR)
            print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
        elif choice == '4':
            print(f"{Colors.YELLOW}Exiting...{Colors.END}")
            break
        else:
            print(f"{Colors.RED}Invalid option. Please try again.{Colors.END}")

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

if __name__ == "__main__":
    main_menu()
