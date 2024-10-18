import os
import re

def load_station_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    return parse_lua_content(content)

def parse_lua_content(content):
    content = re.sub(r'^return\s*', '', content.strip())
    
    result = {}
    country_pattern = r"\['([^']+)'\]=\{((?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*)\}"
    station_pattern = r"\{n='([^']+)',u='([^']+)'\}"
    
    country_matches = re.findall(country_pattern, content, re.DOTALL)
    
    for country, stations_data in country_matches:
        stations = re.findall(station_pattern, stations_data)
        if country not in result:
            result[country] = []
        result[country].extend([{'n': name, 'u': url} for name, url in stations])
    
    return result

def lua_encode(data):
    result = []
    for country, stations in data.items():
        result.append(f"['{country}']={{")
        for station in stations:
            result.append(f"{{n='{station['n']}',u='{station['u']}'}},")
        result.append("},")
    return ''.join(result)

def save_station_data(data, file_path):
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(f"return{{{lua_encode(data)}}}")

def get_file_size(data):
    return len(f"return{{{lua_encode(data)}}}".encode('utf-8'))

def pack_stations(input_directory, output_directory, size_limit=63 * 1024):
    all_stations = {}
    
    # Load all station data
    for filename in os.listdir(input_directory):
        if filename.startswith('data_') and filename.endswith('.lua'):
            file_path = os.path.join(input_directory, filename)
            print(f"Loading data from {file_path}")
            stations = load_station_data(file_path)
            for country, country_stations in stations.items():
                if country not in all_stations:
                    all_stations[country] = []
                all_stations[country].extend(country_stations)

    print(f"Total countries loaded: {len(all_stations)}")

    # Calculate size for each country
    country_sizes = {country: get_file_size({country: stations}) for country, stations in all_stations.items()}

    # Sort countries by size (largest first)
    sorted_countries = sorted(country_sizes.items(), key=lambda x: x[1], reverse=True)

    # Pack stations into new files
    output_files = []
    current_file = {}
    current_size = 0

    def try_add_country(country, size):
        nonlocal current_file, current_size
        if current_size + size <= size_limit:
            current_file[country] = all_stations[country]
            current_size += size
            return True
        return False

    for country, size in sorted_countries:
        if not try_add_country(country, size):
            output_files.append(current_file)
            current_file = {country: all_stations[country]}
            current_size = size

    if current_file:
        output_files.append(current_file)

    # Try to fit smaller countries into existing files
    for i, file_data in enumerate(output_files):
        remaining_space = size_limit - get_file_size(file_data)
        for country, size in sorted_countries:
            if country not in file_data and size <= remaining_space:
                file_data[country] = all_stations[country]
                remaining_space -= size
                sorted_countries = [(c, s) for c, s in sorted_countries if c != country]

    # Remove empty files and consolidate
    output_files = [file_data for file_data in output_files if file_data]

    # Save packed files
    for i, file_data in enumerate(output_files, 1):
        output_file = os.path.join(output_directory, f'packed_data_{i}.lua')
        print(f"Saving file: {output_file} ({len(file_data)} countries)")
        save_station_data(file_data, output_file)

    print(f"Packed stations into {len(output_files)} files.")

# Usage
input_directory = 'helpers/stations'
output_directory = 'helpers/packed_stations'

# Create output directory if it doesn't exist
os.makedirs(output_directory, exist_ok=True)

print(f"Input directory: {input_directory}")
print(f"Output directory: {output_directory}")

pack_stations(input_directory, output_directory)

print("Script execution completed.")
