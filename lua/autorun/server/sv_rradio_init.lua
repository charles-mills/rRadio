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

local rRadioEntities = {}
local playerPositions = {}

-- Function to update the list of rRadio entities
local function UpdateRRadioEntities()
    rRadioEntities = ents.FindByClass("ent_rradio")
end

-- Initial entity update
UpdateRRadioEntities()

-- Update entity list periodically
timer.Create("rRadio_UpdateEntities", 5, 0, UpdateRRadioEntities)

-- Function to check and update entity transmission
local function CheckAndUpdateTransmission()
    for _, ply in ipairs(player.GetAll()) do
        local playerPos = ply:GetPos()
        local lastPos = playerPositions[ply] or Vector(0, 0, 0)
        
        -- Only check if the player has moved more than 32 units
        if playerPos:DistToSqr(lastPos) > 1024 then
            playerPositions[ply] = playerPos
            
            for _, ent in ipairs(rRadioEntities) do
                if IsValid(ent) and not ply:TestPVS(ent) then
                    ent:SetPreventTransmit(ply, false)
                end
            end
        end
    end
end

-- Run the check every second instead of every frame
timer.Create("rRadio_ReliabilityCheck", 1, 0, CheckAndUpdateTransmission)

-- Clean up player positions when a player disconnects
hook.Add("PlayerDisconnected", "rRadio_CleanupPlayerPos", function(ply)
    playerPositions[ply] = nil
end)
