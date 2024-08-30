include("radio/key_names.lua")
include("radio/config.lua")
local countryTranslations = include("country_translations.lua")

surface.CreateFont("Roboto18", {
    font = "Roboto",
    size = ScreenScale(5),
    weight = 500,
})

surface.CreateFont("HeaderFont", {
    font = "Roboto",
    size = ScreenScale(8),
    weight = 700,
})

local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil

local currentRadioSources = {}
local entityVolumes = {}

local lastMessageTime = -math.huge

local function getEntityConfig(entity)
    if entity:GetClass() == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entity:GetClass() == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    else
        return nil
    end
end

local function updateRadioVolume(station, distance, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    
    if not entityConfig then return end

    local volume = entityVolumes[entity] or entityConfig.Volume
import os
import re
import aiohttp
import asyncio
import requests
import configparser
import logging
import argparse
from tqdm import tqdm
from logging.handlers import RotatingFileHandler
from typing import List, Dict, Tuple, Optional
import shutil
import subprocess
import datetime
from asyncio import Semaphore
import platform

# Configuration setup
class Config:
    def __init__(self):
        print("Initializing configuration...")
        self.config = configparser.ConfigParser()
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(script_dir, 'config.ini')
        if os.path.exists(config_file):
            print(f"Reading config file: {config_file}")
            self.config.read(config_file)
        else:
            logging.warning(f"Config file not found: {config_file}")
        self.load_defaults()

    def load_defaults(self):
        print("Loading default configuration values...")
        self.STATIONS_DIR = self.config['DEFAULT'].get('stations_dir', 'lua/radio/stations')
        self.MAX_CONCURRENT_REQUESTS = int(self.config['DEFAULT'].get('max_concurrent_requests', 5))
        self.API_BASE_URL = self.config['DEFAULT'].get('api_base_url', 'https://de1.api.radio-browser.info/json')
        self.REQUEST_TIMEOUT = int(self.config['DEFAULT'].get('request_timeout', 10))
        self.BATCH_DELAY = int(self.config['DEFAULT'].get('batch_delay', 5))
        self.LOG_FILE = self.config['DEFAULT'].get('log_file', 'logs/radio_station_manager.log')
        self.VERBOSE = self.config['DEFAULT'].getboolean('verbose', False)
        self.README_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'README.md')

