import os
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import time

# Function to escape special characters for Lua
def escape_lua_string(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "").replace("\r", "")

# Create a session with retry logic
session = requests.Session()
retries = Retry(total=5, backoff_factor=1, status_forcelist=[500, 502, 503, 504], allowed_methods=["GET"])
adapter = HTTPAdapter(max_retries=retries)
session.mount("https://", adapter)

# Function to get radio stations for a specific country
def get_radio_stations(country_name):
    stations = []
    url = f"https://de1.api.radio-browser.info/json/stations/bycountry/{country_name.replace(' ', '%20')}"
    
    try:
        response = session.get(url, timeout=10)  # Add a timeout for each request
        response.raise_for_status()  # Raise an error for bad status codes
        if response.headers['Content-Type'].startswith('application/json'):
            data = response.json()
            for station in data:
                name = escape_lua_string(station.get('name', 'Unknown'))
                url = escape_lua_string(station.get('url_resolved', ''))
                if url:
                    stations.append({"name": name, "url": url})
        else:
            print(f"Unexpected content type for {country_name}: {response.headers['Content-Type']}")
            print(response.text)  # Print the actual HTML or other response for debugging
    except requests.exceptions.SSLError as e:
        print(f"SSL error occurred for {country_name}: {e}")
    except requests.exceptions.RequestException as e:
        print(f"Request error occurred for {country_name}: {e}")
    
    return stations

# Function to save stations to a Lua file for a specific country
def save_stations_to_file(country, stations):
    directory = "rml-radio/lua/radio/stations"
    os.makedirs(directory, exist_ok=True)  # Create the directory if it doesn't exist
    
    # Create the file path
    file_path = os.path.join(directory, f"{country}.lua")
    
    # Write the Lua table to the file
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            f.write(f'    {{name = "{station["name"]}", url = "{station["url"]}"}},\n')
        f.write("}\n\n")
        f.write("return stations\n")
    
    print(f"Saved stations for {country} to {file_path}")

# Get the list of all countries, excluding DPRK
def get_all_countries():
    url = "https://de1.api.radio-browser.info/json/countries"
    response = session.get(url)
    countries = response.json()
    return [country['name'] for country in countries if country['name'] != "Korea, Democratic People's Republic of"]

# Example usage
countries = get_all_countries()

# Fetch radio stations for each country and save to separate files
for country in countries:
    print(f"Fetching stations for {country}...")
    time.sleep(1)
    stations = get_radio_stations(country)
    if stations:
        save_stations_to_file(country, stations)
    else:
        print(f"No stations found for {country}.")

print("Finished fetching and saving radio stations.")
