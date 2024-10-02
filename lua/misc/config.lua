--[[ 
    rRadio Addon for Garry's Mod - Client Radio Script
    Description: Sets up the car radio system, including radio stations, themes, network strings, and various settings for different radio devices.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-02
]]

-- ===========================
-- Configuration Table
-- ===========================
local Config = {}

-- ===========================
-- Network Strings
-- ===========================
-- Define network strings for client-server communication
Config.NetworkStrings = {
    "PlayCarRadioStation",
    "StopCarRadioStation",
    "CarRadioMessage",
    "OpenRadioMenu",
    "UpdateRadioStatus",
    "ToggleFavoriteCountry"
}

-- ===========================
-- Language Management
-- =========================--
-- Load the appropriate language file based on user settings or default to English
local function loadLanguage()
    local lang = Config.Language or GetConVar("gmod_language"):GetString() or "en"
    local path = "localisation/lang/" .. lang .. ".lua"

    if file.Exists(path, "LUA") then
        Config.Lang = include(path)
    else
        Config.Lang = include("localisation/lang/en.lua")
    end
end

loadLanguage()

-- ===========================
-- Radio Stations Management
-- ===========================
Config.RadioStations = {}

-- Utility function to format country names for UI display
local function formatCountryName(filename)
    return filename:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
end

-- Load radio stations for a specific country
local function loadStationsForCountry(country)
    local path = "radio/stations/" .. country .. ".lua"
    if file.Exists(path, "LUA") then
        local stations = include(path)
        Config.RadioStations[formatCountryName(country)] = stations -- Store with formatted name for UI
    else
        print("[CarRadio] Warning: Radio stations file not found for country:", country)
    end
end

-- Dynamically detect and load all available country radio stations
local function loadAllRadioStations()
    local files, folders = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(files) do
        local country = string.TrimExtension(filename)
        loadStationsForCountry(country)
    end
end

loadAllRadioStations()

-- ===========================
-- Theme Management
-- ===========================
-- Load available themes
local function loadThemes()
    local themesPath = "themes/theme_palettes.lua"
    if file.Exists(themesPath, "LUA") then
        return include(themesPath) or {}
    else
        print("[CarRadio] Error: Theme palettes file not found.")
        return {}
    end
end

Config.Themes = loadThemes()

-- Select default theme or allow user to set preference
local function selectTheme()
    local defaultTheme = "neon"
    Config.SelectedTheme = Config.Themes[defaultTheme] or next(Config.Themes) or {}
end

selectTheme()

-- ===========================
-- User Interface Settings
-- ===========================
Config.UI = Config.SelectedTheme

-- Priority settings for UK and US radio stations
Config.UKAndUSPrioritised = true -- Set to false for default alphabetical sort

-- Chat message cooldown settings
Config.MessageCooldown = 1 -- Time in seconds before the chat message can be sent again

-- Key binding for opening the radio menu
local function setupOpenKey()
    local openKeyConvar = GetConVar("car_radio_open_key")
    if not openKeyConvar then
        CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
        openKeyConvar = GetConVar("car_radio_open_key")
    end
    Config.OpenKey = openKeyConvar:GetInt()
end

setupOpenKey()

-- ===========================
-- Radio Device Settings
-- ===========================
-- General settings structure
local function createRadioSettings(volume, maxDistance, minDistance, retryAttempts, retryDelay)
    return {
        Volume = volume or 1.0, -- Default volume (0.0 to 1.0)
        MaxHearingDistance = maxDistance or 1000, -- Max distance to hear the radio
        MinVolumeDistance = minDistance or 500, -- Distance where volume starts to decrease
        RetryAttempts = retryAttempts or 3, -- Number of retry attempts on failure
        RetryDelay = retryDelay or 2 -- Delay between retry attempts in seconds
    }
end

-- Boombox Settings
Config.Boombox = createRadioSettings(1.0, 1000, 500, 3, 2)

-- Golden Boombox Settings
Config.GoldenBoombox = createRadioSettings(1.0, 350000, 250000, 3, 2)

-- Vehicle Radio Settings
Config.VehicleRadio = createRadioSettings(1.0, 800, 500, 3, 2)

-- ===========================
-- Return Configuration
-- ===========================
return Config
