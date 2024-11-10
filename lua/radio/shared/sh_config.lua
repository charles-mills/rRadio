local Config = {}

-- Core Settings
Config.secureTransmission = true  -- If true, clients will check that a received URL is approved (in their list of stations).
Config.ApprovedStations = {}
Config.StationDomains = {}
Config.RadioStations = {}
Config.Lang = {}
Config.UI = {}
Config.MaxStationNameLength = 40
Config.VolumeAttenuationExponent = 0.8

Config.RegisteredConVars = {
    server = {},
    client = {}
}

-- Sound Settings
Config.Sound3D = {
    InnerAngle = 180,
    OuterAngle = 360,
    OuterVolume = 0.8
}

-- Admin Settings
Config.AdminPanel = {
    AllowedGroups = {
        ["superadmin"] = true,
        ["admin"] = true
    },
    
    CanAccess = function(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        return Config.AdminPanel.AllowedGroups[ply:GetUserGroup()] == true
    end
}

-- ConVar Creation Helpers
local function CreateServerConVar(name, default, helpText)
    Config.RegisteredConVars.server[name] = default
    return CreateConVar(name, default, {
        FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_PROTECTED
    }, helpText)
end

local function EnsureConVar(name, default, flags, helpText)
    Config.RegisteredConVars.client[name] = default
    if not ConVarExists(name) then
        CreateClientConVar(name, default, flags or FCVAR_ARCHIVE, false, helpText)
    end
    return GetConVar(name)
end

-- Client ConVars
local languageConVar = EnsureConVar("radio_language", "en", true)
local openKeyConVar = EnsureConVar("car_radio_open_key", "21", true)
local radioTheme = EnsureConVar("radio_theme", "dark", true)
local carRadioShowMessages = EnsureConVar("car_radio_show_messages", "1", true)

-- Server ConVars
local maxVolumeCvar = CreateServerConVar("radio_max_volume_limit", "1.0")
local messageCooldownCvar = CreateServerConVar("radio_message_cooldown", "5")
local animationOnCarEnterCvar = CreateServerConVar("radio_animation_on_car_enter", "1")

-- Boombox ConVars
local boomboxVolumeCvar = CreateServerConVar("radio_boombox_volume", "1.0")
local boomboxMaxDistCvar = CreateServerConVar("radio_boombox_max_distance", "800")
local boomboxMinDistCvar = CreateServerConVar("radio_boombox_min_distance", "500")
local boomboxFalloffCvar = CreateServerConVar("radio_boombox_falloff", "1.0")

-- Golden Boombox ConVars
local goldenVolumeCvar = CreateServerConVar("radio_golden_boombox_volume", "1.0")
local goldenMaxDistCvar = CreateServerConVar("radio_golden_boombox_max_distance", "350000")
local goldenMinDistCvar = CreateServerConVar("radio_golden_boombox_min_distance", "250000")
local goldenFalloffCvar = CreateServerConVar("radio_golden_boombox_falloff", "1.0")

-- Vehicle Radio ConVars
local vehicleVolumeCvar = CreateServerConVar("radio_vehicle_volume", "1.0")
local vehicleMaxDistCvar = CreateServerConVar("radio_vehicle_max_distance", "800")
local vehicleMinDistCvar = CreateServerConVar("radio_vehicle_min_distance", "500")
local vehicleFalloffCvar = CreateServerConVar("radio_vehicle_falloff", "2.0")

-- Entity Configurations
Config.Boombox = {
    Volume = function() return boomboxVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return boomboxMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return boomboxMinDistCvar:GetFloat() end,
    Falloff = function() return boomboxFalloffCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.GoldenBoombox = {
    Volume = function() return goldenVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return goldenMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return goldenMinDistCvar:GetFloat() end,
    Falloff = function() return goldenFalloffCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.VehicleRadio = {
    Volume = function() return vehicleVolumeCvar:GetFloat() end,
    MaxHearingDistance = function() return vehicleMaxDistCvar:GetFloat() end,
    MinVolumeDistance = function() return vehicleMinDistCvar:GetFloat() end,
    Falloff = function() return vehicleFalloffCvar:GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

-- Getter Functions
Config.MessageCooldown = function() return messageCooldownCvar:GetFloat() end
Config.MaxVolume = function() return maxVolumeCvar:GetFloat() end
Config.AnimationOnCarEnter = function() return animationOnCarEnterCvar:GetBool() end

-- Station Processing
local function processStationURL(url)
    if not url then return end
    local domain = url:match('^%w+://([^/]+)') or url
    Config.ApprovedStations[url] = true
    Config.StationDomains[domain:lower()] = true
    print("[rRadio Debug] Added approved station:", url) -- Debug print
end

function Config.IsApprovedStation(url)
    if not Config.secureTransmission then return true end
    if not url then return false end
    
    if Config.ApprovedStations[url] then return true end
    local domain = url:match('^%w+://([^/]+)') or url
    return Config.StationDomains[domain:lower()] == true
end

-- Station Loading
local function formatCountryName(rawName)
    return rawName:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
end

local function loadStationsForCountry(rawCountryName)
    local formattedName = formatCountryName(rawCountryName)
    local path = "radio/client/stations/data_" .. rawCountryName .. ".lua"

    if file.Exists(path, "LUA") then
        local success, stations = pcall(include, path)
        if success and stations then
            for country, countryStations in pairs(stations) do
                Config.RadioStations[country] = countryStations
                -- Process each station in the country
                for _, station in ipairs(countryStations) do
                    if station.u then -- Note: Station URLs use 'u' in data files
                        processStationURL(station.u)
                    end
                end
            end
            print(string.format("[rRadio] Loaded stations from %s", path))
        else
            print(string.format("[rRadio] Failed to load stations from %s", path))
        end
    end
end

-- Initialize Stations
local function initializeStations()
    -- Reset tables
    Config.ApprovedStations = {}
    Config.StationDomains = {}
    Config.RadioStations = {}

    -- Find all data files
    local stationFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
    print("[rRadio] Found " .. #stationFiles .. " station data files")

    -- Load each file
    for _, filename in ipairs(stationFiles) do
        local countryName = filename:match("^data_(.+)%.lua$")
        if countryName then
            loadStationsForCountry(countryName)
        end
    end

    -- Debug output
    local stationCount = table.Count(Config.ApprovedStations)
    local domainCount = table.Count(Config.StationDomains)
    print(string.format("[rRadio] Loaded %d approved stations across %d domains", stationCount, domainCount))
end

-- Call initialization
initializeStations()

-- Sound Physics Functions
function Config.DistanceToDb(distance, referenceDistance)
    if distance <= referenceDistance then return 0 end
    return -20 * math.log10(distance / referenceDistance)
end

function Config.DbToVolume(db)
    return math.Clamp(10^(db/20), 0, 1)
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
    
    local falloff = math.pow(1 - math.Clamp((distance - entityConfig.MinVolumeDistance()) / 
                                          (maxDist - entityConfig.MinVolumeDistance()), 0, 1), 
                            entityConfig.Falloff())
    
    return baseVolume * falloff
end

CreateConVar("radio_debug", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable debug prints for radio system")

return Config
