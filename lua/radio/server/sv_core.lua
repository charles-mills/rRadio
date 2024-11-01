--[[
    Radio Addon Server-Side Core Functionality
    Author: Charles Mills
    Description: This file contains the core server-side functionality for the Radio Addon.
                 It handles network communications, manages active radios, processes player
                 requests for playing and stopping stations, and coordinates with permanent
                 boombox functionality. It also includes utility functions for entity ownership
                 and permissions.
    Date: November 01, 2024
]]--

util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")
util.AddNetworkString("MakeBoomboxPermanent")
util.AddNetworkString("RemoveBoomboxPermanent")
util.AddNetworkString("BoomboxPermanentConfirmation")
util.AddNetworkString("RadioConfigUpdate")

-- Global action cooldown system
local GLOBAL_COOLDOWN = 0.1 -- 100ms cooldown between global actions
local lastGlobalAction = 0

local ActiveRadios = {}
local PlayerRetryAttempts = {}
local PlayerCooldowns = {}
BoomboxStatuses = BoomboxStatuses or {}
local SavePermanentBoombox, LoadPermanentBoomboxes

include("radio/server/sv_permanent.lua")
local utils = include("radio/shared/sh_utils.lua")
local ResourceManager = include("radio/server/sv_resource_manager.lua")

SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

--[[
    Function: CreateSafeTimer
    Creates a timer with safety checks and automatic cleanup
    Parameters:
    - name: Timer identifier
    - delay: Time between executions
    - reps: Number of repetitions (0 for infinite)
    - func: Function to execute that returns true to keep timer running
]]
local function CreateSafeTimer(name, delay, reps, func)
    if not name or not delay or not reps or not func then
        ErrorNoHalt("[rRadio] CreateSafeTimer: Invalid parameters provided\n")
        return
    end
    
    if timer.Exists(name) then 
        timer.Remove(name) 
    end
    
    timer.Create(name, delay, reps, function()
        if not func() then 
            timer.Remove(name)
        end
    end)
end

--[[
    VolumeUpdater: Handles volume update queuing and debouncing
    Provides a clean interface for processing volume updates with built-in safety checks
]]
local VolumeUpdater = {
    queue = {},
    timeout = 0.1,
    
    -- Process a volume update request
    process = function(self, entity, volume, ply)
        if not IsValid(entity) or not IsValid(ply) then return false end
        
        local entIndex = entity:EntIndex()
        
        -- If already queued, update the pending values
        if self.queue[entIndex] then
            self.queue[entIndex].volume = volume
            self.queue[entIndex].ply = ply
            return true
        end
        
        -- Queue the update
        self.queue[entIndex] = {
            volume = volume,
            ply = ply,
            time = CurTime(),
            entity = entity
        }
        
        -- Create safe timer to process this update
        CreateSafeTimer("VolumeUpdate_" .. entIndex, self.timeout, 1, function()
            return self:processQueue(entIndex)
        end)
        
        return true
    end,
    
    -- Process a queued update
    processQueue = function(self, entIndex)
        local data = self.queue[entIndex]
        if not data then return false end
        
        -- Validate all required components
        if not IsValid(data.entity) or not IsValid(data.ply) then
            self.queue[entIndex] = nil
            return false
        end
        
        -- Process the actual volume update
        ProcessVolumeUpdate(data.entity, data.volume, data.ply)
        
        -- Cleanup
        self.queue[entIndex] = nil
        return true
    end,
    
    -- Clean up any queued updates for an entity
    cleanup = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        if self.queue[entIndex] then
            if timer.Exists("VolumeUpdate_" .. entIndex) then
                timer.Remove("VolumeUpdate_" .. entIndex)
            end
            self.queue[entIndex] = nil
        end
    end,
    
    -- Clean up any queued updates for a player
    cleanupPlayer = function(self, ply)
        for entIndex, data in pairs(self.queue) do
            if data.ply == ply then
                if timer.Exists("VolumeUpdate_" .. entIndex) then
                    timer.Remove("VolumeUpdate_" .. entIndex)
                end
                self.queue[entIndex] = nil
            end
        end
    end
}

-- Replace the existing volume update receiver with this simplified version:
net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not IsValid(entity) then return end
    
    -- Let VolumeUpdater handle all the queuing and processing
    VolumeUpdater:process(entity, volume, ply)
end)

-- Update the cleanup hooks to use VolumeUpdater:
hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up volume updates
    VolumeUpdater:cleanup(entity)
    
    -- Clean up data tables
    EntityVolumes[entIndex] = nil
    
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
    
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
    end
    
    -- Clean up any remaining timers
    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    -- Clean up volume updates for this player
    VolumeUpdater:cleanupPlayer(ply)
    
    -- Clean up other player data
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

