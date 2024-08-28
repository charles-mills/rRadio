import os
import re

def count_stations_in_file(file_path):
    count = 0
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                count += 1
    return count

def count_total_stations(directory):
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    return total_stations

stations_directory = 'rml-radio/lua/radio/stations'
total_stations = count_total_stations(stations_directory)
print(f'Total number of radio stations: {total_stations}')