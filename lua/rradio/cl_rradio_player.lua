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

function rRadio.PlayStation(boomboxEntity, country, index)
    print("PlayStation called:", boomboxEntity, country, index)
    if not IsValid(boomboxEntity) then 
        print("Invalid boombox entity")
        return 
    end
    
    print("Sending rRadio_PlayStation net message")
    net.Start("rRadio_PlayStation")
    net.WriteEntity(boomboxEntity)
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

-- Update stream positions
hook.Add("Think", "rRadio_UpdateStreamPositions", function()
    for boombox, stream in pairs(activeStreams) do
        if IsValid(boombox) and IsValid(stream) then
            stream:SetPos(boombox:GetPos())
        else
            -- Clean up invalid streams or boomboxes
            if IsValid(stream) then
                stream:Stop()
            end
            activeStreams[boombox] = nil
        end
    end
end)
