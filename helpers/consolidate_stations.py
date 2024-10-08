import os
import json
import re
import shutil

def load_stations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        content = content.split('return stations')[0].split('local stations = ')[1]
        stations = []
        for station in re.findall(r'\{.*?\}', content, re.DOTALL):
            station_dict = {}
            for key, value in re.findall(r'(\w+)\s*=\s*"(.*?)"', station):
                station_dict[key] = value
            if 'name' in station_dict and 'url' in station_dict:
                stations.append(station_dict)
    return stations

def save_consolidated_file(stations, file_number):
    output = "return{"
    for country, country_stations in stations.items():
        output += f"['{country}']={{"
        for station in country_stations:
            name = station['name'].replace("'", "\\'").replace('"', '\\"')
            url = station['url'].replace("'", "\\'").replace('"', '\\"')
            output += f"{{n='{name}',u='{url}'}},"
        output += "},"
    output += "}"
    
    file_path = os.path.join(addon_root, 'lua', 'radio', 'stations', f'data_{file_number}.lua')
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(output)
    
    return len(output.encode('utf-8'))

def consolidate_stations():
    global addon_root
    current_dir = os.path.dirname(os.path.abspath(__file__))
    addon_root = os.path.dirname(current_dir)
    stations_dir = os.path.join(current_dir, 'stations')
    
    all_stations = {}
    current_file_size = 0
    file_number = 1
    max_file_size = 63 * 1024  # 63KB

    # Remove old consolidated files
    output_dir = os.path.join(addon_root, 'lua', 'radio', 'stations')
    for filename in os.listdir(output_dir):
        if filename.startswith('data_') and filename.endswith('.lua'):
            os.remove(os.path.join(output_dir, filename))

    # First pass: load all stations and calculate sizes
    for filename in os.listdir(stations_dir):
        if filename.endswith('.lua'):
            country = filename[:-4]  # Remove .lua extension
            file_path = os.path.join(stations_dir, filename)
            country_stations = load_stations(file_path)
            
            if country_stations:
                all_stations[country] = country_stations

    # Second pass: optimize file distribution
    current_file = {}
    for country, stations in all_stations.items():
        country_size = len(json.dumps({country: stations}))
        
        if current_file_size + country_size > max_file_size:
            if current_file:
                actual_size = save_consolidated_file(current_file, file_number)
                print(f"File {file_number} size: {actual_size} bytes")
                file_number += 1
                current_file = {}
                current_file_size = 0

        if country_size > max_file_size:
            # Split large countries
            split_stations = []
            current_split = []
            split_size = 0
            for station in stations:
                station_size = len(json.dumps(station))
                if split_size + station_size > max_file_size:
                    if current_split:
                        split_stations.append(current_split)
                    current_split = [station]
                    split_size = station_size
                else:
                    current_split.append(station)
                    split_size += station_size
            if current_split:
                split_stations.append(current_split)
            
            for i, split in enumerate(split_stations):
                actual_size = save_consolidated_file({f"{country}_{i+1}": split}, file_number)
                print(f"File {file_number} size: {actual_size} bytes")
                file_number += 1
        else:
            current_file[country] = stations
            current_file_size += country_size

        # Check if we can add more countries to the current file
        while current_file_size < max_file_size and all_stations:
            next_country, next_stations = next(iter(all_stations.items()))
            next_size = len(json.dumps({next_country: next_stations}))
            if current_file_size + next_size <= max_file_size:
                current_file[next_country] = next_stations
                current_file_size += next_size
                del all_stations[next_country]
            else:
                break

    # Save any remaining stations
    if current_file:
        actual_size = save_consolidated_file(current_file, file_number)
        print(f"File {file_number} size: {actual_size} bytes")

    print(f"Consolidated stations into {file_number} files.")

if __name__ == "__main__":
    consolidate_stations()