import os
import requests
import re

# Path to the directory containing the radio station files
stations_dir = "rml-radio/lua/radio/stations"

# Regular expression to match the URLs in the Lua table
url_pattern = re.compile(r'url\s*=\s*"([^"]+)"')

def check_station(url):
    """Checks if the radio station URL is up and responding."""
    try:
        response = requests.get(url, stream=True, timeout=10)
        if response.status_code == 200:
            return True
        else:
            print(f"Station '{url}' responded with status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Station '{url}' could not be reached: {e}")
        return False

def clean_station_file(file_path):
    """Removes non-responsive stations from the given Lua file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all station entries
    stations = re.findall(r'\{name\s*=\s*"([^"]+)",\s*url\s*=\s*"([^"]+)"\}', content)

    # Keep only responsive stations
    responsive_stations = []
    for name, url in stations:
        print(f"Checking station '{name}' with URL: {url}")
        if check_station(url):
            responsive_stations.append((name, url))

    if not responsive_stations:
        print(f"No responsive stations found in {file_path}. File will be empty.")
    else:
        print(f"{len(responsive_stations)} responsive stations found in {file_path}.")

    # Rebuild the Lua table with only responsive stations
    new_content = "local stations = {\n"
    for name, url in responsive_stations:
        new_content += f'    {{name = "{name}", url = "{url}"}},\n'
    new_content += "}\n\nreturn stations\n"

    # Write the cleaned content back to the file
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Updated {file_path} with responsive stations only.")

def main():
    # Traverse through all files in the directory
    for root, dirs, files in os.walk(stations_dir):
        for file in files:
            if file.endswith(".lua"):
                file_path = os.path.join(root, file)
                print(f"Processing file: {file_path}")
                clean_station_file(file_path)

if __name__ == "__main__":
    main()
