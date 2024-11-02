--[[
    Base Boombox Entity Initialization
    Author: Charles Mills
    Description: This file initializes the base boombox entity, setting up its physical properties,
                 network variables, and core functionality. It handles entity spawning, permissions,
                 and interaction logic for the boombox entities in the Radio Addon.
    Date: October 30, 2024
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Ensure SavedBoomboxStates is initialized
SavedBoomboxStates = SavedBoomboxStates or {}

-- Table to track the last time a player received a "no permission" message
local lastPermissionMessageTime = {}
-- Cooldown period for permission messages in seconds
local PERMISSION_MESSAGE_COOLDOWN = 3 -- 3 seconds cooldown

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

    -- Initialize networked variables with default values
    self:SetNWString("StationName", "")
    self:SetNWString("StationURL", "")
    self:SetNWString("Status", "stopped")
    self:SetNWBool("IsPlaying", false)
    self:SetNWBool("IsPermanent", false)
    
    -- Set initial volume from config
    if self.Config and self.Config.Volume then
        self:SetNWFloat("Volume", self.Config.Volume())
    end

    -- Initialize permanence state
    self.IsPermanent = false
end

-- Add Use function to handle interaction
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local owner = self:GetNWEntity("Owner")
    
    -- Check if the player is the owner or a superadmin
    if activator == owner or activator:IsSuperAdmin() then
        net.Start("OpenRadioMenu")
            net.WriteEntity(self)
        net.Send(activator)
    else
        local currentTime = CurTime()
        if not lastPermissionMessageTime[activator] or 
           (currentTime - lastPermissionMessageTime[activator] >= PERMISSION_MESSAGE_COOLDOWN) then
            activator:ChatPrint("You do not have permission to use this boombox.")
            lastPermissionMessageTime[activator] = currentTime
        end
    end
end

-- Spawn function called when the entity is created
function ENT:SpawnFunction(ply, tr, className)
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal * 16
    local ent = ents.Create(className)
    
    if not IsValid(ent) then return end
    
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y - 90, 0))
    ent:Spawn()
    ent:Activate()

    -- Set the owner
    if IsValid(ply) then
        ent:SetNWEntity("Owner", ply)
    end

    return ent
end

-- Function to stop the radio
function ENT:StopRadio()
    net.Start("StopCarRadioStation")
        net.WriteEntity(self)
    net.Broadcast()
end

-- Clean up the cooldown table when players leave
hook.Add("PlayerDisconnected", "CleanupBoomboxPermissionCooldowns", function(ply)
    lastPermissionMessageTime[ply] = nil
end)

-- Prevent non-owners from using tools or physgun
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