# Setup logging with UTF-8 encoding
def setup_logging(log_file, verbose=False):
    print(f"Setting up logging to {log_file}...")
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    handler = RotatingFileHandler(log_file, maxBytes=5*1024*1024, backupCount=5, encoding='utf-8')
    logging.basicConfig(handlers=[handler], level=logging.DEBUG if verbose else logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s')

# Utility functions
class Utils:
    @staticmethod
    def escape_lua_string(s: str) -> str:
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

    @staticmethod
    def clean_station_name(name: str) -> str:
        cleaned_name = re.sub(r'[!\/\.\$\^&\(\)£"£_]', '', name)
        try:
            cleaned_name = ' '.join([word if word.isupper() else word.title() for word in cleaned_name.split()])
        except Exception as e:
            logging.error(f"Error applying title case to name '{name}': {e}")
        return cleaned_name

    @staticmethod
    def clean_file_name(name: str) -> str:
        name = re.sub(r'[^\w\s-]', '', name)
        name = name.replace(' ', '_')
        return name.lower()

    @staticmethod
    def validate_lua_file(file_path: str):
        try:
            result = subprocess.run(['lua', '-p', file_path], check=True, capture_output=True, text=True)
            if result.returncode == 0:
                logging.info(f"Lua file {file_path} is valid.")
            else:
                logging.error(f"Lua validation failed for {file_path}: {result.stderr}")
        except Exception as e:
            logging.error(f"Lua validation failed for {file_path}: {e}")

# Radio station management class
class RadioStationManager:
    def __init__(self, config: Config):
        print("Initializing RadioStationManager...")
        self.config = config
        self.semaphore = Semaphore(self.config.MAX_CONCURRENT_REQUESTS)

    async def fetch_stations(self, session: aiohttp.ClientSession, country_name: str, retries: int = 5) -> List[Dict[str, str]]:
        print(f"Fetching stations for country: {country_name}")
        url = f"{self.config.API_BASE_URL}/stations/bycountry/{country_name.replace(' ', '%20')}"
        for attempt in range(retries):
            try:
                async with session.get(url, timeout=self.config.REQUEST_TIMEOUT, ssl=True) as response:
                    if response.status == 200:
                        print(f"Successfully fetched stations for {country_name}")
                        return await response.json()
                    elif response.status == 429:
                        logging.warning(f"Rate limit exceeded (429) for {country_name}. Retrying...")
                    elif response.status == 502:
                        logging.warning(f"Bad Gateway (502) for {country_name}. Retrying...")
                    else:
                        logging.warning(f"Unexpected response ({response.status}) for {country_name}")
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                logging.error(f"Attempt {attempt + 1} failed for {country_name}: {e}")
            await asyncio.sleep(2 ** attempt)
        print(f"Failed to fetch stations for {country_name} after {retries} attempts.")
        return []

    def save_stations_to_file(self, country: str, stations: List[Dict[str, str]]):
        print(f"Saving stations for country: {country}")
        directory = self.config.STATIONS_DIR
        os.makedirs(directory, exist_ok=True)
        cleaned_country_name = Utils.clean_file_name(country)
        file_name = f"{cleaned_country_name}.lua" if country else "other.lua"
        file_path = os.path.join(directory, file_name)

        # Use sets to ensure no duplicates
        unique_names = set()
        unique_urls = set()
        filtered_stations = []

        for station in stations:
            name = Utils.clean_station_name(station["name"])
            url = station["url"]
            if name.lower() not in unique_names and url not in unique_urls:
                unique_names.add(name.lower())
                unique_urls.add(url)
                filtered_stations.append({"name": name, "url": url})

        with open(file_path, "w", encoding="utf-8") as f:
            f.write("local stations = {\n")
            for station in filtered_stations:
                f.write(f'    {{name = "{Utils.escape_lua_string(station["name"])}", url = "{Utils.escape_lua_string(station["url"])}"}},\n')
            f.write("}\n\nreturn stations\n")

        logging.info(f"Saved stations for {country or 'Other'} to {file_path}")
        Utils.validate_lua_file(file_path)

    def commit_and_push_changes(self, file_path: str, message: str):
        print(f"Committing and pushing changes for file: {file_path}")
        try:
            repo_dir = os.path.dirname(file_path)
            while not os.path.exists(os.path.join(repo_dir, '.git')):
                repo_dir = os.path.dirname(repo_dir)
                if repo_dir == '/' or repo_dir == '':
                    logging.error("Git repository not found.")
                    return
            subprocess.run(["git", "add", file_path], check=True, cwd=repo_dir)
            subprocess.run(["git", "commit", "-m", message], check=True, cwd=repo_dir)
            subprocess.run(["git", "push"], check=True, cwd=repo_dir)
            logging.info(f"Committed and pushed changes: {message}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to commit and push changes: {e}")

    async def verify_stations(self, session: aiohttp.ClientSession, stations: List[Dict[str, str]]) -> List[Dict[str, str]]:
        print(f"Verifying {len(stations)} stations...")
        verified_stations = []
        tasks = [self.check_and_add_station(session, station, verified_stations) for station in stations]
        await asyncio.gather(*tasks)
        print(f"Verified {len(verified_stations)} stations successfully.")
        return verified_stations

    async def check_and_add_station(self, session: aiohttp.ClientSession, station: Dict[str, str], verified_stations: List[Dict[str, str]]):
        try:
            async with session.get(station["url"], timeout=self.config.REQUEST_TIMEOUT, ssl=True) as response:
                if response.status == 200:
                    verified_stations.append(station)
                else:
                    logging.warning(f"Station {station['name']} ({station['url']}) not responsive. Status: {response.status}")
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            logging.error(f"Station {station['name']} ({station['url']}) check failed: {e}")

    async def fetch_all_stations(self):
        print("Starting to fetch all stations...")
        countries = self.get_all_countries()
        with tqdm(total=len(countries), desc="Fetching stations") as pbar:
            async with aiohttp.ClientSession() as session:
                tasks = [self.fetch_save_stations(session, country, pbar) for country in countries]
                await asyncio.gather(*tasks)
        logging.info("All stations fetched and saved.")

    async def fetch_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm):
        print(f"Fetching and saving stations for {country}...")
        async with self.semaphore:
            stations = await self.fetch_stations(session, country)
            if stations:
                self.save_stations_to_file(country, stations)
                file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
                self.commit_and_push_changes(file_path, f"Fetched and saved stations for {country}")
            pbar.update(1)

    async def verify_all_stations(self):
        print("Starting to verify all stations...")
        countries = self.get_all_countries()
        with tqdm(total=len(countries), desc="Verifying stations") as pbar:
            async with aiohttp.ClientSession() as session:
                tasks = [self.verify_and_save_stations(session, country, pbar) for country in countries]
                await asyncio.gather(*tasks)
        logging.info("All stations verified and saved.")

    async def verify_and_save_stations(self, session: aiohttp.ClientSession, country: str, pbar: tqdm):
        print(f"Verifying and saving stations for {country}...")
        file_path = os.path.join(self.config.STATIONS_DIR, f"{Utils.clean_file_name(country)}.lua")
        
        # Check if the file exists before attempting to open it
        if not os.path.exists(file_path):
            logging.warning(f"File {file_path} not found. Skipping verification for {country}.")
            pbar.update(1)
            return
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        stations = re.findall(r'\{name\s*=\s*"(.*?)",\s*url\s*=\s*"(.*?)"\}', content)
        stations = [{"name": name, "url": url} for name, url in stations]

        verified_stations = await self.verify_stations(session, stations)
        if verified_stations:
            self.save_stations_to_file(country, verified_stations)
            self.commit_and_push_changes(file_path, f"Verified and saved stations for {country}")
        pbar.update(1)

    def get_all_countries(self) -> List[str]:
        print("Fetching list of all countries...")
        url = f"{self.config.API_BASE_URL}/countries"
        response = requests.get(url, verify=True)
        countries = response.json()
        print(f"Found {len(countries)} countries.")
        return [country['name'] for country in countries if Utils.clean_file_name(country['name']) != "the_democratic_peoples_republic_of_korea"]

