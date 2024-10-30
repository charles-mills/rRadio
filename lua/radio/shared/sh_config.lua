--[[
    Radio Addon Shared Configuration
    Author: Charles Mills
    Description: This file contains the main configuration settings for the Radio Addon.
                 It defines global variables, ConVars, and functions used across both
                 client and server. This includes settings for boomboxes, vehicle radios,
                 UI themes, language options, and various other customizable parameters.
    Date: October 30, 2024
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
--      Server ConVars Setup
-- ------------------------------

-- Function to create server ConVar with proper flags
local function CreateServerConVar(name, default, helpText)
    return CreateConVar(name, default, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, helpText)
end

-- Global volume limit
local maxVolumeCvar = CreateServerConVar(
    "radio_max_volume_limit",
    "1.0",
    "Maximum volume limit for all radio entities (0.0-1.0)"
)

-- Message cooldown
local messageCooldownCvar = CreateServerConVar(
    "radio_message_cooldown",
    "1",
    "Cooldown time in seconds before chat messages can be sent again"
)

-- Boombox Settings
local boomboxVolumeCvar = CreateServerConVar("radio_boombox_volume", "1.0", "Default volume for boomboxes")
local boomboxMaxDistCvar = CreateServerConVar("radio_boombox_max_distance", "800", "Maximum hearing distance for boomboxes")
local boomboxMinDistCvar = CreateServerConVar("radio_boombox_min_distance", "500", "Distance at which boombox volume starts to drop off")

-- Golden Boombox Settings
local goldenVolumeCvar = CreateServerConVar("radio_golden_boombox_volume", "1.0", "Default volume for golden boomboxes")
local goldenMaxDistCvar = CreateServerConVar("radio_golden_boombox_max_distance", "350000", "Maximum hearing distance for golden boomboxes")
local goldenMinDistCvar = CreateServerConVar("radio_golden_boombox_min_distance", "250000", "Distance at which golden boombox volume starts to drop off")

-- Vehicle Radio Settings
local vehicleVolumeCvar = CreateServerConVar("radio_vehicle_volume", "1.0", "Default volume for vehicle radios")
local vehicleMaxDistCvar = CreateServerConVar("radio_vehicle_max_distance", "800", "Maximum hearing distance for vehicle radios")
local vehicleMinDistCvar = CreateServerConVar("radio_vehicle_min_distance", "500", "Distance at which vehicle radio volume starts to drop off")

-- Update Config tables based on ConVars
Config.Boombox = {
    Volume = function() return boomboxVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return boomboxMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return boomboxMinDistCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.GoldenBoombox = {
    Volume = function() return goldenVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return goldenMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return goldenMinDistCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.VehicleRadio = {
    Volume = function() return vehicleVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return vehicleMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return vehicleMinDistCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

-- General Settings
Config.MessageCooldown = function() return messageCooldownCvar:GetFloat() end
Config.MaxVolume = function() return maxVolumeCvar:GetFloat() end
Config.VolumeAttenuationExponent = 0.8

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
local defaultThemeName = "midnight"
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

local function AddConVarCallback(name)
    cvars.AddChangeCallback(name, function(_, _, _)
        -- Notify clients of config update
        if SERVER then
            net.Start("RadioConfigUpdate")
            net.Broadcast()
        end
    end)
end

if SERVER then
    util.AddNetworkString("RadioConfigUpdate")
    
    local convars = {
        "radio_max_volume_limit",
        "radio_message_cooldown",
        "radio_boombox_volume",
        "radio_boombox_max_distance",
        "radio_boombox_min_distance",
        "radio_golden_boombox_volume",
        "radio_golden_boombox_max_distance",
        "radio_golden_boombox_min_distance",
        "radio_vehicle_volume",
        "radio_vehicle_max_distance",
        "radio_vehicle_min_distance"
    }

    for _, cvar in ipairs(convars) do
        AddConVarCallback(cvar)
    end
end

return Config
