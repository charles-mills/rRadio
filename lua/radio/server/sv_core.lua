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

-- Core constants
local GLOBAL_COOLDOWN = 0.1
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1
local STATION_UPDATE_DEBOUNCE_TIME = 2.0
local PERMANENT_SAVE_DELAY = 0.5
local STREAM_RETRY_DELAY = 0.2
local STATION_TUNING_DELAY = 2.0
local MAX_RETRY_ATTEMPTS = 3
local RETRY_COOLDOWN = 1.0
local CLEANUP_INTERVAL = 300 -- 5 minutes

-- State tables
local ActiveRadios = {}
local PlayerRetryAttempts = {}
local PlayerCooldowns = {}
local EntityVolumes = {}
local volumeUpdateQueue = {}
BoomboxStatuses = BoomboxStatuses or {}

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

local function ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = GetConVar("radio_max_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

local function InitializeEntityVolume(entity)
    if not IsValid(entity) or not utils.canUseRadio(entity) then return end
    
    local entIndex = entity:EntIndex()
    if not EntityVolumes[entIndex] then
        EntityVolumes[entIndex] = GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", EntityVolumes[entIndex])
    end
end

local function ProcessVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) then return false end
    
    -- Get the actual vehicle entity if needed
    entity = utils.GetVehicle(entity) or entity
    
    -- Use shared utility for permission check
    if not utils.canUseRadio(entity) then return false end
    
    -- Check permissions based on entity type
    if utils.IsBoombox(entity) then
        if not utils.canInteractWithBoombox(ply, entity) then
            return false
        end
    elseif utils.GetVehicle(entity) then
        if not utils.isPlayerInVehicle(ply, entity) then
            return false
        end
    end

    -- Update server-side state
    volume = ClampVolume(volume)
    local entIndex = entity:EntIndex()
    EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)

    -- Only broadcast to players in range
    local inRangePlayers = {}
    local entityPos = entity:GetPos()
    
    -- Get max distance based on entity type
    local maxDistance
    if utils.IsBoombox(entity) then
        if entity:GetClass() == "golden_boombox" then
            maxDistance = GetConVar("radio_golden_boombox_max_distance"):GetFloat()
        else
            maxDistance = GetConVar("radio_boombox_max_distance"):GetFloat()
        end
    else
        maxDistance = GetConVar("radio_vehicle_max_distance"):GetFloat()
    end
    
    for _, player in ipairs(player.GetAll()) do
        if player:GetPos():DistToSqr(entityPos) <= (maxDistance * maxDistance) then
            table.insert(inRangePlayers, player)
        end
    end

    if #inRangePlayers > 0 then
        net.Start("UpdateRadioVolume")
            net.WriteEntity(entity)
            net.WriteFloat(volume)
        net.Send(inRangePlayers)
    end
    
    return true
end

-- VolumeManager definition
local VolumeManager = {
    queue = {},
    lastUpdates = {},
    DEBOUNCE_TIME = 0.1,
    
    init = function(self)
        if not self.initialized then
            self.queue = {}
            self.lastUpdates = {}
            self.initialized = true
        end
    end,

    queueUpdate = function(self, entity, volume, ply)
        if not IsValid(entity) or not IsValid(ply) then return false end
        
        local entIndex = entity:EntIndex()
        
        if not self.queue[entIndex] then
            self.queue[entIndex] = {
                volume = volume,
                player = ply,
                timestamp = CurTime()
            }
        else
            self.queue[entIndex].volume = volume
            self.queue[entIndex].player = ply
            self.queue[entIndex].timestamp = CurTime()
        end
        
        if not self.lastUpdates[entIndex] or 
           (CurTime() - self.lastUpdates[entIndex]) >= self.DEBOUNCE_TIME then
            self:processUpdate(entIndex)
        end
        
        return true
    end,

    processUpdate = function(self, entIndex)
        local data = self.queue[entIndex]
        if not data then return false end
        
        local entity = Entity(entIndex)
        if not IsValid(entity) or not IsValid(data.player) then
            self.queue[entIndex] = nil
            return false
        end
        
        local success = ProcessVolumeUpdate(entity, data.volume, data.player)
        
        if success then
            self.lastUpdates[entIndex] = CurTime()
            self.queue[entIndex] = nil
        end
        
        return success
    end,

    cleanup = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        self.queue[entIndex] = nil
        self.lastUpdates[entIndex] = nil
        
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
    end,

    cleanupPlayer = function(self, ply)
        if not IsValid(ply) then return end
        
        for entIndex, data in pairs(self.queue) do
            if data.player == ply then
                self.queue[entIndex] = nil
                self.lastUpdates[entIndex] = nil
                
                if timer.Exists("VolumeUpdate_" .. entIndex) then
                    timer.Remove("VolumeUpdate_" .. entIndex)
                end
            end
        end
    end
}