# Main application logic
async def main_async(auto_run=False, fetch=False, verify=False, count=False):
    print("Starting the Radio Station Manager...")
    config = Config()
    setup_logging(config.LOG_FILE, config.VERBOSE)
    manager = RadioStationManager(config)

    if auto_run:
        print("Auto-run mode enabled.")
        if fetch:
            print("Fetching stations...")
            await manager.fetch_all_stations()
        if verify:
            print("Verifying stations...")
            await manager.verify_all_stations()
        if count:
            print("Counting stations and updating README...")
            total_stations = count_total_stations(config.STATIONS_DIR)
            update_readme_with_station_count(config.README_PATH, total_stations)
            manager.commit_and_push_changes(config.README_PATH, f"Update README.md with {total_stations} radio stations")
    else:
        print("Interactive mode enabled.")
        while True:
            print("\n--- Radio Station Manager ---")
            print("1 - Fetch and Save Stations")
            print("2 - Verify Stations")
            print("3 - Count Total Stations and Update README")
            print("4 - Full Rescan, Verify, Update README, and Push Changes")
            print("5 - Exit")
            
            choice = input("Select an option: ")

            if choice == '1':
                await manager.fetch_all_stations()
            elif choice == '2':
                await manager.verify_all_stations()
            elif choice == '3':
                total_stations = count_total_stations(config.STATIONS_DIR)
                update_readme_with_station_count(config.README_PATH, total_stations)
            elif choice == '4':
                await manager.fetch_all_stations()
                await manager.verify_all_stations()
                total_stations = count_total_stations(config.STATIONS_DIR)
                update_readme_with_station_count(config.README_PATH, total_stations)
                manager.commit_and_push_changes(config.README_PATH, f"Update README.md with {total_stations} radio stations")
            elif choice == '5':
                print("Exiting...")
                break
            else:
                print("Invalid option. Please try again.")

