
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")

local ActiveRadios = {}
debug_mode = true  -- Set to true to enable debug statements

-- Function to add a radio to the active list
local function AddActiveRadio(entity, station)
    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        station = station
    }
    -- Debug: Print when a radio is added
    print("[DEBUG] Added active radio:", entity, "Station:", station)
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
    -- Debug: Print when a radio is removed
    print("[DEBUG] Removed active radio:", entity)
end

-- Function to send active radios to a specific player
local function SendActiveRadiosToPlayer(ply)
    print("[DEBUG] Sending active radios to player:", ply)
    for _, radio in pairs(ActiveRadios) do
        print("[DEBUG] Broadcasting active radio:", radio.entity, "Station:", radio.station)
        net.Start("PlayCarRadioStation")
        net.WriteEntity(radio.entity)
        net.WriteString(radio.station)
        net.WriteFloat(1) -- Assume default volume; adjust as necessary
        net.Send(ply)
    end
end

-- Hook to send active radios when a player initially joins
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    print("[DEBUG] Player joined:", ply)
    SendActiveRadiosToPlayer(ply)
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    print("[DEBUG] Player entered vehicle:", ply, vehicle)
    net.Start("CarRadioMessage")
    net.Send(ply)
end)

net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    -- Check if the entity is a boombox or a vehicle
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        entity:SetVolume(volume)
        entity:SetStationName(stationName)

        -- Broadcast the station play request to all clients
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        -- Update clients with the current station name
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()

    elseif entity:IsVehicle() then
        -- Handle vehicle-specific logic here
        -- Broadcast the station play request to all clients without setting volume on the vehicle
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
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

