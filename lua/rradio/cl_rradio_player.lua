--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Client-side radio player functionality for rRadio addon. Handles stream
    playback, volume control, station switching, and synchronization with
    the server.
]]

local activeStreams = {}

local function isValidURL(url)
    return isstring(url) and (string.match(url, "^https?://") or string.match(url, "^http?://"))
end

local function RequestBoomboxData()
    net.Start("rRadio_RequestBoomboxData")
    net.SendToServer()
end

function rRadio.SetVolume(boomboxEnt, volume)
    if not IsValid(boomboxEnt) then return end
    volume = math.Clamp(volume, 0, 1)
    boomboxEnt:SetNWFloat("Volume", volume)
    
    if activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:SetVolume(volume)
    end

    net.Start("rRadio_UpdateVolume")
    net.WriteEntity(boomboxEnt)
    net.WriteFloat(volume)
    net.SendToServer()
end

function rRadio.PlayStation(entity, country, stationName)
    if not IsValid(entity) or not country or not stationName then return end

    local station = rRadio.FindStationByName(country, stationName)
    if not station then
        print("Invalid station: Country =", country, "Name =", stationName)
        return
    end

    local url = station.u
    if not isValidURL(url) then
        print("Invalid station URL for:", stationName)
        return
    end

    -- Set the status to "tuning" locally
    entity:SetNWString("CurrentStatus", "tuning")
    entity:SetNWString("CurrentStationName", "Tuning in")
    entity:SetNWString("CurrentStationCountry", country)

    -- Update menu if it's open
    if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == entity then
        rRadio.Menu:UpdateCurrentStation(entity)
    end

    -- Send update to server
    net.Start("rRadio_PlayStation")
    net.WriteEntity(entity)
    net.WriteString(country)
    net.WriteString(stationName)
    net.SendToServer()

    -- Start playing the stream
    rRadio.PlayStream(entity, url, country, stationName)
end

function rRadio.StopStation(boomboxEntity)
    if not IsValid(boomboxEntity) then return end

    if IsValid(rRadio.Menu) then
        rRadio.Menu:UpdateStatusPanel()
    end
    
    net.Start("rRadio_StopStation")
    net.WriteEntity(boomboxEntity)
    net.SendToServer()
end

function rRadio.PlayStream(boomboxEnt, url, country, stationName)
    if not IsValid(boomboxEnt) or not isValidURL(url) then return end

    if activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:Stop()
        activeStreams[boomboxEnt] = nil
    end

    sound.PlayURL(url, "3d noblock", function(station, errCode, errStr)
        if IsValid(station) then
            local volume = boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            station:SetPos(boomboxEnt:GetPos())
            station:SetVolume(volume)
            station:Play()
            activeStreams[boomboxEnt] = station
            
            -- Update entity network variables with actual station name
            boomboxEnt:SetNWString("CurrentStationName", stationName)
            boomboxEnt:SetNWString("CurrentStationURL", url)
            boomboxEnt:SetNWString("CurrentStationCountry", country)
            boomboxEnt:SetNWString("CurrentStatus", "playing")
            
            -- Update menu if it's open
            if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
                rRadio.Menu:UpdateCurrentStation(boomboxEnt)
            end
            
            notification.AddLegacy("Now playing: " .. stationName, NOTIFY_GENERIC, 3)
        else
            boomboxEnt:SetNWString("CurrentStationURL", "")
            boomboxEnt:SetNWString("CurrentStationName", "")
            boomboxEnt:SetNWString("CurrentStationCountry", "")
            boomboxEnt:SetNWString("CurrentStatus", "outage")
            if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
                rRadio.Menu:UpdateCurrentStation(boomboxEnt)
            end
            notification.AddLegacy("Failed to play station: " .. (errStr or "Unknown error"), NOTIFY_ERROR, 3)
        end
    end)
end

