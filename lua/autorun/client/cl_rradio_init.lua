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

include("rradio/cl_rradio_favorites.lua")

for _, v in pairs(file.Find("rradio/cl_*.lua", "LUA")) do
    if v ~= "cl_rradio_favorites.lua" then  -- Skip favorites as we've already included it
        include("rradio/" .. v)
        print("rradio/" .. v)
    end
end

print("-----------------------------")
print("|  Loading Shared rRadio    |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/sh_*.lua", "LUA")) do
    include("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")

-- Initialize client-side rRadio table
rRadio.CurrentStation = nil

-- Ensure stations are loaded
rRadio.LoadStationData()

-- Load favorites
rRadio.LoadFavorites()

-- Precache sounds
util.PrecacheSound("ui/buttonclick.wav")
util.PrecacheSound("ui/slider.wav")
