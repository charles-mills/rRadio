import os
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import time
import re

# Function to escape special characters for Lua
def escape_lua_string(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "").replace("\r", "")

# Function to clean and format station names
def clean_station_name(name):
    # Remove unwanted symbols
    cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
    # Apply title case only to words that are not fully capitalized
    try:
        cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
    except Exception as e:
        print(f"Error applying title case to name '{name}': {e}")
    return cleaned_name

# Function to clean and format file names
def clean_file_name(name):
    # Replace spaces with underscores and remove problematic characters
    name = re.sub(r'[^\w\s-]', '', name)  # Remove non-alphanumeric characters except spaces and hyphens
    name = name.replace(' ', '_')  # Replace spaces with underscores
    return name.lower()  # Convert to lowercase for consistency

# Create a session with retry logic
session = requests.Session()
retries = Retry(total=5, backoff_factor=1, status_forcelist=[500, 502, 503, 504], allowed_methods=["GET"])
adapter = HTTPAdapter(max_retries=retries)
session.mount("https://", adapter)

# Function to get radio stations for a specific country
def get_radio_stations(country_name):
    stations = []
    seen_names = set()
    url = f"https://de1.api.radio-browser.info/json/stations/bycountry/{country_name.replace(' ', '%20')}"

    try:
        response = session.get(url, timeout=10)  # Add a timeout for each request
        response.raise_for_status()  # Raise an error for bad status codes
        if response.headers['Content-Type'].startswith('application/json'):
            data = response.json()
            for station in data:
                name = escape_lua_string(station.get('name', 'Unknown'))
                url = escape_lua_string(station.get('url_resolved', ''))
                if url and name.lower() not in seen_names and re.match(r'^[\w\s\-]+$', name):  # Check for valid characters
                    cleaned_name = clean_station_name(name)
                    stations.append({"name": cleaned_name, "url": url})
                    seen_names.add(cleaned_name.lower())
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

    # Clean the country name for use as a file name
    cleaned_country_name = clean_file_name(country)
    file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
    file_path = os.path.join(directory, file_name)

    # Write the Lua table to the file
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("local stations = {\n")
        for station in stations:
            f.write(f'    {{name = "{station["name"]}", url = "{station["url"]}"}},\n')
        f.write("}\n\n")
        f.write("return stations\n")

    print(f"Saved stations for {country or 'Other'} to {file_path}")

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

# Fetch stations with no country assigned
print("Fetching stations with no country assigned...")
time.sleep(1)
stations = get_radio_stations("")
if stations:
    save_stations_to_file("Other", stations)
else:
    print("No stations found for 'Other'.")

print("Finished fetching and saving radio stations.")