net.Receive("rRadio_UpdateBoombox", function()
    local boomboxEnt = net.ReadEntity()
    local stationCountry = net.ReadString()
    local stationName = net.ReadString()
    local stationUrl = net.ReadString()
    local currentStatus = net.ReadString() -- Read the new status

    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" then return end

    boomboxEnt:SetNWString("CurrentStationCountry", stationCountry)
    boomboxEnt:SetNWString("CurrentStationName", stationName)
    boomboxEnt:SetNWString("CurrentStationURL", stationUrl)
    boomboxEnt:SetNWString("CurrentStatus", currentStatus) -- Set the new status

    if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
        rRadio.Menu:UpdateCurrentStation(boomboxEnt)
    end

    -- Only play the stream if the status is "playing"
    if currentStatus == "playing" then
        rRadio.PlayStream(boomboxEnt, stationUrl, stationCountry, stationName)
    end
end)

net.Receive("rRadio_StopStation", function()
    local boomboxEnt = net.ReadEntity()
    if IsValid(boomboxEnt) and activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:Stop()
        activeStreams[boomboxEnt] = nil
        boomboxEnt:SetNWString("CurrentStationCountry", "")
        boomboxEnt:SetNWString("CurrentStationName", "")
        boomboxEnt:SetNWString("CurrentStationURL", "")
        notification.AddLegacy("Radio stopped", NOTIFY_GENERIC, 3)
    end
end)

local function CalculateVolume(listenerPos, boomboxPos, baseVolume)
    local distance = listenerPos:Distance(boomboxPos)
    local minDist, maxDist = rRadio.Config.AudioMinDistance, rRadio.Config.AudioMaxDistance
    
    if distance <= minDist then return baseVolume end
    if distance >= maxDist then return 0 end
    
    local fadeRange = maxDist - minDist
    local fadeAmount = (distance - minDist) / fadeRange
    return baseVolume * (1 - fadeAmount^rRadio.Config.AudioFalloffExponent)
end

hook.Add("Think", "rRadio_UpdateStreamPositions", function()
    local listener = LocalPlayer()
    local listenerPos = listener:GetPos()
    
    for boombox, stream in pairs(activeStreams) do
        if IsValid(boombox) and IsValid(stream) then
            local boomboxPos = boombox:GetPos()
            stream:SetPos(boomboxPos)
            local baseVolume = boombox:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            local calculatedVolume = CalculateVolume(listenerPos, boomboxPos, baseVolume)
            stream:SetVolume(calculatedVolume)
        else
            if IsValid(stream) then
                stream:Stop()
            end
            activeStreams[boombox] = nil
        end
    end
end)

net.Receive("rRadio_SyncNewPlayer", function()
    RequestBoomboxData()
end)

net.Receive("rRadio_RequestBoomboxData", function()
    local boomboxCount = net.ReadUInt(8)
    for i = 1, boomboxCount do
        local boomboxEnt = net.ReadEntity()
        local stationUrl = net.ReadString()
        local stationCountry = net.ReadString()
        local stationName = net.ReadString()
        local volume = net.ReadFloat()
        local owner = net.ReadEntity()

        if IsValid(boomboxEnt) and boomboxEnt:GetClass() == "ent_rradio" then
            boomboxEnt:SetNWString("CurrentStationURL", stationUrl)
            boomboxEnt:SetNWString("CurrentStationCountry", stationCountry)
            boomboxEnt:SetNWString("CurrentStationName", stationName)
            boomboxEnt:SetNWFloat("Volume", volume)
            boomboxEnt:SetNWEntity("Owner", owner)

            if isValidURL(stationUrl) then
                rRadio.PlayStream(boomboxEnt, stationUrl)
            end
        end
    end
end)

hook.Add("ShutDown", "rRadio_CleanupStreams", function()
    for _, stream in pairs(activeStreams) do
        if IsValid(stream) then
            stream:Stop()
        end
    end
    activeStreams = {}
end)

function rRadio.FindStationByName(country, stationName)
    if rRadio.Stations[country] then
        for _, station in ipairs(rRadio.Stations[country]) do
            if station.n == stationName then
                return station
            end
        end
    end
    return nil
end