-- Initialize VolumeManager immediately
VolumeManager:init()

-- Required includes
local utils = include("radio/shared/sh_utils.lua")
local ResourceManager = include("radio/server/sv_resource_manager.lua")

include("radio/server/sv_permanent.lua")

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

local TimerManager = {
    activeTimers = {},
    
    create = function(self, name, delay, repetitions, func)
        if not name or not delay or not func then return end
        
        -- Clean up existing timer
        self:remove(name)
        
        -- Create new timer
        timer.Create(name, delay, repetitions or 1, function()
            if func() == false then
                self:remove(name)
            end
        end)
        
        self.activeTimers[name] = true
    end,
    
    remove = function(self, name)
        if timer.Exists(name) then
            timer.Remove(name)
        end
        self.activeTimers[name] = nil
    end,
    
    cleanup = function(self, pattern)
        for timerName in pairs(self.activeTimers) do
            if pattern and string.find(timerName, pattern) then
                self:remove(timerName)
            end
        end
    end
}

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.
    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    ActiveRadios[entIndex] = nil
    
    -- Clean up any associated timers
    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end
end

-- Move this function definition before any code that uses it
local function CleanupEntity(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Clean up timers
    TimerManager:cleanup("_" .. entIndex)
    
    -- Clean up volume management
    VolumeManager:cleanup(entity)
    EntityVolumes[entIndex] = nil
    
    -- Clean up radio status
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
    
    -- Clean up boombox status
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
        utils.clearRadioStatus(entity)
    end
end

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    CleanupEntity(entity)
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    VolumeManager:cleanupPlayer(ply)
    
    -- Clean up any entities owned by this player
    for _, ent in ipairs(ents.GetAll()) do
        if utils.GetEntityOwner(ent) == ply then
            CleanupEntity(ent)
        end
    end
end)

--[[ 
    Function: StartNewStream
    Initiates a new stream for the specified entity, handling the necessary network communication and state updates.

    Parameters:
    - entity: The entity on which to play the radio station (Entity).
    - stationName: The name of the radio station (string).
    - stationURL: The URL of the radio station stream (string).
    - volume: The volume level for playback (number).

    Returns:
    - None: This function does not return a value, but it updates the state and broadcasts the stream request to clients.
]]
local function StartNewStream(entity, stationName, stationURL, volume)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Add to active radios
    AddActiveRadio(entity, stationName, stationURL, volume)
    
    -- Broadcast to clients
    net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.WriteString(stationURL)
        net.WriteFloat(volume)
    net.Broadcast()
    
    -- Handle boombox specific logic
    if utils.IsBoombox(entity) then
        utils.setRadioStatus(entity, "tuning", stationName)
        
        TimerManager:create("StationUpdate_" .. entIndex, STATION_TUNING_DELAY, 1, function()
            if IsValid(entity) then
                utils.setRadioStatus(entity, "playing", stationName)
            end
            return true
        end)
    end
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
    if not IsValid(entity) or not utils.canUseRadio(entity) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Initialize volume if not set
    InitializeEntityVolume(entity)

    -- Set networked variables
    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", EntityVolumes[entIndex])

    -- Update ActiveRadios table
    ActiveRadios[entIndex] = {
        stationName = stationName,
        url = url,
        volume = EntityVolumes[entIndex]
    }

    -- Update radio status
    if utils.IsBoombox(entity) then
        utils.setRadioStatus(entity, "playing", stationName, true)
    end
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
    if currentTime - (PlayerCooldowns[ply] or 0) < GLOBAL_COOLDOWN then
        return
    end
    PlayerCooldowns[ply] = currentTime

    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end
    
    -- Get actual entity and validate
    local actualEntity = GetVehicleEntity(entity)
    if not IsValid(actualEntity) then return end
    
    -- Validate permissions
    if utils.IsBoombox(actualEntity) and not utils.canInteractWithBoombox(ply, actualEntity) then
        ply:ChatPrint("[rRadio] You don't have permission to use this boombox.")
        return
    end

    local entIndex = actualEntity:EntIndex()
    
    -- Handle the stream request
    ResourceManager:RequestStream(ply, actualEntity, stationURL, function(success, error)
        if not success then
            ply:ChatPrint("[rRadio] " .. (error or "Failed to start stream"))
            return
        end
        
        -- Stop any existing playback
        if ActiveRadios[entIndex] then
            net.Start("StopCarRadioStation")
                net.WriteEntity(actualEntity)
            net.Broadcast()
            
            -- Add delay before starting new stream
            TimerManager:create("StartStream_" .. entIndex, STREAM_RETRY_DELAY, 1, function()
                StartNewStream(actualEntity, stationName, stationURL, volume)
                return true
            end)
        else
            StartNewStream(actualEntity, stationName, stationURL, volume)
        end
    end)
