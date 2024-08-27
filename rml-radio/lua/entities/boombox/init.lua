AddCSLuaFile("cl_init.lua")  -- Ensure the client-side file is sent to the client.
AddCSLuaFile("shared.lua")  -- Ensure the shared file is sent to the client.

include("shared.lua")  -- Include the shared file.

-- Called when the entity is initialized.
function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")  -- Set the model of the entity.
    self:PhysicsInit(SOLID_VPHYSICS)  -- Initialize physics.
    self:SetMoveType(MOVETYPE_VPHYSICS)  -- Allow the entity to move.
    self:SetSolid(SOLID_VPHYSICS)  -- Set the entity as solid.
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()  -- Wake up the physics object.
    end
end

function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        -- Open the radio menu on client
        net.Start("OpenRadioMenu")
        net.Send(activator)
    end
end

-- Handle the playing and stopping of the radio from the boombox
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")

-- Example function to trigger the radio playback from server-side
function ENT:PlayStation(url)
    net.Start("PlayCarRadioStation")
    net.WriteEntity(self)  -- Send the boombox entity
    net.WriteString(url)
    net.WriteFloat(Config.Volume)
    net.Broadcast()  -- Send to all players, or adjust based on proximity
end

function ENT:StopStation()
    net.Start("StopCarRadioStation")
    net.WriteEntity(self)
    net.Broadcast()  -- Send to all players, or adjust based on proximity
end
