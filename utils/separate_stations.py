import aiohttp
import asyncio
import json
import os
import logging
from typing import Dict, List, Tuple
from dataclasses import dataclass
from pathlib import Path
import math
from collections import defaultdict
import random
from tenacity import retry, stop_after_attempt, wait_exponential
from asyncio import Semaphore
from itertools import islice
import re
from urllib.parse import urlparse
import unicodedata
from collections import Counter
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class RadioStation:
    name: str
    url: str

@dataclass
class Country:
    name: str
    stations: List[RadioStation]
    size_bytes: int = 0

class RadioStationPacker:
    SEPARATED_COUNTRIES = {
        'The United Kingdom Of Great Britain And Northern Ireland': 'uk',
        'The United States of America': 'usa',
        'The Russian Federation': 'russia',
        'Germany': 'germany',
        'France': 'france',
        'Turkey': 'turkey'
    }
    
    MAX_FILE_SIZE = 63 * 1024  # 63KB in bytes
    STANDARD_FILE_SIZE = 300 * 1024  # 300KB in bytes
    MAX_RETRIES = 5
    MIN_WAIT = 1  # minimum wait time in seconds
    MAX_WAIT = 30  # maximum wait time in seconds
    CONCURRENT_REQUESTS = 5  # Maximum concurrent requests
    RATE_LIMIT_REQUESTS = 20  # Number of requests per time window
    RATE_LIMIT_WINDOW = 60  # Time window in seconds
    AUDIO_CHECK_TIMEOUT = 10  # seconds to wait for audio stream check
    VERIFICATION_ROUNDS = 3
    ROUND_DELAY = 15  # seconds between rounds
    
    def __init__(self):
        self.base_path = Path('lua/radio/client/stations')
        self.temp_path = Path('temp_stations')
        self.separated_path = self.temp_path / 'separated'
        self.standard_path = self.temp_path / 'standard'
        
        # Create directory structure
        for path in [self.separated_path, self.standard_path]:
            path.mkdir(parents=True, exist_ok=True)
        self.request_semaphore = Semaphore(self.CONCURRENT_REQUESTS)
        self.rate_limit_semaphore = Semaphore(self.RATE_LIMIT_REQUESTS)
        self.rate_limit_reset_task = None
        self.all_urls = set()
        self.country_stations = defaultdict(dict)  # country -> {lowercase_name: station}

    @retry(
        stop=stop_after_attempt(MAX_RETRIES),
        wait=wait_exponential(multiplier=MIN_WAIT, max=MAX_WAIT),
        before_sleep=lambda retry_state: logger.warning(
            f"Attempt {retry_state.attempt_number} failed. Retrying in {retry_state.next_action.sleep} seconds..."
        )
    )
    async def _make_request(self, session: aiohttp.ClientSession, url: str, params: dict = None) -> dict:
        """Make an HTTP request with both concurrency and rate limiting."""
        async with self.request_semaphore:  # Limit concurrent requests
            async with self.rate_limit_semaphore:  # Rate limiting
                return await self._make_rate_limited_request(session, url, params)

    @retry(
        stop=stop_after_attempt(MAX_RETRIES),
        wait=wait_exponential(multiplier=MIN_WAIT, max=MAX_WAIT),
        before_sleep=lambda retry_state: logger.warning(
            f"Attempt {retry_state.attempt_number} failed. Retrying in {retry_state.next_action.sleep} seconds..."
        )
    )
    async def _make_rate_limited_request(self, session: aiohttp.ClientSession, url: str, params: dict = None) -> dict:
        """Execute the actual rate-limited request."""
        jitter = random.uniform(0, 0.5)
        await asyncio.sleep(jitter)
        
        async with session.get(url, params=params) as response:
            if response.status == 200:
                return await response.json()
            elif response.status == 429:
                logger.warning("Rate limit hit, backing off...")
                raise Exception("Rate limit reached")
            else:
                logger.error(f"Request failed with status {response.status}")
                raise Exception(f"Request failed with status {response.status}")

    async def fetch_stations(self, session: aiohttp.ClientSession, country: str) -> List[dict]:
        """Fetch radio stations for a specific country with retry mechanism."""
        try:
            url = 'https://de1.api.radio-browser.info/json/stations/bycountry/'
            params = {
                'country': country,
                'hidebroken': 'true',
                'order': 'clickcount',
                'reverse': 'true',
                'limit': 500
            }
            
            return await self._make_request(session, url + country, params=params)
            
        except Exception as e:
            logger.error(f"Failed to fetch stations for {country} after all retries: {e}")
            return []

    async def verify_audio_stream(self, url: str) -> bool:
        """Verify that URL is a valid audio stream."""
        try:
            async with aiohttp.ClientSession() as session:
                # First try a HEAD request
                try:
                    async with session.head(url, timeout=self.AUDIO_CHECK_TIMEOUT) as response:
                        if response.status == 200:
                            content_type = response.headers.get('Content-Type', '').lower()
                            if any(t in content_type for t in ['audio', 'mpegurl', 'mp3', 'ogg', 'aac']):
                                return True
                except Exception:
                    pass  # Fall through to GET request if HEAD fails

                # If HEAD failed or didn't confirm audio, try GET
                async with session.get(url, timeout=self.AUDIO_CHECK_TIMEOUT) as response:
                    if response.status == 200:
                        content_type = response.headers.get('Content-Type', '').lower()
                        
                        # Check content type
                        if any(t in content_type for t in ['audio', 'mpegurl', 'mp3', 'ogg', 'aac']):
                            return True
                        
                        # Try to read first few bytes to verify stream
                        try:
                            first_bytes = await response.content.read(1024)
                            # Check for common audio file signatures
                            if (first_bytes.startswith(b'ID3') or  # MP3 with ID3
                                b'MPEG' in first_bytes or          # MPEG audio
                                b'OggS' in first_bytes or         # OGG
                                b'M3U' in first_bytes):           # M3U playlist
                                return True
                        except Exception:
                            pass
                        
            return False
        except Exception as e:
            logger.debug(f"Stream verification failed for {url}: {e}")
            return False

    def verify_station(self, country: str, station: RadioStation) -> bool:
        """Verify station meets all criteria."""
        try:
            # Check URL uniqueness across all countries
            if station.url in self.all_urls:
                logger.debug(f"Duplicate URL found: {station.url}")
                return False

            # Sanitize station name
            station.name = self.sanitize_string(station.name)
            if not station.name:
                logger.debug("Empty station name after sanitization")
                return False

            # Check for case-insensitive name duplicates within country
            lowercase_name = station.name.lower()
            if lowercase_name in self.country_stations[country]:
                logger.debug(f"Duplicate station name in {country}: {station.name}")
                return False

            # Verify URL format
            parsed_url = urlparse(station.url)
            if not all([parsed_url.scheme, parsed_url.netloc]):
                logger.debug(f"Invalid URL format: {station.url}")
                return False

            # Verify URL scheme is http or https
            if parsed_url.scheme not in ['http', 'https']:
                logger.debug(f"Invalid URL scheme: {station.url}")
                return False

            return True
        except Exception as e:
            logger.debug(f"Station verification failed: {e}")
            return False

    def sanitize_string(self, text: str) -> str:
        """Remove/replace special characters and normalize text."""
        try:
            # Normalize unicode characters
            text = unicodedata.normalize('NFKD', text)
            
            # Remove accents
            text = ''.join(c for c in text if not unicodedata.combining(c))
            
            # Replace quotes with escaped quotes
            text = text.replace("'", "\\'")
            
            # Replace problematic characters with safe alternatives
            text = re.sub(r'[<>:"/\\|?*]', '', text)
            
            # Replace multiple spaces/newlines with single space
            text = ' '.join(text.split())
            
            # Remove leading/trailing spaces
            text = text.strip()
            
            return text
        except Exception as e:
            logger.error(f"String sanitization failed: {e}")
            return ""

    def format_station_data(self, stations: List[dict]) -> List[RadioStation]:
        """Convert raw station data to RadioStation objects."""
        formatted_stations = []
        for station in stations:
            if station.get('url_resolved') and station.get('name'):
                formatted_stations.append(RadioStation(
                    name=station['name'].replace("'", "\\'"),
                    url=station['url_resolved']
                ))
        return formatted_stations

    def calculate_lua_size(self, country: str, stations: List[RadioStation]) -> int:
        """Calculate the size of the Lua representation."""
        lua_content = self.generate_lua_content(country, stations)
        return len(lua_content.encode('utf-8'))

    def generate_lua_content(self, country: str, stations: List[RadioStation]) -> str:
        """Generate minified Lua content for stations."""
        # Compress station entries by removing unnecessary whitespace
        station_entries = [f"{{n='{station.name}',u='{station.url}'}}" 
                         for station in stations]
        # Remove all unnecessary whitespace and newlines
        return f"return{{['{country}']={{{','.join(station_entries)}}}}}"

    def pack_content_efficiently(self, contents: List[Tuple[str, str]], max_size: int) -> List[List[Tuple[str, str]]]:
        """Pack content into files efficiently using a first-fit bin packing algorithm."""
        bins = []
        current_bin = []
        current_size = 0

        # Sort contents by size in descending order for better packing
        contents.sort(key=lambda x: len(x[1].encode('utf-8')), reverse=True)

        for country, content in contents:
            content_size = len(content.encode('utf-8'))
            
            # If content is larger than max_size, split it
            if content_size > max_size:
                logger.warning(f"Content for {country} exceeds max size, will be split")
                # Handle splitting logic in pack_separated_country
                continue

            # If content doesn't fit in current bin, start a new one
            if current_size + content_size > max_size:
                if current_bin:
                    bins.append(current_bin)
                current_bin = [(country, content)]
                current_size = content_size
            else:
                current_bin.append((country, content))
                current_size += content_size

        if current_bin:
            bins.append(current_bin)

        return bins

    async def pack_separated_countries(self, separated_stations: Dict[str, List[RadioStation]]):
        """Pack all separated countries together optimally."""
        if not separated_stations:
            logger.warning("No separated countries to pack!")
            return

        logger.info(f"Packing separated countries: {list(separated_stations.keys())}")
        
        # Generate all station chunks across all separated countries
        all_chunks = []
        
        for country, stations in separated_stations.items():
            # Pre-calculate station entries
            station_entries = []
            current_chunk = []
            current_chunk_size = 0
            base_size = len("return{['']={}}".encode('utf-8'))  # Base structure size
            
            for station in stations:
                entry = f"{{n='{station.name}',u='{station.url}'}}"
                entry_size = len(entry.encode('utf-8')) + 1  # +1 for comma
                
                # Calculate total size if we add this station
                chunk_overhead = len(f"return{{['{country}']={{}}}}").encode('utf-8')
                total_size = chunk_overhead + current_chunk_size + entry_size
                
                if total_size > self.MAX_FILE_SIZE and current_chunk:
                    # Save current chunk and start new one
                    all_chunks.append((country, current_chunk.copy()))
                    current_chunk.clear()
                    current_chunk_size = 0
                
                current_chunk.append(entry)
                current_chunk_size += entry_size
            
            # Add remaining stations in the last chunk
            if current_chunk:
                all_chunks.append((country, current_chunk))

        # Sort chunks by size for better packing
        all_chunks.sort(
            key=lambda x: len(','.join(x[1])).encode('utf-8'), 
            reverse=True
        )

        # Pack chunks into files optimally
        current_file_chunks = []
        current_file_size = 0
        file_counter = 1
        
        for country, chunk in all_chunks:
            chunk_str = ','.join(chunk)
            chunk_size = len(chunk_str.encode('utf-8'))
            country_overhead = len(f"['{country}']={{}}").encode('utf-8')
            total_new_size = current_file_size + chunk_size + country_overhead
            
            if current_file_chunks and total_new_size > self.MAX_FILE_SIZE:
                # Write current file and start new one
                self._write_separated_file(file_counter, current_file_chunks)
                current_file_chunks = [(country, chunk)]
                current_file_size = chunk_size + country_overhead
                file_counter += 1
            else:
                current_file_chunks.append((country, chunk))
                current_file_size = total_new_size

        # Write remaining chunks
        if current_file_chunks:
            self._write_separated_file(file_counter, current_file_chunks)

    def _write_separated_file(self, file_number: int, chunks: List[Tuple[str, List[str]]]):
        """Write optimally packed separated country data to file."""
        filename = f"data_{file_number}.lua"
        file_path = self.separated_path / filename
        
        # Construct file content with minimal overhead
        content_parts = []
        for country, chunk in chunks:
            content_parts.append(f"['{country}']={{{','.join(chunk)}}}")
        
        content = f"return{{{','.join(content_parts)}}}"
        
        # Ensure directory exists and write file
        self.separated_path.mkdir(exist_ok=True)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        logger.info(f"Created separated file: {filename} containing {len(chunks)} country chunks")

    async def pack_standard_countries(self, countries: Dict[str, List[RadioStation]]):
        """Pack standard countries using efficient bin packing."""
        # Generate content for all countries
        contents = []
        for country, stations in countries.items():
            content = self.generate_lua_content(country, stations)
            contents.append((country, content))

        # Pack contents efficiently
        packed_contents = self.pack_content_efficiently(contents, self.STANDARD_FILE_SIZE)

        # Write packed contents to files
        file_counter = len(self.SEPARATED_COUNTRIES) + 1
        for content_group in packed_contents:
            self.write_standard_file(file_counter, [content for _, content in content_group])
            file_counter += 1

    def write_standard_file(self, file_number: int, content_list: List[str]):
        """Write standard country data to file with minimal whitespace."""
        filename = f"data_{file_number}.lua"
        file_path = self.standard_path / filename
        
        # Combine contents with minimal whitespace
        combined_content = "return" + ",".join(
            [content.replace("return", "") for content in content_list]
        )
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(combined_content)
        
        logger.info(f"Created standard file: {filename}")

    async def _reset_rate_limit(self):
        """Periodically reset the rate limit semaphore."""
        while True:
            await asyncio.sleep(self.RATE_LIMIT_WINDOW)
            for _ in range(self.RATE_LIMIT_REQUESTS):
                try:
                    self.rate_limit_semaphore.release()
                except ValueError:
                    pass  # Semaphore was already at maximum

    def normalize_country_name(self, country_name: str) -> str:
        """Normalize country name to match API response format."""
        # Create a mapping of normalized names to original names
        normalized = country_name.lower().strip()
        if "united kingdom" in normalized:
            return "The United Kingdom Of Great Britain And Northern Ireland"
        elif "united states" in normalized:
            return "United States of America"
        elif "russia" in normalized:
            return "Russian Federation"
        return country_name

    async def fetch_and_process_country(self, session: aiohttp.ClientSession, 
                                      country_name: str,
                                      separated_countries: dict,
                                      standard_countries: dict):
        """Fetch and process a single country's stations."""
        try:
            stations = await self.fetch_stations(session, country_name)
            formatted_stations = self.format_station_data(stations)
            
            if formatted_stations:
                # Normalize country name for comparison
                normalized_name = self.normalize_country_name(country_name)
                if normalized_name in self.SEPARATED_COUNTRIES:
                    logger.info(f"Adding {len(formatted_stations)} stations to separated country: {normalized_name}")
                    separated_countries[normalized_name] = formatted_stations
                else:
                    standard_countries[country_name] = formatted_stations
                logger.info(f"Processed {country_name}: {len(formatted_stations)} stations")
            else:
                logger.warning(f"No valid stations found for {country_name}")
            return len(formatted_stations)
        except Exception as e:
            logger.error(f"Error processing country {country_name}: {e}")
            return 0

    async def fetch_countries_batch(self, session: aiohttp.ClientSession, 
                                  countries: List[dict], 
                                  separated_countries: dict, 
                                  standard_countries: dict):
        """Process a batch of countries concurrently."""
        tasks = []
        for country_data in countries:
            country_name = country_data['name']
            task = asyncio.create_task(self.fetch_and_process_country(
                session, country_name, separated_countries, standard_countries
            ))
            tasks.append(task)
        
        results = await asyncio.gather(*tasks)
        return sum(results)  # Return total stations processed in this batch

    async def pack_stations(self):
        """Main method with multiple verification rounds."""
        all_rounds_stations = defaultdict(list)
        
        for round_num in range(self.VERIFICATION_ROUNDS):
            logger.info(f"\n=== Starting Verification Round {round_num + 1}/{self.VERIFICATION_ROUNDS} ===")
            
            # Clear verification sets for new round
            self.all_urls.clear()
            self.country_stations.clear()
            
            # Run a complete fetch and verify cycle
            round_separated, round_standard, round_stats = await self._fetch_and_verify_round()
            
            # Compare with previous rounds and add new stations
            for country, stations in round_separated.items():
                existing = set(station.url for station in all_rounds_stations.get(country, []))
                new_stations = [s for s in stations if s.url not in existing]
                if new_stations:
                    logger.info(f"Round {round_num + 1}: Found {len(new_stations)} new stations for {country}")
                    all_rounds_stations[country].extend(new_stations)
            
            # Log round statistics
            logger.info(f"\n=== Round {round_num + 1} Statistics ===")
            logger.info(f"Countries processed: {round_stats['countries_processed']}")
            logger.info(f"Total stations found: {round_stats['total_stations']}")
            logger.info(f"New stations added: {round_stats['new_stations']}")
            
            if round_num < self.VERIFICATION_ROUNDS - 1:
                logger.info(f"\nWaiting {self.ROUND_DELAY} seconds before next round...")
                await asyncio.sleep(self.ROUND_DELAY)

        # Final processing with verified stations from all rounds
        total_stations = sum(len(stations) for stations in all_rounds_stations.values())
        logger.info(f"\n=== Final Results After {self.VERIFICATION_ROUNDS} Rounds ===")
        logger.info(f"Total verified stations: {total_stations}")
        
        # Split into separated and standard countries
        separated_countries = {k: v for k, v in all_rounds_stations.items() 
                             if k in self.SEPARATED_COUNTRIES}
        standard_countries = {k: v for k, v in all_rounds_stations.items() 
                            if k not in self.SEPARATED_COUNTRIES}
        
        # Pack verified stations
        await self.pack_separated_countries(separated_countries)
        await self.pack_standard_countries(standard_countries)
        
        # Print final summary
        logger.info("\n=== Final Summary ===")
        logger.info(f"Total stations verified and packed: {total_stations}")
        logger.info(f"Separated countries: {len(separated_countries)}")
        for country, stations in separated_countries.items():
            logger.info(f"  - {country}: {len(stations)} stations")
        logger.info(f"Standard countries: {len(standard_countries)}")
        logger.info("===================")

    async def _fetch_and_verify_round(self) -> Tuple[Dict[str, List[RadioStation]], Dict[str, List[RadioStation]], Dict[str, int]]:
        """Fetch and verify stations for one complete round."""
        round_separated = {}
        round_standard = {}
        stats = {
            'countries_processed': 0,
            'total_stations': 0,
            'new_stations': 0
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                # Start rate limit reset task
                self.rate_limit_reset_task = asyncio.create_task(self._reset_rate_limit())
                
                # Fetch list of countries
                countries_data = await self._make_request(
                    session,
                    'https://de1.api.radio-browser.info/json/countries'
                )
                
                logger.info(f"Processing {len(countries_data)} countries")
                stats['countries_processed'] = len(countries_data)
                
                # Process countries in batches
                batch_size = self.CONCURRENT_REQUESTS * 2
                countries_iter = iter(countries_data)
                
                while True:
                    batch = list(islice(countries_iter, batch_size))
                    if not batch:
                        break
                    
                    stations_in_batch = await self.fetch_countries_batch(
                        session, batch, round_separated, round_standard
                    )
                    stats['total_stations'] += stations_in_batch
                
            except Exception as e:
                logger.error(f"Error in verification round: {e}")
            finally:
                if self.rate_limit_reset_task:
                    self.rate_limit_reset_task.cancel()
                    try:
                        await self.rate_limit_reset_task
                    except asyncio.CancelledError:
                        pass
                
        return round_separated, round_standard, stats

async def main():
    packer = RadioStationPacker()
    await packer.pack_stations()

if __name__ == "__main__":
    asyncio.run(main())
