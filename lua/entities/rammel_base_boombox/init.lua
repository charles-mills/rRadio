AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

SavedBoomboxStates = SavedBoomboxStates or {}
local lastPermissionMessageTime = lastPermissionMessageTime or {}
local PERMISSION_MESSAGE_COOLDOWN = 3

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
    self:SetNWString("StationName", "")
    self:SetNWString("StationURL", "")
    self:SetNWInt("Status", rRadio.status.STOPPED)
    self:SetNWBool("IsPlaying", false)
    self:SetNWBool("IsPermanent", false)
    if self.Config and self.Config.Volume then
    self:SetNWFloat("Volume", self.Config.Volume())
    end
    self.IsPermanent = false
    self.NextUse = 0
    self.InteractCooldown = 0.25
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local now = CurTime()
    if now < (self.NextUse or 0) then return end
    self.NextUse = now + self.InteractCooldown

    if rRadio.utils.canInteractWithBoombox(activator, self) then
        net.Start("rRadio.OpenMenu")
        net.WriteEntity(self)
        net.Send(activator)
    else
        if not lastPermissionMessageTime[activator] or
           now - lastPermissionMessageTime[activator] >= PERMISSION_MESSAGE_COOLDOWN then
            activator:ChatPrint("You do not have permission to use this boombox.")
            lastPermissionMessageTime[activator] = now
        end
    end
end

function ENT:SpawnFunction(ply, tr, className)
    if not tr.Hit then return end
    local spawnPos = tr.HitPos + tr.HitNormal * 16
    local ent = ents.Create(className)
    if not IsValid(ent) then return end
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y - 90, 0))
    ent:Spawn()
    ent:Activate()
    if IsValid(ply) then
    ent:SetNWEntity("Owner", ply)
    end
    return ent
end

function ENT:StopRadio()
    net.Start("rRadio.StopStation")
    net.WriteEntity(self)
    net.Broadcast()
end

function ENT:CanTool(ply, trace, tool)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return ply == self:GetNWEntity("Owner")
    end
    function ENT:PhysgunPickup(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return ply == self:GetNWEntity("Owner")
end

if rRadio.config.DisablePushDamage then
    function ENT:PhysicsCollide(data, phys)
        return
    end
end

hook.Add("PlayerDisconnected", "CleanupBoomboxPermissionCooldowns", function(ply)
    lastPermissionMessageTime[ply] = nil
end)