local Radio, Config = rRadio:Import("Radio", "!config")

Config.RadioVersion = "1.2.5"

--[[ ! Server settings ! ]]

Config.EnableLogging = true  -- enable bLogs integration
Config.SecureStationLoad = false  -- block playing stations not in the client's list
Config.DriverPlayOnly = false     -- only allow driver to control radio
Config.AnimationDefaultOn = true  -- enable animations by default
Config.ClientHardDisable = false  -- disables file loading when client's rradio_enabled convar is set to 0 (relog required to re-enable) (does not include config and its dependencies)
Config.DisablePushDamage = true  -- disable push damage
Config.PrioritiseCustom  = true -- the custom / server added station category will appear at the top of the menu (instead of alphabetical)
Config.AllowCreatePermanentBoombox = true -- allow new permanent boomboxes to be created by superadmins

Config.MaxClientStations = 10
Config.SearchDebounceSeconds = 0.1
Config.MessageCooldown = 5
Config.MaxVolume = 1
Config.InactiveTimeout = 3600
Config.CleanupInterval = 300
Config.VolumeUpdateDebounce = 0.1
Config.StationUpdateDebounce = 10

Config.MaxActiveRadios = 100
Config.MaxPlayerRadios = 15

--[[ ! Conditional Load Settings ! ]]

Config.ConditionalStationLoad = true -- only load station audio when within range
Config.ConditionalStationUnload = true -- unload station audio when out of range

-- Ensure that unload is more than or equal to load to prevent stations from being unloaded before they are loaded
Config.LoadDistanceFactor   = 2.0 -- multiplier for the distance before a station starts loading (where 1 is the max hearing distance)
Config.UnloadDistanceFactor = 2.5 -- multiplier for the distance before a station unloads (where 1 is the max hearing distance)

--[[ ! Custom Station Settings ! ]]

-- name of the category for all custom stations, e.g. "Our Favourite Stations!"
-- the key is only localised if set to "Custom" (case sensitive)
Config.CustomStationCategory = "Custom"
Config.CommandAddStation = "rradioadd"
Config.CommandRemoveStation = "rradiorem"

--[[ ! Client Sound settings ! ]]

Config.EnableSoundEffects = true 

Config.Sounds = {
    ButtonPressMain = "buttons/button3.wav",
    ButtonPressSecondary = "buttons/button17.wav",
    SettingsMenuSuccess = "common/bugreporter_succeeded.wav",
    SettingsMenuError = "common/warning.wav",
    MenuClosed = "buttons/lightswitch2.wav",
    StopStation = "buttons/button6.wav"
}

--[[ !! Entity Configuration !! ]]

Config.Boombox = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

Config.GoldenBoombox = {
    Volume = 1.0,
    MaxHearingDistance = 350000,
    MinVolumeDistance = 250000,
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

--[[ ! Additional settings ! ]]

Config.MaxNameChars = 40 -- Truncate station names sent to the server to this length

Config.VehicleClassOverides = {
    "lvs_",
    "ses_",
    "sw_",
    "drs_"
}

--[[ ! Internal settings ! ]]

Config.RadioStations = Config.RadioStations or {}
Config.Lang = Config.Lang or {}

Radio.status = Radio.status or {}

Radio.status = {
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

Config.UI = Config.UI or DEFAULT_UI

if Radio.DEV then
    Config.SecureStationLoad = true
    Config.DriverPlayOnly = true
    Config.AnimationDefaultOn = false
    Config.ClientHardDisable = true
    Config.CustomStationCategory = "Rammel's Top Stations"
end

return Radio.config
