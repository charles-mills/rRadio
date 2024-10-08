import os
import json
import re

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
    output = "return {"
    for country, country_stations in stations.items():
        output += f"['{country}']={{"
        for station in country_stations:
            name = station['name'].replace("'", "\\'")
            url = station['url'].replace("'", "\\'")
            output += f"{{n='{name}',u='{url}'}},"
        output += "},"
    output += "}"
    
    file_path = f'rRadio/lua/radio/stations/data_{file_number}.lua'
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(output)
    
    return len(output.encode('utf-8'))

def consolidate_stations():
    stations_dir = 'rRadio/lua/radio/stations'
    all_stations = {}
    current_file_size = 0
    file_number = 1
    max_file_size = 63 * 1024  # 63KB

    for filename in os.listdir(stations_dir):
        if filename.endswith('.lua') and not filename.startswith('data_'):
            country = filename[:-4]  # Remove .lua extension
            file_path = os.path.join(stations_dir, filename)
            country_stations = load_stations(file_path)
            
            if not country_stations:
                print(f"Warning: No valid stations found in {filename}")
                continue
            
            country_size = len(json.dumps({country: country_stations}))
            
            if current_file_size + country_size > max_file_size:
                if all_stations:
                    actual_size = save_consolidated_file(all_stations, file_number)
                    print(f"File {file_number} size: {actual_size} bytes")
                    all_stations = {}
                    current_file_size = 0
                    file_number += 1
                
                if country_size > max_file_size:
                    split_stations = []
                    current_split = []
                    split_size = 0
                    for station in country_stations:
                        station_size = len(json.dumps(station))
                        if split_size + station_size > max_file_size:
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
                    all_stations[country] = country_stations
                    current_file_size = country_size
            else:
                all_stations[country] = country_stations
                current_file_size += country_size

    if all_stations:
        actual_size = save_consolidated_file(all_stations, file_number)
        print(f"File {file_number} size: {actual_size} bytes")

    print(f"Consolidated stations into {file_number} files.")

if __name__ == "__main__":
    consolidate_stations()