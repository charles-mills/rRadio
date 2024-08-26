import requests
import time

# Function to get all available countries
def get_all_countries():
    url = "https://de1.api.radio-browser.info/json/countries"
    response = requests.get(url)
    countries = response.json()
    return [country['name'] for country in countries if country['name'] != "Korea, Democratic People's Republic of"]

# Function to get radio stations for a specific country
def get_radio_stations(country_name):
    stations = []
    url = f"https://de1.api.radio-browser.info/json/stations/bycountry/{country_name.replace(' ', '%20')}"
    
    response = requests.get(url)
    
    if response.headers['Content-Type'].startswith('application/json'):
        try:
            data = response.json()
            for station in data:
                name = station.get('name', 'Unknown')
                url = station.get('url_resolved', '')
                if url:
                    stations.append({"name": name, "url": url})
        except requests.exceptions.JSONDecodeError:
            print(f"Error: Could not decode JSON for {country_name}")
    else:
        print(f"Unexpected content type for {country_name}: {response.headers['Content-Type']}")
        print(response.text)  # Print the actual HTML or other response for debugging
    
    return stations

# Function to format the stations into Lua-compatible format
def format_stations_to_lua(country_stations):
    lua_str = 'Config.RadioStations = {\n'
    
    for country, stations in country_stations.items():
        lua_str += f'    ["{country}"] = {{\n'
        for station in stations:
            lua_str += f'        {{name = "{station["name"]}", url = "{station["url"]}"}},\n'
        lua_str += '    },\n'
    
    lua_str += '}\n'
    return lua_str

# Get the list of all countries, excluding DPRK
countries = get_all_countries()
country_stations = {}

# Fetch radio stations for each country
for country in countries:
    print(f"Fetching stations for {country}...")
    stations = get_radio_stations(country)
    country_stations[country] = stations
    time.sleep(1)  # Sleep for a second to avoid rate limiting

# Format the output to Lua
lua_output = format_stations_to_lua(country_stations)

# Write to config.lua file using UTF-8 encoding
with open("config.lua", "w", encoding="utf-8") as f:
    f.write(lua_output)

print("Finished fetching and writing radio stations.")