local EntityVolumes = {}

local function ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = GetConVar("radio_max_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

local function GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    
    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return GetConVar("radio_golden_boombox_volume"):GetFloat()
    elseif entityClass == "boombox" then
        return GetConVar("radio_boombox_volume"):GetFloat()
    else
        return GetConVar("radio_vehicle_volume"):GetFloat()
    end
end

local function InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    if not EntityVolumes[entIndex] then
        EntityVolumes[entIndex] = GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", EntityVolumes[entIndex])
    end
end

--[[
    Function: AddActiveRadio
    Adds a radio to the active radios list.
    Parameters:
    - entity: The entity representing the radio.
    - stationName: The name of the station.
    - url: The URL of the station.
    - volume: The volume level.
]]
local function AddActiveRadio(entity, stationName, url, volume)
    local entIndex = entity:EntIndex()
    
    -- Initialize volume if not set
    if not EntityVolumes[entIndex] then
        EntityVolumes[entIndex] = volume or GetDefaultVolume(entity)
    end

    -- Set networked variables
    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)  -- Make sure we set the URL
    entity:SetNWFloat("Volume", EntityVolumes[entIndex])

    -- Update ActiveRadios table
    ActiveRadios[entIndex] = {
        stationName = stationName,
        url = url,  -- Store the URL here
        volume = EntityVolumes[entIndex]
    }

    -- Update boombox status table
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = {
            stationStatus = "playing",
            stationName = stationName,
            url = url
        }
    end
end

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.
    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

--[[
    Function: SendActiveRadiosToPlayer
    Sends active radios to a specific player with limited retries.
    Parameters:
    - ply: The player to send active radios to.
]]
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end

    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    print("[rRadio Debug] Sending active radios to player:", ply)

    local attempt = PlayerRetryAttempts[ply]
    if table.IsEmpty(ActiveRadios) then
        if attempt >= 3 then
            PlayerRetryAttempts[ply] = nil
            return
        end

        PlayerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                PlayerRetryAttempts[ply] = nil
            end
        end)
        return
    end

    for entIndex, radio in pairs(ActiveRadios) do
        local entity = Entity(entIndex)
        if IsValid(entity) then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
        end
    end

    PlayerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

--[[
    Function: UpdateVehicleStatus
    Description: Returns the actual vehicle entity, handling parent relationships
    @param vehicle (Entity): The vehicle to check
    @return (Entity): The actual vehicle entity or nil
]]
local function UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end

    local veh = utils.GetVehicle(vehicle)
    if not veh then return end

    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    
    return isSitAnywhere
end

hook.Add("PlayerEnteredVehicle", "RadioVehicleHandling", function(ply, vehicle)
    local veh = utils.GetVehicle(vehicle)
    if not veh then return end
    
    -- Don't show radio message for sit anywhere seats
    if utils.isSitAnywhereSeat(vehicle) then return end
    
    if not UpdateVehicleStatus(vehicle) then
        net.Start("CarRadioMessage")
        net.Send(ply)
    end
end)

-- Add hook for new vehicles
hook.Add("OnEntityCreated", "InitializeVehicleStatus", function(ent)
    timer.Simple(0, function()
        if IsValid(ent) and utils.GetVehicle(ent) then
            UpdateVehicleStatus(ent)
        end
    end)
end)

--[[
    Function: IsLVSVehicle
    Checks if the given entity is an LVS vehicle or a seat in an LVS vehicle.
    Parameters:
    - entity: The entity to check.
    Returns:
    - The LVS vehicle entity if it's an LVS vehicle or seat, nil otherwise.
]]
local function IsLVSVehicle(entity)
    if not IsValid(entity) then return nil end

    local parent = entity:GetParent()
    if IsValid(parent) and (string.StartWith(parent:GetClass(), "lvs_") or string.StartWith(parent:GetClass(), "ses_")) then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") then
        return entity
    elseif string.StartWith(entity:GetClass(), "ses_") then
        return entity
    end

    return nil
end

local function GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

--[[
    Function: GetEntityOwner
    Gets the owner of an entity, using CPPI if available, otherwise falling back to other methods.
    Parameters:
    - entity: The entity to check ownership for.
    Returns:
    - The owner of the entity, or nil if no owner is found.
]]
local function GetEntityOwner(entity)
    if not IsValid(entity) then return nil end

    if entity.CPPIGetOwner then
        return entity:CPPIGetOwner()
    end

    local nwOwner = entity:GetNWEntity("Owner")
    if IsValid(nwOwner) then
        return nwOwner
    end

    return nil
