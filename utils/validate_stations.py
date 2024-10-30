import asyncio
import aiohttp
import json
import os
import re
from typing import Dict, List, Set
from concurrent.futures import ThreadPoolExecutor
import time
from urllib.parse import urlparse
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('station_validation.log'),
        logging.StreamHandler()
    ]
)

# Constants
MAX_CONCURRENT_REQUESTS = 50
REQUEST_TIMEOUT = 10
MAX_RETRIES = 2
VALID_CONTENT_TYPES = {
    'audio/mpeg', 'audio/mp3', 'application/octet-stream',
    'audio/aac', 'audio/aacp', 'audio/ogg', 'application/ogg',
    'audio/x-mpegurl', 'm3u', 'application/x-mpegurl', 'audio/x-scpls',
    'application/pls+xml', 'audio/x-pn-realaudio'
}

class StationValidator:
    def __init__(self):
        self.valid_stations: Set[str] = set()
        self.invalid_stations: Dict[str, str] = {}
        self.session = None
        self.semaphore = None
        self.start_time = None

    async def init_session(self):
        """Initialize aiohttp session with custom headers and timeout"""
        timeout = aiohttp.ClientTimeout(total=REQUEST_TIMEOUT)
        self.session = aiohttp.ClientSession(
            timeout=timeout,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': '*/*',
                'Connection': 'keep-alive'
            }
        )
        self.semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    async def close_session(self):
        """Close aiohttp session"""
        if self.session:
            await self.session.close()

    async def validate_url(self, country: str, station_name: str, url: str) -> bool:
        """
        Validate a single station URL with retries and proper error handling.
        Returns True if valid, False if invalid.
        """
        for attempt in range(MAX_RETRIES):
            try:
                async with self.semaphore:
                    async with self.session.head(url, allow_redirects=True) as response:
                        if response.status == 200:
                            content_type = response.headers.get('Content-Type', '').lower()
                            
                            # Check if it's a valid audio stream
                            if any(valid_type in content_type for valid_type in VALID_CONTENT_TYPES):
                                self.valid_stations.add(url)
                                return True
                            
                            # If head request doesn't provide enough info, try a GET request
                            async with self.session.get(url, timeout=5) as get_response:
                                if get_response.status == 200:
                                    content = await get_response.content.read(1024)
                                    if content.startswith(b'ID3') or content.startswith(b'OggS'):
                                        self.valid_stations.add(url)
                                        return True

            except (asyncio.TimeoutError, aiohttp.ClientError, Exception) as e:
                if attempt < MAX_RETRIES - 1:
                    await asyncio.sleep(1)
                    continue

            # Only print invalid station name
            print(f"❌ Invalid station: {station_name}")
            self.invalid_stations[url] = {"country": country, "name": station_name}
            return False

    async def process_station_file(self, file_path: str) -> Dict[str, List[Dict]]:
        """Process a single station file and validate all URLs"""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Parse Lua table
        country_pattern = r"\['([^']+)'\]\s*=\s*{(.*?)(?=},\['|}\s*$)"
        station_pattern = r"{n='((?:[^'\\]|\\.)*)',u='((?:[^'\\]|\\.)*)'}"
        
        valid_stations = {}
        tasks = []

        # Find all country blocks
        for country_match in re.finditer(country_pattern, content, re.DOTALL):
            country = country_match.group(1)
            stations_block = country_match.group(2)
            
            valid_stations[country] = []
            
            # Find all stations in this country
            for station_match in re.finditer(station_pattern, stations_block):
                name = station_match.group(1).replace('\\', '')
                url = station_match.group(2).replace('\\', '')
                
                # Create task for URL validation
                task = asyncio.create_task(self.validate_url(country, name, url))
                tasks.append((country, name, url, task))

        # Wait for all validation tasks to complete
        for country, name, url, task in tasks:
            is_valid = await task
            if is_valid:
                valid_stations[country].append({
                    "name": name,
                    "url": url
                })

        return valid_stations

    async def validate_all_stations(self, input_dir: str, output_dir: str):
        """Validate all station files in parallel"""
        self.start_time = time.time()
        await self.init_session()

        try:
            # Verify directories exist
            if not os.path.exists(input_dir):
                raise ValueError(f"Input directory does not exist: {input_dir}")
            if not os.path.exists(output_dir):
                raise ValueError(f"Output directory does not exist: {output_dir}")

            # Get all station files
            input_files = [
                os.path.join(input_dir, f) 
                for f in os.listdir(input_dir) 
                if f.startswith("data_") and f.endswith(".lua")
            ]

            if not input_files:
                raise ValueError(f"No station files found in {input_dir}")

            print(f"\nFound {len(input_files)} station files to process")
            for f in input_files:
                print(f"  - {os.path.basename(f)}")

            # Verify files are readable
            for file in input_files:
                try:
                    with open(file, 'r', encoding='utf-8') as f:
                        f.read()
                except Exception as e:
                    raise ValueError(f"Cannot read file {file}: {str(e)}")

            # Process all files in parallel
            tasks = [self.process_station_file(f) for f in input_files]
            results = await asyncio.gather(*tasks)

            # Combine results
            all_valid_stations = {}
            for result in results:
                for country, stations in result.items():
                    if stations:  # Only add countries with valid stations
                        if country not in all_valid_stations:
                            all_valid_stations[country] = []
                        all_valid_stations[country].extend(stations)

            if not all_valid_stations:
                raise ValueError("No valid stations found after validation")

            # Write validated stations back to files
            from pack_stations import pack_stations
            input_files = [
                os.path.join(output_dir, f) 
                for f in os.listdir(output_dir) 
                if f.startswith("data_") and f.endswith(".lua")
            ]

            # Verify write permissions
            try:
                test_file = os.path.join(output_dir, "write_test.tmp")
                with open(test_file, 'w') as f:
                    f.write("test")
                os.remove(test_file)
            except Exception as e:
                raise ValueError(f"Cannot write to output directory {output_dir}: {str(e)}")

            print("\nAll pre-validation checks passed successfully!")
            pack_stations(input_files, output_dir)

        except Exception as e:
            print(f"\n❌ Error during validation process:")
            print(f"  {str(e)}")
            raise

        finally:
            await self.close_session()

        # Print statistics
        duration = time.time() - self.start_time
        total_stations = len(self.valid_stations) + len(self.invalid_stations)
        
        print("\nValidation Results:")
        print(f"Total stations checked: {total_stations}")
        print(f"Valid stations: {len(self.valid_stations)}")
        print(f"Invalid stations: {len(self.invalid_stations)}")
        print(f"Success rate: {(len(self.valid_stations)/total_stations)*100:.1f}%")
        print(f"Total time: {duration:.2f} seconds")

        # Write detailed report
        report = {
            "statistics": {
                "total_stations": total_stations,
                "valid_stations": len(self.valid_stations),
                "invalid_stations": len(self.invalid_stations),
                "success_rate": (len(self.valid_stations)/total_stations)*100,
                "duration_seconds": duration
            },
            "invalid_stations": self.invalid_stations
        }

        with open('station_validation_report.json', 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

async def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    input_dir = os.path.join(project_root, "rRadio", "lua", "radio", "client", "stations")
    output_dir = input_dir

    validator = StationValidator()
    await validator.validate_all_stations(input_dir, output_dir)

if __name__ == "__main__":
    asyncio.run(main()) 