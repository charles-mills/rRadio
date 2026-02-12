rRadio.config = rRadio.config or {}
rRadio.config.RadioVersion = "1.2.7"
--[[ ! Server settings ! ]]
rRadio.config.EnableLogging = true -- enable bLogs integration
rRadio.config.SecureStationLoad = false -- block playing stations not in the client's list
rRadio.config.DriverPlayOnly = false -- only allow driver to control radio
rRadio.config.AnimationDefaultOn = true -- enable animations by default
-- disables file loading when client's rradio_enabled convar is set to 0
-- (relog required to re-enable) (does not include config and its dependencies)
rRadio.config.ClientHardDisable = false
rRadio.config.DisablePushDamage = true -- disable push damage
-- the custom / server added station category will appear at the top of the menu
-- (instead of alphabetical)
rRadio.config.PrioritiseCustom = true
rRadio.config.AllowCreatePermanentBoombox = true -- allow new permanent boomboxes to be created by superadmins
rRadio.config.MaxClientStations = 10
rRadio.config.SearchDebounceSeconds = 0.1
rRadio.config.MessageCooldown = 5
rRadio.config.MaxVolume = 1
rRadio.config.InactiveTimeout = 3600
rRadio.config.CleanupInterval = 300
rRadio.config.VolumeUpdateDebounce = 0.1
rRadio.config.StationUpdateDebounce = 10
rRadio.config.ErrorDisplayDuration = 5
rRadio.config.MaxActiveRadios = 100
rRadio.config.MaxPlayerRadios = 15
--[[ ! Conditional Load Settings ! ]]
rRadio.config.ConditionalStationLoad = true -- only load station audio when within range
rRadio.config.ConditionalStationUnload = true -- unload station audio when out of range
-- Ensure that unload is more than or equal to load to prevent stations from being unloaded before they are loaded
-- multiplier for the distance before a station starts loading
-- (where 1 is the max hearing distance)
rRadio.config.LoadDistanceFactor = 2.0
-- multiplier for the distance before a station unloads
-- (where 1 is the max hearing distance)
rRadio.config.UnloadDistanceFactor = 2.5
--[[ ! Custom Station Settings ! ]]
-- name of the category for all custom stations, e.g. "Our Favourite Stations!"
-- the key is only localised if set to "Custom" (case sensitive)
rRadio.config.CustomStationCategory = "Custom"
rRadio.config.CommandAddStation = "rradioadd"
rRadio.config.CommandRemoveStation = "rradiorem"
--[[ ! Client Sound settings ! ]]
rRadio.config.EnableSoundEffects = true
rRadio.config.Sounds = {
    ButtonPressMain = "buttons/button3.wav",
    ButtonPressSecondary = "buttons/button17.wav",
    SettingsMenuSuccess = "common/bugreporter_succeeded.wav",
    SettingsMenuError = "common/warning.wav",
    MenuClosed = "buttons/lightswitch2.wav",
    StopStation = "buttons/button6.wav"
}

--[[ !! Entity Configuration !! ]]
rRadio.config.Boombox = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.GoldenBoombox = {
    Volume = 1.0,
    MaxHearingDistance = 350000,
    MinVolumeDistance = 250000,
    RetryAttempts = 3,
    RetryDelay = 2
}

rRadio.config.VehicleRadio = {
    Volume = 1.0,
    MaxHearingDistance = 800,
    MinVolumeDistance = 500,
    RetryAttempts = 3,
    RetryDelay = 2
}

--[[ ! Additional settings ! ]]
rRadio.config.MaxNameChars = 40 -- Truncate station names sent to the server to this length
rRadio.config.FrameSize = {
    width = 600,
    height = 800
}
rRadio.config.MenuScale = {
    Min = 0.75,
    Max = 2.00,
    Default = 1.00,
    WidthDefault = 1.00
}

rRadio.config.VehicleClassOverides = { "lvs_", "ses_", "sw_", "drs_" }
--[[ ! Internal settings ! ]]
rRadio.config.RadioStations = rRadio.config.RadioStations or {}
rRadio.config.Lang = rRadio.config.Lang or {}
rRadio.status = {
    STOPPED = 0,
    TUNING = 1,
    PLAYING = 2,
    ERROR = 3
}

local DEFAULT_UI = {
    BackgroundColor = Color( 0, 0, 0, 255 ),
    AccentPrimary = Color( 58, 114, 255 ),
    Highlight = Color( 58, 114, 255 ),
    TextColor = Color( 255, 255, 255, 255 ),
    Disabled = Color( 180, 180, 180, 255 )
}

rRadio.config.UI = rRadio.config.UI or DEFAULT_UI
if rRadio.DEV then
    rRadio.config.SecureStationLoad = true
    rRadio.config.DriverPlayOnly = true
    rRadio.config.AnimationDefaultOn = false
    rRadio.config.ClientHardDisable = true
    rRadio.config.CustomStationCategory = "Rammel's Top Stations"
end
return rRadio.config
