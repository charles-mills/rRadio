local Config = {}
local Misc
if CLIENT then Misc = include("radio/client/cl_misc.lua") end
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
Config.RadioStations = {}
Config.Lang = {}
Config.UI = {}
Config.Boombox = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.VehicleRadio = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.MessageCooldown = 1
Config.VolumeAttenuationExponent = 0.8
local function EnsureConVar(name, default, flags, helpText)
    if not ConVarExists(name) then CreateClientConVar(name, default, flags or FCVAR_ARCHIVE, false, helpText) end
    return GetConVar(name)
end

local languageConVar = EnsureConVar("radio_language", "en", true, "Set the language for the radio addon")
local openKeyConVar = EnsureConVar("car_radio_open_key", "21", true, "Select the key to open the car radio menu.")
local radioMaxVolume = EnsureConVar("radio_max_volume", 1, true, "Set the maximum volume for the radio.")
local radioTheme = EnsureConVar("radio_theme", "dark", true, "Set the theme for the radio.")
local carRadioShowMessages = EnsureConVar("car_radio_show_messages", "1", true, "Enable or disable car radio messages.")
local function loadLanguage()
    local lang = languageConVar:GetString() or "en"
    LanguageManager:SetLanguage(lang)
    Config.Lang = LanguageManager.translations[lang] or {}
end

loadLanguage()
cvars.AddChangeCallback("radio_language", function(_, _, newValue) loadLanguage() end)
local function formatCountryName(rawName)
    return rawName:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest) return string.upper(first) .. string.lower(rest) end)
end

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

local stationFiles = file.Find("radio/client/stations/*.lua", "LUA")
for _, filename in ipairs(stationFiles) do
    local countryName = string.StripExtension(filename)
    loadStationsForCountry(countryName)
end

local selectedTheme = CLIENT and Misc and Misc.Themes:GetTheme(radioTheme:GetString()) or {}
Config.UI = selectedTheme
if CLIENT then cvars.AddChangeCallback("radio_theme", function(_, _, newValue) if Misc then Config.UI = Misc.Themes:GetTheme(newValue) end end) end
function Config.GetLocalizedString(key)
    return Config.Lang[key] or key
end

local function getTranslatedCountryName(country)
    return LanguageManager:GetCountryTranslation(LanguageManager.currentLanguage, country) or country
end

function Config.GetKeyName(keyCode)
    if CLIENT and Misc then return Misc.KeyNames:GetKeyName(keyCode) end
    return "the Open Key"
end
return Config