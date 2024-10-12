-- Server-side networking for rRadio

local RATE_LIMIT = 1 -- 1 second cooldown

util.AddNetworkString("rRadio_PlayStation")
util.AddNetworkString("rRadio_StopStation")
util.AddNetworkString("rRadio_UpdateVolume")
util.AddNetworkString("rRadio_ToggleFavorite")
util.AddNetworkString("rRadio_OpenMenu")
util.AddNetworkString("rRadio_UpdateBoombox")
util.AddNetworkString("rRadio_SyncNewPlayer")

local playerCooldowns = {}

-- Helper function to check rate limit
local function checkRateLimit(ply)
    if not IsValid(ply) then return false end
    local lastRequest = playerCooldowns[ply:SteamID()] or 0
    if (CurTime() - lastRequest) < RATE_LIMIT then
        return false
    end
    playerCooldowns[ply:SteamID()] = CurTime()
    return true
end

-- Helper function to validate boombox
local function validateBoombox(ply, boomboxEnt)
    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" then
        return false
    end
    if boomboxEnt:GetOwner() ~= ply and not ply:IsAdmin() then
        return false
    end
    return true
end

-- Play Station
net.Receive("rRadio_PlayStation", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    
    if not validateBoombox(ply, boomboxEnt) then return end
    if not rRadio.Stations[stationKey] or not rRadio.Stations[stationKey][stationIndex] then
        rRadio.LogError("Invalid station request from " .. ply:Nick())
        return
    end

    local station = rRadio.Stations[stationKey][stationIndex]
    local stationUrl = station.u

    if stationUrl then
        boomboxEnt:SetNWString("CurrentStation", stationUrl)
        boomboxEnt:SetNWString("CurrentStationKey", stationKey)
        boomboxEnt:SetNWInt("CurrentStationIndex", stationIndex)
        
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationKey)
        net.WriteUInt(stationIndex, 16)
        net.WriteString(stationUrl)
        net.Broadcast()
    end
end)

-- Stop Station
net.Receive("rRadio_StopStation", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    
    if validateBoombox(ply, boomboxEnt) then
        net.Start("rRadio_StopStation")
        net.WriteEntity(boomboxEnt)
        net.Broadcast()
    end
end)

-- Update Volume
net.Receive("rRadio_UpdateVolume", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not validateBoombox(ply, boomboxEnt) then return end

    volume = math.Clamp(volume, 0, 1)
    
    if boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume) ~= volume then
        boomboxEnt:SetNWFloat("Volume", volume)
        
        net.Start("rRadio_UpdateVolume")
        net.WriteEntity(boomboxEnt)
        net.WriteFloat(volume)
        net.Broadcast()
    end
end)

-- Update Boombox
net.Receive("rRadio_UpdateBoombox", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)

    if validateBoombox(ply, boomboxEnt) then
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationKey)
        net.WriteUInt(stationIndex, 16)
        net.Broadcast()
    end
end)

-- Add this function to collect boombox data
local function CollectBoomboxData()
    local boomboxData = {}
    for _, ent in ipairs(ents.FindByClass("ent_rradio")) do
        table.insert(boomboxData, {
            entity = ent,
            currentStation = ent:GetNWString("CurrentStation", ""),
            currentStationKey = ent:GetNWString("CurrentStationKey", ""),
            currentStationIndex = ent:GetNWInt("CurrentStationIndex", 0),
            volume = ent:GetNWFloat("Volume", rRadio.Config.DefaultVolume),
            owner = ent:GetNWEntity("Owner")
        })
    end
    return boomboxData
end

hook.Add("PlayerInitialSpawn", "rRadio_SyncNewPlayer", function(ply)
    -- Wait for the player to fully load
    timer.Simple(5, function()
        if IsValid(ply) then
            local boomboxData = CollectBoomboxData()
            net.Start("rRadio_SyncNewPlayer")
            net.WriteUInt(#boomboxData, 8)
            for _, data in ipairs(boomboxData) do
                net.WriteEntity(data.entity)
                net.WriteString(data.currentStation)
                net.WriteString(data.currentStationKey)
                net.WriteUInt(data.currentStationIndex, 16)
                net.WriteFloat(data.volume)
                net.WriteEntity(data.owner)
            end
            net.Send(ply)
        end
    end)
end)
