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

-- Only allow the owner, a superadmin
function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        local owner = self:GetNWEntity("Owner")

        -- Check if the player is the owner, a superadmin
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
