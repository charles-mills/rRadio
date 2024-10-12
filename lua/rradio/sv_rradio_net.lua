-- Server-side networking for rRadio

local RATE_LIMIT = 1 -- 1 second cooldown

util.AddNetworkString("rRadio_PlayStation")
util.AddNetworkString("rRadio_StopStation")
util.AddNetworkString("rRadio_UpdateVolume")
util.AddNetworkString("rRadio_ToggleFavorite")
util.AddNetworkString("rRadio_OpenMenu")
util.AddNetworkString("rRadio_UpdateBoombox")

local playerCooldowns = {}

-- Play Station
net.Receive("rRadio_PlayStation", function(len, ply)
    print("Received rRadio_PlayStation from", ply:Nick())
    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    
    print("Boombox:", boomboxEnt, "Station:", stationKey, stationIndex)

    -- Check cooldown
    if playerCooldowns[ply] and playerCooldowns[ply] > CurTime() then
        print("Rate limit hit, skipping")
        return
    end
    playerCooldowns[ply] = CurTime() + RATE_LIMIT

    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" or
       (boomboxEnt:GetOwner() ~= ply and not ply:IsAdmin() and not ply:IsSuperAdmin()) then
        print("Invalid boombox or permissions")
        return
    end

    if not rRadio.Stations[stationKey] or not rRadio.Stations[stationKey][stationIndex] then
        rRadio.LogError("Invalid station request from " .. ply:Nick())
        return
    end

    local station = rRadio.Stations[stationKey][stationIndex]
    local stationUrl = station.u

    if stationUrl then
        -- Check if the station is already playing
        if boomboxEnt:GetNWString("CurrentStation") == stationUrl then
            print("Station is already playing, skipping")
            return
        end

        -- Set new station
        boomboxEnt:SetNWString("CurrentStation", stationUrl)
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationKey)
        net.WriteUInt(stationIndex, 16)
        net.WriteString(stationUrl)
        net.Broadcast()
        
        print("Broadcasted new station:", stationUrl)
    end
end)

-- Stop Station
net.Receive("rRadio_StopStation", function(len, ply)
    local boomboxEnt = net.ReadEntity()
    
    if IsValid(boomboxEnt) and boomboxEnt:GetClass() == "ent_rradio" and
       (boomboxEnt:GetOwner() == ply or ply:IsAdmin() or ply:IsSuperAdmin()) then
        -- Broadcast the stop command to all clients
        net.Start("rRadio_StopStation")
        net.WriteEntity(boomboxEnt)
        net.Broadcast()
    end
end)

-- Update Volume
net.Receive("rRadio_UpdateVolume", function(len, ply)
    local boomboxEnt = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" or
       (boomboxEnt:GetOwner() ~= ply and not ply:IsAdmin() and not ply:IsSuperAdmin()) then
        return
    end

    -- Validate volume range on the server side
    volume = math.Clamp(volume, 0, 1)
    
    -- Check if the volume has actually changed
    if boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume) ~= volume then
        boomboxEnt:SetNWFloat("Volume", volume)
        
        -- Broadcast the volume change to all clients
        net.Start("rRadio_UpdateVolume")
        net.WriteEntity(boomboxEnt)
        net.WriteFloat(volume)
        net.Broadcast()
    end
end)

-- Toggle Favorite
net.Receive("rRadio_ToggleFavorite", function(len, ply)
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    
    -- Validate input
    if not rRadio.Stations[stationKey] or not rRadio.Stations[stationKey][stationIndex] then
        rRadio.LogError("Invalid favorite toggle request from " .. ply:Nick())
        return
    end
end)

net.Receive("rRadio_OpenMenu", function(len, ply)
    local ent = net.ReadEntity()
    if IsValid(ent) and ent:GetClass() == "ent_rradio" then
        -- The menu opening is handled client-side, so we don't need to do anything here
    end
end)

-- Update Boombox
net.Receive("rRadio_UpdateBoombox", function(len, ply)
    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)

    if IsValid(boomboxEnt) and boomboxEnt:GetClass() == "ent_rradio" and
       (boomboxEnt:GetOwner() == ply or ply:IsAdmin() or ply:IsSuperAdmin()) then
        -- Broadcast the update to all clients
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationKey)
        net.WriteUInt(stationIndex, 16)
        net.Broadcast()
    end
end)
