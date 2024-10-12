-- Server-side networking for rRadio

local RATE_LIMIT = 1 -- 1 second cooldown

util.AddNetworkString("rRadio_PlayStation")
util.AddNetworkString("rRadio_StopStation")
util.AddNetworkString("rRadio_UpdateVolume")
util.AddNetworkString("rRadio_ToggleFavorite")
util.AddNetworkString("rRadio_OpenMenu")
util.AddNetworkString("rRadio_UpdateBoombox")

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
