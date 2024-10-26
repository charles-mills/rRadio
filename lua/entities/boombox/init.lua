AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
SavedBoomboxStates = SavedBoomboxStates or {} -- Ensure SavedBoomboxStates is initialized
local lastPermissionMessageTime = {} -- Table to track the last time a player received a "no permission" message
local permissionMessageCooldown = 5 -- Cooldown period for permission messages in seconds
function ENT:Initialize()
    self:SetModel(self.Model or "models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    if self.Color then self:SetColor(self.Color) end
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:Wake() end
    self:SetCollisionGroup(COLLISION_GROUP_NONE) -- Ensure the collision group allows interaction with the Physgun
    self.StationName = self.StationName or "" -- Initialize boombox properties
    self.StationURL = self.StationURL or ""
    self.Volume = self.Volume or 1.0
    self.IsPermanent = false -- Initialize permanence
    self:SetNWBool("IsPermanent", false)
end

function ENT:SpawnFunction(ply, tr, className) -- Spawn function called when the entity is created via the Spawn Menu or other means
    if not tr.Hit then return end
    local spawnPos = tr.HitPos + tr.HitNormal * 16
    local ent = ents.Create(className)
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y - 90, 0))
    ent:Spawn()
    ent:Activate()
    if IsValid(ply) then -- Set the owner of the entity using NWEntity if a valid player is available
        ent:SetNWEntity("Owner", ply)
    end
    return ent
end

function ENT:PhysgunPickup(ply)
    local owner = self:GetNWEntity("Owner")
    if ply:IsSuperAdmin() then -- Always allow superadmins to pick up the boombox
        return true
    end
    return ply == owner or not IsValid(owner)
end

function ENT:Use(activator, caller) -- Only allow the owner or a superadmin to use the boombox
    if activator:IsPlayer() then
        local owner = self:GetNWEntity("Owner")
        if activator == owner or activator:IsSuperAdmin() then -- Check if the player is the owner or a superadmin
            net.Start("OpenRadioMenu")
            net.WriteEntity(self)
            net.Send(activator)
        else
            local currentTime = CurTime()
            if not lastPermissionMessageTime[activator] or (currentTime - lastPermissionMessageTime[activator] > permissionMessageCooldown) then
                activator:ChatPrint("You do not have permission to use this boombox.")
                lastPermissionMessageTime[activator] = currentTime
            end
        end
    end
end

function ENT:MakePermanent() -- Function to make the boombox permanent (called by the server)
    if self.IsPermanent then return end
    self.IsPermanent = true
    self:SetNWBool("IsPermanent", true)
end

function ENT:RemovePermanent() -- Function to remove permanence from the boombox (called by the server)
    if not self.IsPermanent then return end
    self.IsPermanent = false
    self:SetNWBool("IsPermanent", false)
    if self.StopRadio then -- Optionally stop the radio if it's playing
        self:StopRadio()
    end
end

function ENT:CanTool(ply, tool) -- Prevent non-superadmins from using tools or physgun on boomboxes
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return false
end

function ENT:CanPhysgun(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return false
end