end

--[[
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("PlayCarRadioStation", function(len, ply)
    local currentTime = CurTime()
    if currentTime - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("[rRadio] The radio system is busy. Please try again in a moment.")
        return
    end

    lastGlobalAction = currentTime

    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    -- Enhanced validation chain with debug logging
    print("[rRadio Debug] Initial entity:", entity, "IsValid:", IsValid(entity))

    -- Basic validation
    if not IsValid(entity) then 
        print("[rRadio Debug] Initial entity validation failed")
        return 
    end

    -- Get the actual vehicle entity if needed
    local actualEntity = GetVehicleEntity(entity)
    print("[rRadio Debug] After GetVehicleEntity:", actualEntity, "IsValid:", IsValid(actualEntity))
    
    if not IsValid(actualEntity) then
        print("[rRadio Debug] Actual entity validation failed")
        return
    end

    if not utils.canUseRadio(actualEntity) then
        print("[rRadio Debug] canUseRadio check failed")
        ply:ChatPrint("[rRadio] This seat cannot use the radio.")
        return
    end

    -- Validate permissions for boomboxes
    if utils.IsBoombox(actualEntity) then
        print("[rRadio Debug] Entity is boombox")
        if not utils.canInteractWithBoombox(ply, actualEntity) then
            print("[rRadio Debug] Boombox permission check failed")
            ply:ChatPrint("[rRadio] You don't have permission to use this boombox.")
            return
        end
    end

    -- Request the stream through ResourceManager
    local success, reason = ResourceManager:RequestStream(ply, actualEntity, stationURL, function(success, error)
        if not success then
            print("[rRadio Debug] Stream request failed:", error)
            ply:ChatPrint("[rRadio] Failed to start stream: " .. (error or "Unknown error"))
            return
        end
        
        print("[rRadio Debug] Stream request successful, broadcasting to clients")
        
        -- Add to active radios first
        AddActiveRadio(actualEntity, stationName, stationURL, volume)

        -- Then broadcast to all clients to start playback
        net.Start("PlayCarRadioStation")
            net.WriteEntity(actualEntity)
            net.WriteString(stationName)
            net.WriteString(stationURL)
            net.WriteFloat(volume)
        net.Broadcast()

        -- Update boombox status if needed
        if utils.IsBoombox(actualEntity) then
            local entIndex = actualEntity:EntIndex()
            if not BoomboxStatuses[entIndex] then
                BoomboxStatuses[entIndex] = {}
            end
            BoomboxStatuses[entIndex].url = stationURL
            
            -- Set initial status to tuning
            utils.setRadioStatus(actualEntity, "tuning", stationName)
            
            -- Set to playing after a delay
            timer.Create("StationUpdate_" .. entIndex, 2, 1, function()
                if IsValid(actualEntity) then
                    utils.setRadioStatus(actualEntity, "playing", stationName)
                end
            end)
        end
    end)

    if not success then
        print("[rRadio Debug] Initial request failed:", reason)
        ply:ChatPrint("[rRadio] " .. reason)
    end
end)

--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)

    if not IsValid(entity) then
        return
    end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        if not utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        utils.setRadioStatus(entity, "stopped")
        RemoveActiveRadio(entity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteString("stopped")
        net.Broadcast()

        local entIndex = entity:EntIndex()
        if timer.Exists("StationUpdate_" .. entIndex) then
            timer.Remove("StationUpdate_" .. entIndex)
        end

        timer.Create("StationUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function()
            if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
                SavePermanentBoombox(entity)
            end
        end)

    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity

        RemoveActiveRadio(radioEntity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
            net.WriteBool(false)
        net.Broadcast()
    else
        return
    end
end)

local function ProcessVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) then return end
    
    -- Get the actual vehicle entity if needed
    entity = utils.GetVehicle(entity) or entity
    local entIndex = entity:EntIndex()
    
    -- Validate permissions
    if utils.IsBoombox(entity) then
        if not utils.canInteractWithBoombox(ply, entity) then
            return
        end
    elseif utils.GetVehicle(entity) then
        local vehicle = utils.GetVehicle(entity)
        if utils.isSitAnywhereSeat(vehicle) then return end
        
        -- Check if player is in any seat of the vehicle
        local isInVehicle = false
        for _, seat in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == vehicle and seat:GetDriver() == ply then
                isInVehicle = true
                break
            end
        end
        if not isInVehicle and vehicle:GetDriver() ~= ply then
            return
        end
    else
        return
    end

    -- Update server-side state
    volume = ClampVolume(volume)
    EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)

    -- Broadcast to all clients
    net.Start("UpdateRadioVolume")
        net.WriteEntity(entity)
        net.WriteFloat(volume)
    net.Broadcast()
