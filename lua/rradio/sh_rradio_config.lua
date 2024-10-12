-- Shared configuration file for rRadio

rRadio = rRadio or {}
rRadio.Config = {
    MenuTitle = "rRadio | Internet Radio",
    MaxStationNameLength = 50,
    BoomboxModel = "models/rammel/boombox.mdl",
    DefaultVolume = 0.5,
    EnableFavorites = true,
    MaxFavorites = 10,
    EnableSearch = true,
    LogErrors = true,
    CacheTimeout = 300, -- 5 minutes
    CacheCleanupInterval = 600, -- 10 minutes
    MaxRecentStations = 5,
    EnableRecentStations = true,
    AudioMinDistance = 100,  -- Distance at which volume starts to fade
    AudioMaxDistance = 500,  -- Distance at which volume becomes 0
    AudioFalloffExponent = 2,  -- Controls the rate of volume falloff (1 for linear, 2 for quadratic, etc.)
}

if CLIENT then
    rRadio.Config.MenuWidth = ScrW() * 0.4
    rRadio.Config.MenuHeight = ScrH() * 0.7
else
    rRadio.Config.MenuWidth = 800  -- Default width for server-side calculations if needed
    rRadio.Config.MenuHeight = 600 -- Default height for server-side calculations if needed
end

-- Add a function to validate and update config values
function rRadio.UpdateConfig(key, value)
    if rRadio.Config[key] ~= nil then
        if type(rRadio.Config[key]) == type(value) then
            rRadio.Config[key] = value
            return true
        else
            rRadio.LogError("Invalid type for config key: " .. key)
        end
    else
        rRadio.LogError("Invalid config key: " .. key)
    end
    return false
end
