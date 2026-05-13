rRadio = rRadio or {}
rRadio.settingsCatalog = rRadio.settingsCatalog or {}

local catalog = rRadio.settingsCatalog

local SERVER_SECTIONS = {
    { id = "serverGeneral", labelKey = "ServerConfigSection.serverGeneral", labelFallback = "Server: General" },
    { id = "serverLimits", labelKey = "ServerConfigSection.serverLimits", labelFallback = "Server: Limits" },
    { id = "serverTiming", labelKey = "ServerConfigSection.serverTiming", labelFallback = "Server: Timing" },
    { id = "serverStations", labelKey = "ServerConfigSection.serverStations", labelFallback = "Server: Stations" },
    { id = "serverCrossfade", labelKey = "ServerConfigSection.serverCrossfade", labelFallback = "Server: Crossfade" },
    { id = "serverOcclusion", labelKey = "ServerConfigSection.serverOcclusion", labelFallback = "Server: Occlusion" },
    { id = "serverBoombox", labelKey = "ServerConfigSection.serverBoombox", labelFallback = "Server: Boombox" },
    {
        id = "serverGoldenBoombox",
        labelKey = "ServerConfigSection.serverGoldenBoombox",
        labelFallback = "Server: Golden Boombox"
    },
    {
        id = "serverVehicleRadio",
        labelKey = "ServerConfigSection.serverVehicleRadio",
        labelFallback = "Server: Vehicle Radio"
    },
    { id = "serverSounds", labelKey = "ServerConfigSection.serverSounds", labelFallback = "Server: Sounds" }
}

