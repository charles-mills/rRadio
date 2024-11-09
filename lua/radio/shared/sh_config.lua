local Config = {}
Config.RegisteredConVars = {
server = {},
client = {}
}
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
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
local themes = include("radio/client/cl_themes.lua") or {}
local keyCodeMapping = include("radio/client/cl_key_names.lua") or {}
Config.RadioStations = {}
Config.Lang = {}
Config.UI = {}
local languageConVar = EnsureConVar(
"radio_language",
"en",
true,
"Set the language for the radio addon"
)
local openKeyConVar = EnsureConVar(
"car_radio_open_key",
"21",
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
local maxVolumeCvar = CreateServerConVar(
"radio_max_volume_limit",
"1.0",
"Maximum volume limit for all radio entities (0.0-1.0)"
)
local messageCooldownCvar = CreateServerConVar(
"radio_message_cooldown",
"5",
"Cooldown time in seconds before the animation can be played again"
)
local boomboxVolumeCvar = CreateServerConVar("radio_boombox_volume", "1.0", "Default volume for boomboxes")
local boomboxMaxDistCvar = CreateServerConVar("radio_boombox_max_distance", "800", "Maximum hearing distance for boomboxes")
local boomboxMinDistCvar = CreateServerConVar("radio_boombox_min_distance", "500", "Distance at which boombox volume starts to drop off")
local goldenVolumeCvar = CreateServerConVar("radio_golden_boombox_volume", "1.0", "Default volume for golden boomboxes")
local goldenMaxDistCvar = CreateServerConVar("radio_golden_boombox_max_distance", "350000", "Maximum hearing distance for golden boomboxes")
local goldenMinDistCvar = CreateServerConVar("radio_golden_boombox_min_distance", "250000", "Distance at which golden boombox volume starts to drop off")
local vehicleVolumeCvar = CreateServerConVar("radio_vehicle_volume", "1.0", "Default volume for vehicle radios")
local vehicleMaxDistCvar = CreateServerConVar("radio_vehicle_max_distance", "800", "Maximum hearing distance for vehicle radios")
local vehicleMinDistCvar = CreateServerConVar("radio_vehicle_min_distance", "500", "Distance at which vehicle radio volume starts to drop off")
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
Config.MessageCooldown = function() return messageCooldownCvar:GetFloat() end
Config.MaxVolume = function() return maxVolumeCvar:GetFloat() end
Config.VolumeAttenuationExponent = 0.8
local function loadLanguage()
local lang = languageConVar:GetString() or "en"
LanguageManager:SetLanguage(lang)
Config.Lang = LanguageManager.translations[lang] or {}
end
loadLanguage()
cvars.AddChangeCallback("radio_language", function(_, _, newValue)
loadLanguage()
end)
local function formatCountryName(rawName)
return rawName:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest)
return string.upper(first) .. string.lower(rest)
end)
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
local defaultThemeName = "midnight"
local selectedTheme = themes[defaultThemeName] or themes[next(themes)] or {}
Config.UI = selectedTheme
function Config.GetLocalizedString(key)
return Config.Lang[key] or key
end
local function getTranslatedCountryName(country)
return LanguageManager:GetCountryTranslation(LanguageManager.currentLanguage, country) or country
end
Config.RegisteredConVars = {
server = {},
client = {}
}
function Config.ReloadConVars()
for name, defaultValue in pairs(Config.RegisteredConVars.server) do
local cvar = GetConVar(name)
if cvar then
local value = cvar:GetFloat()
if name == "radio_boombox_volume" then
Config.Boombox.Volume = function() return value end
elseif name == "radio_boombox_max_distance" then
Config.Boombox.MaxHearingDistance = function() return value end
elseif name == "radio_boombox_min_distance" then
Config.Boombox.MinVolumeDistance = function() return value end
elseif name == "radio_golden_boombox_volume" then
Config.GoldenBoombox.Volume = function() return value end
elseif name == "radio_golden_boombox_max_distance" then
Config.GoldenBoombox.MaxHearingDistance = function() return value end
elseif name == "radio_golden_boombox_min_distance" then
Config.GoldenBoombox.MinVolumeDistance = function() return value end
elseif name == "radio_vehicle_volume" then
Config.VehicleRadio.Volume = function() return value end
elseif name == "radio_vehicle_max_distance" then
Config.VehicleRadio.MaxHearingDistance = function() return value end
elseif name == "radio_vehicle_min_distance" then
Config.VehicleRadio.MinVolumeDistance = function() return value end
elseif name == "radio_max_volume_limit" then
Config.MaxVolume = function() return value end
elseif name == "radio_message_cooldown" then
Config.MessageCooldown = function() return value end
end
end
end
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
if SERVER then
net.Start("RadioConfigUpdate")
net.Broadcast()
end
hook.Run("RadioConfig_Updated")
end
if SERVER then
concommand.Add("radio_reload_config", function(ply)
if IsValid(ply) and not ply:IsAdmin() then return end
Config.ReloadConVars()
end)
local function AddConVarCallback(name)
cvars.AddChangeCallback(name, function(_, _, _)
Config.ReloadConVars()
end)
end
for cvarName, _ in pairs(Config.RegisteredConVars.server) do
AddConVarCallback(cvarName)
end
end
if CLIENT then
net.Receive("RadioConfigUpdate", function()
Config.ReloadConVars()
end)
end
function Config.DistanceToDb(distance, referenceDistance)
if distance <= referenceDistance then return 0 end
return -20 * math.log10(distance / referenceDistance)
end
function Config.DbToVolume(db)
return math.Clamp(10^(db/20), 0, 1)
end
function Config.CalculateVolumeAtDistance(distance, maxDist, minDist, baseVolume)
if distance >= maxDist then return 0 end
if distance <= minDist then return baseVolume end
local db = Config.DistanceToDb(distance, minDist)
local atmosphericLoss = (distance - minDist) * 0.0005
db = db - atmosphericLoss
local volumeMultiplier = Config.DbToVolume(db)
return math.Clamp(volumeMultiplier * baseVolume, 0, baseVolume)
end
function Config.CalculateVolume(entity, player, distanceSqr)
if not IsValid(entity) or not IsValid(player) then return 0 end
local entityConfig = utils.GetEntityConfig(entity)
if not entityConfig then return 0 end
local baseVolume = entity:GetNWFloat("Volume", entityConfig.Volume())
if player:GetVehicle() == entity or distanceSqr <= entityConfig.MinVolumeDistance()^2 then
return baseVolume
end
local maxDist = entityConfig.MaxHearingDistance()
local distance = math.sqrt(distanceSqr)
if distance >= maxDist then return 0 end
local falloff = 1 - math.Clamp((distance - entityConfig.MinVolumeDistance()) /
(maxDist - entityConfig.MinVolumeDistance()), 0, 1)
return baseVolume * falloff
end
return Config