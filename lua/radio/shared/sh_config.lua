rRadio.config = rRadio.config or {}

-- Server settings
rRadio.config.SecureStationLoad = false  -- Block stations not in client's list
rRadio.config.DriverPlayOnly = false     -- Only driver can control radio
rRadio.config.AnimationDefaultOn = true  -- Enable animations by default
rRadio.config.ClientHardDisable = false  -- Disable file loading when rradio_enabled is 0 (relog required)
rRadio.config.DisablePushDamage = true   -- Disable push damage

if rRadio.DEV then
    rRadio.config.SecureStationLoad = true
    rRadio.config.DriverPlayOnly = true
    rRadio.config.AnimationDefaultOn = false
    rRadio.config.ClientHardDisable = true
end

rRadio.config.RadioStations = rRadio.config.RadioStations or {}
rRadio.config.Lang = rRadio.config.Lang or {}
rRadio.config.UI = rRadio.config.UI or {}
rRadio.config.RadioVersion = "1.2.0"

local function ClampVolume(volume)
    return math.Clamp(tonumber(volume) or 1.0, 0, 1.0)
end

local function CalculateVolumeAtDistance(distance, maxDist, minDist, baseVolume)
    if distance >= maxDist then return 0 end
    if distance <= minDist then return baseVolume end
    local t = (distance - minDist) / (maxDist - minDist)
    local falloff = 1 - t ^ 0.8
    return ClampVolume(baseVolume * falloff)
end

function rRadio.config.CalculateVolume(entity, player, distanceSqr)
    if not IsValid(entity) or not IsValid(player) then return 0 end
    local entityConfig = rRadio.utils.GetEntityConfig(entity)
    if not entityConfig then return 0 end
    local baseVolume = ClampVolume(entity:GetNWFloat("Volume", entityConfig.Volume()))
    if player:GetVehicle() == entity or distanceSqr <= entityConfig.MinVolumeDistance()^2 then
        return baseVolume
    end
    local distance = math.sqrt(distanceSqr)
    return CalculateVolumeAtDistance(distance, entityConfig.MaxHearingDistance(), entityConfig.MinVolumeDistance(), baseVolume)
end

local function CreateSharedConVar(name, default, helpText)
    local flags = SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY} or {FCVAR_ARCHIVE}
    return CreateConVar(name, default, flags, helpText)
end

local serverConVars = {
    rammel_rradio_sv_vehicle_volume_limit = { default = "1.0", help = "Maximum volume limit for all radios (0.0-1.0)" },
    rammel_rradio_sv_animation_cooldown = { default = "5", help = "Cooldown for radio animation (seconds)" },
    rammel_rradio_sv_boombox_default_volume = { default = "1.0", help = "Default volume for boomboxes" },
    rammel_rradio_sv_boombox_max_distance = { default = "800", help = "Maximum hearing distance for boomboxes" },
    rammel_rradio_sv_boombox_min_distance = { default = "500", help = "Distance where boombox volume starts dropping" },
    rammel_rradio_sv_gold_default_volume = { default = "1.0", help = "Default volume for golden boomboxes" },
    rammel_rradio_sv_gold_max_distance = { default = "350000", help = "Maximum hearing distance for golden boomboxes" },
    rammel_rradio_sv_gold_min_distance = { default = "250000", help = "Distance where golden boombox volume starts dropping" },
    rammel_rradio_sv_vehicle_default_volume = { default = "1.0", help = "Default volume for vehicle radios" },
    rammel_rradio_sv_vehicle_max_distance = { default = "800", help = "Maximum hearing distance for vehicle radios" },
    rammel_rradio_sv_vehicle_min_distance = { default = "500", help = "Distance where vehicle radio volume starts dropping" }
}

for name, info in pairs(serverConVars) do
    CreateSharedConVar(name, info.default, info.help)
end