end)


--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end

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

        -- Save permanent boombox state after a delay
        if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
            timer.Create("SavePermanent_" .. entIndex, PERMANENT_SAVE_DELAY, 1, function()
                if IsValid(entity) then
                    SavePermanentBoombox(entity)
                end
            end)
        end

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
    end
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not IsValid(entity) then return end
    
    -- Get the actual vehicle entity if needed
    entity = utils.GetVehicle(entity) or entity
    local entIndex = entity:EntIndex()
    
    -- Initialize queue entry if it doesn't exist
    if not volumeUpdateQueue[entIndex] then
        volumeUpdateQueue[entIndex] = {
            lastUpdate = 0,
            pendingVolume = nil,
            pendingPlayer = nil
        }
    end
    
    local updateData = volumeUpdateQueue[entIndex]
    local currentTime = CurTime()
    
    -- Update pending data
    updateData.pendingVolume = volume
    updateData.pendingPlayer = ply
    
    -- Process immediately if not debouncing
    if currentTime - updateData.lastUpdate >= VOLUME_UPDATE_DEBOUNCE_TIME then
        ProcessVolumeUpdate(entity, volume, ply)
        updateData.lastUpdate = currentTime
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        -- Schedule update if within debounce period
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
        
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            if IsValid(entity) and IsValid(updateData.pendingPlayer) then
                ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
                updateData.lastUpdate = CurTime()
                updateData.pendingVolume = nil
                updateData.pendingPlayer = nil
            end
        end)
    end
end)

-- Update the cleanup functions
local function CleanupVolumeData(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Clean up volume update queue
    if volumeUpdateQueue[entIndex] then
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
        volumeUpdateQueue[entIndex] = nil
    end
    
    -- Clean up entity volumes
    EntityVolumes[entIndex] = nil
end

-- Update the EntityRemoved hook
hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up all timers
    CleanupEntityTimers(entity)
    
    -- Clean up volume-related data
    CleanupVolumeData(entity)
    
    -- Clean up radio status
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
    
    -- Clean up boombox status
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
    end
end)

-- Update the PlayerDisconnected hook
hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    -- Clean up player-specific data
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    
    -- Clean up any pending volume updates for this player
    for entIndex, data in pairs(volumeUpdateQueue) do
        if data.pendingPlayer == ply then
            if timer.Exists("VolumeUpdate_" .. entIndex) then
                timer.Remove("VolumeUpdate_" .. entIndex)
            end
            volumeUpdateQueue[entIndex] = nil
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
        if IsValid(entity) then
            InitializeEntityVolume(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupRadioVolume", function(entity)
    local entIndex = entity:EntIndex()
    EntityVolumes[entIndex] = nil
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if not IsValid(entity) then return end
    
    -- Get the actual vehicle entity if needed
    entity = utils.GetVehicle(entity) or entity
    
    -- Queue the update through VolumeManager
    VolumeManager:queueUpdate(entity, volume, ply)
end)

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up volume management
    VolumeManager:cleanup(entity)
    EntityVolumes[entIndex] = nil
    
    -- Clean up radio status
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
    
    -- Clean up boombox status
    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
    end
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    -- Clean up player-specific data
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    
    -- Clean up volume management
    VolumeManager:cleanupPlayer(ply)
end)

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    CleanupEntity(entity)
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    
    -- Clean up any entities owned by this player
    for _, ent in ipairs(ents.GetAll()) do
        if utils.GetEntityOwner(ent) == ply then
            CleanupEntity(ent)
        end
    end
end)

timer.Create("RadioSystemCleanup", CLEANUP_INTERVAL, 0, function()
    -- Clean up invalid entities
    for entIndex, _ in pairs(ActiveRadios) do
        local entity = Entity(entIndex)
        if not IsValid(entity) then
            CleanupEntity(entity)
        end
    end
    
    -- Clean up stale timers
    for timerName in pairs(TimerManager.activeTimers) do
        if not timer.Exists(timerName) then
            TimerManager.activeTimers[timerName] = nil
        end
    end
end)

hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) then
            InitializeEntityVolume(entity)
        end
    end)
end)
hook.Add("EntityRemoved", "CleanupRadioVolume", function(entity)
    local entIndex = entity:EntIndex()
    EntityVolumes[entIndex] = nil
end)
