rRadio.config = rRadio.config or {}

-----------------------------------------------------------------------
-- Server settings
-----------------------------------------------------------------------

rRadio.config.SecureStationLoad = false  -- block playing stations not in the client's list
rRadio.config.DriverPlayOnly = false     -- only allow driver to control radio
rRadio.config.AnimationDefaultOn = true  -- enable animations by default
rRadio.config.ClientHardDisable = false  -- disables file loading when client's rradio_enabled convar is set to 0 (relog required to re-enable) (does not include config and its dependencies)
rRadio.config.DisablePushDamage = true  -- disable push damage

-----------------------------------------------------------------------

if rRadio.DEV then
    rRadio.config.SecureStationLoad = true
    rRadio.config.DriverPlayOnly = true
    rRadio.config.AnimationDefaultOn = false
    rRadio.config.ClientHardDisable = true
end

-----------------------------------------------------------------------

rRadio.config.RadioStations = rRadio.config.RadioStations or {}
rRadio.config.Lang = rRadio.config.Lang or {}
rRadio.config.UI = rRadio.config.UI or {}

rRadio.config.RadioVersion = "1.2.1"

rRadio.config.RegisteredConVars = rRadio.config.RegisteredConVars or {
    server = {},
    client = {}
}

function rRadio.config.DistanceToDb(distance, referenceDistance)
    if distance <= referenceDistance then return 0 end
    return -20 * math.log10(distance / referenceDistance)
end

function rRadio.config.DbToVolume(db)
    return math.Clamp(10^(db/20), 0, 1)
end

function rRadio.config.CalculateVolumeAtDistance(distance, maxDist, minDist, baseVolume)
    if distance >= maxDist then return 0 end
    if distance <= minDist then return baseVolume end
    local db = rRadio.config.DistanceToDb(distance, minDist)
    local atmosphericLoss = (distance - minDist) * 0.0005
    db = db - atmosphericLoss
    local volumeMultiplier = rRadio.config.DbToVolume(db)
    return math.Clamp(volumeMultiplier * baseVolume, 0, baseVolume)
end

function rRadio.config.CalculateVolume(entity, player, distanceSqr)
    if not IsValid(entity) or not IsValid(player) then return 0 end
    local entityConfig = rRadio.utils.GetEntityConfig(entity)
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

local function CreateSharedConVar(name, default, helpText)
    rRadio.config.RegisteredConVars.server[name] = default
    local flags = SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY} or {FCVAR_ARCHIVE}
    return CreateConVar(name, default, flags, helpText)
end

CreateSharedConVar("rammel_rradio_sv_vehicle_volume_limit", "1.0", "Maximum volume limit for all radio entities (0.0-1.0)")
CreateSharedConVar("rammel_rradio_sv_animation_cooldown", "5", "Cooldown time in seconds before the animation can be played again")
CreateSharedConVar("rammel_rradio_sv_boombox_default_volume", "1.0", "Default volume for boomboxes")
CreateSharedConVar("rammel_rradio_sv_boombox_max_distance", "800", "Maximum hearing distance for boomboxes")
CreateSharedConVar("rammel_rradio_sv_boombox_min_distance", "500", "Distance at which boombox volume starts to drop off")
CreateSharedConVar("rammel_rradio_sv_gold_default_volume", "1.0", "Default volume for golden boomboxes")
CreateSharedConVar("rammel_rradio_sv_gold_max_distance", "350000", "Maximum hearing distance for golden boomboxes")
CreateSharedConVar("rammel_rradio_sv_gold_min_distance", "250000", "Distance at which golden boombox volume starts to drop off")
CreateSharedConVar("rammel_rradio_sv_vehicle_default_volume", "1.0", "Default volume for vehicle radios")
CreateSharedConVar("rammel_rradio_sv_vehicle_max_distance", "800", "Maximum hearing distance for vehicle radios")
CreateSharedConVar("rammel_rradio_sv_vehicle_min_distance", "500", "Distance at which vehicle radio volume starts to drop off")
CreateSharedConVar("rammel_rradio_sv_inactive_timeout", "3600", "Time in seconds before inactive radios are removed.")
CreateSharedConVar("rammel_rradio_sv_cleanup_interval", "300", "Interval in seconds between cleanup runs.")
CreateSharedConVar("rammel_rradio_sv_volume_update_debounce", "0.1", "Debounce time for volume updates (seconds).")
CreateSharedConVar("rammel_rradio_sv_station_update_debounce", "10", "Debounce time for station update saves (seconds).")

