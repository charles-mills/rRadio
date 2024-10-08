import os
import json
import math

def load_stations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        # Extract the Lua table content
        content = content.split('return stations')[0].split('local stations = ')[1]
        # Convert Lua table to Python dict
        return json.loads(content.replace('{', '[').replace('}', ']').replace('=', ':'))

def save_consolidated_file(stations, file_number):
    output = "local stations = {\n"
    for country, country_stations in stations.items():
        output += f"    ['{country}'] = {{\n"
        for station in country_stations:
            output += f"        {{name = \"{station['name']}\", url = \"{station['url']}\"}},\n"
        output += "    },\n"
    output += "}\n\nreturn stations"
    
    with open(f'rRadio/lua/radio/stations/consolidated_{file_number}.lua', 'w', encoding='utf-8') as f:
        f.write(output)

def consolidate_stations():
    stations_dir = 'rRadio/lua/radio/stations'
    all_stations = {}
    current_file_size = 0
    file_number = 1
    max_file_size = 62 * 1024  # 62KB

    for filename in os.listdir(stations_dir):
        if filename.endswith('.lua') and not filename.startswith('consolidated_'):
            country = filename[:-4]  # Remove .lua extension
            file_path = os.path.join(stations_dir, filename)
            country_stations = load_stations(file_path)
            
            # Estimate the size this country's stations would add
            country_size = len(json.dumps(country_stations))
            
            if current_file_size + country_size > max_file_size:
                # Save current file and start a new one
                save_consolidated_file(all_stations, file_number)
                all_stations = {}
                current_file_size = 0
                file_number += 1
            
            all_stations[country] = country_stations
            current_file_size += country_size

    # Save the last file
    if all_stations:
        save_consolidated_file(all_stations, file_number)

    print(f"Consolidated stations into {file_number} files.")

if __name__ == "__main__":
    consolidate_stations()