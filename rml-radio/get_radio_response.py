import os
import requests
import re

# Path to the directory containing the radio station files
stations_dir = "rml-radio/lua/radio/stations"

# Regular expression to match the URLs in the Lua table
url_pattern = re.compile(r'url\s*=\s*"([^"]+)"')

def extract_stations(directory):
    """Extracts all radio station URLs from Lua files in the given directory."""
    stations = []

    # Traverse through all files in the directory
    for root, dirs, files in os.walk(directory):
        print(f"Checking directory: {root}")  # Debug print
        for file in files:
            if file.endswith(".lua"):
                file_path = os.path.join(root, file)
                print(f"Reading file: {file_path}")  # Debug print
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        # Find all URLs using the regular expression
                        matches = url_pattern.findall(content)
                        stations.extend(matches)
                except UnicodeDecodeError as e:
                    print(f"Error reading file {file_path}: {e}")
    
    return stations

def check_station(url):
    """Checks if the radio station URL is up and responding."""
    try:
        # Send a request to the radio station
        response = requests.get(url, stream=True, timeout=10)
        
        # Check if the response is valid
        if response.status_code == 200:
            print(f"Station '{url}' is up and responding.")
        else:
            print(f"Station '{url}' responded with status code: {response.status_code}")
        
        # Optional: Check if the content-type is audio (might vary)
        if 'audio' in response.headers.get('Content-Type', '').lower():
            print(f"Station '{url}' is streaming audio.")
        else:
            print(f"Station '{url}' is not streaming audio (Content-Type: {response.headers.get('Content-Type', 'Unknown')}).")
        
    except requests.exceptions.RequestException as e:
        # Catch any request-related errors
        print(f"Station '{url}' could not be reached: {e}")

def main():
    # Extract stations from the directory
    radio_stations = extract_stations(stations_dir)

    if not radio_stations:
        print(f"No radio stations found in {stations_dir}.")
        return

    # Check each station
    for station in radio_stations:
        check_station(station)

if __name__ == "__main__":
    main()