def main(auto_run=False, fetch=False, verify=False, count=False):
    # Setting the appropriate event loop policy based on the platform
    if platform.system() == "Windows":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(main_async(auto_run=auto_run, fetch=fetch, verify=verify, count=count))

# Helper functions
def count_total_stations(directory: str) -> int:
    print(f"Counting total stations in directory: {directory}")
    total_stations = 0
    for filename in os.listdir(directory):
        if filename.endswith('.lua'):
            file_path = os.path.join(directory, filename)
            total_stations += count_stations_in_file(file_path)
    print(f"Total stations counted: {total_stations}")
    return total_stations

def count_stations_in_file(file_path: str) -> int:
    count = 0
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            if re.match(r'\s*{\s*name\s*=\s*".*?",\s*url\s*=\s*".*?"\s*},\s*', line):
                count += 1
    return count

def update_readme_with_station_count(readme_path: str, total_stations: int):
    print(f"Updating README.md at {readme_path} with station count: {total_stations}")
    if not os.path.exists(readme_path):
        logging.error(f"README.md not found at {readme_path}")
        return

    try:
        new_readme_content = (
            f"## 🎵 Active Stations: `{total_stations}` 🎵\n\n"
            f"## Description\n"
            f"**rRadio** is a Garry's Mod addon that allows players to listen to their favorite radio stations in-game, either with friends or alone. The stations are regularly fetched via the [Radio Browser API](https://www.radio-browser.info/), and confirmed to be active.\n\n"
            f"## Features\n"
            f"- **Wide Range of Stations**: Access to radio stations from around the world.\n"
            f"- **User-Friendly Interface**: Simple and intuitive UI for easy navigation and station selection.\n"
            f"- **Multiplayer and Singleplayer Support**: Works seamlessly in both modes.\n"
            f"- **Customizable Client-Side Settings**: Personalize the UI to fit your preferences.\n"
            f"- **Adjustable Server-Side Settings**: Modify key values such as audio range and maximum volume.\n\n"
            f"## Installation\n\n"
            f"1. **Download the Addon**: Get the rRadio addon from the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) or clone this repository.\n"
            f"2. **Extract the Files**: Place the extracted addon files into the `addons` folder within your Garry's Mod installation directory.\n"
            f"3. **Enable the Addon**: Launch Garry's Mod and activate the rRadio addon through the Addons menu (if installed via Steam Workshop).\n\n"
            f"## Usage\n\n"
            f"1. **Open the Radio Menu**: Press the designated key (default: `K`) to open the RML Radio menu.\n"
            f"2. **Browse Stations**: Use the mouse to scroll through the list of available radio stations.\n"
            f"3. **Select a Station**: Left-click on a station to start playing it.\n"
            f"4. **Adjust Settings**: Modify the volume and other settings according to your preferences.\n"
            f"5. **Enjoy**: Listen to your favorite radio station while enjoying your Garry's Mod experience!\n"
        )

        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(new_readme_content)

        logging.info(f"Updated README.md with the current station count: {total_stations}")
    except Exception as e:
        logging.error(f"Failed to update README.md: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Radio Station Manager')
    parser.add_argument('--auto-run', action='store_true', help='Automatically run full rescan, save, and verify')
    parser.add_argument('--fetch', action='store_true', help='Fetch and save stations')
    parser.add_argument('--verify', action='store_true', help='Verify saved stations')
    parser.add_argument('--count', action='store_true', help='Count total stations and update README')
    args = parser.parse_args()

    main(auto_run=args.auto_run, fetch=args.fetch, verify=args.verify, count=args.count)

    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    local maxVolume = GetConVar("radio_max_volume"):GetFloat()
    local effectiveVolume = math.min(volume, maxVolume)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    else
        if distance <= entityConfig.MinVolumeDistance then
            station:SetVolume(effectiveVolume)
        elseif distance <= entityConfig.MaxHearingDistance then
            local adjustedVolume = effectiveVolume * (1 - (distance - entityConfig.MinVolumeDistance) / (entityConfig.MaxHearingDistance - entityConfig.MinVolumeDistance))
            station:SetVolume(adjustedVolume)
        else
            station:SetVolume(0)
        end
    end
end

local function PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local currentTime = CurTime()

    if (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge then
        return
    end

    lastMessageTime = currentTime

    local prefixColor = Color(0, 255, 128)
    local keyColor = Color(255, 165, 0)
    local messageColor = Color(255, 255, 255)
    local keyName = GetKeyName(Config.OpenKey)

    local message = Config.Lang["PressKeyToOpen"]:gsub("{key}", keyName)

    chat.AddText(
        prefixColor, "[CAR RADIO] ",
        messageColor, message
    )
end

net.Receive("CarRadioMessage", function()
    PrintCarRadioMessage()
end)

local function Scale(value)
    return value * (ScrW() / 2560)
end

local function formatCountryName(name)
    -- Reformat and then translate the country name
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    local translation = countryTranslations:GetCountryName(lang, formattedName)
    
    return translation
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if backButton and selectedCountry == nil then
        backButton:SetVisible(false)
    end

    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText()
    local lang = GetConVar("radio_language"):GetString() or "en"

    if selectedCountry == nil then
        local countries = {}
        for country, _ in pairs(Config.RadioStations) do
            local translatedCountry = formatCountryName(country)  -- Reformat and translate the country name
            if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        if Config.UKAndUSPrioritised then
            table.sort(countries, function(a, b)
                local UK_OPTIONS = {"United Kingdom", "The United Kingdom", "The_united_kingdom"}
                local US_OPTIONS = {"United States", "The United States Of America", "The_united_states_of_america"}

                if table.HasValue(UK_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(UK_OPTIONS, b.original) then
                    return false
                elseif table.HasValue(US_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(US_OPTIONS, b.original) then
                    return false 
                else
                    return a.translated < b.translated
                end
            end)
        else
            table.sort(countries, function(a, b) return a.translated < b.translated end)
        end

        for _, country in ipairs(countries) do
            local countryButton = vgui.Create("DButton", stationListPanel)
            countryButton:Dock(TOP)
            countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            countryButton:SetTall(Scale(40))
            countryButton:SetText(country.translated)  -- Use the translated country name
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        for _, station in ipairs(Config.RadioStations[selectedCountry]) do
            if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
                local stationButton = vgui.Create("DButton", stationListPanel)
                stationButton:Dock(TOP)
                stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
                stationButton:SetTall(Scale(40))
                stationButton:SetText(station.name)
                stationButton:SetFont("Roboto18")
                stationButton:SetTextColor(Config.UI.TextColor)

                local currentlyPlayingStations = {}

                stationButton.Paint = function(self, w, h)
                    if station == currentlyPlayingStations[LocalPlayer().currentRadioEntity] then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                    else
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                        if self:IsHovered() then
                            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                        end
                    end
                end

                stationButton.DoClick = function()
                    surface.PlaySound("buttons/button17.wav")
                    local entity = LocalPlayer().currentRadioEntity

                    if not IsValid(entity) then
                        return
                    end

                    if currentlyPlayingStations[entity] then
                        net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                        net.SendToServer()
                    end

                    local volume = entityVolumes[entity] or getEntityConfig(entity).Volume
                    net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(station.name)
                    net.WriteString(station.url)
                    net.WriteFloat(volume)
                    net.SendToServer()

                    currentlyPlayingStations[entity] = station
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            end
        end
    end
end

local function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local fontName = "DynamicStopButtonFont"

    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    })

    surface.SetFont(fontName)
    local textWidth, _ = surface.GetTextSize(text)

    while textWidth > buttonWidth * 0.9 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        })
        surface.SetFont(fontName)
        textWidth, _ = surface.GetTextSize(text)
    end

    return fontName