rRadio.config.Boombox = {
    Volume = function()
        local cvar = GetConVar("rammel_rradio_sv_boombox_default_volume")
        return cvar and cvar:GetFloat() or 1.0
    end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_boombox_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_boombox_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.GoldenBoombox = {
    Volume = function()
        local cvar = GetConVar("rammel_rradio_sv_gold_default_volume")
        return cvar and cvar:GetFloat() or 1.0
    end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_gold_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_gold_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.VehicleRadio = {
    Volume = function()
        local cvar = GetConVar("rammel_rradio_sv_vehicle_default_volume")
        return cvar and cvar:GetFloat() or 1.0
    end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_vehicle_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_vehicle_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.MessageCooldown = function() return GetConVar("rammel_rradio_sv_animation_cooldown"):GetFloat() end
rRadio.config.MaxVolume = function() return GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat() end
rRadio.config.VolumeAttenuationExponent = 0.8
rRadio.config.InactiveTimeout = function() return GetConVar("rammel_rradio_sv_inactive_timeout"):GetFloat() end
rRadio.config.CleanupInterval = function() return GetConVar("rammel_rradio_sv_cleanup_interval"):GetFloat() end
rRadio.config.VolumeUpdateDebounce = function() return GetConVar("rammel_rradio_sv_volume_update_debounce"):GetFloat() end
rRadio.config.StationUpdateDebounce = function() return GetConVar("rammel_rradio_sv_station_update_debounce"):GetFloat() end

if CLIENT then
    local gmodLang = GetConVar("gmod_language")

    local function loadLanguage()
        local raw = (gmodLang and gmodLang:GetString()) or "en"
        local code = raw:lower()
        code = code:gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
        local langMap = {
        english = "en", german = "de", spanish = "es", español = "es",
        french = "fr", français = "fr", italian = "it", italiano = "it",
        japanese = "ja", korean = "ko", portuguese = "pt_br", pt_br = "pt_br",
        russian = "ru", chinese = "zh_cn", simplified_chinese = "zh_cn",
        turkish = "tr", pirate_english = "en_pt", en_pt = "en_pt"
        }
        code = langMap[code] or code
        rRadio.LanguageManager.currentLanguage = code
        rRadio.config.Lang = rRadio.LanguageManager.translations[rRadio.LanguageManager.currentLanguage] or {}
        hook.Run("LanguageUpdated")
    end

    loadLanguage()
    cvars.AddChangeCallback("gmod_language", function(_, _, _)
        loadLanguage()
    end)

    cvars.AddChangeCallback("rammel_rradio_enabled", function(_, _, _)
        if GetConVar("rammel_rradio_enabled"):GetBool() then
            if rRadio.interface then 
                rRadio.FormattedOutput("rRadio has been re-enabled.")
            else
                rRadio.FormattedOutput("Reload required to enable rRadio")
            end
        else
            if not rRadio.interface then return end
            rRadio.FormattedOutput("rRadio has been disabled.")

            if rRadio.config.ClientHardDisable then
                rRadio.FormattedOutput("Files will not be loaded upon next join.")
            end
        end
    end)
end

rRadio.config.RegisteredConVars = {
    server = {},
    client = {}
}

function rRadio.config.ReloadConVars()
    for name, defaultValue in pairs(rRadio.config.RegisteredConVars.server) do
        local cvar = GetConVar(name)
        if cvar then
            local value = cvar:GetFloat()

            if name == "rammel_rradio_sv_boombox_default_volume" then
                rRadio.config.Boombox.Volume = function() return value end
            elseif name == "rammel_rradio_sv_boombox_max_distance" then
                rRadio.config.Boombox.MaxHearingDistance = function() return value end
            elseif name == "rammel_rradio_sv_boombox_min_distance" then
                rRadio.config.Boombox.MinVolumeDistance = function() return value end
            elseif name == "rammel_rradio_sv_gold_default_volume" then
                rRadio.config.GoldenBoombox.Volume = function() return value end
            elseif name == "rammel_rradio_sv_gold_max_distance" then
                rRadio.config.GoldenBoombox.MaxHearingDistance = function() return value end
            elseif name == "rammel_rradio_sv_gold_min_distance" then
                rRadio.config.GoldenBoombox.MinVolumeDistance = function() return value end
            elseif name == "rammel_rradio_sv_vehicle_default_volume" then
                rRadio.config.VehicleRadio.Volume = function() return value end
            elseif name == "rammel_rradio_sv_vehicle_max_distance" then
                rRadio.config.VehicleRadio.MaxHearingDistance = function() return value end
            elseif name == "rammel_rradio_sv_vehicle_min_distance" then
                rRadio.config.VehicleRadio.MinVolumeDistance = function() return value end
            elseif name == "rammel_rradio_sv_vehicle_volume_limit" then
                rRadio.config.MaxVolume = function() return value end
            elseif name == "rammel_rradio_sv_animation_cooldown" then
                rRadio.config.MessageCooldown = function() return value
            end
        end
    end
end

if CLIENT then
    for name, defaultValue in pairs(rRadio.config.RegisteredConVars.client) do
        local cvar = GetConVar(name)
        if cvar then
            if name == "rammel_rradio_menu_theme" then
                local themeName = cvar:GetString()
                local defaultThemeName = "dark"
                local selectedTheme = rRadio.themes and (rRadio.themes[themeName] or rRadio.themes[defaultThemeName] or rRadio.themes[next(rRadio.themes)]) or {}
                rRadio.config.UI = selectedTheme
            end
        end
    end

    net.Receive("RadioConfigUpdate", function()
        rRadio.config.ReloadConVars()
    end)
end

if SERVER then
    net.Start("RadioConfigUpdate")
    net.Broadcast()

    concommand.Add("radio_reload_config", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        rRadio.config.ReloadConVars()
    end)

    local function AddConVarCallback(name)
        cvars.AddChangeCallback(name, function(_, _, _)
            rRadio.config.ReloadConVars()
        end)
    end
    for cvarName, _ in pairs(rRadio.config.RegisteredConVars.server) do
        AddConVarCallback(cvarName)
    end
end

hook.Run("RadioConfig_Updated")
end

return rRadio.config