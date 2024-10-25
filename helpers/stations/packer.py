import os
import re
import asyncio
import aiofiles
from typing import Dict, List, Any
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StationPacker:
    def __init__(self, input_directory: str, size_limit: int = 63 * 1024):
        self.input_directory = input_directory
        self.size_limit = size_limit
        self.all_stations: Dict[str, List[Dict[str, str]]] = {}

    async def load_station_data(self, file_path: str) -> List[Dict[str, str]]:
        async with aiofiles.open(file_path, 'r', encoding='utf-8') as f:
            content = await f.read()
        return self.parse_lua_content(content)

    @staticmethod
    def parse_lua_content(content: str) -> List[Dict[str, str]]:
        content = re.sub(r'^local stations = |return stations$', '', content.strip())
        station_pattern = r"\{name\s*=\s*\"(.*?)\",\s*url\s*=\s*\"(.*?)\"\}"
        stations = re.findall(station_pattern, content, re.DOTALL)
        return [{'n': name, 'u': url} for name, url in stations]

    @staticmethod
    def lua_encode(data: Dict[str, List[Dict[str, str]]]) -> str:
        result = []
        for country, stations in data.items():
            result.append(f"['{country}']={{")
            for station in stations:
                result.append(f"{{n='{station['n']}',u='{station['u']}'}},")
            result.append("},")
        return ''.join(result)

    async def save_station_data(self, data: Dict[str, List[Dict[str, str]]], file_path: str) -> None:
        content = f"return{{{self.lua_encode(data)}}}"
        async with aiofiles.open(file_path, 'w', encoding='utf-8') as f:
            await f.write(content)

    def get_file_size(self, data: Dict[str, List[Dict[str, str]]]) -> int:
        return len(f"return{{{self.lua_encode(data)}}}".encode('utf-8'))

    async def pack_stations(self) -> None:
        try:
            await self.load_all_stations()
            if not self.all_stations:
                logger.warning("No stations found to pack.")
                return

            output_files = self.pack_into_files()
            await self.save_packed_files(output_files)
            logger.info(f"Packed stations into {len(output_files)} files.")
        except Exception as e:
            logger.error(f"Error packing stations: {e}")

    async def load_all_stations(self) -> None:
        tasks = []
        for filename in os.listdir(self.input_directory):
            if filename.endswith('.lua') and not filename.startswith('packed_data_'):
                file_path = os.path.join(self.input_directory, filename)
                tasks.append(self.load_file(filename, file_path))
        await asyncio.gather(*tasks)
        logger.info(f"Total countries loaded: {len(self.all_stations)}")

    async def load_file(self, filename: str, file_path: str) -> None:
        logger.info(f"Loading data from {file_path}")
        stations = await self.load_station_data(file_path)
        country = filename[:-4]  # Remove '.lua' extension
        if country not in self.all_stations:
            self.all_stations[country] = []
        self.all_stations[country].extend(stations)

    def pack_into_files(self) -> List[Dict[str, List[Dict[str, str]]]]:
        output_files = []
        current_file = {}
        current_size = 0

        # Calculate size for each country
        country_sizes = {country: self.get_file_size({country: stations}) for country, stations in self.all_stations.items()}

        # Sort countries by size (largest first)
        sorted_countries = sorted(country_sizes.items(), key=lambda x: x[1], reverse=True)

        def try_add_country(country: str, size: int) -> bool:
            nonlocal current_file, current_size
            if current_size + size <= self.size_limit:
                current_file[country] = self.all_stations[country]
                current_size += size
                return True
            return False

        for country, size in sorted_countries:
            if not try_add_country(country, size):
                output_files.append(current_file)
                current_file = {country: self.all_stations[country]}
                current_size = size

        if current_file:
            output_files.append(current_file)

        # Try to fit smaller countries into existing files
        for i, file_data in enumerate(output_files):
            remaining_space = self.size_limit - self.get_file_size(file_data)
            for country, size in sorted_countries:
                if country not in file_data and size <= remaining_space:
                    file_data[country] = self.all_stations[country]
                    remaining_space -= size
                    sorted_countries = [(c, s) for c, s in sorted_countries if c != country]

        # Remove empty files and consolidate
        output_files = [file_data for file_data in output_files if file_data]

        return output_files

    async def save_packed_files(self, output_files: List[Dict[str, List[Dict[str, str]]]]) -> None:
        for i, file_data in enumerate(output_files, 1):
            output_file = os.path.join(self.input_directory, f'packed_data_{i}.lua')
            logger.info(f"Saving file: {output_file} ({len(file_data)} countries)")
            await self.save_station_data(file_data, output_file)

async def pack_stations(input_directory: str, size_limit: int = 63 * 1024) -> None:
    packer = StationPacker(input_directory, size_limit)
    await packer.pack_stations()

if __name__ == "__main__":
    asyncio.run(main())