end

local function openRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function() radioMenuOpen = false end

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), Config.UI.HeaderColor, true, true, false, false)
        
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        
        surface.SetFont("HeaderFont")
        local textHeight = select(2, surface.GetTextSize("H"))
        
        local iconOffsetY = Scale(2) + textHeight - iconSize
        
        surface.SetMaterial(Material("hud/radio"))
        surface.SetDrawColor(Config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
        
        draw.SimpleText(selectedCountry and formatCountryName(selectedCountry) or Config.Lang["SelectCountry"], "HeaderFont", iconOffsetX + iconSize + Scale(5), iconOffsetY, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(Config.Lang["SearchPlaceholder"])
    searchBox:SetTextColor(Config.UI.TextColor)
    searchBox:SetDrawBackground(false)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
        self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)

        if self:GetText() == "" then
            draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(200))

    local stopButtonHeight = Scale(Config.UI.FrameSize.width) / 8
    local stopButtonWidth = Scale(Config.UI.FrameSize.width) / 4
    local stopButtonText = Config.Lang["StopRadio"] or "STOP"
    local stopButtonFont = calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(90))
    stopButton:SetSize(stopButtonWidth, stopButtonHeight)
    stopButton:SetText(stopButtonText)
    stopButton:SetFont(stopButtonFont)
    stopButton:SetTextColor(Config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonHoverColor)
        end
    end

    stopButton.DoClick = function()
        surface.PlaySound("buttons/button6.wav")
        local entity = LocalPlayer().currentRadioEntity
        if IsValid(entity) then
            net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
            net.SendToServer()
            currentlyPlayingStation = nil
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end 

    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
    volumePanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
    end

    local volumeIconSize = Scale(50)
    
    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
    volumeIcon:SetSize(volumeIconSize, volumeIconSize)
    volumeIcon:SetImage("hud/volume")

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(volumeIcon:GetWide() - Scale(200), Scale(5))
    volumeSlider:SetSize(volumePanel:GetWide() - volumeIcon:GetWide() + Scale(180), volumePanel:GetTall() - Scale(20))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)
    
    local entity = LocalPlayer().currentRadioEntity
    
    local currentVolume = entityVolumes[entity] or getEntityConfig(entity).Volume
    volumeSlider:SetValue(currentVolume)
    
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, h/2 - 4, w, 16, Config.UI.TextColor)
    end
    
    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
    end
    
    volumeSlider.TextArea:SetVisible(false)

    volumeSlider.OnValueChanged = function(_, value)
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
    end    
    
    local backButton = vgui.Create("DButton", frame)
    backButton:SetSize(Scale(30), Scale(30))
    backButton:SetPos(frame:GetWide() - Scale(79), Scale(5))
    backButton:SetText("")

    backButton.Paint = function(self, w, h)
        draw.NoTexture()
        local arrowSize = Scale(15)
        local arrowOffset = Scale(8)
        local arrowColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.TextColor

        surface.SetDrawColor(arrowColor)
        surface.DrawPoly({
            { x = arrowOffset, y = h / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 - arrowSize / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 + arrowSize / 2 },
        })
    end

    backButton.DoClick = function()
        surface.PlaySound("buttons/lightswitch2.wav")
        selectedCountry = nil
        backButton:SetVisible(false)
        populateList(stationListPanel, backButton, searchBox, true)
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetFont("Roboto18")
    closeButton:SetTextColor(Config.UI.TextColor)
    closeButton:SetSize(Scale(40), Scale(40))
    closeButton:SetPos(frame:GetWide() - Scale(40), 0)
    closeButton.Paint = function(self, w, h)
        local cornerRadius = 8
        draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonColor, false, true, false, false)
        if self:IsHovered() then
            draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonHoverColor, false, true, false, false)
        end
    end
    closeButton.DoClick = function()
        surface.PlaySound("buttons/lightswitch2.wav")
        frame:Close()
    end

    local sbar = stationListPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    populateList(stationListPanel, backButton, searchBox, true)

    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end
