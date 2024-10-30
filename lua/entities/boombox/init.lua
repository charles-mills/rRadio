include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    self.Config = Config.Boombox
end

-- Add Use function to handle interaction
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    net.Start("OpenRadioMenu")
        net.WriteEntity(self)
    net.Send(activator)
end