import json
import os
from typing import Dict, List, Tuple
import math
import re

# Size limit in bytes (63KB)
MAX_FILE_SIZE = 63 * 1024

def count_stations(stations_dict: Dict[str, List[Dict]]) -> Tuple[int, int]:
    """Count total number of countries and stations."""
    country_count = len(stations_dict)
    station_count = sum(len(stations) for stations in stations_dict.values())
    return country_count, station_count

def estimate_lua_size(country: str, stations: List[Dict]) -> int:
    """Estimate the size of the Lua representation of stations."""
    # Base template size
    base = len("return{['']={{}}") + len(country)
    
    # Estimate station entries
    station_size = 0
    for station in stations:
        # Account for station template and data
        entry_size = len("{{n='',u=''}},") 
        entry_size += len(station['name']) + len(station['url'])
        station_size += entry_size
    
    return base + station_size

def parse_lua_stations(content: str) -> Dict[str, List[Dict]]:
    """Parse Lua station data into Python dictionary."""
    # Remove 'return' and get the main table content
    content = content.replace('return', '', 1).strip()
    
    # Find all country blocks using improved regex that handles more variations
    country_pattern = r"\['([^']+)'\]\s*=\s*{(.*?)(?=},\['|}\s*$)"
    country_matches = re.finditer(country_pattern, content, re.DOTALL)
    
    stations_dict = {}
    for match in country_matches:
        country = match.group(1)
        stations_block = match.group(2)
        
        # Parse individual station entries with improved regex
        station_pattern = r"{n='((?:[^'\\]|\\.)*)',u='((?:[^'\\]|\\.)*)'}"
        stations = []
        for station_match in re.finditer(station_pattern, stations_block):
            name = station_match.group(1).replace('\\', '')
            url = station_match.group(2).replace('\\', '')
            stations.append({"name": name, "url": url})
        
        if stations:  # Only add if stations were found
            stations_dict[country] = stations
            print(f"Debug: Found {len(stations)} stations for country {country}")
    
    return stations_dict

def find_best_fit_combination(remaining_countries: List[Tuple[str, List[Dict], int]], max_size: int) -> List[Tuple[str, List[Dict], int]]:
    """
    Find the best combination of countries that maximizes space usage while staying under max_size.
    Uses dynamic programming approach for the 0/1 knapsack problem.
    """
    n = len(remaining_countries)
    dp = [[[] for _ in range(max_size + 1)] for _ in range(n + 1)]
    value = [[0 for _ in range(max_size + 1)] for _ in range(n + 1)]

    for i in range(1, n + 1):
        country, stations, size = remaining_countries[i - 1]
        for w in range(max_size + 1):
            if size <= w:
                if value[i - 1][w] < value[i - 1][w - size] + size:
                    value[i][w] = value[i - 1][w - size] + size
                    dp[i][w] = dp[i - 1][w - size] + [(country, stations, size)]
                else:
                    value[i][w] = value[i - 1][w]
                    dp[i][w] = dp[i - 1][w]
            else:
                value[i][w] = value[i - 1][w]
                dp[i][w] = dp[i - 1][w]

    return dp[n][max_size]

