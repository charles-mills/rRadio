AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MENU_COOLDOWN = 1 -- 1 second cooldown

function ENT:Initialize()
    self:SetModel(rRadio.Config.BoomboxModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self:SetNWString("CurrentStation", "")
    self:SetNWFloat("Volume", rRadio.Config.DefaultVolume)
    
    self.LastMenuOpen = 0 -- Initialize the last menu open time
end

function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() and 
       (activator == self:GetOwner() or activator:IsAdmin() or activator:IsSuperAdmin()) then
        
        local currentTime = CurTime()
        if currentTime - self.LastMenuOpen < MENU_COOLDOWN then
            return -- Don't open the menu if the cooldown hasn't expired
        end
        
        self.LastMenuOpen = currentTime -- Update the last menu open time
        
        net.Start("rRadio_OpenMenu")
        net.WriteEntity(self)
        net.Send(activator)
    end
end