rRadio.config.Boombox = {
    Volume = function() return ClampVolume(GetConVar("rammel_rradio_sv_boombox_default_volume"):GetFloat()) end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_boombox_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_boombox_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.GoldenBoombox = {
    Volume = function() return ClampVolume(GetConVar("rammel_rradio_sv_gold_default_volume"):GetFloat()) end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_gold_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_gold_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.VehicleRadio = {
    Volume = function() return ClampVolume(GetConVar("rammel_rradio_sv_vehicle_default_volume"):GetFloat()) end,
    MaxHearingDistance = function() return GetConVar("rammel_rradio_sv_vehicle_max_distance"):GetFloat() end,
    MinVolumeDistance = function() return GetConVar("rammel_rradio_sv_vehicle_min_distance"):GetFloat() end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.MessageCooldown = function() return GetConVar("rammel_rradio_sv_animation_cooldown"):GetFloat() end
rRadio.config.MaxVolume = function() return ClampVolume(GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat()) end

function rRadio.config.ReloadConVars()
    for name, _ in pairs(serverConVars) do
        local cvar = GetConVar(name)
        if not cvar then continue end
        local value = cvar:GetFloat()
        if name == "rammel_rradio_sv_boombox_default_volume" then
            rRadio.config.Boombox.Volume = function() return ClampVolume(value) end
        elseif name == "rammel_rradio_sv_boombox_max_distance" then
            rRadio.config.Boombox.MaxHearingDistance = function() return value end
        elseif name == "rammel_rradio_sv_boombox_min_distance" then
            rRadio.config.Boombox.MinVolumeDistance = function() return value end
        elseif name == "rammel_rradio_sv_gold_default_volume" then
            rRadio.config.GoldenBoombox.Volume = function() return ClampVolume(value) end
        elseif name == "rammel_rradio_sv_gold_max_distance" then
            rRadio.config.GoldenBoombox.MaxHearingDistance = function() return value end
        elseif name == "rammel_rradio_sv_gold_min_distance" then
            rRadio.config.GoldenBoombox.MinVolumeDistance = function() return value end
        elseif name == "rammel_rradio_sv_vehicle_default_volume" then
            rRadio.config.VehicleRadio.Volume = function() return ClampVolume(value) end
        elseif name == "rammel_rradio_sv_vehicle_max_distance" then
            rRadio.config.VehicleRadio.MaxHearingDistance = function() return value end
        elseif name == "rammel_rradio_sv_vehicle_min_distance" then
            rRadio.config.VehicleRadio.MinVolumeDistance = function() return value end
        elseif name == "rammel_rradio_sv_vehicle_volume_limit" then
            rRadio.config.MaxVolume = function() return ClampVolume(value) end
        elseif name == "rammel_rradio_sv_animation_cooldown" then
            rRadio.config.MessageCooldown = function() return value end
        end
    end
    hook.Run("RadioConfig_Updated")
end

if SERVER then
    util.AddNetworkString("RadioConfigUpdate")
    net.Start("RadioConfigUpdate")
    net.Broadcast()

    concommand.Add("radio_reload_config", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("[rRADIO] Admin required!")
            return
        end
        rRadio.config.ReloadConVars()
        net.Start("RadioConfigUpdate")
        net.Broadcast()
        local msg = "[rRADIO] Configuration reloaded!"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)

    for name, _ in pairs(serverConVars) do
        cvars.AddChangeCallback(name, function()
            rRadio.config.ReloadConVars()
            net.Start("RadioConfigUpdate")
            net.Broadcast()
        end)
    end
end

if CLIENT then
    net.Receive("RadioConfigUpdate", function()
        rRadio.config.ReloadConVars()
    end)

    local function loadLanguage()
        local raw = GetConVar("gmod_language"):GetString():lower()
        local langMap = {
            english = "en", german = "de", spanish = "es", español = "es",
            french = "fr", français = "fr", italian = "it", italiano = "it",
            japanese = "ja", korean = "ko", portuguese = "pt_br", pt_br = "pt_br",
            russian = "ru", chinese = "zh_cn", simplified_chinese = "zh_cn",
            turkish = "tr", pirate_english = "en_pt", en_pt = "en_pt"
        }
        local code = langMap[raw] or "en"
        rRadio.LanguageManager.currentLanguage = code
        rRadio.config.Lang = rRadio.LanguageManager.translations[code] or {}
        hook.Run("LanguageUpdated")
    end

    loadLanguage()
    cvars.AddChangeCallback("gmod_language", loadLanguage)

    cvars.AddChangeCallback("rammel_rradio_enabled", function()
        local enabled = GetConVar("rammel_rradio_enabled"):GetBool()
        local msg = enabled and "rRadio has been re-enabled." or "rRadio has been disabled."
        if not enabled and rRadio.config.ClientHardDisable then
            msg = msg .. " Files will not load on next join."
        elseif enabled and not rRadio.interface then
            msg = "Reload required to enable rRadio."
        end
        rRadio.FormattedOutput(msg)
    end)
end

return rRadio.config