def pack_stations(input_files: List[str], output_dir: str):
    """Pack stations optimally into files under MAX_FILE_SIZE."""
    
    print("\nDebug: Starting station packing process")
    print(f"Debug: Looking for files in {input_dir}")
    print(f"Debug: Found {len(input_files)} input files:")
    for f in input_files:
        print(f"  - {f}")
    
    if not input_files:
        print("\nERROR: No input files found!")
        print("Make sure you're running the script from the correct directory")
        print(f"Current working directory: {os.getcwd()}")
        return
    
    # Read and combine all stations
    all_stations: Dict[str, List[Dict]] = {}
    for file in input_files:
        print(f"\nDebug: Processing file {file}")
        try:
            with open(file, 'r', encoding='utf-8') as f:
                content = f.read()
                stations_dict = parse_lua_stations(content)
                all_stations.update(stations_dict)
        except Exception as e:
            print(f"ERROR processing {file}: {str(e)}")
            continue

    # Count initial statistics
    initial_countries, initial_stations = count_stations(all_stations)
    print(f"\nInitial count:")
    print(f"Countries: {initial_countries}")
    print(f"Stations: {initial_stations}\n")

    if initial_countries == 0:
        print("\nERROR: No stations were parsed from the input files!")
        return

    # Create list of countries with their sizes
    country_sizes = []
    for country, stations in all_stations.items():
        size = estimate_lua_size(country, stations)
        country_sizes.append((country, stations, size))

    # Sort by size (largest first)
    country_sizes.sort(key=lambda x: x[2], reverse=True)

    # Initialize output files list
    output_files = []
    packed_stations: Dict[str, List[Dict]] = {}

    # Handle oversized countries first
    remaining_countries = []
    for country, stations, size in country_sizes:
        if size > MAX_FILE_SIZE:
            # Split into multiple files if too large
            stations_per_file = math.floor((MAX_FILE_SIZE - 100) / (size / len(stations)))
            chunks = [stations[i:i + stations_per_file] for i in range(0, len(stations), stations_per_file)]
            
            for i, chunk in enumerate(chunks):
                chunk_country = country + f"_{i}"
                chunk_size = estimate_lua_size(chunk_country, chunk)
                output_files.append({
                    'countries': [(chunk_country, chunk)],
                    'size': chunk_size
                })
                packed_stations[chunk_country] = chunk
        else:
            remaining_countries.append((country, stations, size))

    # Pack remaining countries optimally
    while remaining_countries:
        # Find best combination for current file
        best_combination = find_best_fit_combination(remaining_countries, MAX_FILE_SIZE)
        
        if not best_combination:
            # If no combination found, take the largest remaining country
            country, stations, size = remaining_countries[0]
            best_combination = [(country, stations, size)]

        # Create new file with best combination
        total_size = sum(size for _, _, size in best_combination)
        output_files.append({
            'countries': [(country, stations) for country, stations, _ in best_combination],
            'size': total_size
        })

        # Update packed stations
        for country, stations, _ in best_combination:
            packed_stations[country] = stations

        # Remove packed countries from remaining list
        packed_country_names = set(country for country, _, _ in best_combination)
        remaining_countries = [
            (country, stations, size) 
            for country, stations, size in remaining_countries 
            if country not in packed_country_names
        ]

    # Write output files
    print("\nDebug: Writing output files")
    for i, file_data in enumerate(output_files, 1):
        output_path = os.path.join(output_dir, f'data_{i}.lua')
        content = "return{"
        for country, stations in file_data['countries']:
            content += f"['{country}']={{"
            for station in stations:
                content += f"{{n='{station['name']}',u='{station['url']}'}},"
            content += "},"
        content += "}"
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Debug: Successfully wrote {output_path}")
        except Exception as e:
            print(f"ERROR writing {output_path}: {str(e)}")

    # Count final statistics
    final_countries, final_stations = count_stations(packed_stations)
    
    print(f"\nPacking results:")
    print(f"Packed {len(all_stations)} countries into {len(output_files)} files")
    for i, file_data in enumerate(output_files, 1):
        print(f"File {i}: {file_data['size']/1024:.1f}KB with {len(file_data['countries'])} countries")
        print(f"Space utilization: {(file_data['size'] / MAX_FILE_SIZE) * 100:.1f}%")
    
    print(f"\nFinal count:")
    print(f"Countries: {final_countries} (was {initial_countries})")
    print(f"Stations: {final_stations} (was {initial_stations})")
    
    # Calculate average space utilization
    avg_utilization = sum(f['size'] for f in output_files) / (len(output_files) * MAX_FILE_SIZE) * 100
    print(f"\nAverage space utilization: {avg_utilization:.1f}%")
    
    # Verify no data was lost
    if initial_countries != final_countries or initial_stations != final_stations:
        print("\nWARNING: Data loss detected!")
        print("Some stations or countries were not properly packed")
    else:
        print("\nVerification: All stations and countries preserved successfully")

if __name__ == "__main__":
    # Get the absolute path to the script's directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Go up one directory to get to the root of the project
    project_root = os.path.dirname(os.path.dirname(script_dir))
    
    # Construct paths relative to project root
    input_dir = os.path.join(project_root, "rRadio", "lua", "radio", "client", "stations")
    output_dir = input_dir  # Same as input directory
    
    print(f"\nScript directory: {script_dir}")
    print(f"Project root: {project_root}")
    print(f"Input/Output directory: {input_dir}")
    
    # Ensure the directories exist
    if not os.path.exists(input_dir):
        print(f"\nERROR: Input directory does not exist: {input_dir}")
        exit(1)
    
    # Get input files
    input_files = [
        os.path.join(input_dir, f) 
        for f in os.listdir(input_dir) 
        if f.startswith("data_") and f.endswith(".lua")
    ]
    
    pack_stations(input_files, output_dir)