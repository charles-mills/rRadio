-- lua/entities/boombox/init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Ensure SavedBoomboxStates is initialized
SavedBoomboxStates = SavedBoomboxStates or {}

-- Table to track the last time a player received a "no permission" message
local lastPermissionMessageTime = {}
-- Cooldown period for permission messages in seconds
local permissionMessageCooldown = 5

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

    -- Ensure the collision group allows interaction with the Physgun
    self:SetCollisionGroup(COLLISION_GROUP_NONE)

    -- Initialize boombox properties
    self.StationName = self.StationName or ""
    self.StationURL = self.StationURL or ""
    self.Volume = self.Volume or 1.0

    -- Initialize permanence
    self.IsPermanent = false
    self:SetNWBool("IsPermanent", false)
end

-- Spawn function called when the entity is created via the Spawn Menu or other means
function ENT:SpawnFunction(ply, tr, className)
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal * 16

    local ent = ents.Create(className)
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y - 90, 0))
    ent:Spawn()
    ent:Activate()

    -- Set the owner of the entity using NWEntity if a valid player is available
    if IsValid(ply) then
        ent:SetNWEntity("Owner", ply)
    end

    return ent
end

function ENT:PhysgunPickup(ply)
    local owner = self:GetNWEntity("Owner")

    -- Always allow superadmins to pick up the boombox
    if ply:IsSuperAdmin() then
        return true
    end

    return ply == owner or not IsValid(owner)
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
            local currentTime = CurTime()

            -- Check if the player has recently received a "no permission" message
            if not lastPermissionMessageTime[activator] or (currentTime - lastPermissionMessageTime[activator] > permissionMessageCooldown) then
                activator:ChatPrint("You do not have permission to use this boombox.")
                lastPermissionMessageTime[activator] = currentTime
            end
        end
    end
end

-- Function to make the boombox permanent (called by the server)
function ENT:MakePermanent()
    if self.IsPermanent then return end
    self.IsPermanent = true
    self:SetNWBool("IsPermanent", true)
end

-- Function to remove permanence from the boombox (called by the server)
function ENT:RemovePermanent()
    if not self.IsPermanent then return end
    self.IsPermanent = false
    self:SetNWBool("IsPermanent", false)

    -- Optionally stop the radio if it's playing
    if self.StopRadio then
        self:StopRadio()
    end
end

-- Prevent non-superadmins from using tools or physgun on boomboxes
function ENT:CanTool(ply, tool)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return false
end

function ENT:CanPhysgun(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return false
end
