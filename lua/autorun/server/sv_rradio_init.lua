/*
  ____  ____           _ _       
 |  _ \|  _ \ __ _  __| (_) ___  
 | |_) | |_) / _` |/ _` | |/ _ \ 
 |  _ <|  _ < (_| | (_| | | (_) |
 |_| \_\_| \_\__,_|\__,_|_|\___/ 
                                 
*/

if not rRadio then rRadio = {} end

print("-----------------------------")
print("| Loading ServerSide rRadio |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/sv_*.lua", "LUA")) do
    include("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")
print("|  Loading Shared rRadio    |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/sh_*.lua", "LUA")) do
    include("rradio/" .. v)
    AddCSLuaFile("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")
print("| Adding ClientSide rRadio  |")
print("-----------------------------")

for _, v in pairs(file.Find("rradio/cl_*.lua", "LUA")) do
    AddCSLuaFile("rradio/" .. v)
    print("rradio/" .. v)
end

print("-----------------------------")

-- Add other necessary files
AddCSLuaFile("entities/ent_rradio/cl_init.lua")
AddCSLuaFile("entities/ent_rradio/shared.lua")
AddCSLuaFile("autorun/client/cl_rradio_init.lua")
AddCSLuaFile("fonts/fonts.lua")

-- Initialize rRadio tables
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

-- Add this at the end of the file

hook.Add("Think", "rRadio_ReliabilityCheck", function()
    for _, ply in ipairs(player.GetAll()) do
        for _, ent in ipairs(ents.FindByClass("ent_rradio")) do
            if not ply:TestPVS(ent) then
                ent:SetPreventTransmit(ply, false)
            end
        end
    end
end)
