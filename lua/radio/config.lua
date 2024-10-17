local Config = {}

Config.RadioStations = {}

-- Import the LanguageManager
local LanguageManager = include("language_manager.lua")

-- Add this near the top of the file, after loading the LanguageManager
local function getTranslatedLanguageName(lang)
    return LanguageManager.languages[lang] or lang
end

-- Modify the loadLanguage function
local function loadLanguage()
    local lang = GetConVar("radio_language"):GetString() or "en"
    LanguageManager:SetLanguage(lang)
end

-- Create a ConVar for language selection if it doesn't exist
if not ConVarExists("radio_language") then
    CreateClientConVar("radio_language", "en", true, false, "Set the language for the radio addon")
end

-- Call loadLanguage to set the initial language
loadLanguage()

-- Function to format the country name for UI display
local function formatCountryName(filename)
    local formattedName = filename:gsub("-", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
    return formattedName
end

-- Function to load stations for a specific country
local function loadStationsForCountry(country)
    local path = "radio/stations/" .. country .. ".lua"
    if file.Exists(path, "LUA") then
        local stations = include(path)
        Config.RadioStations[formatCountryName(country)] = stations -- Store with formatted name for UI
    end
end

-- Dynamically detect and load countries from the stations directory
local files = file.Find("radio/stations/*.lua", "LUA")
for _, filename in ipairs(files) do
    local country = string.StripExtension(filename)
    loadStationsForCountry(country)
end

-- Load themes
local themes = include("themes.lua")

-- Default to dark theme or set based on user preference
local selectedTheme = themes["neon"]

-- General UI Settings
Config.UI = selectedTheme
Config.MessageCooldown = 1 -- Cooldown time in seconds before the chat message can be sent again ("Press {key} to open the radio menu")
Config.VolumeAttenuationExponent = 0.8

local openKeyConvar = GetConVar("car_radio_open_key")

if not openKeyConvar then
    CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
    openKeyConvar = GetConVar("car_radio_open_key")
end

Config.OpenKey = openKeyConvar:GetInt()

-- Boombox Settings (Normal)
Config.Boombox = {
    Volume = 1, -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 800, -- Maximum distance at which the radio can be heard (in units)
    MinVolumeDistance = 500, -- Distance at which the radio volume starts to drop off (in units)
    RetryAttempts = 3, -- Number of retry attempts to play a station in case of failure
    RetryDelay = 2 -- Delay in seconds between retry attempts
}

-- Golden Boombox Settings
Config.GoldenBoombox = {
    Volume = 1, -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 350000, -- Increased maximum distance at which the radio can be heard (in units)
    MinVolumeDistance = 250000, -- Increased distance at which the radio volume starts to drop off (in units)
    RetryAttempts = 3, -- Number of retry attempts to play a station in case of failure
    RetryDelay = 2 -- Delay in seconds between retry attempts
}

-- Vehicle Radio Settings
Config.VehicleRadio = {
    Volume = 1, -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 800, -- Maximum distance at which the radio can be heard (in units)
    MinVolumeDistance = 500, -- Distance at which the radio volume starts to drop off (in units)
    RetryAttempts = 3, -- Number of retry attempts to play a station in case of failure
    RetryDelay = 2 -- Delay in seconds between retry attempts
}

-- Function to get a localized string
function Config.GetLocalizedString(key)
    return LanguageManager:Translate(key)
end

-- Add this near the top of the file, after loading the LanguageManager
local function getTranslatedCountryName(country)
    return LanguageManager:GetCountryTranslation(LanguageManager.currentLanguage, country)
end

-- You can then use this function when working with country names in the config file

return Config
