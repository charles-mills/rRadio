import os
import requests
import re
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Global constants
STATIONS_DIR = "rml-radio/lua/radio/stations"

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
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "").replace("\r", "")

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

# Function to check if a radio station is responsive
def check_station(url):
    try:
        response = requests.get(url, stream=True, timeout=10)
        if response.status_code == 200:
            return True
        else:
            print(f"{Colors.RED}NO RESPONSE:{Colors.END} {url} responded with status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"{Colors.RED}NO RESPONSE:{Colors.END} Could not reach {url}: {e}")
        return False

# Function to get radio stations for a specific country
def get_radio_stations(country_name):
    session = requests.Session()
    retries = Retry(total=5, backoff_factor=1, status_forcelist=[500, 502, 503, 504], allowed_methods=["GET"])
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("https://", adapter)

    stations = []
    seen_names = set()
    url = f"https://de1.api.radio-browser.info/json/stations/bycountry/{country_name.replace(' ', '%20')}"

    try:
        response = session.get(url, timeout=10)
        response.raise_for_status()
        if response.headers['Content-Type'].startswith('application/json'):
            data = response.json()
            for station in data:
                name = escape_lua_string(station.get('name', 'Unknown'))
                url = escape_lua_string(station.get('url_resolved', ''))
                if url and name.lower() not in seen_names and re.match(r'^[\w\s\-]+$', name):
                    cleaned_name = clean_station_name(name)
                    stations.append({"name": cleaned_name, "url": url})
                    seen_names.add(cleaned_name.lower())
        else:
            print(f"{Colors.YELLOW}WARNING:{Colors.END} Unexpected content type for {country_name}: {response.headers['Content-Type']}")
            print(response.text)
    except requests.exceptions.RequestException as e:
        print(f"{Colors.RED}ERROR:{Colors.END} Request error occurred for {country_name}: {e}")

    return stations

# Function to verify each station and save to a Lua file
def verify_and_save_stations(country, stations):
    verified_stations = []
    total_stations = len(stations)
    for station in stations:
        if check_station(station["url"]):
            verified_stations.append(station)

    if verified_stations:
        save_stations_to_file(country, verified_stations)
        print(f"{Colors.GREEN}VERIFICATION COMPLETE:{Colors.END} {len(verified_stations)} out of {total_stations} stations were responsive for {country}.")
    else:
        print(f"{Colors.RED}NO RESPONSIVE STATIONS:{Colors.END} No responsive stations found for {country}. No file will be saved.")

# Function to save stations to a Lua file for a specific country
def save_stations_to_file(country, stations):
    directory = STATIONS_DIR
    os.makedirs(directory, exist_ok=True)

    cleaned_country_name = clean_file_name(country)
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            f.write(f'    {{name = "{station["name"]}", url = "{station["url"]}"}},\n')
        f.write("}\n\nreturn stations\n")

    print(f"{Colors.CYAN}Saved stations for {Colors.BOLD}{country or 'Other'}{Colors.END}{Colors.CYAN} to {file_path}{Colors.END}")

# Function to get the list of all countries, excluding DPRK
def get_all_countries():
    session = requests.Session()
    response = session.get("https://de1.api.radio-browser.info/json/countries")
    countries = response.json()
    return [country['name'] for country in countries if country['name'] != "Korea, Democratic People's Republic of"]

# Function to count stations in a file
def count_stations_in_file(file_path):
    count = 0
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
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

# Function to clean station file by removing non-responsive stations
def clean_station_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    stations = re.findall(r'\{name\s*=\s*"([^"]+)",\s*url\s*=\s*"([^"]+)"\}', content)
    responsive_stations = [(name, url) for name, url in stations if check_station(url)]

    if not responsive_stations:
        print(f"{Colors.RED}NO RESPONSIVE STATIONS:{Colors.END} No responsive stations found in {file_path}. File will be empty.")
    else:
        print(f"{Colors.GREEN}{len(responsive_stations)} responsive stations found in {file_path}.{Colors.END}")

    new_content = "local stations = {\n"
    for name, url in responsive_stations:
        new_content += f'    {{name = "{name}", url = "{url}"}},\n'
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
            countries = get_all_countries()
            for country in countries:
                print(f"{Colors.BLUE}Fetching stations for {country}...{Colors.END}")
                time.sleep(1)
                stations = get_radio_stations(country)
                if stations:
                    verify_and_save_stations(country, stations)
            print(f"{Colors.GREEN}Rescan, verification, and saving complete.{Colors.END}")
        elif choice == '2':
            for root, dirs, files in os.walk(STATIONS_DIR):
                for file in files:
                    if file.endswith(".lua"):
                        file_path = os.path.join(root, file)
                        print(f"{Colors.BLUE}Processing file: {file_path}{Colors.END}")
                        clean_station_file(file_path)
            print(f"{Colors.GREEN}Verification complete.{Colors.END}")
        elif choice == '3':
            total_stations = count_total_stations(STATIONS_DIR)
            print(f'{Colors.CYAN}Total number of radio stations: {Colors.BOLD}{total_stations}{Colors.END}')
        elif choice == '4':
            print(f"{Colors.YELLOW}Exiting...{Colors.END}")
            break
        else:
            print(f"{Colors.RED}Invalid option. Please try again.{Colors.END}")

if __name__ == "__main__":
    main_menu()
