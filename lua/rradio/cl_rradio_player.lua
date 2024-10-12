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

    -- Update status to "Tuning in..." immediately
    entity:SetNWString("CurrentStationKey", country)
    entity:SetNWInt("CurrentStationIndex", index)
    entity:SetNWString("CurrentStation", "tuning") -- Use a special value to indicate tuning

    -- Update menu if it's open
    if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == entity then
        rRadio.Menu:UpdateCurrentStation(entity)
    end

    -- Send update to server
    net.Start("rRadio_PlayStation")
    net.WriteEntity(entity)
    net.WriteString(country)
    net.WriteUInt(index, 16)
    net.SendToServer()
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

net.Receive("rRadio_UpdateBoombox", function()
    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    local stationUrl = net.ReadString()

    if not IsValid(boomboxEnt) or boomboxEnt:GetClass() ~= "ent_rradio" then return end

    if activeStreams[boomboxEnt] then
        activeStreams[boomboxEnt]:Stop()
        activeStreams[boomboxEnt] = nil
    end

    sound.PlayURL(stationUrl, "3d noblock", function(station, errCode, errStr)
        if IsValid(station) then
            local volume = boomboxEnt:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
            station:SetPos(boomboxEnt:GetPos())
            station:SetVolume(volume)
            
            timer.Simple(0.1, function()
                if IsValid(station) then
                    station:Play()
                    activeStreams[boomboxEnt] = station

                    boomboxEnt:SetNWString("CurrentStation", stationUrl)
                    boomboxEnt:SetNWString("CurrentStationKey", stationKey)
                    boomboxEnt:SetNWInt("CurrentStationIndex", stationIndex)

                    if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
                        rRadio.Menu:UpdateCurrentStation(boomboxEnt)
                    end

                    local stationName = rRadio.Stations[stationKey] and rRadio.Stations[stationKey][stationIndex] and rRadio.Stations[stationKey][stationIndex].n or "Unknown"
                    notification.AddLegacy("Now playing: " .. stationName, NOTIFY_GENERIC, 3)
                else
                    boomboxEnt:SetNWString("CurrentStation", "")
                    if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
                        rRadio.Menu:UpdateCurrentStation(boomboxEnt)
                    end
                end
            end)
        else
            notification.AddLegacy("Failed to play station: " .. (errStr or "Unknown error"), NOTIFY_ERROR, 3)
            boomboxEnt:SetNWString("CurrentStation", "")
            if IsValid(rRadio.Menu) and rRadio.Menu.BoomboxEntity == boomboxEnt then
                rRadio.Menu:UpdateCurrentStation(boomboxEnt)
            end
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
    -- The server is notifying us that we can request boombox data
    RequestBoomboxData()
end)

net.Receive("rRadio_RequestBoomboxData", function()
    local boomboxCount = net.ReadUInt(8)
    for i = 1, boomboxCount do
        local boomboxEnt = net.ReadEntity()
        local stationUrl = net.ReadString()
        local stationKey = net.ReadString()
        local stationIndex = net.ReadUInt(16)
        local volume = net.ReadFloat()
        local owner = net.ReadEntity()

        if IsValid(boomboxEnt) and boomboxEnt:GetClass() == "ent_rradio" then
            boomboxEnt:SetNWString("CurrentStation", stationUrl)
            boomboxEnt:SetNWString("CurrentStationKey", stationKey)
            boomboxEnt:SetNWInt("CurrentStationIndex", stationIndex)
            boomboxEnt:SetNWFloat("Volume", volume)
            boomboxEnt:SetNWEntity("Owner", owner)

            if stationUrl ~= "" and stationUrl ~= "tuning" then
                -- Start playing the stream
                sound.PlayURL(stationUrl, "3d noblock", function(station, errCode, errStr)
                    if IsValid(station) then
                        station:SetPos(boomboxEnt:GetPos())
                        station:SetVolume(volume)
                        station:Play()
                        activeStreams[boomboxEnt] = station
                    else
                        print("Failed to create stream for synced boombox. Error: " .. (errStr or "Unknown"))
                    end
                end)
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
