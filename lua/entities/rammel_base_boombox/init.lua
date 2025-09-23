local Radio, Utils, Status, Config = rRadio:Import("Radio", "utils", "status", "config")

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

SavedBoomboxStates = SavedBoomboxStates or {}

local lastPermissionMessageTime = lastPermissionMessageTime or {}
local PERMISSION_MESSAGE_COOLDOWN = 3

local DEFAULT_MODEL = "models/rammel/boombox.mdl"
local NEXT_USE_KEY = "NextUse"
local INTERACT_COOLDOWN = 1

ENT.IsPermanent = false

function ENT:Initialize()
    self:SetModel(self.Model or DEFAULT_MODEL)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self.Color then
        self:SetColor(self.Color)
    end

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    self:SetNWString("StationName", "")
    self:SetNWString("StationURL", "")
    self:SetNWInt("Status", Status.STOPPED)
    self:SetNWBool("IsPlaying", false)
    self:SetNWBool("IsPermanent", false)

    if self.Config and self.Config.Volume then
        self:SetNWFloat("Volume", self.Config.Volume)
    end

    self[NEXT_USE_KEY] = 0
    self.InteractCooldown = INTERACT_COOLDOWN
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local now = CurTime()
    if now < (self[NEXT_USE_KEY] or 0) then return end
    self[NEXT_USE_KEY] = now + self.InteractCooldown

    if Utils.CanInteractWithBoombox(activator, self) then
        net.Start("rRadio.OpenMenu")
        net.WriteEntity(self)
        net.Send(activator)
        return
    end

    if not lastPermissionMessageTime[activator] or now - lastPermissionMessageTime[activator] >= PERMISSION_MESSAGE_COOLDOWN then
        activator:ChatPrint("You do not have permission to use this boombox.")
        lastPermissionMessageTime[activator] = now
    end
end

function ENT:SpawnFunction(ply, tr, className)
    if not tr.Hit then return end

    local ent = ents.Create(className)
    if not IsValid(ent) then return end

    ent:SetPos(tr.HitPos + tr.HitNormal * 16)
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

local function canManipulate(ply, ent)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return ply == ent:GetNWEntity("Owner")
end

function ENT:CanTool(ply)
    return canManipulate(ply, self)
end

function ENT:PhysgunPickup(ply)
    return canManipulate(ply, self)
end

if Config.DisablePushDamage then
    function ENT:PhysicsCollide()
        return
    end
end

hook.Add("PlayerDisconnected", "CleanupBoomboxPermissionCooldowns", function(ply)
    lastPermissionMessageTime[ply] = nil
end)