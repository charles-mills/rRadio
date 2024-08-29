util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")

local ActiveRadios = {}
debug_mode = true  -- Set to true to enable debug statements

-- Function to add a radio to the active list
local function AddActiveRadio(entity, stationName, url, volume)
    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

-- Function to send active radios to a specific player
local function SendActiveRadiosToPlayer(ply)
    for _, radio in pairs(ActiveRadios) do
        -- Check if the entity is valid before sending
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)  -- Send the correct URL
            net.WriteFloat(radio.volume) -- Send the actual volume
            net.Send(ply)
        end
    end
end

-- Hook to send active radios when a player initially joins
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    -- Add a short delay to ensure entities are fully loaded on the client
    timer.Simple(3, function()  -- Consider increasing the delay to 3 seconds
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    net.Start("CarRadioMessage")
    net.Send(ply)
end)

net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    -- Clamp the volume to ensure it's within the valid range
    if volume < 0 or volume > 1 then
        volume = 1 -- Default to 1.0 if the volume is out of range
    end

    -- Check if the entity is a boombox or a vehicle
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        entity:SetVolume(volume)
        entity:SetStationName(stationName)

        AddActiveRadio(entity, stationName, url, volume)  -- Save both station name and URL

        -- Broadcast the station play request to all clients
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)  -- Broadcast the URL
        net.WriteFloat(volume)
        net.Broadcast()

        -- Update clients with the current station name
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()

    elseif entity:IsVehicle() then
        AddActiveRadio(entity, stationName, url, volume)  -- Save both station name and URL

        -- Broadcast the station play request to all clients without setting volume on the vehicle
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)  -- Broadcast the URL
        net.WriteFloat(volume)
        net.Broadcast()

        -- Update clients with the current station name (if applicable for vehicles)
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()
    end
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    -- Check if the entity is a boombox or a vehicle
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        entity:SetStationName("")
        RemoveActiveRadio(entity)

        -- Broadcast the stop request to all clients
        net.Start("StopCarRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        -- Update clients to clear the station name
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
        net.Broadcast()

    elseif entity:IsVehicle() then
        -- Handle vehicle-specific stop logic here
        RemoveActiveRadio(entity)

        -- Broadcast the stop request to all clients
        net.Start("StopCarRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        -- Update clients to clear the station name (if applicable for vehicles)
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
        net.Broadcast()
    end
end)
