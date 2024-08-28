AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Network strings for communication
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")

function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        -- Send the entity (boombox) to the client when the player uses it
        net.Start("OpenRadioMenu")
        net.WriteEntity(self)  -- Send the boombox entity
        net.Send(activator)
    end
end

-- Handle playing the radio station from the client
net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    -- Broadcast the station to be played on this entity
    net.Start("PlayCarRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.Broadcast()
end)

-- Handle stopping the radio station
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    net.Start("StopCarRadioStation")
    net.WriteEntity(entity)
    net.Broadcast()
end)