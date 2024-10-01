-- Include the utilities
include("radio/utils.lua")

-- Configuration Table
Config = {}

-- Radio Stations
Config.RadioStations = {}

-- Centralized ConVar Creation
local function initializeConVars()
    CreateClientConVar("radio_theme", "neon", true, false, "Select the theme for the radio UI.")
    CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
    CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
    CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
    CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox.")
end

initializeConVars()

-- Load Language
local function loadLanguage()
    local lang = GetConVar("radio_language"):GetString() or "en"
    local path = "radio/lang/" .. lang .. ".lua"

    if file.Exists(path, "LUA") then
        Config.Lang = include(path)
    else
        Config.Lang = include("radio/lang/en.lua")
    end
end

loadLanguage()

-- Load Stations for Each Country
local function loadStations()
    local stationFiles = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(stationFiles) do
        local country = string.StripExtension(filename)
        local path = "radio/stations/" .. filename
        if file.Exists(path, "LUA") then
            local stations = include(path)
            Config.RadioStations[utils.formatCountryName(country)] = stations
        end
    end
end

loadStations()

-- Load Themes
local themes = include("themes.lua")

-- Apply Saved Theme or Default to "neon"
local themeName = GetConVar("radio_theme"):GetString() or "neon"
if themes[themeName] then
    Config.UI = themes[themeName]
else
    Config.UI = themes["neon"]
end

-- Other Config Settings
Config.UKAndUSPrioritised = true  -- Prioritize UK and US stations in the list
Config.MessageCooldown = 1  -- Cooldown in seconds for chat messages
Config.OpenKey = GetConVar("car_radio_open_key"):GetInt()

-- Boombox Settings
Config.Boombox = {
    Volume = 1.0,
    MaxHearingDistance = 1000,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2.0
}

-- Golden Boombox Settings
Config.GoldenBoombox = {
    Volume = 1.0,
    MaxHearingDistance = 350000,
    MinVolumeDistance = 250000,
    RetryAttempts = 3,
    RetryDelay = 2.0
}

-- Vehicle Radio Settings
Config.VehicleRadio = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2.0
}

-- Return Config
return Config