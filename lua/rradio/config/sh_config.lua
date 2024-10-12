rRadio = rRadio or {}
rRadio.Config = rRadio.Config or {}

rRadio.Config = {
    MenuTitle = "rRadio",
    MaxStationNameLength = 50,
    BoomboxModel = "models/rammel/boombox.mdl",
    DefaultVolume = 0.5,
    EnableFavorites = true,
    MaxFavorites = 10,
    EnableSearch = true,
    LogErrors = false,
    CacheTimeout = 300, -- 5 minutes
    CacheCleanupInterval = 600, -- 10 minutes
    MaxRecentStations = 5,
    EnableRecentStations = true,
    AudioMinDistance = 100,  -- Distance at which volume starts to fade
    AudioMaxDistance = 500,  -- Distance at which volume becomes 0
    AudioFalloffExponent = 1,  -- Controls the rate of volume falloff (1 for linear, 2 for quadratic, etc.)
}

function rRadio.LoadConfig()
    -- This function can be used to load external config files if needed
end

function rRadio.GetConfig(key, default)
    return rRadio.Config[key] or default
end

if CLIENT then
    rRadio.Config.MenuWidth = ScrW() * 0.4
    rRadio.Config.MenuHeight = ScrH() * 0.7
else
    rRadio.Config.MenuWidth = 800  -- Default width for server-side calculations if needed
    rRadio.Config.MenuHeight = 600 -- Default height for server-side calculations if needed
end