end

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local entIndex = IsValid(entity) and entity:EntIndex() or nil

    if not entIndex then return end

    -- Get or create the update data for this entity
    if not volumeUpdateQueue[entIndex] then
        volumeUpdateQueue[entIndex] = {
            lastUpdate = 0,
            pendingVolume = nil,
            pendingPlayer = nil
        }
    end

    local updateData = volumeUpdateQueue[entIndex]
    local currentTime = CurTime()

    updateData.pendingVolume = volume
    updateData.pendingPlayer = ply

    -- If we're not currently debouncing, process immediately
    if currentTime - updateData.lastUpdate >= VOLUME_UPDATE_DEBOUNCE_TIME then
        ProcessVolumeUpdate(entity, volume, ply)
        updateData.lastUpdate = currentTime
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        -- Otherwise, schedule an update using safe timer
        CreateSafeTimer("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            if not IsValid(entity) or not IsValid(updateData.pendingPlayer) then return false end
            
            ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
            updateData.lastUpdate = CurTime()
            updateData.pendingVolume = nil
            updateData.pendingPlayer = nil
            return true
        end)
    end
end)

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up timers
    local timerNames = {
        "VolumeUpdate_" .. entIndex,
        "StationUpdate_" .. entIndex
    }
    
    for _, timerName in ipairs(timerNames) do
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
    
    -- Clean up data tables
    EntityVolumes[entIndex] = nil
    
    -- Clean up radio status
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
    
    -- Clean up boombox status if applicable
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
    end
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    -- Clean up player-specific data
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    
    -- Clean up any entities owned by this player
    for entIndex, data in pairs(volumeUpdateQueue) do
        if data.pendingPlayer == ply then
            local entity = Entity(entIndex)
            if IsValid(entity) then
                CleanupEntity(entity)
            end
        end
    end
end)

--[[
    Function: IsDarkRP
    Utility function to detect if the gamemode is DarkRP or DerivedRP.
    Returns:
    - Boolean indicating if DarkRP is detected.
]]
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

--[[
    Function: AssignOwner
    Assigns ownership of an entity using CPPI.
    Parameters:
    - ply: The player to assign as the owner.
    - ent: The entity to assign ownership to.
]]
local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return
    end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end

    ent:SetNWEntity("Owner", ply)
end

hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and utils.IsBoombox(ent) then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.IsBoombox(ent) then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and utils.IsBoombox(ent) then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

-- Clean up player data on disconnect
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

-- Update the CleanupInactiveRadios timer:
local function CleanupInactiveRadios()
    local currentTime = CurTime()
    for entIndex, radio in pairs(ActiveRadios) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then  -- 1 hour inactivity
            RemoveActiveRadio(Entity(entIndex))
        end
    end
    return true -- Keep timer running
end

CreateSafeTimer("CleanupInactiveRadios", 300, 0, CleanupInactiveRadios)  -- Run every 5 minutes

-- Update the InitPostEntity hook to use CreateSafeTimer:
hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
    CreateSafeTimer("LoadPermanentBoomboxes", 0.5, 1, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        end
        return true
    end)
end)

-- Update OnEntityCreated hook to use CreateSafeTimer:
hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
    CreateSafeTimer("InitVolume_" .. entity:EntIndex(), 0, 1, function()
        if IsValid(entity) and (utils.IsBoombox(entity) or utils.GetVehicle(entity)) then
            InitializeEntityVolume(entity)
        end
        return true
    end)
end)

hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity

    if ActiveRadios[mainEntity:EntIndex()] then
        RemoveActiveRadio(mainEntity)
    end
end)

_G.AddActiveRadio = AddActiveRadio

hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function()
    if not _G.AddActiveRadio then
        _G.AddActiveRadio = AddActiveRadio
    end
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    -- Force ConVar updates
    game.ReloadConVars()
    
    -- Notify admins
    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Configuration reloaded!")
    else
        print("[rRadio] Configuration reloaded!")
    end
end)

local function AddRadioCommand(name, helpText)
    concommand.Add("radio_set_" .. name, function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        
        local value = tonumber(args[1])
        if not value then
            if IsValid(ply) then
                ply:ChatPrint("[rRadio] Invalid value provided!")
            else
                print("[rRadio] Invalid value provided!")
            end
            return
        end
        
        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)
            
            local message = string.format("[rRadio] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then
                ply:ChatPrint(message)
            else
                print(message)
            end
        end
    end)
