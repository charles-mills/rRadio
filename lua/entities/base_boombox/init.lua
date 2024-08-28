AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")

function ENT:Initialize()
    self:SetModel(self.Model or "models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    if self.Color then
        self:SetColor(self.Color)
    end

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        net.Start("OpenRadioMenu")
        net.WriteEntity(self)
        net.Send(activator)
    end
end

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
