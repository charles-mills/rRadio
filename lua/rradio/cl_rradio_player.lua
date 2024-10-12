-- Client-side radio player for rRadio

local activeStreams = {}

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

function rRadio.PlayStation(entity, country, index)
    if not IsValid(entity) or not country or not index then return end

    local station = rRadio.Stations[country] and rRadio.Stations[country][index]
    if not station then
        print("Invalid station: Country =", country, "Index =", index)
        return
    end

    local url = station.u
    if not url or url == "" then
        print("Invalid station URL for:", station.n)
        return
    end

    sound.PlayURL(url, "3d noblock", function(station, errCode, errStr)
        if IsValid(station) then
            station:SetPos(entity:GetPos())
            local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            station:SetVolume(volume)
            activeStreams[entity] = station

            -- Update entity network variables
            entity:SetNWString("CurrentStation", url)
            entity:SetNWString("CurrentStationKey", country)
            entity:SetNWInt("CurrentStationIndex", index)

            -- Notification
            notification.AddLegacy("Now playing: " .. rRadio.Stations[country][index].n, NOTIFY_GENERIC, 3)
        else
            print("Error playing station:", errStr)
            notification.AddLegacy("Failed to play station: " .. errStr, NOTIFY_ERROR, 3)
        end
    end)

    -- Send update to server
    net.Start("rRadio_UpdateBoombox")
    net.WriteEntity(entity)
    net.WriteString(country)
    net.WriteUInt(index, 16)
    net.SendToServer()
end

function rRadio.StopStation(boomboxEntity)
    if not IsValid(boomboxEntity) then return end
    
    net.Start("rRadio_StopStation")
    net.WriteEntity(boomboxEntity)
    net.SendToServer()
end

net.Receive("rRadio_UpdateBoombox", function()
    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    local stationUrl = net.ReadString()

    print("Received rRadio_UpdateBoombox:", boomboxEnt, stationKey, stationIndex, stationUrl)

    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" then 
        print("Invalid boombox entity or wrong class")
        return 
    end

    -- Stop any existing stream for this boombox
    if activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:Stop()
        activeStreams[boomboxEnt] = nil
    end

    -- Start new stream
    sound.PlayURL(stationUrl, "3d noblock", function(station, errCode, errStr)
        if IsValid(station) then
            local volume = boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            station:SetPos(boomboxEnt:GetPos())
            station:SetVolume(volume)
            station:Play()
            activeStreams[boomboxEnt] = station

            -- Update station info
            boomboxEnt:SetNWString("CurrentStation", stationUrl)
            boomboxEnt:SetNWString("CurrentStationKey", stationKey)
            boomboxEnt:SetNWInt("CurrentStationIndex", stationIndex)

            -- Notification
            notification.AddLegacy("Now playing: " .. rRadio.Stations[stationKey][stationIndex].n, NOTIFY_GENERIC, 3)
        else
            rRadio.LogError("Failed to play station: " .. errStr)
            notification.AddLegacy("Failed to play station: " .. errStr, NOTIFY_ERROR, 3)
        end
    end)
end)

net.Receive("rRadio_StopStation", function()
    local boomboxEnt = net.ReadEntity()
    if IsValid(boomboxEnt) and activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:Stop()
        activeStreams[boomboxEnt] = nil
        boomboxEnt:SetNWString("CurrentStation", "")
        boomboxEnt:SetNWString("CurrentStationKey", "")
        boomboxEnt:SetNWInt("CurrentStationIndex", 0)
        notification.AddLegacy("Radio stopped", NOTIFY_GENERIC, 3)
    end
end)

local function CalculateVolume(listener, boombox, baseVolume)
    local distance = listener:GetPos():Distance(boombox:GetPos())
    local minDist = rRadio.Config.AudioMinDistance
    local maxDist = rRadio.Config.AudioMaxDistance
    local falloffExponent = rRadio.Config.AudioFalloffExponent

    if distance <= minDist then
        return baseVolume
    elseif distance >= maxDist then
        return 0
    else
        local fadeRange = maxDist - minDist
        local fadeAmount = (distance - minDist) / fadeRange
        return baseVolume * (1 - fadeAmount^falloffExponent)
    end
end

hook.Add("Think", "rRadio_UpdateStreamPositions", function()
    local listener = LocalPlayer()
    for boombox, stream in pairs(activeStreams) do
        if IsValid(boombox) and IsValid(stream) then
            stream:SetPos(boombox:GetPos())
            local baseVolume = boombox:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            local calculatedVolume = CalculateVolume(listener, boombox, baseVolume)
            stream:SetVolume(calculatedVolume)
        else
            -- Clean up invalid streams or boomboxes
            if IsValid(stream) then
                stream:Stop()
            end
            activeStreams[boombox] = nil
        end
    end
end)
