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
--    ConVar Management
-- ------------------------------

-- Table to store all registered ConVars
Config.RegisteredConVars = {
    server = {},
    client = {}
}

-- Function declarations that use RegisteredConVars
local function CreateServerConVar(name, default, helpText)
    Config.RegisteredConVars.server[name] = default
    return CreateConVar(name, default, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, helpText)
end

local function EnsureConVar(name, default, flags, helpText)
    Config.RegisteredConVars.client[name] = default
    if not ConVarExists(name) then
        CreateClientConVar(name, default, flags or FCVAR_ARCHIVE, false, helpText)
    end
    return GetConVar(name)
end

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

-- Global volume limit
local maxVolumeCvar = CreateServerConVar(
    "radio_max_volume_limit",
    "1.0",
    "Maximum volume limit for all radio entities (0.0-1.0)"
)

-- Message cooldown
local messageCooldownCvar = CreateServerConVar(
    "radio_message_cooldown",
    "5",
    "Cooldown time in seconds before the animation can be played again"
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

-- ------------------------------
--    ConVar Management
-- ------------------------------

-- Table to store all registered ConVars
Config.RegisteredConVars = {
    server = {},
    client = {}
}

function Config.ReloadConVars()
    -- Reload server ConVars
    for name, defaultValue in pairs(Config.RegisteredConVars.server) do
        local cvar = GetConVar(name)
        if cvar then
            local value = cvar:GetFloat()
            
            -- Boombox settings
            if name == "radio_boombox_volume" then
                Config.Boombox.Volume = function() return value end
            elseif name == "radio_boombox_max_distance" then
                Config.Boombox.MaxHearingDistance = function() return value end
            elseif name == "radio_boombox_min_distance" then
                Config.Boombox.MinVolumeDistance = function() return value end
            
            -- Golden Boombox settings
            elseif name == "radio_golden_boombox_volume" then
                Config.GoldenBoombox.Volume = function() return value end
            elseif name == "radio_golden_boombox_max_distance" then
                Config.GoldenBoombox.MaxHearingDistance = function() return value end
            elseif name == "radio_golden_boombox_min_distance" then
                Config.GoldenBoombox.MinVolumeDistance = function() return value end
            
            -- Vehicle Radio settings
            elseif name == "radio_vehicle_volume" then
                Config.VehicleRadio.Volume = function() return value end
            elseif name == "radio_vehicle_max_distance" then
                Config.VehicleRadio.MaxHearingDistance = function() return value end
            elseif name == "radio_vehicle_min_distance" then
                Config.VehicleRadio.MinVolumeDistance = function() return value end
            
            -- Global settings
            elseif name == "radio_max_volume_limit" then
                Config.MaxVolume = function() return value end
            elseif name == "radio_message_cooldown" then
                Config.MessageCooldown = function() return value end
            end
        end
    end

    -- Reload client ConVars
    if CLIENT then
        for name, defaultValue in pairs(Config.RegisteredConVars.client) do
            local cvar = GetConVar(name)
            if cvar then
                if name == "radio_language" then
                    loadLanguage()
                elseif name == "radio_theme" then
                    local themeName = cvar:GetString()
                    Config.UI = themes[themeName] or themes[defaultThemeName] or themes[next(themes)] or {}
                end
            end
        end
    end

    -- Notify clients of the update if we're on the server
    if SERVER then
        net.Start("RadioConfigUpdate")
        net.Broadcast()
    end

    -- Call any registered callbacks
    hook.Run("RadioConfig_Updated")
end

if SERVER then
    util.AddNetworkString("RadioConfigUpdate")
    
    -- Handle the reload command
    concommand.Add("radio_reload_config", function(ply)
        -- Only allow admins to reload the config
        if IsValid(ply) and not ply:IsAdmin() then return end
        Config.ReloadConVars()
    end)

    -- Modified callback registration
    local function AddConVarCallback(name)
        cvars.AddChangeCallback(name, function(_, _, _)
            Config.ReloadConVars()
        end)
    end

    -- Register callbacks for all server ConVars
    for cvarName, _ in pairs(Config.RegisteredConVars.server) do
        AddConVarCallback(cvarName)
    end
end

if CLIENT then
    -- Handle config updates from server
    net.Receive("RadioConfigUpdate", function()
        Config.ReloadConVars()
    end)
end

-- Add these helper functions near the other utility functions
-- ------------------------------
--    Sound Physics Helpers
-- ------------------------------

-- Convert linear distance to decibel reduction (inverse square law)
function Config.DistanceToDb(distance, referenceDistance)
    if distance <= referenceDistance then return 0 end
    return -20 * math.log10(distance / referenceDistance)
end

-- Convert decibels to volume multiplier (0-1)
function Config.DbToVolume(db)
    return math.Clamp(10^(db/20), 0, 1)
end

-- Calculate volume based on distance with realistic falloff
function Config.CalculateVolumeAtDistance(distance, maxDist, minDist, baseVolume)
    if distance >= maxDist then return 0 end
    if distance <= minDist then return baseVolume end
    
    -- Calculate attenuation in decibels
    local db = Config.DistanceToDb(distance, minDist)
    
    -- Apply atmospheric absorption (air absorbs high frequencies more)
    local atmosphericLoss = (distance - minDist) * 0.0005 -- Approximate atmospheric absorption
    db = db - atmosphericLoss
    
    -- Convert back to volume multiplier and apply base volume
    local volumeMultiplier = Config.DbToVolume(db)
    return math.Clamp(volumeMultiplier * baseVolume, 0, baseVolume)
end

-- Optional: Add environmental factors
function Config.GetEnvironmentalFactor(ent1, ent2)
    local trace = {
        start = ent1:GetPos(),
        endpos = ent2:GetPos(),
        mask = MASK_SOLID
    }
    
    local tr = util.TraceLine(trace)
    
    -- Reduce volume if there are obstacles
    if tr.Hit and tr.HitPos != tr.EndPos then
        return 0.7 -- 30% reduction through walls
    end
    
    -- Check if entities are in water
    local ent1InWater = ent1:WaterLevel() > 0
    local ent2InWater = ent2:WaterLevel() > 0
    
    if ent1InWater and ent2InWater then
        return 0.5 -- Sound travels differently in water
    elseif ent1InWater != ent2InWater then
        return 0.3 -- Significant reduction when crossing water boundary
    end
    
    return 1
end

-- Main volume calculation function that combines all factors
function Config.CalculateVolume(source, listener, baseVolume, maxDist, minDist)
    local distance = source:GetPos():Distance(listener:GetPos())
    local baseVol = Config.CalculateVolumeAtDistance(distance, maxDist, minDist, baseVolume)
    
    -- Apply environmental factors
    local envFactor = Config.GetEnvironmentalFactor(source, listener)
    
    return baseVol * envFactor
end

return Config
