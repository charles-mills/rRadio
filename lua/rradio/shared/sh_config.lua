rRadio.config = rRadio.config or {}

-----------------------------------------------------------------------
-- Server settings
-----------------------------------------------------------------------

rRadio.config.UsePlayerBindHook = false -- Set to true in multiplayer - do not enable in singleplayer.
rRadio.config.EnableLogging = true  -- enable bLogs integration
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

rRadio.config.MAX_CLIENT_STATIONS = 10
rRadio.config.MessageCooldown = function() return 5 end
rRadio.config.MaxVolume = function() return 1 end
rRadio.config.InactiveTimeout = function() return 3600 end
rRadio.config.CleanupInterval = function() return 300 end
rRadio.config.VolumeUpdateDebounce = function() return 0.1 end
rRadio.config.StationUpdateDebounce = function() return 10 end

rRadio.config.Boombox = {
    Volume = function() return 1.0 end,
    MaxHearingDistance = function() return 800 end,
    MinVolumeDistance = function() return 500 end,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.GoldenBoombox = {
    Volume = function() return 1.0 end,
    MaxHearingDistance = function() return 350000 end,
    MinVolumeDistance = function() return 250000 end
}

rRadio.config.VehicleRadio = {
    Volume = function() return 1.0 end,
    MaxHearingDistance = function() return 800 end,
    MinVolumeDistance = function() return 500 end,
    RetryAttempts = 3,
    RetryDelay = 2
}

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
rRadio.config.RadioVersion = "1.2.3"

return rRadio.config