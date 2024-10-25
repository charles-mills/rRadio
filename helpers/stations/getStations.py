import os
import re
import aiohttp
import asyncio
import configparser
import argparse
from tqdm import tqdm
from typing import List, Dict
from asyncio import Semaphore
import platform
import aiofiles
import ujson
import mimetypes
import shutil
from packer import pack_stations
from urllib.parse import urlparse

# Configuration setup
class Config:
    def __init__(self):
        print("Initializing configuration...")
        self.config = configparser.ConfigParser()
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(self.script_dir, 'config.ini')
        if os.path.exists(config_file):
            print(f"Reading config file: {config_file}")
            self.config.read(config_file)
        else:
            print(f"Config file not found: {config_file}")
        self.load_defaults()

    def load_defaults(self):
        print("Loading default configuration values...")
        self.STATIONS_DIR = os.path.join(self.script_dir, 'responses')
        self.MAX_CONCURRENT_REQUESTS = int(self.config['DEFAULT'].get('max_concurrent_requests', 60))
        self.API_BASE_URL = self.config['DEFAULT'].get('api_base_url', 'https://de1.api.radio-browser.info/json')
        self.REQUEST_TIMEOUT = int(self.config['DEFAULT'].get('request_timeout', 10))
        self.BATCH_DELAY = int(self.config['DEFAULT'].get('batch_delay', 1))

# Utility functions
class Utils:
    @staticmethod
    def escape_lua_string(s: str) -> str:
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

    @staticmethod
    def clean_station_name(name: str) -> str:
        # Remove leading/trailing whitespace and unwanted characters
        cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name.strip())
        # Apply title case, preserving all-uppercase words
        return ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])

    @staticmethod
    def clean_file_name(name: str) -> str:
        return re.sub(r'[^\w\s-]', '', name).replace(' ', '_').lower()

    @staticmethod
    def normalize_url(url: str) -> str:
        parsed = urlparse(url)
        # Remove http:// or https:// and www. from the beginning of the URL
        normalized = re.sub(r'^(https?://)?(www\.)?', '', parsed.netloc + parsed.path)
        # Remove trailing slash if present
        return normalized.rstrip('/')

