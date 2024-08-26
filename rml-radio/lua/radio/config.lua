local Config = {}

Config.RadioStations = {}

-- Function to load stations for a specific country
local function loadStationsForCountry(country)
    local path = "radio/stations/" .. country .. ".lua"
    if file.Exists(path, "LUA") then
        local stations = include(path)
        Config.RadioStations[country] = stations
    else
        print("Warning: No stations found for " .. country)
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
local selectedTheme = themes["dark"]

-- General Settings
Config.UI = selectedTheme
Config.MessageCooldown = 300 -- Cooldown time in seconds before the chat message can be sent again ("Press {key} to open the radio menu")
Config.OpenKey = KEY_K -- Key to open the radio menu
Config.Volume = 1 -- Default radio volume (range: 0.0 to 1.0)
Config.MaxHearingDistance = 1000 -- Maximum distance at which the radio can be heard (in units)
Config.MinVolumeDistance = 500 -- Distance at which the radio volume starts to drop off (in units)
Config.RetryAttempts = 3 -- Number of retry attempts to play a station in case of failure
Config.RetryDelay = 2 -- Delay in seconds between retry attempts

return Config