--[[ 
    rRadio Addon for Garry's Mod - Boombox Entity Script
    Description: Manages the server-side functionalities of the boombox entity, including spawning, permissions, and interactions.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

utils.DebugPrint("Loading base_boombox/init.lua")

ENT = ENT or {}

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")
include("misc/utils.lua")

-- Ensure SavedBoomboxStates is initialized
SavedBoomboxStates = SavedBoomboxStates or {}

-- Table to track the last time a player received a "no permission" message
local lastPermissionMessageTime = {}

-- Cooldown period for permission messages in seconds
local permissionMessageCooldown = 5

-- Function to load authorized friends
local function loadAuthorizedFriends(ply)
    if not IsValid(ply) then return {} end
    
    local steamID = ply:SteamID64()
    local filename = "rradio_authorized_friends_" .. steamID .. ".txt"
    local friendsData = file.Read(filename, "DATA")
    
    if friendsData then
        return util.JSONToTable(friendsData) or {}
    else
        return {}
    end
end

-- Function to check if a player is an authorized friend
local function isAuthorizedFriend(owner, player)
    if not IsValid(owner) or not IsValid(player) then return false end
    
    local ownerSteamID = owner:SteamID64()
    local playerSteamID = player:SteamID64()
    
    local authorizedFriends = loadAuthorizedFriends(owner)
    for _, friend in ipairs(authorizedFriends) do
        if friend.steamid == playerSteamID then
            return true
        end
    end
    
    return false
end

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

    -- Set up the Use function
    self:SetupUse()
end

function ENT:SetupUse()
    self.Use = function(self, activator, caller)
        if activator:IsPlayer() then
            local owner = self:GetNWEntity("Owner")

            -- Check if the player is the owner, an admin, a superadmin, or an authorized friend
            if activator == owner or activator:IsAdmin() or activator:IsSuperAdmin() or isAuthorizedFriend(owner, activator) then
                net.Start("OpenRadioMenu")
                net.WriteEntity(self)
                net.Send(activator)
                utils.DebugPrint("[CarRadio Debug] Opening radio menu for authorized player: " .. activator:Nick())
            else
                local currentTime = CurTime()

                -- Check if the player has recently received a "no permission" message
                if not lastPermissionMessageTime[activator] or (currentTime - lastPermissionMessageTime[activator] > permissionMessageCooldown) then
                    activator:ChatPrint(utils.L("NoPermissionBoombox", "You do not have permission to use this boombox."))
                    lastPermissionMessageTime[activator] = currentTime
                    utils.DebugPrint("[CarRadio Debug] No permission message sent to: " .. activator:Nick())
                end
            end
        end
    end
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

-- Ensure only the owner, an admin, or a superadmin can pick up the boombox with the Physgun
function ENT:PhysgunPickup(ply)
    local owner = self:GetNWEntity("Owner")
    
    if not IsValid(owner) or ply == owner or ply:IsAdmin() or ply:IsSuperAdmin() or isAuthorizedFriend(owner, ply) then
        return true
    end

    return false
end

-- Add this hook to ensure the Use function is set up for all boomboxes, including permanent ones
hook.Add("OnEntityCreated", "SetupBoomboxUse", function(ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        timer.Simple(0, function()
            if IsValid(ent) then
                if ent.SetupUse then
                    ent:SetupUse()
                    utils.DebugPrint("[CarRadio Debug] Set up Use function for boombox: " .. ent:EntIndex())
                else
                    utils.DebugPrint("[CarRadio Debug] SetupUse function not found for boombox: " .. ent:EntIndex())
                end
            end
        end)
    end
end)

-- Add this to handle existing entities when the script is reloaded
timer.Simple(0, function()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and utils.isBoombox(ent) then
            if ent.SetupUse then
                ent:SetupUse()
                utils.DebugPrint("[CarRadio Debug] Set up Use function for existing boombox: " .. ent:EntIndex())
            else
                utils.DebugPrint("[CarRadio Debug] SetupUse function not found for existing boombox: " .. ent:EntIndex())
            end
        end
    end
end)

-- Add this hook to load authorized friends when a player joins
hook.Add("PlayerInitialSpawn", "LoadAuthorizedFriends", function(ply)
    ply.AuthorizedFriends = loadAuthorizedFriends(ply)
end)