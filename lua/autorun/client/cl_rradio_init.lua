/*
  ____  ____           _ _       
 |  _ \|  _ \ __ _  __| (_) ___  
 | |_) | |_) / _` |/ _` | |/ _ \ 
 |  _ <|  _ < (_| | (_| | | (_) |
 |_| \_\_| \_\__,_|\__,_|_|\___/ 
                                 
*/

if not rRadio then rRadio = {} end

print("-----------------------------")
print("| Loading ClientSide rRadio |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/cl_*.lua", "LUA")) do
    include("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")
print("|  Loading Shared rRadio    |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/sh_*.lua", "LUA")) do
    include("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")

-- Add this line with the other includes
include("rradio/cl_rradio_favorites.lua")

-- Initialize client-side rRadio table
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

-- Precache sounds
util.PrecacheSound("ui/buttonclick.wav")
util.PrecacheSound("ui/slider.wav")