end

local commands = {
    "max_volume_limit",
    "message_cooldown",
    "boombox_volume",
    "boombox_max_distance",
    "boombox_min_distance",
    "golden_boombox_volume",
    "golden_boombox_max_distance",
    "golden_boombox_min_distance",
    "vehicle_volume",
    "vehicle_max_distance",
    "vehicle_min_distance"
}

for _, cmd in ipairs(commands) do
    AddRadioCommand(cmd)
end

local radioCommands = {
    max_volume_limit = {
        desc = "Sets the maximum volume limit for all radio entities (0.0-1.0)",
        example = "0.8"
    },
    message_cooldown = {
        desc = "Sets the cooldown time in seconds for radio messages (the animation when entering a vehicle)",
        example = "2"
    },
    boombox_volume = {
        desc = "Sets the default volume for regular boomboxes",
        example = "0.7"
    },
    boombox_max_distance = {
        desc = "Sets the maximum hearing distance for boomboxes",
        example = "1000"
    },
    boombox_min_distance = {
        desc = "Sets the distance at which boombox volume starts to drop off",
        example = "500"
    },
    golden_boombox_volume = {
        desc = "Sets the default volume for golden boomboxes",
        example = "1.0"
    },
    golden_boombox_max_distance = {
        desc = "Sets the maximum hearing distance for golden boomboxes",
        example = "350000"
    },
    golden_boombox_min_distance = {
        desc = "Sets the distance at which golden boombox volume starts to drop off",
        example = "250000"
    },
    vehicle_volume = {
        desc = "Sets the default volume for vehicle radios",
        example = "0.8"
    },
    vehicle_max_distance = {
        desc = "Sets the maximum hearing distance for vehicle radios",
        example = "800"
    },
    vehicle_min_distance = {
        desc = "Sets the distance at which vehicle radio volume starts to drop off",
        example = "500"
    }
}

concommand.Add("radio_help", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[rRadio] You need to be a superadmin to use radio commands!")
        return 
    end
    
    local function printMessage(msg)
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, msg)
        else
            print(msg)
        end
    end
    
    printMessage("\n=== Radio Configuration Commands ===\n")
    
    -- Print general commands first
    printMessage("General Commands:")
    printMessage("  radio_help - Shows this help message")
    printMessage("  radio_reload_config - Reloads all radio configuration values")
    printMessage("\nConfiguration Commands:")
    
    -- Print all available commands with descriptions
    for cmd, info in pairs(radioCommands) do
        printMessage(string.format("  radio_set_%s <value>", cmd))
        printMessage(string.format("    Description: %s", info.desc))
        printMessage(string.format("    Example: radio_set_%s %s\n", cmd, info.example))
    end
    
    -- Print current values
    printMessage("Current Values:")
    for cmd, _ in pairs(radioCommands) do
        local cvar = GetConVar("radio_" .. cmd)
        if cvar then
            printMessage(string.format("  %s: %.2f", cmd, cvar:GetFloat()))
        end
    end
    
    printMessage("\nNote: All commands require superadmin privileges.")
    
    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Help information printed to console!")
    end
end)

local function AddRadioCommand(name)
    local cmdInfo = radioCommands[name]
    if not cmdInfo then return end
    
    concommand.Add("radio_set_" .. name, function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then 
            ply:ChatPrint("[rRadio] You need to be a superadmin to use this command!")
            return 
        end
        
        if not args[1] or args[1] == "help" then
            local msg = string.format("[rRadio] %s\nUsage: %s <value>\nExample: %s %s", 
                cmdInfo.desc, cmd, cmd, cmdInfo.example)
            
            if IsValid(ply) then
                ply:PrintMessage(HUD_PRINTCONSOLE, msg)
                ply:ChatPrint("[rRadio] Command help printed to console!")
            else
                print(msg)
            end
            return
        end
        
        local value = tonumber(args[1])
        if not value then
            if IsValid(ply) then
                ply:ChatPrint("[rRadio] Invalid value provided! Use 'help' for usage information.")
            else
                print("[rRadio] Invalid value provided! Use 'help' for usage information.")
            end
            return
        end
        
        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)
            
            local message = string.format("[rRadio] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then
                ply:ChatPrint(message)
            else
                print(message)
            end
        end
    end)
end

for cmd, _ in pairs(radioCommands) do
    AddRadioCommand(cmd)
end

hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) and (utils.IsBoombox(entity) or utils.GetVehicle(entity)) then
            InitializeEntityVolume(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupRadioVolume", function(entity)
    local entIndex = entity:EntIndex()
    EntityVolumes[entIndex] = nil
end)