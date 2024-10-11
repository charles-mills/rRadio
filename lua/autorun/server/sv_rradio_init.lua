-- Server-side initialization for rRadio

AddCSLuaFile("rradio/sh_rradio_config.lua")
AddCSLuaFile("rradio/cl_rradio_menu.lua")
AddCSLuaFile("rradio/cl_rradio_player.lua")
AddCSLuaFile("rradio/sh_rradio_utils.lua")
AddCSLuaFile("entities/ent_rradio/cl_init.lua")
AddCSLuaFile("entities/ent_rradio/shared.lua")
AddCSLuaFile("autorun/client/cl_rradio_init.lua")
AddCSLuaFile("fonts/fonts.lua")
AddCSLuaFile("rradio/sh_rradio_stations.lua")

include("rradio/sh_rradio_config.lua")
include("rradio/sv_rradio_net.lua")
include("rradio/sh_rradio_utils.lua")
include("rradio/sh_rradio_stations.lua")

-- Initialize rRadio tables
rRadio = rRadio or {}
rRadio.Cache = rRadio.Cache or {}

-- Ensure Config is initialized
rRadio.Config = rRadio.Config or {}
rRadio.Config.CacheCleanupInterval = rRadio.Config.CacheCleanupInterval or 600

-- Periodically clean up the cache
timer.Create("rRadio_CacheCleanup", rRadio.Config.CacheCleanupInterval, 0, function()
    local currentTime = os.time()
    for key, data in pairs(rRadio.Cache) do
        if currentTime - data.timestamp > (rRadio.Config.CacheTimeout or 300) then
            rRadio.Cache[key] = nil
        end
    end
end)
