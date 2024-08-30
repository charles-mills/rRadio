AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Set the owner when the entity is initialized
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

    -- Set the owner of the boombox
    if IsValid(self.Owner) then
        self:SetNWEntity("Owner", self.Owner)
    end
end

-- Only allow the owner or a superadmin to use the boombox
function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        local owner = self:GetNWEntity("Owner")
        
        -- Check if the player is the owner or a superadmin
        if activator == owner or activator:IsSuperAdmin() then
            net.Start("OpenRadioMenu")
            net.WriteEntity(self)
            net.Send(activator)
        else
            activator:ChatPrint("You do not have permission to use this boombox.")
        end
    end
end