local SERVER_SETTINGS = {
    {
        id = "EnableLogging",
        path = { "EnableLogging" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.EnableLogging",
        labelFallback = "Enable integration logging",
        helpKey = "ServerConfigHelp.EnableLogging",
        helpFallback = "Allow rRadio to emit integration log messages when supported."
    },
    {
        id = "SecureStationLoad",
        path = { "SecureStationLoad" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.SecureStationLoad",
        labelFallback = "Secure station loading",
        helpKey = "ServerConfigHelp.SecureStationLoad",
        helpFallback = "Require playback requests to resolve through the validated station registry."
    },
    {
        id = "DriverPlayOnly",
        path = { "DriverPlayOnly" },
        scope = "server",
        type = "bool",
        default = false,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.DriverPlayOnly",
        labelFallback = "Driver play only",
        helpKey = "ServerConfigHelp.DriverPlayOnly",
        helpFallback = "Only vehicle drivers can control vehicle radios."
    },
    {
        id = "AllowAnyVehicleEntityRadio",
        path = { "AllowAnyVehicleEntityRadio" },
        scope = "server",
        type = "bool",
        default = false,
        section = "serverVehicleRadio",
        control = "toggle",
        labelKey = "ServerConfig.AllowAnyVehicleEntityRadio",
        labelFallback = "Allow any vehicle entity",
        helpKey = "ServerConfigHelp.AllowAnyVehicleEntityRadio",
        helpFallback = "Treat every initialized GMod Vehicle entity as radio-compatible "
            .. "when strict vehicle detection fails."
    },
    {
        id = "DisablePushDamage",
        path = { "DisablePushDamage" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.DisablePushDamage",
        labelFallback = "Disable boombox push damage",
        helpKey = "ServerConfigHelp.DisablePushDamage",
        helpFallback = "Disable boombox physics collision damage behavior."
    },
    {
        id = "AllowCreatePermanentBoombox",
        path = { "AllowCreatePermanentBoombox" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.AllowCreatePermanentBoombox",
        labelFallback = "Allow permanent boomboxes",
        helpKey = "ServerConfigHelp.AllowCreatePermanentBoombox",
        helpFallback = "Allow authorized admins to persist boomboxes across restarts."
    },
    {
        id = "EnableSoundEffects",
        path = { "EnableSoundEffects" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverGeneral",
        control = "toggle",
        labelKey = "ServerConfig.EnableSoundEffects",
        labelFallback = "Enable menu sound effects",
        helpKey = "ServerConfigHelp.EnableSoundEffects",
        helpFallback = "Play rRadio interface sound effects on clients."
    },
    {
        id = "MaxClientStations",
        path = { "MaxClientStations" },
        scope = "server",
        type = "integer",
        default = 10,
        section = "serverLimits",
        control = "number",
        minimum = 1,
        maximum = 64,
        labelKey = "ServerConfig.MaxClientStations",
        labelFallback = "Max client streams",
        helpKey = "ServerConfigHelp.MaxClientStations",
        helpFallback = "Maximum number of active radio streams each client keeps loaded."
    },
    {
        id = "RecentStationLimit",
        path = { "RecentStationLimit" },
        scope = "server",
        type = "integer",
        default = 25,
        section = "serverLimits",
        control = "number",
        minimum = 0,
        maximum = 200,
        labelKey = "ServerConfig.RecentStationLimit",
        labelFallback = "Recent station limit",
        helpKey = "ServerConfigHelp.RecentStationLimit",
        helpFallback = "Maximum number of recent stations stored per client."
    },
    {
        id = "MaxVolume",
        path = { "MaxVolume" },
        scope = "server",
        type = "number",
        default = 1,
        section = "serverLimits",
        control = "number",
        minimum = 0,
        maximum = 5,
        decimals = 2,
        labelKey = "ServerConfig.MaxVolume",
        labelFallback = "Maximum volume",
        helpKey = "ServerConfigHelp.MaxVolume",
        helpFallback = "Server-wide volume cap for radio playback."
    },
    {
        id = "MaxActiveRadios",
        path = { "MaxActiveRadios" },
        scope = "server",
        type = "integer",
        default = 100,
        section = "serverLimits",
        control = "number",
        minimum = 1,
        maximum = 4096,
        labelKey = "ServerConfig.MaxActiveRadios",
        labelFallback = "Max active radios",
        helpKey = "ServerConfigHelp.MaxActiveRadios",
        helpFallback = "Maximum active radios allowed across the server."
    },
    {
        id = "MaxPlayerRadios",
        path = { "MaxPlayerRadios" },
        scope = "server",
        type = "integer",
        default = 15,
        section = "serverLimits",
        control = "number",
        minimum = 1,
        maximum = 512,
        labelKey = "ServerConfig.MaxPlayerRadios",
        labelFallback = "Max player radios",
        helpKey = "ServerConfigHelp.MaxPlayerRadios",
        helpFallback = "Maximum radios a player can have active at once."
    },
    {
        id = "MaxNameChars",
        path = { "MaxNameChars" },
        scope = "server",
        type = "integer",
        default = 40,
        section = "serverLimits",
        control = "number",
        minimum = 8,
        maximum = 96,
        labelKey = "ServerConfig.MaxNameChars",
        labelFallback = "Max station name length",
        helpKey = "ServerConfigHelp.MaxNameChars",
        helpFallback = "Maximum display length for custom station names."
    },
    {
        id = "SearchDebounceSeconds",
        path = { "SearchDebounceSeconds" },
        scope = "server",
        type = "number",
        default = 0.1,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 2,
        decimals = 2,
        labelKey = "ServerConfig.SearchDebounceSeconds",
        labelFallback = "Search debounce",
        helpKey = "ServerConfigHelp.SearchDebounceSeconds",
        helpFallback = "Delay before refreshing menu search results."
    },
    {
        id = "MessageCooldown",
        path = { "MessageCooldown" },
        scope = "server",
        type = "number",
        default = 5,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 60,
        decimals = 1,
        labelKey = "ServerConfig.MessageCooldown",
        labelFallback = "Permission message cooldown",
        helpKey = "ServerConfigHelp.MessageCooldown",
        helpFallback = "Seconds between repeated permission chat messages."
    },
    {
        id = "InactiveTimeout",
        path = { "InactiveTimeout" },
        scope = "server",
        type = "number",
        default = 3600,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 86400,
        decimals = 0,
        labelKey = "ServerConfig.InactiveTimeout",
        labelFallback = "Inactive radio timeout",
        helpKey = "ServerConfigHelp.InactiveTimeout",
        helpFallback = "Seconds before inactive radios are cleaned up."
    },
    {
        id = "CleanupInterval",
        path = { "CleanupInterval" },
        scope = "server",
        type = "number",
        default = 300,
        section = "serverTiming",
        control = "number",
        minimum = 5,
        maximum = 3600,
        decimals = 0,
        labelKey = "ServerConfig.CleanupInterval",
        labelFallback = "Cleanup interval",
        helpKey = "ServerConfigHelp.CleanupInterval",
        helpFallback = "Seconds between inactive and invalid radio cleanup passes."
    },
    {
        id = "VolumeUpdateDebounce",
        path = { "VolumeUpdateDebounce" },
        scope = "server",
        type = "number",
        default = 0.1,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 2,
        decimals = 2,
        labelKey = "ServerConfig.VolumeUpdateDebounce",
        labelFallback = "Volume update debounce",
        helpKey = "ServerConfigHelp.VolumeUpdateDebounce",
        helpFallback = "Client-side delay before sending dragged volume changes."
    },
    {
        id = "VolumeControlCooldown",
        path = { "VolumeControlCooldown" },
        scope = "server",
        type = "number",
        default = 0.05,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 5,
        decimals = 2,
        labelKey = "ServerConfig.VolumeControlCooldown",
        labelFallback = "Volume control cooldown",
        helpKey = "ServerConfigHelp.VolumeControlCooldown",
        helpFallback = "Server-side cooldown between accepted volume changes."
    },
    {
        id = "StationUpdateDebounce",
        path = { "StationUpdateDebounce" },
        scope = "server",
        type = "number",
        default = 10,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 120,
        decimals = 1,
        labelKey = "ServerConfig.StationUpdateDebounce",
        labelFallback = "Station update debounce",
        helpKey = "ServerConfigHelp.StationUpdateDebounce",
        helpFallback = "Delay used by station update workflows."
    },
    {
        id = "ErrorDisplayDuration",
        path = { "ErrorDisplayDuration" },
        scope = "server",
        type = "number",
        default = 5,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 60,
        decimals = 1,
        labelKey = "ServerConfig.ErrorDisplayDuration",
        labelFallback = "Error display duration",
        helpKey = "ServerConfigHelp.ErrorDisplayDuration",
        helpFallback = "Seconds client-side station errors stay visible."
    },
    {
        id = "ControlCooldown",
        path = { "ControlCooldown" },
        scope = "server",
        type = "number",
        default = 0.25,
        section = "serverTiming",
        control = "number",
        minimum = 0,
        maximum = 5,
        decimals = 2,
        labelKey = "ServerConfig.ControlCooldown",
        labelFallback = "Control cooldown",
        helpKey = "ServerConfigHelp.ControlCooldown",
        helpFallback = "Server-side cooldown between accepted radio control actions."
    },
    {
        id = "PrioritiseCustom",
        path = { "PrioritiseCustom" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverStations",
        control = "toggle",
        labelKey = "ServerConfig.PrioritiseCustom",
        labelFallback = "Prioritise custom stations",
        helpKey = "ServerConfigHelp.PrioritiseCustom",
        helpFallback = "Show the custom station category before generated station countries."
    },
    {
        id = "ConditionalStationLoad",
        path = { "ConditionalStationLoad" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverStations",
        control = "toggle",
        labelKey = "ServerConfig.ConditionalStationLoad",
        labelFallback = "Conditional station load",
        helpKey = "ServerConfigHelp.ConditionalStationLoad",
        helpFallback = "Only load radio streams while clients are close enough to hear them."
    },
    {
        id = "ConditionalStationUnload",
        path = { "ConditionalStationUnload" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverStations",
        control = "toggle",
        labelKey = "ServerConfig.ConditionalStationUnload",
        labelFallback = "Conditional station unload",
        helpKey = "ServerConfigHelp.ConditionalStationUnload",
        helpFallback = "Unload radio streams after clients move outside the unload range."
    },
    {
        id = "LoadDistanceFactor",
        path = { "LoadDistanceFactor" },
        scope = "server",
        type = "number",
        default = 2.0,
        section = "serverStations",
        control = "number",
        minimum = 0,
        maximum = 20,
        decimals = 2,
        labelKey = "ServerConfig.LoadDistanceFactor",
        labelFallback = "Load distance factor",
        helpKey = "ServerConfigHelp.LoadDistanceFactor",
        helpFallback = "Multiplier applied to hearing distance before client streams are loaded."
    },
    {
        id = "UnloadDistanceFactor",
        path = { "UnloadDistanceFactor" },
        scope = "server",
        type = "number",
        default = 2.5,
        section = "serverStations",
        control = "number",
        minimum = 0,
        maximum = 20,
        decimals = 2,
        labelKey = "ServerConfig.UnloadDistanceFactor",
        labelFallback = "Unload distance factor",
        helpKey = "ServerConfigHelp.UnloadDistanceFactor",
        helpFallback = "Multiplier applied to hearing distance before client streams are unloaded."
    },
    {
        id = "CustomStationCategory",
        path = { "CustomStationCategory" },
        scope = "server",
        type = "string",
        default = "Custom",
        section = "serverStations",
        control = "text",
        maxLength = 64,
        required = true,
        labelKey = "ServerConfig.CustomStationCategory",
        labelFallback = "Custom station category",
        helpKey = "ServerConfigHelp.CustomStationCategory",
        helpFallback = "Category name used for custom stations in the station browser."
    },
    {
        id = "Crossfade.StationChangeMs",
        path = { "Crossfade", "StationChangeMs" },
        scope = "server",
        type = "integer",
        default = 4000,
        section = "serverCrossfade",
        control = "number",
        minimum = 0,
        maximum = 30000,
        labelKey = "ServerConfig.Crossfade.StationChangeMs",
        labelFallback = "Station change fade",
        helpKey = "ServerConfigHelp.Crossfade.StationChangeMs",
        helpFallback = "Milliseconds used when fading between stations."
    },
    {
        id = "Crossfade.InitialFadeInMs",
        path = { "Crossfade", "InitialFadeInMs" },
        scope = "server",
        type = "integer",
        default = 200,
        section = "serverCrossfade",
        control = "number",
        minimum = 0,
        maximum = 30000,
        labelKey = "ServerConfig.Crossfade.InitialFadeInMs",
        labelFallback = "Initial fade in",
        helpKey = "ServerConfigHelp.Crossfade.InitialFadeInMs",
        helpFallback = "Milliseconds used for initial stream fade in."
    },
    {
        id = "Crossfade.StopFadeOutMs",
        path = { "Crossfade", "StopFadeOutMs" },
        scope = "server",
        type = "integer",
        default = 250,
        section = "serverCrossfade",
        control = "number",
        minimum = 0,
        maximum = 30000,
        labelKey = "ServerConfig.Crossfade.StopFadeOutMs",
        labelFallback = "Stop fade out",
        helpKey = "ServerConfigHelp.Crossfade.StopFadeOutMs",
        helpFallback = "Milliseconds used when stopping a stream."
    },
    {
        id = "Crossfade.TickInterval",
        path = { "Crossfade", "TickInterval" },
        scope = "server",
        type = "number",
        default = 0.05,
        section = "serverCrossfade",
        control = "number",
        minimum = 0.01,
        maximum = 1,
        decimals = 2,
        labelKey = "ServerConfig.Crossfade.TickInterval",
        labelFallback = "Fade tick interval",
        helpKey = "ServerConfigHelp.Crossfade.TickInterval",
        helpFallback = "Seconds between crossfade envelope updates."
    },
    {
        id = "Crossfade.MaxOutgoing",
        path = { "Crossfade", "MaxOutgoing" },
        scope = "server",
        type = "integer",
        default = 3,
        section = "serverCrossfade",
        control = "number",
        minimum = 0,
        maximum = 16,
        labelKey = "ServerConfig.Crossfade.MaxOutgoing",
        labelFallback = "Max outgoing streams",
        helpKey = "ServerConfigHelp.Crossfade.MaxOutgoing",
        helpFallback = "Maximum old streams kept alive during crossfades."
    },
    {
        id = "Occlusion.Enabled",
        path = { "Occlusion", "Enabled" },
        scope = "server",
        type = "bool",
        default = true,
        section = "serverOcclusion",
        control = "toggle",
        labelKey = "ServerConfig.Occlusion.Enabled",
        labelFallback = "Enable occlusion",
        helpKey = "ServerConfigHelp.Occlusion.Enabled",
        helpFallback = "Reduce radio volume when world geometry blocks the source."
    },
    {
        id = "Occlusion.TraceInterval",
        path = { "Occlusion", "TraceInterval" },
        scope = "server",
        type = "number",
        default = 0.2,
        section = "serverOcclusion",
        control = "number",
        minimum = 0.01,
        maximum = 5,
        decimals = 2,
        labelKey = "ServerConfig.Occlusion.TraceInterval",
        labelFallback = "Trace interval",
        helpKey = "ServerConfigHelp.Occlusion.TraceInterval",
        helpFallback = "Seconds between occlusion traces per stream."
    },
    {
        id = "Occlusion.MaxTracesPerTick",
        path = { "Occlusion", "MaxTracesPerTick" },
        scope = "server",
        type = "integer",
        default = 4,
        section = "serverOcclusion",
        control = "number",
        minimum = 1,
        maximum = 128,
        labelKey = "ServerConfig.Occlusion.MaxTracesPerTick",
        labelFallback = "Trace budget",
        helpKey = "ServerConfigHelp.Occlusion.MaxTracesPerTick",
        helpFallback = "Maximum occlusion traces processed per client tick."
    },
    {
        id = "Occlusion.BlockedVolumeMultiplier",
        path = { "Occlusion", "BlockedVolumeMultiplier" },
        scope = "server",
        type = "number",
        default = 0.35,
        section = "serverOcclusion",
        control = "number",
        minimum = 0,
        maximum = 1,
        decimals = 2,
        labelKey = "ServerConfig.Occlusion.BlockedVolumeMultiplier",
        labelFallback = "Blocked volume multiplier",
        helpKey = "ServerConfigHelp.Occlusion.BlockedVolumeMultiplier",
        helpFallback = "Volume multiplier used when a stream is occluded."
    },
    {
        id = "Occlusion.SmoothingSpeed",
        path = { "Occlusion", "SmoothingSpeed" },
        scope = "server",
        type = "number",
        default = 8,
        section = "serverOcclusion",
        control = "number",
        minimum = 0,
        maximum = 64,
        decimals = 1,
        labelKey = "ServerConfig.Occlusion.SmoothingSpeed",
        labelFallback = "Occlusion smoothing",
        helpKey = "ServerConfigHelp.Occlusion.SmoothingSpeed",
        helpFallback = "Speed used when smoothing occlusion volume changes."
    }
}

local RADIO_CONFIG_FIELDS = {
    {
        suffix = "Volume",
        type = "number",
        default = 1.0,
        labelSuffix = "volume",
        helpFallback = "Default volume for this radio type.",
        minimum = 0,
        maximum = 5,
        decimals = 2
    },
    {
        suffix = "FullVolumeDistance",
        type = "number",
        default = 120,
        labelSuffix = "full volume distance",
        helpFallback = "Distance where this radio type remains at full volume.",
        minimum = 0,
        maximum = 1000000,
        decimals = 0
    },
    {
        suffix = "MaxHearingDistance",
        type = "number",
        default = 900,
        labelSuffix = "max hearing distance",
        helpFallback = "Maximum distance where this radio type can be heard.",
        minimum = 1,
        maximum = 1000000,
        decimals = 0
    },
    {
        suffix = "DistanceFalloffExponent",
        type = "number",
        default = 1.35,
        labelSuffix = "falloff exponent",
        helpFallback = "Volume falloff curve exponent for this radio type.",
        minimum = 0.1,
        maximum = 10,
        decimals = 2
    },
    {
        suffix = "RetryAttempts",
        type = "integer",
        default = 3,
        labelSuffix = "retry attempts",
        helpFallback = "Number of stream retry attempts for this radio type.",
        minimum = 0,
        maximum = 20
    },
    {
        suffix = "RetryDelay",
        type = "number",
        default = 2,
        labelSuffix = "retry delay",
        helpFallback = "Seconds between stream retry attempts for this radio type.",
        minimum = 0,
        maximum = 60,
        decimals = 1
    }
}

local function appendRadioConfig( prefix, sectionID, labelPrefix, overrides )
    overrides = overrides or {}

    for _, field in ipairs( RADIO_CONFIG_FIELDS ) do
        local default = overrides[field.suffix]
        if default == nil then default = field.default end

        SERVER_SETTINGS[#SERVER_SETTINGS + 1] = {
            id = prefix .. "." .. field.suffix,
            path = { prefix, field.suffix },
            scope = "server",
            type = field.type,
            default = default,
            section = sectionID,
            control = "number",
            minimum = field.minimum,
            maximum = field.maximum,
            decimals = field.decimals,
            labelKey = "ServerConfig." .. prefix .. "." .. field.suffix,
            labelFallback = labelPrefix .. " " .. field.labelSuffix,
            helpKey = "ServerConfigHelp." .. prefix .. "." .. field.suffix,
            helpFallback = field.helpFallback
        }
    end
end

appendRadioConfig( "Boombox", "serverBoombox", "Boombox" )
appendRadioConfig( "GoldenBoombox", "serverGoldenBoombox", "Golden boombox", {
    FullVolumeDistance = 250000,
    MaxHearingDistance = 350000
} )
appendRadioConfig( "VehicleRadio", "serverVehicleRadio", "Vehicle radio" )

local SOUND_SETTINGS = {
    {
        id = "Sounds.ButtonPressMain",
        path = { "Sounds", "ButtonPressMain" },
        default = "buttons/button3.wav",
        labelFallback = "Main button sound",
        helpFallback = "Sound path played for primary rRadio button actions."
    },
    {
        id = "Sounds.ButtonPressSecondary",
        path = { "Sounds", "ButtonPressSecondary" },
        default = "buttons/button17.wav",
        labelFallback = "Secondary button sound",
        helpFallback = "Sound path played for secondary rRadio button actions."
    },
    {
        id = "Sounds.SettingsMenuSuccess",
        path = { "Sounds", "SettingsMenuSuccess" },
        default = "common/bugreporter_succeeded.wav",
        labelFallback = "Settings success sound",
        helpFallback = "Sound path played after a successful settings action."
    },
    {
        id = "Sounds.SettingsMenuError",
        path = { "Sounds", "SettingsMenuError" },
        default = "common/warning.wav",
        labelFallback = "Settings error sound",
        helpFallback = "Sound path played after a failed settings action."
    },
    {
        id = "Sounds.MenuClosed",
        path = { "Sounds", "MenuClosed" },
        default = "buttons/lightswitch2.wav",
        labelFallback = "Menu closed sound",
        helpFallback = "Sound path played when the rRadio menu closes."
    },
    {
        id = "Sounds.StopStation",
        path = { "Sounds", "StopStation" },
        default = "buttons/button6.wav",
        labelFallback = "Stop station sound",
        helpFallback = "Sound path played when a station is stopped."
    }
}

for _, soundSetting in ipairs( SOUND_SETTINGS ) do
    soundSetting.scope = "server"
    soundSetting.type = "string"
    soundSetting.section = "serverSounds"
    soundSetting.control = "text"
    soundSetting.maxLength = 128
    soundSetting.labelKey = "ServerConfig." .. soundSetting.id
    soundSetting.helpKey = "ServerConfigHelp." .. soundSetting.id
    SERVER_SETTINGS[#SERVER_SETTINGS + 1] = soundSetting
end

local INTERNAL_CONFIG_SETTINGS = {
    { id = "AnimationDefaultOn", path = { "AnimationDefaultOn" }, scope = "internal", type = "bool", default = true },
    {
        id = "Boombox.SourceOffset",
        path = { "Boombox", "SourceOffset" },
        scope = "internal",
        type = "vector",
        default = Vector( 5, 0, 8 )
    },
    {
        id = "GoldenBoombox.SourceOffset",
        path = { "GoldenBoombox", "SourceOffset" },
        scope = "internal",
        type = "vector",
        default = Vector( 5, 0, 8 )
    },
    {
        id = "VehicleHint.CooldownSeconds",
        path = { "VehicleHint", "CooldownSeconds" },
        scope = "internal",
        type = "number",
        default = 5
    },
    {
        id = "VehicleHint.ShowSeconds",
        path = { "VehicleHint", "ShowSeconds" },
        scope = "internal",
        type = "number",
        default = 2
    },
    {
        id = "VehicleHint.AnimationSeconds",
        path = { "VehicleHint", "AnimationSeconds" },
        scope = "internal",
        type = "number",
        default = 1.0
    },
    {
        id = "VehicleHint.AnchorY",
        path = { "VehicleHint", "AnchorY" },
        scope = "internal",
        type = "number",
        default = 0.20
    },
    {
        id = "VehicleHint.Width",
        path = { "VehicleHint", "Width" },
        scope = "internal",
        type = "integer",
        default = 300
    },
    {
        id = "VehicleHint.Height",
        path = { "VehicleHint", "Height" },
        scope = "internal",
        type = "integer",
        default = 70
    },
    {
        id = "VehicleHint.KeyWidth",
        path = { "VehicleHint", "KeyWidth" },
        scope = "internal",
        type = "integer",
        default = 40
    },
    {
        id = "VehicleHint.KeyHeight",
        path = { "VehicleHint", "KeyHeight" },
        scope = "internal",
        type = "integer",
        default = 30
    },
    {
        id = "VehicleHint.KeyMarginLeft",
        path = { "VehicleHint", "KeyMarginLeft" },
        scope = "internal",
        type = "integer",
        default = 20
    },
    {
        id = "VehicleHint.DividerGap",
        path = { "VehicleHint", "DividerGap" },
        scope = "internal",
        type = "integer",
        default = 7
    },
    {
        id = "VehicleHint.MessageGap",
        path = { "VehicleHint", "MessageGap" },
        scope = "internal",
        type = "integer",
        default = 15
    },
    {
        id = "VehicleHint.PanelRadius",
        path = { "VehicleHint", "PanelRadius" },
        scope = "internal",
        type = "integer",
        default = 12
    },
    {
        id = "VehicleHint.KeycapRadius",
        path = { "VehicleHint", "KeycapRadius" },
        scope = "internal",
        type = "integer",
        default = 6
    },
    {
        id = "VehicleHint.PulseHz",
        path = { "VehicleHint", "PulseHz" },
        scope = "internal",
        type = "number",
        default = 1.5
    },
    {
        id = "VehicleHint.PulseAmplitude",
        path = { "VehicleHint", "PulseAmplitude" },
        scope = "internal",
        type = "number",
        default = 0.05
    },
    {
        id = "VehicleHint.HoverBrightness",
        path = { "VehicleHint", "HoverBrightness" },
        scope = "internal",
        type = "number",
        default = 1.2
    },
    { id = "FrameSize.width", path = { "FrameSize", "width" }, scope = "internal", type = "integer", default = 600 },
    { id = "FrameSize.height", path = { "FrameSize", "height" }, scope = "internal", type = "integer", default = 800 },
    { id = "MenuScale.Min", path = { "MenuScale", "Min" }, scope = "internal", type = "number", default = 0.75 },
    { id = "MenuScale.Max", path = { "MenuScale", "Max" }, scope = "internal", type = "number", default = 2.00 },
    {
        id = "MenuScale.Default",
        path = { "MenuScale", "Default" },
        scope = "internal",
        type = "number",
        default = 1.00
    },
    {
        id = "MenuScale.WidthDefault",
        path = { "MenuScale", "WidthDefault" },
        scope = "internal",
        type = "number",
        default = 1.00
    },
    {
        id = "UI.BackgroundColor",
        path = { "UI", "BackgroundColor" },
        scope = "internal",
        type = "color",
        default = Color( 0, 0, 0, 255 )
    },
    {
        id = "UI.PanelColor",
        path = { "UI", "PanelColor" },
        scope = "internal",
        type = "color",
        default = Color( 18, 18, 20, 245 )
    },
    {
        id = "UI.AccentPrimary",
        path = { "UI", "AccentPrimary" },
        scope = "internal",
        type = "color",
        default = Color( 58, 114, 255 )
    },
    {
        id = "UI.Highlight",
        path = { "UI", "Highlight" },
        scope = "internal",
        type = "color",
        default = Color( 58, 114, 255 )
    },
    {
        id = "UI.TextColor",
        path = { "UI", "TextColor" },
        scope = "internal",
        type = "color",
        default = Color( 255, 255, 255, 255 )
    },
    {
        id = "UI.Disabled",
        path = { "UI", "Disabled" },
        scope = "internal",
        type = "color",
        default = Color( 180, 180, 180, 255 )
    },
    { id = "UI.Error", path = { "UI", "Error" }, scope = "internal", type = "color", default = Color( 248, 81, 73 ) }
}

local function getMenuScaleConfig()
    return rRadio.config and rRadio.config.MenuScale or {}
end

local CLIENT_SETTINGS = {
    {
        id = "menuTheme",
        section = "appearance",
        scope = "client",
        control = "choice",
        conVarID = "menuTheme",
        conVarName = "rammel_rradio_menu_theme",
        default = "dark",
        labelKey = "SelectTheme",
        labelFallback = "Select Theme",
        helpKey = "SettingMenuThemeHelp",
        helpFallback = "Choose the visual theme used by the radio menu."
    },
    {
        id = "softBorders",
        section = "appearance",
        scope = "client",
        control = "toggle",
        conVarID = "softBorders",
        conVarName = "rammel_rradio_menu_soft_borders",
        default = "1",
        labelKey = "SoftUI",
        labelFallback = "Soft UI",
        helpKey = "SettingSoftUIHelp",
        helpFallback = "Use softer borders and lighter separators for menu controls."
    },
    {
        id = "goldBoomboxTheme",
        section = "appearance",
        scope = "client",
        control = "toggle",
        conVarID = "goldBoomboxTheme",
        conVarName = "rammel_rradio_gold_boombox_theme",
        default = "1",
        labelKey = "GoldBoomboxTheme",
        labelFallback = "Gold boombox theme",
        helpKey = "SettingGoldBoomboxThemeHelp",
        helpFallback = "Use the exclusive gold menu and HUD theme for golden boomboxes."
    },
    {
        id = "hideResizeGrabbers",
        section = "appearance",
        scope = "client",
        control = "toggle",
        conVarID = "hideResizeGrabbers",
        conVarName = "rammel_rradio_hide_resize_grabbers",
        default = "0",
        labelKey = "HideResizeGrabbers",
        labelFallback = "Hide resize grabbers",
        helpKey = "SettingHideResizeGrabbersHelp",
        helpFallback = "Only show menu resize grabbers while hovering or resizing."
    },
    {
        id = "menuMoveCursor",
        section = "controls",
        scope = "client",
        control = "toggle",
        conVarID = "menuMoveCursor",
        conVarName = "rammel_rradio_menu_move_cursor",
        default = "1",
        labelKey = "MoveCursorOnMenuOpen",
        labelFallback = "Move cursor on menu open",
        helpKey = "SettingMoveCursorOnMenuOpenHelp",
        helpFallback = "Move the cursor to the radio menu when it opens."
    },
    {
        id = "menuScale",
        section = "appearance",
        scope = "client",
        control = "slider",
        conVarID = "menuScale",
        conVarName = "rammel_rradio_menu_scale",
        default = function()
            return tonumber( getMenuScaleConfig().Default ) or 1
        end,
        minimum = function()
            return tonumber( getMenuScaleConfig().Min ) or 0.75
        end,
        maximum = function()
            return tonumber( getMenuScaleConfig().Max ) or 2
        end,
        decimals = 2,
        labelKey = "MenuScaleSize",
        labelFallback = "Menu Size",
        helpKey = "SettingMenuScaleHelp",
        helpFallback = "Adjust the overall height and text scale of the radio menu."
    },
    {
        id = "menuWidthScale",
        section = "appearance",
        scope = "client",
        control = "slider",
        conVarID = "menuWidthScale",
        conVarName = "rammel_rradio_menu_width_scale",
        default = function()
            return tonumber( getMenuScaleConfig().WidthDefault ) or 1
        end,
        minimum = function()
            local config = getMenuScaleConfig()
            return tonumber( config.WidthMin ) or tonumber( config.Min ) or 0.75
        end,
        maximum = function()
            local config = getMenuScaleConfig()
            return tonumber( config.WidthMax ) or tonumber( config.Max ) or 2
        end,
        decimals = 2,
        labelKey = "MenuScaleWidth",
        labelFallback = "Menu Width",
        helpKey = "SettingMenuWidthHelp",
        helpFallback = "Adjust only the width of the radio menu."
    },
    {
        id = "menuKey",
        section = "controls",
        scope = "client",
        control = "keybind",
        conVarID = "menuKey",
        conVarName = "rammel_rradio_menu_key",
        default = "21",
        labelKey = "SelectKey",
        labelFallback = "Open Vehicle Radio Menu",
        helpKey = "SettingMenuKeyHelp",
        helpFallback = "Choose the key that opens the radio menu while driving."
    },
    {
        id = "blockVehicleKillBind",
        section = "controls",
        scope = "client",
        control = "toggle",
        conVarID = "blockVehicleKillBind",
        conVarName = "rammel_rradio_block_vehicle_kill_bind",
        default = "1",
        labelKey = "BlockVehicleKillBind",
        labelFallback = "Block kill on menu key",
        helpKey = "SettingBlockVehicleKillBindHelp",
        helpFallback = "Block kill when the radio menu key is pressed in an rRadio vehicle."
    },
    {
        id = "maxVolume",
        section = "audio",
        scope = "client",
        control = "slider",
        conVarID = "maxVolume",
        conVarName = "rammel_rradio_max_volume",
        conVarDefault = "1.0",
        default = 1,
        minimum = 0,
        maximum = function()
            return tonumber( rRadio.config and rRadio.config.MaxVolume ) or 1
        end,
        decimals = 2,
        labelKey = "MaxVolumeCap",
        labelFallback = "Global Volume Cap",
        helpKey = "SettingMaxVolumeHelp",
        helpFallback = "Cap all local radio playback volume."
    },
    {
        id = "crossfadeMs",
        section = "audio",
        scope = "client",
        control = "slider",
        conVarID = "crossfadeMs",
        conVarName = "rammel_rradio_crossfade_ms",
        default = function()
            local crossfade = rRadio.config and rRadio.config.Crossfade
            return tonumber( crossfade and crossfade.StationChangeMs ) or 0
        end,
        conVarDefault = function()
            local crossfade = rRadio.config and rRadio.config.Crossfade
            return tostring( crossfade and crossfade.StationChangeMs or 0 )
        end,
        minimum = 0,
        maximum = 6000,
        decimals = 0,
        labelKey = "CrossfadeDuration",
        labelFallback = "Crossfade duration",
        helpKey = "SettingCrossfadeDurationHelp",
        helpFallback = "Set transition length. Use 0 ms to disable crossfade."
    },
    {
        id = "muteGameMenu",
        section = "audio",
        scope = "client",
        control = "toggle",
        conVarID = "muteGameMenu",
        conVarName = "rammel_rradio_mute_game_menu",
        default = "1",
        labelKey = "MuteInEscapeMenu",
        labelFallback = "Mute in Escape Menu",
        helpKey = "SettingMuteGameMenuHelp",
        helpFallback = "Mute local radio playback while the Escape menu is open."
    },
    {
        id = "enabled",
        section = "general",
        scope = "client",
        control = "toggle",
        conVarID = "enabled",
        conVarName = "rammel_rradio_enabled",
        default = "1",
        labelKey = "EnableRRadio",
        labelFallback = "Enable rRadio",
        helpKey = "SettingEnabledHelp",
        helpFallback = "Enable or disable local rRadio playback and menu access.",
        confirmOff = true,
        confirmTitleKey = "DisableRRadioConfirmTitle",
        confirmTitleFallback = "Disable rRadio?",
        confirmMessageKey = "DisableRRadioConfirmMessage",
        confirmMessageFallback = "This will stop local playback and close the radio UI.",
        confirmActionKey = "DisableRRadioConfirmAction",
        confirmActionFallback = "Disable"
    },
    {
        id = "boomboxHud",
        section = "general",
        scope = "client",
        control = "toggle",
        conVarID = "boomboxHud",
        conVarName = "rammel_rradio_boombox_hud",
        default = "1",
        labelKey = "ShowBoomboxHUD",
        labelFallback = "Show the Boombox HUD",
        helpKey = "SettingBoomboxHUDHelp",
        helpFallback = "Show the full boombox HUD when looking at a radio."
    },
    {
        id = "boomboxHudMode",
        section = "general",
        scope = "client",
        control = "choice",
        conVarID = "boomboxHudMode",
        conVarName = "rammel_rradio_boombox_hud_mode",
        default = "full",
        labelKey = "BoomboxHUDMode",
        labelFallback = "Boombox HUD Mode"
    },
    {
        id = "vehicleAnimation",
        section = "general",
        scope = "client",
        control = "toggle",
        conVarID = "vehicleAnimation",
        conVarName = "rammel_rradio_vehicle_animation",
        default = function()
            return rRadio.config and rRadio.config.AnimationDefaultOn and "1" or "0"
        end,
        labelKey = "ShowCarMessages",
        labelFallback = "Show Animation When Entering Vehicle",
        helpKey = "SettingVehicleAnimationHelp",
        helpFallback = "Show the vehicle radio hint animation when entering supported vehicles."
    }
}

local function copyValue( value )
    if isvector and isvector( value ) then return Vector( value.x, value.y, value.z ) end
    if type( value ) ~= "table" then return value end

    local copy = {}
    for key, child in pairs( value ) do
        copy[key] = copyValue( child )
    end

    return copy
end

local function resolveValue( value )
    if type( value ) == "function" then return value() end

    return value
end

local function buildConfigSettings()
    local rows = {}

    for _, setting in ipairs( SERVER_SETTINGS ) do
        rows[#rows + 1] = setting
    end

    for _, setting in ipairs( INTERNAL_CONFIG_SETTINGS ) do
        rows[#rows + 1] = setting
    end

    return rows
end

local CONFIG_SETTINGS = buildConfigSettings()

local function addLocalisationRequirement( rows, key, fallback )
    if not key then return end

    rows[#rows + 1] = {
        key = key,
        fallback = fallback or key
    }
end

function catalog.CopyValue( value )
    return copyValue( value )
end

function catalog.ResolveValue( value )
    return resolveValue( value )
end

function catalog.GetDefaultValue( setting )
    if not setting then return nil end

    return copyValue( resolveValue( setting.default ) )
end

function catalog.GetConfigSettings()
    return CONFIG_SETTINGS
end

function catalog.GetServerSections()
    return SERVER_SECTIONS
end

function catalog.GetServerSettings()
    return SERVER_SETTINGS
end

function catalog.GetClientSettings()
    return CLIENT_SETTINGS
end

function catalog.GetClientConVarDefinitions()
    local definitions = {}

    for _, setting in ipairs( CLIENT_SETTINGS ) do
        if setting.conVarName then
            local default = setting.conVarDefault
            if default == nil then default = setting.default end

            definitions[#definitions + 1] = {
                id = setting.conVarID or setting.id,
                name = setting.conVarName,
                default = tostring( resolveValue( default ) or "" )
            }
        end
    end

    return definitions
end

function catalog.GetLocalisationRequirements()
    local rows = {}

    for _, section in ipairs( SERVER_SECTIONS ) do
        addLocalisationRequirement( rows, section.labelKey, section.labelFallback )
    end

    for _, setting in ipairs( SERVER_SETTINGS ) do
        addLocalisationRequirement( rows, setting.labelKey, setting.labelFallback )
        addLocalisationRequirement( rows, setting.helpKey, setting.helpFallback )
    end

    for _, setting in ipairs( CLIENT_SETTINGS ) do
        addLocalisationRequirement( rows, setting.labelKey, setting.labelFallback )
        addLocalisationRequirement( rows, setting.helpKey, setting.helpFallback )
        addLocalisationRequirement( rows, setting.confirmTitleKey, setting.confirmTitleFallback )
        addLocalisationRequirement( rows, setting.confirmMessageKey, setting.confirmMessageFallback )
        addLocalisationRequirement( rows, setting.confirmActionKey, setting.confirmActionFallback )
    end

    return rows
end

return catalog