end

hook.Add("Think", "OpenCarRadioMenu", function()
    if input.IsKeyDown(Config.OpenKey) and not radioMenuOpen and IsValid(LocalPlayer():GetVehicle()) then
        LocalPlayer().currentRadioEntity = LocalPlayer():GetVehicle()
        openRadioMenu()
    end
end)

net.Receive("PlayCarRadioStation", function()
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    local entityRetryAttempts = 5
    local entityRetryDelay = 0.5  -- Delay in seconds between entity retries

    local function attemptPlayStation(attempt)
        if not IsValid(entity) then
            if attempt < entityRetryAttempts then
                timer.Simple(entityRetryDelay, function()
                    attemptPlayStation(attempt + 1)
                end)
            else
                print("[ERROR] Maximum retry attempts reached. Failed to validate entity.")
            end
            return
        end

        local entityConfig = getEntityConfig(entity)

        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:Stop()
        end

        local function tryPlayStation(playAttempt)
            sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
                if IsValid(station) then
                    station:SetPos(entity:GetPos())
                    station:SetVolume(volume)
                    station:Play()
                    currentRadioSources[entity] = station

                    -- Set 3D fade distance according to the entity's configuration
                    station:Set3DFadeDistance(entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance)

                    -- Update the station's position relative to the entity's movement
                    hook.Add("Think", "UpdateRadioPosition_" .. entity:EntIndex(), function()
                        if IsValid(entity) and IsValid(station) then
                            station:SetPos(entity:GetPos())

                            local playerPos = LocalPlayer():GetPos()
                            local entityPos = entity:GetPos()
                            local distance = playerPos:Distance(entityPos)
                            local isPlayerInCar = LocalPlayer():GetVehicle() == entity

                            updateRadioVolume(station, distance, isPlayerInCar, entity)
                        else
                            hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
                        end
                    end)

                    -- Stop the station if the entity is removed
                    hook.Add("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex(), function(ent)
                        if ent == entity then
                            if IsValid(currentRadioSources[entity]) then
                                currentRadioSources[entity]:Stop()
                            end
                            currentRadioSources[entity] = nil
                            hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex())
                            hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
                        end
                    end)
                else      
                    if playAttempt < entityConfig.RetryAttempts then
                        timer.Simple(entityConfig.RetryDelay, function()
                            tryPlayStation(playAttempt + 1)
                        end)
                    else
                        print("[ERROR] Maximum retry attempts reached. Failed to play station: " .. url)
                    end
                end
            end)
        end

        tryPlayStation(1)
    end

    attemptPlayStation(1)
end)

net.Receive("StopCarRadioStation", function()
    local entity = net.ReadEntity()

    if IsValid(entity) and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
        local entIndex = entity:EntIndex()
        hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entIndex)
        hook.Remove("Think", "UpdateRadioPosition_" .. entIndex)
    end
end)

net.Receive("OpenRadioMenu", function()
    local entity = net.ReadEntity()
    LocalPlayer().currentRadioEntity = entity
    if not radioMenuOpen then
        openRadioMenu()
    end
end)

hook.Add("PlayerInitialSpawn", "ApplySavedThemeAndLanguage", function(ply)
    loadSavedSettings()  -- Load and apply the saved theme and language
end)
