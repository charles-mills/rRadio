--[[
    Radio Addon Shared Configuration
    Author: Charles Mills
    Description: This file contains the main configuration settings for the Radio Addon.
    Date: October 17, 2024
]]--

local Config = {}

-- ------------------------------
--          Imports
-- ------------------------------
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
local themes = include("radio/client/cl_themes.lua") or {}
local keyCodeMapping = include("radio/client/cl_key_names.lua") or {}

-- ------------------------------
--      Configuration Tables
-- ------------------------------

-- Radio Stations Data
Config.RadioStations = {}

-- UI Localization
Config.Lang = {}

-- UI Themes and Settings
Config.UI = {}

-- Boombox Settings
Config.Boombox = {
    Volume = 1.0, -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 800, -- Maximum distance at which the radio can be heard (in units)
    MinVolumeDistance = 500, -- Distance at which the radio volume starts to drop off (in units)
    RetryAttempts = 3, -- Number of retry attempts to play a station in case of failure
    RetryDelay = 2 -- Delay in seconds between retry attempts
}

-- Golden Boombox Settings
Config.GoldenBoombox = {
    Volume = 1.0,
    MaxHearingDistance = 350000,
    MinVolumeDistance = 250000,
    RetryAttempts = 3,
    RetryDelay = 2
}

-- Vehicle Radio Settings
Config.VehicleRadio = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

-- General Settings
Config.MessageCooldown = 1 -- Cooldown time in seconds before the chat message can be sent again
Config.VolumeAttenuationExponent = 0.8

-- ------------------------------
--         ConVars Setup
-- ------------------------------

-- Function to ensure a ConVar exists, else create it
local function EnsureConVar(name, default, flags, helpText)
    if not ConVarExists(name) then
        CreateClientConVar(name, default, flags or FCVAR_ARCHIVE, false, helpText)
    end
    return GetConVar(name)
end

-- Language Selection ConVar
local languageConVar = EnsureConVar(
    "radio_language",
    "en",
    true,
    "Set the language for the radio addon"
)

-- Radio Menu Open Key ConVar
local openKeyConVar = EnsureConVar(
    "car_radio_open_key",
    "21", -- Default to KEY_K
    true,
    "Select the key to open the car radio menu."
)

local radioMaxVolume = EnsureConVar(
    "radio_max_volume", 
    1,
    true,
    "Set the maximum volume for the radio."
)

local radioTheme = EnsureConVar(
    "radio_theme",
    "dark",
    true,
    "Set the theme for the radio."
)

local carRadioShowMessages = EnsureConVar(
    "car_radio_show_messages",
    "1",
    true,
    "Enable or disable car radio messages."
)


-- ------------------------------
--         Language Setup
-- ------------------------------

-- Function to load and set the current language
local function loadLanguage()
    local lang = languageConVar:GetString() or "en"
    LanguageManager:SetLanguage(lang)
    Config.Lang = LanguageManager.translations[lang] or {}
end

-- Initialize Language
loadLanguage()

-- Listen for changes in the language ConVar to update localization dynamically
cvars.AddChangeCallback("radio_language", function(_, _, newValue)
    loadLanguage()
end)

-- ------------------------------
--      Station Data Loading
-- ------------------------------

-- Function to format country names for UI display
local function formatCountryName(rawName)
    return rawName:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
end

-- Function to load stations for a specific country
local function loadStationsForCountry(rawCountryName)
    local formattedName = formatCountryName(rawCountryName)
    local path = "radio/client/stations/" .. rawCountryName .. ".lua"

    if file.Exists(path, "LUA") then
        local stations = include(path)
        if stations then
            Config.RadioStations[formattedName] = stations
        else
            print(string.format("[RadioAddon] Failed to include stations from %s", path))
        end
    else
        print(string.format("[RadioAddon] Station file does not exist: %s", path))
    end
end

-- Dynamically detect and load all country station files
local stationFiles = file.Find("radio/client/stations/*.lua", "LUA")
for _, filename in ipairs(stationFiles) do
    local countryName = string.StripExtension(filename)
    loadStationsForCountry(countryName)
end

-- ------------------------------
--         Theme Setup
-- ------------------------------

-- Default to a specific theme or fallback to the first available theme
local defaultThemeName = "neon"
local selectedTheme = themes[defaultThemeName] or themes[next(themes)] or {}

-- Apply Theme Settings to UI Configuration
Config.UI = selectedTheme

-- ------------------------------
--    Utility and Helper Functions
-- ------------------------------

-- Function to get a localized string
function Config.GetLocalizedString(key)
    return Config.Lang[key] or key
end

-- Function to get translated country name
local function getTranslatedCountryName(country)
    return LanguageManager:GetCountryTranslation(LanguageManager.currentLanguage, country) or country
end

-- ------------------------------
--          Return Config
-- ------------------------------

return Config
