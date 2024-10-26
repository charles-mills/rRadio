import os
import json
import re

def extract_stations_from_lua(lua_content):
    """Extract station data from Lua file content."""
    # Find the main return statement content
    match = re.search(r'return\s*{(.+?)}(?=\s*$)', lua_content, re.DOTALL)
    if not match:
        return {}
    
    content = match.group(1)
    
    # Parse the Lua table structure into Python dict
    countries = {}
    
    # Find country entries
    country_matches = re.finditer(r"\['([^']+)'\]=({.+?}),", content, re.DOTALL)
    
    for match in country_matches:
        country_name = match.group(1)
        stations_data = match.group(2)
        
        # Parse stations
        stations = []
        station_matches = re.finditer(r"{n='([^']+)',u='([^']+)'}", stations_data)
        for station_match in station_matches:
            name = station_match.group(1)
            url = station_match.group(2)
            stations.append({"n": name, "u": url})
        
        countries[country_name] = stations
    
    return countries

def calculate_lua_size(country_name, stations):
    """Calculate the size of a country's data when formatted as Lua."""
    lua_content = f"['{country_name}']={{"
    for station in stations:
        lua_content += f"{{n='{station['n']}',u='{station['u']}'}},"
    lua_content += "}},"
    return len(lua_content.encode('utf-8'))

def pack_stations(stations_data, max_file_size=63 * 1024):
    """Pack stations into files optimally."""
    # Calculate size for each country
    country_sizes = {
        country: calculate_lua_size(country, stations)
        for country, stations in stations_data.items()
    }
    
    # Sort countries by size in descending order
    sorted_countries = sorted(
        country_sizes.items(),
        key=lambda x: x[1],
        reverse=True
    )
    
    # Pack countries into files
    files = []
    current_file = {}
    current_size = len("return{".encode('utf-8')) + len("}".encode('utf-8'))
    
    for country, size in sorted_countries:
        # If country is too big for a single file, we need to split it
        if size > max_file_size - len("return{}".encode('utf-8')):
            # Handle large countries by splitting their stations
            stations = stations_data[country]
            current_chunk = []
            chunk_size = len(f"['{country}']={{".encode('utf-8'))
            
            for station in stations:
                station_lua = f"{{n='{station['n']}',u='{station['u']}'}},"
                station_size = len(station_lua.encode('utf-8'))
                
                if chunk_size + station_size > max_file_size - len("return{}".encode('utf-8')):
                    # Save current chunk
                    if current_chunk:
                        files.append({f"{country}_part_{len(files)}": current_chunk})
                    current_chunk = [station]
                    chunk_size = len(f"['{country}']={{".encode('utf-8')) + station_size
                else:
                    current_chunk.append(station)
                    chunk_size += station_size
            
            if current_chunk:
                files.append({f"{country}_part_{len(files)}": current_chunk})
            
        # If adding this country would exceed file size, start a new file
        elif current_size + size > max_file_size:
            files.append(current_file)
            current_file = {country: stations_data[country]}
            current_size = len("return{".encode('utf-8')) + size + len("}".encode('utf-8'))
        else:
            current_file[country] = stations_data[country]
            current_size += size
    
    if current_file:
        files.append(current_file)
    
    return files

def generate_lua_file(data):
    """Generate Lua file content from packed data."""
    content = "return{"
    for country, stations in data.items():
        content += f"['{country}']={{"
        for station in stations:
            content += f"{{n='{station['n']}',u='{station['u']}'}},"
        content += "}},"
    content += "}"
    return content

def main():
    # Read all existing station files
    stations_data = {}
    directory = "lua/radio/client/stations"
    
    # Create directory if it doesn't exist
    os.makedirs(directory, exist_ok=True)
    
    # Read existing files
    for filename in os.listdir(directory):
        if filename.startswith("data_") and filename.endswith(".lua"):
            filepath = os.path.join(directory, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                stations_data.update(extract_stations_from_lua(content))
            # Delete old file
            os.remove(filepath)
    
    # Pack stations optimally
    packed_files = pack_stations(stations_data)
    
    # Generate new files
    total_size = 0
    for i, file_data in enumerate(packed_files, 1):
        filename = f"data_{i}.lua"
        filepath = os.path.join(directory, filename)
        content = generate_lua_file(file_data)
        
        # Write to file
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Calculate and print statistics
        file_size = len(content.encode('utf-8'))
        total_size += file_size
        print(f"Generated {filename}: {file_size/1024:.2f}KB")
    
    print(f"\nTotal files: {len(packed_files)}")
    print(f"Total size: {total_size/1024:.2f}KB")
    print(f"Average file size: {(total_size/len(packed_files))/1024:.2f}KB")

if __name__ == "__main__":
    main()