# Radio station management class
class RadioStationManager:
    def __init__(self, config: Config):
        print("Initializing RadioStationManager...")
        self.config = config
        self.semaphore = Semaphore(self.config.MAX_CONCURRENT_REQUESTS)
        os.makedirs(self.config.STATIONS_DIR, exist_ok=True)

    async def fetch_stations(self, session: aiohttp.ClientSession, country_name: str, retries: int = 5) -> List[Dict[str, str]]:
        print(f"Fetching stations for country: {country_name}")
        url = f"{self.config.API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
        for attempt in range(retries):
            try:
                async with session.get(url, timeout=self.config.REQUEST_TIMEOUT) as response:
                    if response.status == 200:
                        return await response.json(loads=ujson.loads)
                    elif response.status in (429, 502):
                        print(f"Retrying for {country_name} due to status {response.status}")
                    else:
                        print(f"Unexpected response ({response.status}) for {country_name}")
            except Exception as e:
                print(f"Attempt {attempt + 1} failed for {country_name}: {e}")
            await asyncio.sleep(2 ** attempt)
        print(f"Failed to fetch stations for {country_name} after {retries} attempts.")
        return []

    async def save_stations_to_file(self, country: str, stations: List[Dict[str, str]]):
        print(f"Saving stations for country: {country}")
        directory = self.config.STATIONS_DIR
        os.makedirs(directory, exist_ok=True)
        cleaned_country_name = Utils.clean_file_name(country)
        file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
        file_path = os.path.join(directory, file_name)

        # Use dictionaries to ensure no duplicates
        unique_names = {}
        unique_urls = {}
        filtered_stations = []

        for station in stations:
            name = Utils.clean_station_name(station["name"])
            url = Utils.normalize_url(station["url"])
            
            if name.lower() not in unique_names and url not in unique_urls:
                unique_names[name.lower()] = True
                unique_urls[url] = True
                filtered_stations.append({"name": name, "url": station["url"]})  # Keep original URL for saving
        
        async with aiofiles.open(file_path, "w", encoding="utf-8") as f:
            await f.write("local stations = {\n")
            for station in filtered_stations:
                await f.write(f'    {{name = "{Utils.escape_lua_string(station["name"])}", url = "{Utils.escape_lua_string(station["url"])}"}},\n')
            await f.write("}\n\nreturn stations\n")

        print(f"Saved {len(filtered_stations)} unique stations for {country or 'Other'} to {file_path}")

    async def verify_stations(self, session: aiohttp.ClientSession, stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
        print(f"Verifying {len(stations)} stations...")
        verified_stations = []
        unique_names = set()
        unique_urls = set()

        async def check_station(station):
            try:
                async with self.semaphore:
                    name = Utils.clean_station_name(station["name"])
                    url = Utils.normalize_url(station["url"])
                    
                    if name.lower() not in unique_names and url not in unique_urls:
                        is_valid = await self.is_valid_audio_stream(session, station["url"])
                        if is_valid:
                            unique_names.add(name.lower())
                            unique_urls.add(url)
                            verified_stations.append({"name": name, "url": station["url"]})  # Keep original URL
                        else:
                            print(f"Station {station['name']} is not a valid audio stream.")
                    else:
                        print(f"Duplicate station found: {station['name']} ({station['url']})")
            except Exception as e:
                print(f"Station {station['name']} check failed: {e}")

        await asyncio.gather(*[check_station(station) for station in stations])
        print(f"Verified {len(verified_stations)} unique stations successfully.")
        return verified_stations

    async def is_valid_audio_stream(self, session: aiohttp.ClientSession, url: str) -> bool:
        try:
            async with session.head(url, timeout=self.config.REQUEST_TIMEOUT, allow_redirects=True) as response:
                content_type = response.headers.get('Content-Type', '').lower()
                if self.is_audio_content_type(content_type):
                    return True
                
                # If Content-Type is not conclusive, try GET request
                if content_type in ['application/octet-stream', 'text/plain', '']:
                    return await self.check_audio_content(session, url)
                
                return False
        except Exception as e:
            print(f"Error checking URL {url}: {e}")
            return False

    def is_audio_content_type(self, content_type: str) -> bool:
        audio_types = [
            'audio/', 'application/ogg', 'application/x-ogg',
            'application/octet-stream'  # Some streams use this
        ]
        return any(audio_type in content_type for audio_type in audio_types)

    async def check_audio_content(self, session: aiohttp.ClientSession, url: str) -> bool:
        try:
            async with session.get(url, timeout=self.config.REQUEST_TIMEOUT) as response:
                content = await response.content.read(1024)  # Read first 1KB
                return self.is_audio_content(content)
        except Exception as e:
            print(f"Error reading content from {url}: {e}")
            return False

    def is_audio_content(self, content: bytes) -> bool:
        # Check for common audio file signatures
        audio_signatures = [
            b'ID3',  # MP3
            b'OggS',  # Ogg
            b'fLaC',  # FLAC
            b'RIFF'   # WAV
        ]
        return any(content.startswith(sig) for sig in audio_signatures)

    async def fetch_all_stations(self):
        print("Starting to fetch all stations...")
        countries = await self.get_all_countries()
        async with aiohttp.ClientSession() as session:
            tasks = [self.fetch_save_stations(session, country) for country in countries]
            await asyncio.gather(*tasks)
        print("All stations fetched and saved.")
        await self.compress_and_clean_files()

    async def fetch_save_stations(self, session: aiohttp.ClientSession, country: str):
        print(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            stations = await self.fetch_stations(session, country)
            if stations:
                await self.save_stations_to_file(country, stations)

    async def verify_all_stations(self):
        print("Starting to verify all stations...")
        countries = await self.get_all_countries()
        async with aiohttp.ClientSession() as session:
            tasks = [self.verify_and_save_stations(session, country) for country in countries]
            await asyncio.gather(*tasks)
        print("All stations verified and saved.")
        await self.compress_and_clean_files()

    async def verify_and_save_stations(self, session: aiohttp.ClientSession, country: str):
        print(f"Verifying and saving stations for {country}...")
        file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
        
        if not os.path.exists(file_path):
            print(f"File {file_path} not found. Skipping verification for {country}.")
            return
        
        async with aiofiles.open(file_path, 'r', encoding='utf-8') as f:
            content = await f.read()
        
        stations = re.findall(r'\{name\s*=\s*"(.*?)",\s*url\s*=\s*"(.*?)"\}', content)
        stations = [{"name": name, "url": url} for name, url in stations]

        verified_stations = await self.verify_stations(session, stations)
        if verified_stations:
            await self.save_stations_to_file(country, verified_stations)

    async def get_all_countries(self) -> List[str]:
        print("Fetching list of all countries...")
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{self.config.API_BASE_URL}/countries") as response:
                countries = await response.json(loads=ujson.loads)
        print(f"Found {len(countries)} countries.")
        return [country['name'] for country in countries if Utils.clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

    async def compress_and_clean_files(self):
        print("Compressing and cleaning files...")
        input_directory = self.config.STATIONS_DIR
        
        # Pack the stations
        await pack_stations(input_directory)

        # Remove old files
        for filename in os.listdir(input_directory):
            if filename.endswith('.lua') and not filename.startswith('packed_data_'):
                os.remove(os.path.join(input_directory, filename))

        print("Compression and cleaning completed.")

# Main application logic
async def main_async(auto_run=False, fetch=False, verify=False):
    print("Starting the Radio Station Manager...")
    config = Config()
    manager = RadioStationManager(config)

    if auto_run:
        print("Auto-run mode enabled.")
        print("Fetching and verifying stations...")
        await manager.fetch_all_stations()
        await manager.verify_all_stations()
    elif fetch:
        print("Fetching stations...")
        await manager.fetch_all_stations()
    elif verify:
        print("Verifying stations...")
        await manager.verify_all_stations()
    else:
        print("Interactive mode enabled.")
        while True:
            print("\n--- Radio Station Manager ---")
            print("1 - Fetch and Save Stations")
            print("2 - Verify Stations")
            print("3 - Full Rescan and Verify")
            print("4 - Exit")
            
            choice = input("Select an option: ")

            if choice == '1':
                await manager.fetch_all_stations()
            elif choice == '2':
                await manager.verify_all_stations()
            elif choice == '3':
                await manager.fetch_all_stations()
                await manager.verify_all_stations()
            elif choice == '4':
                print("Exiting...")
                break
            else:
                print("Invalid option. Please try again.")

def main(auto_run=False, fetch=False, verify=False):
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())
    asyncio.run(main_async(auto_run=auto_run, fetch=fetch, verify=verify))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--verify', action='store_true', help='Verify saved stations')
    args = parser.parse_args()

    main(auto_run=args.auto_run, fetch=args.fetch, verify=args.verify)
