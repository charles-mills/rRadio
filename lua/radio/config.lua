-- Include the utilities
include("radio/utils.lua")

local Config = {}

Config.RadioStations = {}

-- Centralize ConVar creation (Suggestion 3)
local function initializeConVars()
    if not ConVarExists("radio_theme") then
        CreateClientConVar("radio_theme", "neon", true, false, "Select the theme for the radio UI.")
    end
    if not ConVarExists("radio_language") then
        CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
    end
    if not ConVarExists("car_radio_open_key") then
        CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
    end
    if not ConVarExists("car_radio_show_messages") then
        CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
    end
    if not ConVarExists("boombox_show_text") then
        CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox.")
    end
end

initializeConVars()

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

-- Function to load stations for a specific country
local function loadStationsForCountry(country)
    local path = "radio/stations/" .. country .. ".lua"
    if file.Exists(path, "LUA") then
        local stations = include(path)
        Config.RadioStations[utils.formatCountryName(country)] = stations -- Use formatCountryName from utils.lua (Suggestion 1)
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

-- Apply saved theme or default to "neon"
local themeName = GetConVar("radio_theme"):GetString() or "neon"
if themes[themeName] then
    Config.UI = themes[themeName]
else
    Config.UI = themes["neon"]
end

-- Other Config Settings
Config.UKAndUSPrioritised = true -- Include UK and US stations at the top of the list (default alphabetical sort if false)
Config.MessageCooldown = 1 -- Cooldown time in seconds before the chat message can be sent again ("Press {key} to open the radio menu")
Config.OpenKey = GetConVar("car_radio_open_key"):GetInt()

-- Boombox Settings (Normal)
Config.Boombox = {
    Volume = 1, -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 1000, -- Maximum distance at which the radio can be heard (in units)
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

return Config
