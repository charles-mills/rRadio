import os
import re
from urllib.parse import urlparse
import sys
import io

def normalize_url(url):
    """Normalize URL by removing protocol and standardizing format."""
    if '://' in url:
        url = url.split('://', 1)[1]
    return url.lower().rstrip('/')

def normalize_name(name):
    """Normalize station name for comparison."""
    return name.lower().strip()

def extract_stations_from_lua(lua_content):
    """Extract station data from Lua file content."""
    # First, remove any potential whitespace/newlines around the content
    lua_content = lua_content.strip()
    
    # Match the entire content between return{ and }
    match = re.search(r'return\s*{(.+)}$', lua_content, re.DOTALL)
    if not match:
        return {}
    
    content = match.group(1)
    countries = {}
    
    # Find all country entries
    country_matches = re.finditer(r"\['([^']+)'\]=({.+?}(?=,\['|$))", content, re.DOTALL)
    
    for match in country_matches:
        country_name = match.group(1)
        stations_data = match.group(2)
        
        stations = []
        # Find all station entries
        station_matches = re.finditer(r"{n='((?:[^'\\]|\\.)*)',u='((?:[^'\\]|\\.)*)'}", stations_data)
        for station_match in station_matches:
            name = station_match.group(1)
            url = station_match.group(2)
            stations.append({"n": name, "u": url})
        
        if stations:  # Only add countries that have stations
            countries[country_name] = stations
    
    return countries

def remove_duplicates(all_stations):
    """Remove duplicate stations across all countries."""
    url_lookup = {}
    name_lookup = {}
    duplicates_found = 0

    for country, stations in all_stations.items():
        for station in stations:
            norm_url = normalize_url(station['u'])
            norm_name = normalize_name(station['n'])
            
            if norm_url in url_lookup:
                duplicates_found += 1
                print(f"Duplicate URL found: {station['u']}")
                print(f"  In country: {country}")
                print(f"  Original in: {url_lookup[norm_url]['country']}\n")
            else:
                url_lookup[norm_url] = {
                    'station': station,
                    'country': country
                }

            if norm_name in name_lookup:
                print(f"Note: Similar name found: '{station['n']}' in {country}")
                print(f"  Similar to: '{name_lookup[norm_name]['station']['n']}' in {name_lookup[norm_name]['country']}\n")
            else:
                name_lookup[norm_name] = {
                    'station': station,
                    'country': country
                }

    cleaned_stations = {}
    for country, stations in all_stations.items():
        cleaned_stations[country] = []
        seen_urls = set()
        
        for station in stations:
            norm_url = normalize_url(station['u'])
            if norm_url not in seen_urls:
                seen_urls.add(norm_url)
                cleaned_stations[country].append(station)

    print(f"Total duplicates removed: {duplicates_found}")
    return cleaned_stations

def generate_lua_content(country, stations):
    """Generate Lua content for a single country."""
    content = f"['{country}']={{"
    for station in stations:
        content += f"{{n='{station['n']}',u='{station['u']}'}},"
    content += "}"
    return content

def estimate_content_size(content):
    """Estimate the size of content in bytes when written to file."""
    return len(("return{" + content + "}").encode('utf-8'))

def pack_countries(cleaned_stations, max_file_size=63 * 1024):
    """Pack countries into files using a more efficient bin-packing algorithm."""
    # Calculate size for each country
    country_sizes = {}
    for country, stations in cleaned_stations.items():
        content = generate_lua_content(country, stations)
        country_sizes[country] = len(content.encode('utf-8'))

    # Sort countries by size in descending order
    sorted_countries = sorted(country_sizes.items(), key=lambda x: x[1], reverse=True)

    # Initialize files
    files = [{"content": "", "size": len("return{}".encode('utf-8')), "countries": []}]

    # Pack countries into files
    for country, size in sorted_countries:
        # Try to find the best fit file
        best_fit = None
        min_remaining_space = float('inf')

        for file in files:
            remaining_space = max_file_size - file["size"]
            # Add extra bytes for comma if not first country
            extra_bytes = 0 if not file["countries"] else 1
            if size + extra_bytes <= remaining_space:
                if remaining_space < min_remaining_space:
                    min_remaining_space = remaining_space
                    best_fit = file

        # If no file can fit this country, create a new file
        if best_fit is None:
            if size + len("return{}".encode('utf-8')) > max_file_size:
                raise ValueError(f"Country {country} is too large to fit in a single file!")
            best_fit = {"content": "", "size": len("return{}".encode('utf-8')), "countries": []}
            files.append(best_fit)

        # Add country to the best fit file
        content = generate_lua_content(country, cleaned_stations[country])
        if best_fit["countries"]:
            best_fit["content"] += ","
            best_fit["size"] += 1
        best_fit["content"] += content
        best_fit["size"] += len(content.encode('utf-8'))
        best_fit["countries"].append(country)

    return files

def main():
    # Fix console encoding for Windows
    if sys.platform.startswith('win'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

    directory = "lua/radio/client/stations"
    os.makedirs(directory, exist_ok=True)
    
    # Read and combine all stations
    all_stations = {}
    for filename in os.listdir(directory):
        if filename.startswith("data_") and filename.endswith(".lua"):
            filepath = os.path.join(directory, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                stations = extract_stations_from_lua(f.read())
                for country, country_stations in stations.items():
                    if country in all_stations:
                        all_stations[country].extend(country_stations)
                    else:
                        all_stations[country] = country_stations

    # Remove duplicates
    print("Checking for duplicates...")
    cleaned_stations = remove_duplicates(all_stations)

    # Pack stations into files
    try:
        packed_files = pack_countries(cleaned_stations)
        
        # Write files
        for i, file_data in enumerate(packed_files, 1):
            filename = f"data_{i}.lua"
            filepath = os.path.join(directory, filename)
            
            content = "return{" + file_data["content"] + "}"
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            
            file_size = len(content.encode('utf-8'))
            print(f"\nGenerated {filename}: {file_size/1024:.2f}KB")
            print(f"Countries in file: {len(file_data['countries'])}")
            print(f"Countries: {', '.join(file_data['countries'])}")

        # Print final statistics
        total_stations = sum(len(stations) for stations in cleaned_stations.values())
        print(f"\nFinal Statistics:")
        print(f"Total countries: {len(cleaned_stations)}")
        print(f"Total stations: {total_stations}")
        print(f"Total files: {len(packed_files)}")

    except ValueError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
