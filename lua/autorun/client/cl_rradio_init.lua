-- Client-side initialization for rRadio

include("rradio/sh_rradio_config.lua")
include("rradio/cl_rradio_menu.lua")
include("rradio/cl_rradio_player.lua")
include("rradio/sh_rradio_utils.lua")
include("rradio/sh_rradio_stations.lua")
include("fonts/fonts.lua")

-- Initialize client-side rRadio table
rRadio = rRadio or {}
rRadio.CurrentStation = nil
rRadio.Favorites = rRadio.Favorites or {}

-- Load favorites from client-side storage
local savedFavorites = util.JSONToTable(file.Read("rradio_favorites.txt", "DATA") or "[]")
if savedFavorites then
    rRadio.Favorites = savedFavorites
end

-- Load recent stations from client-side storage
local savedRecent = util.JSONToTable(file.Read("rradio_recent.txt", "DATA") or "[]")
if savedRecent then
    rRadio.RecentStations = savedRecent
end

-- Ensure stations are loaded
rRadio.LoadStationData()
