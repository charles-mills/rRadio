rRadio.config = rRadio.config or {}

-----------------------------------------------------------------------
-- Server settings
-----------------------------------------------------------------------

rRadio.config.SecureStationLoad = false  -- block playing stations not in the client's list
rRadio.config.DriverPlayOnly = false     -- only allow driver to control radio
rRadio.config.AnimationDefaultOn = true  -- enable animations by default
rRadio.config.ClientHardDisable = false  -- disables file loading when client's rradio_enabled convar is set to 0 (relog required to re-enable) (does not include config and its dependencies)
rRadio.config.DisablePushDamage = true  -- disable push damage
rRadio.config.PrioritiseCustom  = true -- the custom / server added station category will appear at the top of the menu (instead of alphabetical)

rRadio.config.AllowCreatePermanentBoombox = true -- allow new permanent boomboxes to be created by superadmins

-- name of the category for all custom stations, e.g. "Our Favourite Stations!"
-- the key is only localised if set to "Custom" (case sensitive)
rRadio.config.CustomStationCategory = "Custom"
rRadio.config.CommandAddStation = "!rradioadd"
rRadio.config.CommandRemoveStation = "!rradiorem"

-----------------------------------------------------------------------

if rRadio.DEV then
    rRadio.config.SecureStationLoad = true
    rRadio.config.DriverPlayOnly = true
    rRadio.config.AnimationDefaultOn = false
    rRadio.config.ClientHardDisable = true
    rRadio.config.CustomStationCategory = "Rammel's Top Stations"
end

-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Additional settings (do not modify, unless you really want to)
-----------------------------------------------------------------------

rRadio.config.VehicleClassOverides = {
    "lvs_",
    "ses_",
    "sw_",
    "drs_"
}

rRadio.config.MAX_NAME_CHARS = 40 -- Truncate station names sent to the server to this length

-----------------------------------------------------------------------

rRadio.config.RadioStations = rRadio.config.RadioStations or {}
rRadio.config.Lang = rRadio.config.Lang or {}

rRadio.status = rRadio.status or {}

rRadio.status = {
    STOPPED = 0,
    TUNING = 1,
    PLAYING = 2
}

local DEFAULT_UI = {
    BackgroundColor = Color(0,0,0,255),
    AccentPrimary   = Color(58,114,255),
    Highlight       = Color(58,114,255),
    TextColor       = Color(255,255,255,255),
    Disabled        = Color(180,180,180,255)
}

rRadio.config.UI = rRadio.config.UI or DEFAULT_UI
rRadio.config.RadioVersion = "1.2.2"

rRadio.config.RegisteredConVars = rRadio.config.RegisteredConVars or {
    server = {},
    client = {}
}

local function CreateSharedConVar(name, default, helpText)
    rRadio.config.RegisteredConVars.server[name] = default

    if SERVER then
        local flags = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
        return CreateConVar(name, default, flags, helpText)
    else
        local cvar = CreateConVar(name, default, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, helpText)
        return cvar
    end
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

function rRadio.config.ReloadConVars()
    for name, _ in pairs(rRadio.config.RegisteredConVars.server) do
        local cvar = GetConVar(name)
        if cvar then
            local getter = function() return cvar:GetFloat() end
            if name == "rammel_rradio_sv_boombox_default_volume" then
                rRadio.config.Boombox.Volume = getter
            elseif name == "rammel_rradio_sv_boombox_max_distance" then
                rRadio.config.Boombox.MaxHearingDistance = getter
            elseif name == "rammel_rradio_sv_boombox_min_distance" then
                rRadio.config.Boombox.MinVolumeDistance = getter
            elseif name == "rammel_rradio_sv_gold_default_volume" then
                rRadio.config.GoldenBoombox.Volume = getter
            elseif name == "rammel_rradio_sv_gold_max_distance" then
                rRadio.config.GoldenBoombox.MaxHearingDistance = getter
            elseif name == "rammel_rradio_sv_gold_min_distance" then
                rRadio.config.GoldenBoombox.MinVolumeDistance = getter
            elseif name == "rammel_rradio_sv_vehicle_default_volume" then
                rRadio.config.VehicleRadio.Volume = getter
            elseif name == "rammel_rradio_sv_vehicle_max_distance" then
                rRadio.config.VehicleRadio.MaxHearingDistance = getter
            elseif name == "rammel_rradio_sv_vehicle_min_distance" then
                rRadio.config.VehicleRadio.MinVolumeDistance = getter
            elseif name == "rammel_rradio_sv_vehicle_volume_limit" then
                rRadio.config.MaxVolume = getter
            elseif name == "rammel_rradio_sv_animation_cooldown" then
                rRadio.config.MessageCooldown = getter
            elseif name == "rammel_rradio_sv_volume_update_debounce" then
                rRadio.config.VolumeUpdateDebounce = getter
            elseif name == "rammel_rradio_sv_station_update_debounce" then
                rRadio.config.StationUpdateDebounce = getter
            end
        end
    end
end

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
        english = "en", german = "de", spanish = "es_es", español = "es_es",
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

    net.Receive("rRadio.SetConfigUpdate", function()
        for name, default in pairs(rRadio.config.RegisteredConVars.server) do
            local cvar = GetConVar(name)
            if not cvar then
                cvar = CreateConVar(name, tostring(default), {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "")
            end

            if cvar then
                local serverValue = net.ReadString()
                if serverValue then
                    RunConsoleCommand(name, serverValue)
                end
            end
        end

        rRadio.config.ReloadConVars()
    end)

    rRadio.config.ReloadConVars()

    timer.Simple(1, function()
        net.Start("rRadio.RequestConfigSync")
        net.SendToServer()
    end)
else
    util.AddNetworkString("rRadio.RequestConfigSync")
    util.AddNetworkString("rRadio.SetConfigUpdate")
    
    net.Receive("rRadio.RequestConfigSync", function(len, ply)
        if not IsValid(ply) then return end
        
        rRadio.config.ReloadConVars()

        net.Start("rRadio.SetConfigUpdate")
        net.Send(ply)

    end)

    timer.Simple(1, function()
        net.Start("rRadio.SetConfigUpdate")
        net.Broadcast()
    end)

    hook.Add("PlayerInitialSpawn", "rRadio.SyncConfig", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                net.Start("rRadio.SetConfigUpdate")
                net.Send(ply)
            end
        end)
    end)

    concommand.Add("radio_reload_config", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        rRadio.config.ReloadConVars()
        net.Start("rRadio.SetConfigUpdate")
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end)

    local function AddConVarCallback(name)
        cvars.AddChangeCallback(name, function(_, old, new)
            rRadio.config.ReloadConVars()
            net.Start("rRadio.SetConfigUpdate")
            net.Broadcast()
        end, "rRadio.ConVarSync_" .. name)
    end

    for cvarName, _ in pairs(rRadio.config.RegisteredConVars.server) do
        AddConVarCallback(cvarName)
    end

    hook.Add("ConVarChanged", "rRadio.ConfigSync", function(name, oldValue, newValue)
        if rRadio.config.RegisteredConVars.server[name] then
            rRadio.config.ReloadConVars()
            net.Start("rRadio.SetConfigUpdate")
            net.WriteString(name)
            net.WriteString(tostring(newValue))
            net.Broadcast()
        end
    end)
end

hook.Run("RadioConfig_Updated")
return rRadio.config