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
    max_file_size = 63 * 1024  # 63KB

    # Remove old consolidated files
    output_dir = os.path.join(addon_root, 'lua', 'radio', 'stations')
    for filename in os.listdir(output_dir):
        if filename.startswith('data_') and filename.endswith('.lua'):
            os.remove(os.path.join(output_dir, filename))

    # Load all stations and calculate their sizes
    country_sizes = []
    for filename in os.listdir(stations_dir):
        if filename.endswith('.lua'):
            country = filename[:-4]  # Remove .lua extension
            file_path = os.path.join(stations_dir, filename)
            country_stations = load_stations(file_path)
            if country_stations:
                all_stations[country] = country_stations
                country_size = len(json.dumps({country: country_stations}))
                country_sizes.append((country, country_size))

    # Sort countries by size (largest first)
    country_sizes.sort(key=lambda x: x[1], reverse=True)

    # Bin packing algorithm
    bins = []
    for country, size in country_sizes:
        if size > max_file_size:
            # Split large countries
            stations = all_stations[country]
            current_bin = {}
            current_size = 0
            for station in stations:
                station_size = len(json.dumps(station))
                if current_size + station_size > max_file_size:
                    if current_bin:
                        bins.append(current_bin)
                    current_bin = {f"{country}_{len(bins)}": [station]}
                    current_size = station_size
                else:
                    if not current_bin:
                        current_bin = {f"{country}_{len(bins)}": []}
                    current_bin[f"{country}_{len(bins)}"].append(station)
                    current_size += station_size
            if current_bin:
                bins.append(current_bin)
        else:
            # Try to fit country into existing bin or create new bin
            fitted = False
            for bin in bins:
                bin_size = sum(len(json.dumps(stations)) for stations in bin.values())
                if bin_size + size <= max_file_size:
                    bin[country] = all_stations[country]
                    fitted = True
                    break
            if not fitted:
                bins.append({country: all_stations[country]})

    # Save consolidated files
    for i, bin in enumerate(bins, 1):
        actual_size = save_consolidated_file(bin, i)
        print(f"File {i} size: {actual_size} bytes")

    print(f"Consolidated stations into {len(bins)} files.")

if __name__ == "__main__":
    consolidate_stations()