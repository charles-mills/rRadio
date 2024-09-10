local Config = {}

--[[---------------------------------------------------------
    Language Loading
-----------------------------------------------------------]]
Config.RadioStations = {}

-- Load the language file based on the player's or server's language settings.
local function loadLanguage()
    local lang = Config.Language or GetConVar("gmod_language"):GetString() or "en"
    local langPath = "radio/lang/" .. lang .. ".lua"
    
    if file.Exists(langPath, "LUA") then
        Config.Lang = include(langPath)
    else
        -- Fallback to English if the selected language is unavailable.
        Config.Lang = include("radio/lang/en.lua")
    end
end

loadLanguage()  -- Initialize language loading.

--[[---------------------------------------------------------
    Station Loading
-----------------------------------------------------------]]

-- Formats country names for display in the UI.
local function formatCountryName(country)
    return country:gsub("-", " "):gsub("(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
end

-- Load radio stations for a specific country from the stations directory.
local function loadStationsForCountry(country)
    local stationPath = "radio/stations/" .. country .. ".lua"
    if file.Exists(stationPath, "LUA") then
        local stations = include(stationPath)
        -- Store the stations with the formatted country name for UI display.
        Config.RadioStations[formatCountryName(country)] = stations
    end
end

-- Dynamically detect and load all available countries from the radio stations directory.
local stationFiles = file.Find("radio/stations/*.lua", "LUA")
for _, filename in ipairs(stationFiles) do
    local country = string.StripExtension(filename)
    loadStationsForCountry(country)
end

--[[---------------------------------------------------------
    UI Settings
-----------------------------------------------------------]]

-- Load available themes from the themes file.
local themes = include("themes.lua")

-- Default to a 'neon' theme or allow setting based on user preference.
local selectedTheme = themes["neon"]

-- General UI Configuration.
Config.UI = selectedTheme
Config.MessageCooldown = 300 -- Cooldown time (in seconds) for chat messages like "Press {key} to open the radio menu."

-- Define the key used to open the car radio menu.
local openKeyConvar = GetConVar("car_radio_open_key")
if not openKeyConvar then
    CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
    openKeyConvar = GetConVar("car_radio_open_key")
end

-- Store the selected key for opening the radio menu.
Config.OpenKey = openKeyConvar:GetInt()

--[[---------------------------------------------------------
    Boombox and Vehicle Radio Settings
-----------------------------------------------------------]]

-- Settings for the normal boombox radio.
Config.Boombox = {
    Volume = 1.0,  -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 1000,  -- Maximum distance (in units) at which the radio can be heard.
    MinVolumeDistance = 500,  -- Distance (in units) where volume begins to decrease.
    RetryAttempts = 3,  -- Number of retries to play a station on failure.
    RetryDelay = 2  -- Delay (in seconds) between retry attempts.
}

-- Settings for the golden boombox radio, with increased range and distance.
Config.GoldenBoombox = {
    Volume = 1.0,  -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 350000,  -- Increased maximum distance (in units) for hearing.
    MinVolumeDistance = 250000,  -- Increased distance (in units) where volume starts to drop.
    RetryAttempts = 3,  -- Retry attempts on failure.
    RetryDelay = 2  -- Retry delay (in seconds).
}

-- Settings for vehicle radio systems.
Config.VehicleRadio = {
    Volume = 1.0,  -- Default radio volume (range: 0.0 to 1.0)
    MaxHearingDistance = 800,  -- Maximum distance (in units) for vehicle radio.
    MinVolumeDistance = 500,  -- Distance (in units) where volume decreases.
    RetryAttempts = 3,  -- Retry attempts on failure.
    RetryDelay = 2  -- Retry delay (in seconds).
}

return Config