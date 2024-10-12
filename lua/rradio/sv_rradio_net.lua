--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Handles server-side networking for rRadio addon, including network strings
    and message handling.
]]

local RATE_LIMIT = 1
local CONNECTION_TIMEOUT = 8

util.AddNetworkString("rRadio_PlayStation")
util.AddNetworkString("rRadio_StopStation")
util.AddNetworkString("rRadio_UpdateVolume")
util.AddNetworkString("rRadio_ToggleFavorite")
util.AddNetworkString("rRadio_OpenMenu")
util.AddNetworkString("rRadio_UpdateBoombox")
util.AddNetworkString("rRadio_SyncNewPlayer")
util.AddNetworkString("rRadio_RequestBoomboxData")

local playerCooldowns = {}
local activeRadios = {}

local function AddActiveRadio(radio)
    if IsValid(radio) and radio:GetClass() == "ent_rradio" then
        activeRadios[radio:EntIndex()] = radio
    end
end

local function RemoveActiveRadio(radio)
    if IsValid(radio) then
        activeRadios[radio:EntIndex()] = nil
    end
end

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
    -- Check if the player is the owner or an admin
    if boomboxEnt:GetOwner() ~= ply and not ply:IsAdmin() then
        return false
    end
    -- Additional check: Ensure the boombox is within a reasonable distance from the player
    if boomboxEnt:GetPos():DistToSqr(ply:GetPos()) > 250000 then -- 500 units squared
        return false
    end
    return true
end

local function validateStationURL(url)
    return isstring(url) and (string.match(url, "^https?://") or string.match(url, "^http?://"))
end

net.Receive("rRadio_PlayStation", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local stationCountry = net.ReadString()
    local stationName = net.ReadString()
    
    if not validateBoombox(ply, boomboxEnt) then return end
    if not rRadio.Stations[stationCountry] then
        rRadio.LogError("Invalid country request from " .. ply:Nick())
        return
    end

    -- Find the station by name
    local station = nil
    for _, s in ipairs(rRadio.Stations[stationCountry]) do
        if s.n == stationName then
            station = s
            break
        end
    end

    if not station then
        rRadio.LogError("Invalid station request from " .. ply:Nick())
        return
    end

    -- Sanitize the station URL
    local stationUrl = station.u
    if not validateStationURL(stationUrl) then
        rRadio.LogError("Invalid station URL from " .. ply:Nick())
        return
    end

    if stationUrl then
        boomboxEnt:SetNWString("CurrentStationURL", stationUrl)
        boomboxEnt:SetNWString("CurrentStationCountry", stationCountry)
        boomboxEnt:SetNWString("CurrentStationName", stationName)
        
        -- Add the boombox to the activeRadios table
        AddActiveRadio(boomboxEnt)
        
        -- Broadcast the station information
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationCountry)
        net.WriteString(stationName)
        net.WriteString(stationUrl)
        net.Broadcast()
    end
end)

-- Helper function to handle station outage
function HandleStationOutage(boomboxEnt, stationCountry, stationName)
    if IsValid(boomboxEnt) then
        boomboxEnt:SetNWString("CurrentStationURL", "outage")
        
        -- Broadcast the outage state
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationCountry)
        net.WriteString(stationName)
        net.WriteString("outage")
        net.Broadcast()

        -- Reset station information after outage
        timer.Simple(2, function()
            if IsValid(boomboxEnt) then
                boomboxEnt:SetNWString("CurrentStationCountry", "")
                boomboxEnt:SetNWString("CurrentStationName", "")
                boomboxEnt:SetNWString("CurrentStationURL", "")
                RemoveActiveRadio(boomboxEnt)

                -- Broadcast the reset state
                net.Start("rRadio_UpdateBoombox")
                net.WriteEntity(boomboxEnt)
                net.WriteString("")
                net.WriteString("")
                net.WriteString("")
                net.Broadcast()
            end
        end)
    end
end

net.Receive("rRadio_StopStation", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    
    if validateBoombox(ply, boomboxEnt) then
        -- Remove the boombox from the activeRadios table
        RemoveActiveRadio(boomboxEnt)
        
        net.Start("rRadio_StopStation")
        net.WriteEntity(boomboxEnt)
        net.Broadcast()
    end
end)

net.Receive("rRadio_UpdateVolume", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not validateBoombox(ply, boomboxEnt) then return end

    -- Ensure volume is within valid range
    volume = math.Clamp(volume, 0, 1)
    
    if boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume) ~= volume then
        boomboxEnt:SetNWFloat("Volume", volume)
        
        net.Start("rRadio_UpdateVolume")
        net.WriteEntity(boomboxEnt)
        net.WriteFloat(volume)
        net.Broadcast()
    end
end)

net.Receive("rRadio_UpdateBoombox", function(len, ply)
    if not checkRateLimit(ply) then return end

    local boomboxEnt = net.ReadEntity()
    local stationCountry = net.ReadString()
    local stationName = net.ReadString()

    if validateBoombox(ply, boomboxEnt) then
        net.Start("rRadio_UpdateBoombox")
        net.WriteEntity(boomboxEnt)
        net.WriteString(stationCountry)
        net.WriteString(stationName)
        net.Broadcast()
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio_NotifyNewPlayer", function(ply)
    -- Wait for the player to fully load
    timer.Simple(5, function()
        if IsValid(ply) then
            -- Just notify the client that they should request boombox data
            net.Start("rRadio_SyncNewPlayer")
            net.Send(ply)
        end
    end)
end)

net.Receive("rRadio_RequestBoomboxData", function(len, ply)
    if not IsValid(ply) then return end

    net.Start("rRadio_SyncNewPlayer")
    net.WriteUInt(table.Count(activeRadios), 8)
    for _, ent in pairs(activeRadios) do
        if IsValid(ent) then
            net.WriteEntity(ent)
            net.WriteString(ent:GetNWString("CurrentStationURL", ""))
            net.WriteString(ent:GetNWString("CurrentStationCountry", ""))
            net.WriteString(ent:GetNWString("CurrentStationName", ""))
            net.WriteFloat(ent:GetNWFloat("Volume", rRadio.Config.DefaultVolume))
            net.WriteEntity(ent:GetNWEntity("Owner"))
        else
            -- If the entity is no longer valid, remove it from activeRadios
            RemoveActiveRadio(ent)
        end
    end
    net.Send(ply)
end)

hook.Add("EntityRemoved", "rRadio_UntrackRadio", function(ent)
    if ent:GetClass() == "ent_rradio" then
        RemoveActiveRadio(ent)
    end
end)