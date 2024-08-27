AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")

-- Called when the entity is initialized.
function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    -- Store the owner when the boombox is spawned.
    if IsValid(self:GetOwner()) then
        self.BoomboxOwner = self:GetOwner()
    else
        self.BoomboxOwner = nil
    end
end

-- Helper function to check if a player can control the boombox.
function ENT:CanPlayerControl(activator)
    if IsValid(self.BoomboxOwner) and activator == self.BoomboxOwner then
        return true
    elseif activator:IsSuperAdmin() then
        return true
    end
    return false
end

-- Called when the player presses "E" on the boombox.
function ENT:Use(activator, caller)
    if not activator:IsPlayer() then return end

    -- Ensure only the owner or a superadmin can control the boombox.
    if self:CanPlayerControl(activator) then
        -- Open the radio menu.
        net.Start("OpenRadioMenu")
        net.WriteEntity(self)  -- Send the boombox entity
        net.Send(activator)
    else
        activator:ChatPrint("You do not have permission to control this boombox.")
    end
end

-- Play a radio station from the server-side.
function ENT:PlayStation(url, volume)
    net.Start("PlayCarRadioStation")
    net.WriteEntity(self)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.Broadcast()
end

-- Stop the radio station from the server-side.
function ENT:StopStation()
    net.Start("StopCarRadioStation")
    net.WriteEntity(self)
    net.Broadcast()
end
