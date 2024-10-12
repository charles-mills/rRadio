AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("rradio/sh_rradio_ownership.lua")

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

    -- Set the owner
    local owner = self:GetCreator()
    if IsValid(owner) and owner:IsPlayer() then
        self:SetNWEntity("Owner", owner)
        rRadio.Ownership.SetupEntity(self, owner)
        print("Setting owner for boombox: ", owner:Nick())  -- Debug print
    else
        print("Failed to set owner for boombox. Creator not valid.")
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local currentTime = CurTime()
    if currentTime - self.LastMenuOpen < MENU_COOLDOWN then
        return -- Don't open the menu if the cooldown hasn't expired
    end

    if rRadio.Ownership.CanControlEntity(activator, self) then
        self.LastMenuOpen = currentTime -- Update the last menu open time
        
        net.Start("rRadio_OpenMenu")
        net.WriteEntity(self)
        net.Send(activator)
    else
        rRadio.Notify(activator, "You don't have permission to use this boombox.", NOTIFY_ERROR)
    end
end

hook.Add("PlayerInitialSpawn", "rRadio_UpdateControlStatus", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            for _, ent in ipairs(ents.FindByClass("ent_rradio")) do
                rRadio.Ownership.UpdateControlStatus(ent)
            end
        end
    end)
end)

hook.Add("PlayerChangedTeam", "rRadio_UpdateControlStatus", function(ply, oldTeam, newTeam)
    for _, ent in ipairs(ents.FindByClass("ent_rradio")) do
        rRadio.Ownership.UpdateControlStatus(ent)
    end
end)

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end
