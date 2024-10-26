import os
import re
import asyncio
import aiofiles
import zlib
from typing import Dict, List, Any, Set, Tuple
import logging
import lzma
import base64
import json
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StationPacker:
    def __init__(self, input_directory: str, size_limit: int = 63 * 1024):
        self.input_directory = input_directory
        self.output_directory = os.path.join(os.getcwd(), "packed")
        self.size_limit = size_limit
        self.all_stations: Dict[str, List[Dict[str, str]]] = {}
        self.common_patterns = {
            'urls': {},
            'prefixes': {},
            'domains': {}
        }
        
        # Create output directory if it doesn't exist
        if not os.path.exists(self.output_directory):
            os.makedirs(self.output_directory)

        # Add lookup tables for common strings
        self.string_lookup = {
            'domains': {},
            'paths': {},
            'params': {},
            'names': {},
            'common_words': set()
        }
        self.reverse_lookup = {}
        self.next_id = 0

    async def load_station_data(self, file_path: str) -> List[Dict[str, str]]:
        async with aiofiles.open(file_path, 'r', encoding='utf-8') as f:
            content = await f.read()
        return self.parse_lua_content(content)

    @staticmethod
    def parse_lua_content(content: str) -> List[Dict[str, str]]:
        """Parse Lua station data content"""
        # Remove comments and normalize newlines
        content = re.sub(r'--.*?\n', '\n', content)
        
        # Extract the stations table content
        match = re.search(r'local stations\s*=\s*{(.*)}.*return stations', content, re.DOTALL)
        if not match:
            logger.error("Could not find stations table in content")
            return []
            
        table_content = match.group(1)
        
        # Find all station entries
        stations = []
        pattern = r'{[\s\n]*name[\s\n]*=[\s\n]*"([^"]+)"[\s\n]*,[\s\n]*url[\s\n]*=[\s\n]*"([^"]+)"[\s\n]*}'
        
        matches = re.finditer(pattern, table_content)
        for match in matches:
            name = match.group(1).replace('\\"', '"')
            url = match.group(2).replace('\\"', '"')
            if name and url:  # Only add if both name and url are present
                stations.append({'n': name, 'u': url})
        
        if not stations:
            # Log the content for debugging
            logger.debug(f"No stations found in content: {table_content[:200]}")
        else:
            logger.debug(f"Successfully parsed {len(stations)} stations")
        
        return stations

    def collect_common_patterns(self):
        """Collect common URL patterns and create lookup tables"""
        for country_stations in self.all_stations.values():
            for station in country_stations:
                url = station['u']
                
                # Store domains
                domain = re.match(r'https?://([^/]+)', url)
                if domain:
                    domain_str = domain.group(1)
                    self.common_patterns['domains'][domain_str] = self.common_patterns['domains'].get(domain_str, 0) + 1
                
                # Store URL prefixes
                prefix = url[:20]
                self.common_patterns['prefixes'][prefix] = self.common_patterns['prefixes'].get(prefix, 0) + 1
                
                # Store common URL patterns
                parts = url.split('/')
                if len(parts) > 3:
                    pattern = '/'.join(parts[:3]) + '/'
                    self.common_patterns['urls'][pattern] = self.common_patterns['urls'].get(pattern, 0) + 1

        # Keep only frequently occurring patterns
        threshold = 3
        for pattern_type in self.common_patterns:
            self.common_patterns[pattern_type] = {
                k: i for i, (k, v) in enumerate(
                    sorted(
                        [(k, v) for k, v in self.common_patterns[pattern_type].items() if v >= threshold],
                        key=lambda x: x[1],
                        reverse=True
                    )
                )
            }

    def get_next_id(self) -> str:
        """Generate short IDs for lookup tables"""
        chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        id_str = ""
        num = self.next_id
        while num >= 0:
            id_str = chars[num % len(chars)] + id_str
            num = num // len(chars) - 1
        self.next_id += 1
        return id_str

    def build_lookup_tables(self):
        """Build lookup tables for common strings"""
        # Collect all strings
        all_strings = defaultdict(int)
        name_parts = defaultdict(int)
        
        for country_stations in self.all_stations.values():
            for station in country_stations:
                # Process URL parts
                url = station['u']
                url = re.sub(r'^https?://', '', url)
                parts = url.split('/')
                
                if len(parts) > 0:
                    all_strings[parts[0]] += 1  # domain
                for part in parts[1:]:
                    all_strings[part] += 1  # paths
                
                # Process query parameters
                if '?' in url:
                    params = url.split('?')[1].split('&')
                    for param in params:
                        all_strings[param] += 1
                
                # Process station name words
                words = station['n'].split()
                for word in words:
                    name_parts[word] += 1
        
        # Build lookup tables for frequently occurring strings
        min_occurrences = 3
        for string, count in all_strings.items():
            if count >= min_occurrences and len(string) > 4:
                id_str = self.get_next_id()
                if '.' in string:
                    self.string_lookup['domains'][string] = id_str
                else:
                    self.string_lookup['paths'][string] = id_str
                self.reverse_lookup[id_str] = string
        
        # Build name word lookup
        for word, count in name_parts.items():
            if count >= min_occurrences and len(word) > 3:
                id_str = self.get_next_id()
                self.string_lookup['names'][word] = id_str
                self.reverse_lookup[id_str] = word

    def compress_string(self, s: str, type: str = 'url') -> str:
        """Compress a string using lookup tables"""
        if type == 'url':
            # Remove protocol
            s = re.sub(r'^https?://', '', s)
            
            # Replace domains
            for domain, id_str in self.string_lookup['domains'].items():
                s = s.replace(domain, f"@{id_str}")
            
            # Replace paths
            for path, id_str in self.string_lookup['paths'].items():
                s = s.replace(path, f"#{id_str}")
            
        elif type == 'name':
            words = s.split()
            compressed_words = []
            for word in words:
                if word in self.string_lookup['names']:
                    compressed_words.append(f"${self.string_lookup['names'][word]}")
                else:
                    compressed_words.append(word)
            s = ' '.join(compressed_words)
        
        return s

    def compress_station_data(self, stations: Dict[str, List[Dict[str, str]]]) -> Dict:
        """Compress station data using advanced compression techniques"""
        logger.info("Building lookup tables...")
        self.build_lookup_tables()
        
        compressed_data = {
            'lookup': self.reverse_lookup,
            'data': {}
        }
        
        # Compress station data
        for country, country_stations in stations.items():
            compressed_stations = []
            for station in country_stations:
                compressed_station = {
                    'n': self.compress_string(station['n'], 'name'),
                    'u': self.compress_string(station['u'], 'url')
                }
                compressed_stations.append(compressed_station)
            compressed_data['data'][country] = compressed_stations
        
        # Final compression using LZMA
        json_data = json.dumps(compressed_data)
        lzma_compressed = lzma.compress(json_data.encode('utf-8'))
        base85_encoded = base64.b85encode(lzma_compressed).decode('utf-8')
        
        return base85_encoded

    def lua_encode(self, compressed_data: str) -> str:
        """Generate Lua code for compressed data"""
        # Create the decompression function
        lua_code = [
            "local b85=require'radio/shared/base85'",
            "local lzma=require'radio/shared/lzma'",
            "local json=require'radio/shared/json'",
            f"local d=lzma.decompress(b85.decode[==[{compressed_data}]==])",
            "local t=json.decode(d)",
            "local function r(s) local l=t.lookup for k,v in pairs(l) do s=s:gsub('@'..k,v):gsub('#'..k,v):gsub('$'..k,v) end return s end",
            "local stations={}"
        ]
        
        # Add station data reconstruction
        lua_code.append("for c,s in pairs(t.data) do")
        lua_code.append("  stations[c]={}")
        lua_code.append("  for _,v in ipairs(s) do")
        lua_code.append("    table.insert(stations[c],{n=r(v.n),u=r(v.u)})")
        lua_code.append("  end")
        lua_code.append("end")
        lua_code.append("return stations")
        
        return '\n'.join(lua_code)

    async def save_station_data(self, data: Dict, file_path: str) -> None:
        """Save the packed data to a file"""
        content = self.lua_encode(data)
        async with aiofiles.open(file_path, 'w', encoding='utf-8') as f:
            await f.write(content)

    def get_file_size(self, data: Dict) -> int:
        """Get the size of the encoded data"""
        return len(self.lua_encode(data).encode('utf-8'))

    def optimize_packing(self, output_files: List[Dict]) -> List[Dict]:
        """Optimize the distribution of data across files"""
        # First, try to merge small files
        i = 0
        while i < len(output_files) - 1:
            file1_size = self.get_file_size(output_files[i])
            file2_size = self.get_file_size(output_files[i + 1])
            
            if file1_size + file2_size <= self.size_limit:
                # Merge files
                output_files[i]['data'].update(output_files[i + 1]['data'])
                output_files.pop(i + 1)
            else:
                i += 1

        # Then try to redistribute countries to balance file sizes
        for i in range(len(output_files)):
            current_size = self.get_file_size(output_files[i])
            space_left = self.size_limit - current_size
            
            if space_left < 1024:  # Skip if file is nearly full
                continue
                
            # Look for small countries in other files that could fit
            for j in range(len(output_files)):
                if i == j:
                    continue
                    
                countries_to_move = []
                for country, stations in output_files[j]['data'].items():
                    country_data = {'data': {country: stations}, 'patterns': output_files[j]['patterns']}
                    country_size = self.get_file_size(country_data)
                    if country_size <= space_left:
                        countries_to_move.append(country)
                        space_left -= country_size
                
                # Move countries if found
                for country in countries_to_move:
                    output_files[i]['data'][country] = output_files[j]['data'].pop(country)

        # Remove empty files
        return [f for f in output_files if f['data']]

    async def pack_stations(self) -> None:
        try:
            logger.info("Step 1: Loading stations...")
            await self.load_all_stations()
            if not self.all_stations:
                logger.warning("No stations found to pack.")
                return

            logger.info(f"Step 2: Processing {sum(len(s) for s in self.all_stations.values())} stations from {len(self.all_stations)} countries")
            
            logger.info("Step 3: Collecting patterns...")
            self.collect_common_patterns()
            pattern_count = sum(len(p) for p in self.common_patterns.values())
            logger.info(f"Collected {pattern_count} patterns")
            
            logger.info("Step 4: Compressing data...")
            compressed_data = self.compress_station_data(self.all_stations)
            if not compressed_data:
                logger.error("Failed to compress data")
                return
            
            logger.info(f"Compressed data size: {len(compressed_data)} bytes")
            
            logger.info("Step 5: Validating compressed data...")
            if not self.validate_data(compressed_data):
                logger.error("Data validation failed")
                return
            
            logger.info("Step 6: Saving files...")
            await self.save_packed_files(compressed_data)
            logger.info("Packing complete!")
            
        except Exception as e:
            logger.error(f"Error packing stations: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
            raise

    def pack_into_files(self, compressed_data: Dict) -> List[Dict]:
        output_files = []
        current_file = {'patterns': compressed_data['patterns'], 'data': {}}
        current_size = 0

        # Sort countries by size
        country_sizes = {}
        for country, stations in compressed_data['data'].items():
            country_data = {'patterns': compressed_data['patterns'], 'data': {country: stations}}
            country_sizes[country] = self.get_file_size(country_data)

        sorted_countries = sorted(country_sizes.items(), key=lambda x: x[1], reverse=True)

        for country, size in sorted_countries:
            if current_size + size <= self.size_limit:
                current_file['data'][country] = compressed_data['data'][country]
                current_size += size
            else:
                output_files.append(current_file)
                current_file = {
                    'patterns': compressed_data['patterns'],
                    'data': {country: compressed_data['data'][country]}
                }
                current_size = size

        if current_file['data']:
            output_files.append(current_file)

        return output_files

    async def load_all_stations(self) -> None:
        tasks = []
        for filename in os.listdir(self.input_directory):
            if filename.endswith('.lua') and not filename.startswith('packed_data_'):
                file_path = os.path.join(self.input_directory, filename)
                tasks.append(self.load_file(filename, file_path))
        await asyncio.gather(*tasks)
        logger.info(f"Total countries loaded: {len(self.all_stations)}")

    async def load_file(self, filename: str, file_path: str) -> None:
        """Load and parse a station file"""
        logger.info(f"Loading data from {file_path}")
        try:
            stations = await self.load_station_data(file_path)
            
            # Skip countries with less than 4 stations
            if len(stations) < 4:
                logger.info(f"Skipping {filename} - only {len(stations)} stations")
                return
            
            logger.info(f"Found {len(stations)} stations in {filename}")
            
            country = filename[:-4]  # Remove '.lua' extension
            if country not in self.all_stations:
                self.all_stations[country] = []
            self.all_stations[country].extend(stations)
            
        except Exception as e:
            logger.error(f"Error loading {filename}: {str(e)}")
            # Log the first few lines of the file for debugging
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    sample = f.read(500)
                    logger.debug(f"File sample: {sample}")
            except Exception as e2:
                logger.error(f"Error reading file sample: {str(e2)}")

    async def save_packed_files(self, compressed_data: str) -> None:
        """Save compressed data to files"""
        try:
            # Calculate optimal chunk size
            chunk_size = self.size_limit - 500  # Leave room for Lua code
            total_size = len(compressed_data)
            num_chunks = (total_size + chunk_size - 1) // chunk_size
            
            logger.info(f"Splitting data into {num_chunks} chunks (total size: {total_size} bytes)")
            
            for i in range(num_chunks):
                start = i * chunk_size
                end = min((i + 1) * chunk_size, total_size)
                chunk = compressed_data[start:end]
                
                output_file = os.path.join(self.output_directory, f'packed_data_{i+1}.lua')
                
                try:
                    lua_code = self.lua_encode(chunk)
                    async with aiofiles.open(output_file, 'w', encoding='utf-8') as f:
                        await f.write(lua_code)
                    
                    file_size = os.path.getsize(output_file)
                    logger.info(f"Wrote chunk {i+1}/{num_chunks} to {output_file} ({file_size} bytes)")
                except Exception as e:
                    logger.error(f"Error saving chunk {i+1}: {str(e)}")
                    raise
            
        except Exception as e:
            logger.error(f"Error in save_packed_files: {str(e)}")
            raise

    def validate_data(self, compressed_data: str) -> bool:
        """Validate the compressed data"""
        try:
            # Check if it's a valid base85 string
            decoded = base64.b85decode(compressed_data)
            decompressed = lzma.decompress(decoded)
            data = json.loads(decompressed.decode('utf-8'))
            
            # Validate the decompressed data structure
            if not isinstance(data, dict):
                logger.error("Decompressed data is not a dictionary")
                return False
                
            if 'lookup' not in data or 'data' not in data:
                logger.error("Missing required data components")
                return False
                
            station_count = sum(len(stations) for stations in data['data'].values())
            if station_count == 0:
                logger.error("No stations found in compressed data")
                return False
                
            logger.info(f"Validated data: {station_count} stations, {len(data['lookup'])} lookup entries")
            return True
            
        except Exception as e:
            logger.error(f"Data validation failed: {str(e)}")
            return False

async def pack_stations(input_directory: str, size_limit: int = 63 * 1024) -> None:
    logger.info(f"Starting station packing from {input_directory}")
    packer = StationPacker(input_directory, size_limit)
    await packer.pack_stations()

if __name__ == "__main__":
    input_dir = os.path.join(os.getcwd(), "stations")
    asyncio.run(pack_stations(input_dir))
