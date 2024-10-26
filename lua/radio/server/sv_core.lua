--[[
    Radio Addon Server-Side Core Functionality
    Author: Charles Mills
    Description: This file contains the core server-side functionality for the Radio Addon.
                 It handles network communications, manages active radios, processes player
                 requests for playing and stopping stations, and coordinates with permanent
                 boombox functionality. It also includes utility functions for entity ownership
                 and permissions.
    Date: October 17, 2024
]]--

-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")

-- Constants
local MAX_ACTIVE_RADIOS = 100  -- Maximum number of active radios allowed
local PLAYER_RADIO_LIMIT = 5   -- Maximum number of radios a single player can activate
local GLOBAL_COOLDOWN = 1      -- Global cooldown in seconds between radio actions
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1  -- 100ms debounce time for volume updates
local STATION_CHANGE_COOLDOWN = 0.5
local DEBOUNCE_TIME = 10 -- 10 seconds debounce
local CLEANUP_PLAYER_THRESHOLD = 10  -- Only cleanup if more players than this
local CLEANUP_RADIO_THRESHOLD = 50   -- Or if more radios than this

-- Rate limiting constants
local RATE_LIMIT = {
    MESSAGES_PER_SECOND = 5,
    BURST_ALLOWANCE = 10,
    COOLDOWN_TIME = 1
}

-- Local variable caching
local IsValid = IsValid
local CurTime = CurTime
local timer = timer
local net = net
local table = table
local math = math
local string = string

-- Timer Management System
local TimerManager = {
    volume = {},
    station = {},
    retry = {},
    cleanup = function(entIndex)
        if not entIndex then return end
        
        local timerNames = {
            "VolumeUpdate_" .. entIndex,
            "StationUpdate_" .. entIndex,
            "NetworkQueue_" .. entIndex
        }
        
        for _, name in ipairs(timerNames) do
            if timer.Exists(name) then
                timer.Remove(name)
            end
        end
        
        TimerManager.volume[entIndex] = nil
        TimerManager.station[entIndex] = nil
        TimerManager.retry[entIndex] = nil
    end
}

-- Safe cleanup function that doesn't depend on TimerManager being available later
local function SafeCleanupTimers(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Direct timer cleanup without depending on TimerManager
    local timerNames = {
        "VolumeUpdate_" .. entIndex,
        "StationUpdate_" .. entIndex,
        "NetworkQueue_" .. entIndex
    }
    
    for _, name in ipairs(timerNames) do
        if timer.Exists(name) then
            timer.Remove(name)
        end
    end
end

-- Update the EntityRemoved hook to use SafeCleanupTimers
hook.Add("EntityRemoved", "CleanupRadioTimers", function(entity)
    SafeCleanupTimers(entity)
end)

-- Active radios and saved boombox states
local RadioManager = {
    active = {},
    count = 0,
    
    add = function(self, entity, stationName, url, volume)
        if not IsValid(entity) then return end
        
        -- Remove oldest if at limit
        if self.count >= MAX_ACTIVE_RADIOS then
            self:removeOldest()
        end
        
        local entIndex = entity:EntIndex()
        self.active[entIndex] = {
            entity = entity,
            stationName = stationName,
            url = url,
            volume = volume,
            timestamp = CurTime()
        }
        self.count = self.count + 1
    end,
    
    remove = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        if self.active[entIndex] then
            self.active[entIndex] = nil
            self.count = self.count - 1
        end
    end,
    
    removeOldest = function(self)
        local oldestTime = math.huge
        local oldestIndex = nil
        
        for entIndex, radio in pairs(self.active) do
            if radio.timestamp < oldestTime then
                oldestTime = radio.timestamp
                oldestIndex = entIndex
            end
        end
        
        if oldestIndex then
            self:remove(Entity(oldestIndex))
        end
    end
}

-- Table to track retry attempts per player
local PlayerRetryAttempts = {}

-- Table to track player cooldowns for net messages
local PlayerCooldowns = {}

-- Global table to store boombox statuses
BoomboxStatuses = BoomboxStatuses or {}
local SavePermanentBoombox, RemovePermanentBoombox, LoadPermanentBoomboxes

include("radio/server/sv_permanent.lua")
local utils = include("radio/shared/sh_utils.lua")

SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local LatestVolumeUpdates = {}
local VolumeUpdateTimers = {}

local volumeUpdateTimers = {}
local stationUpdateTimers = {}

local lastGlobalAction = 0     -- Timestamp of the last global radio action

local lastStationChangeTimes = {}

-- At the top of the file, after includes
local IsValid = IsValid
local CurTime = CurTime
local timer = timer
local net = net
local table = table
local math = math
local string = string

-- Replace multiple timer tracking tables with a single structure
local TimerManager = {
    volume = {},
    station = {},
    retry = {},
    cleanup = function(entIndex)
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
        if timer.Exists("StationUpdate_" .. entIndex) then
            timer.Remove("StationUpdate_" .. entIndex)
        end
        TimerManager.volume[entIndex] = nil
        TimerManager.station[entIndex] = nil
    end
}

-- Add near the top with other constants
local NetworkRateLimiter = {
    players = {},
    
    check = function(self, ply)
        local currentTime = CurTime()
        local data = self.players[ply] or {
            messages = 0,
            lastReset = currentTime,
            burstAllowance = RATE_LIMIT.BURST_ALLOWANCE
        }
        
        -- Reset counter if cooldown has passed
        if currentTime - data.lastReset >= RATE_LIMIT.COOLDOWN_TIME then
            data.messages = 0
            data.lastReset = currentTime
            data.burstAllowance = RATE_LIMIT.BURST_ALLOWANCE
        end
        
        -- Check if rate limit is exceeded
        if data.messages >= RATE_LIMIT.MESSAGES_PER_SECOND then
            if data.burstAllowance <= 0 then
                return false
            end
            data.burstAllowance = data.burstAllowance - 1
        end
        
        data.messages = data.messages + 1
        self.players[ply] = data
        return true
    end,
    
    clear = function(self, ply)
        self.players[ply] = nil
    end
}

-- Update the Validator table
local Validator = {
    volume = function(vol)
        return type(vol) == "number" and vol >= 0 and vol <= 1
    end,
    
    url = function(url)
        -- Just check if it's a string and within reasonable length
        return type(url) == "string" and #url <= 500
    end,
    
    stationName = function(name)
        if type(name) ~= "string" then return false end
        return #name <= 100 and #name > 0
    end
}

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
    if not IsValid(entity) then
        return
    end

    -- Remove the oldest radio if the limit is reached
    if RadioManager.count >= MAX_ACTIVE_RADIOS then
        RadioManager:removeOldest()
    end

    RadioManager:add(entity, stationName, url, volume)
end

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.
    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    RadioManager:remove(entity)
end

--[[
    Function: SendActiveRadiosToPlayer
    Sends active radios to a specific player with limited retries.
    Parameters:
    - ply: The player to send active radios to.
]]
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        return
    end

    -- Initialize attempt count if not present
    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]

    if next(RadioManager.active) == nil then
        if attempt >= 3 then
            PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            return
        end

        -- Increment the attempt count
        PlayerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            end
        end)
        return
    end

    for _, radio in pairs(RadioManager.active) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(radio.entity)
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
        end
    end

    -- Reset attempt count after successful send
    PlayerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    if vehicle.playerdynseat then
        vehicle:SetNWBool("IsSitAnywhereSeat", true)
    else
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    if vehicle.playerdynseat then
        return  -- Do not send the message if it's a sit anywhere seat
    end

    net.Start("CarRadioMessage")
    net.Send(ply)
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
    if IsValid(parent) and string.StartWith(parent:GetClass(), "lvs_") then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") then
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
    
    -- Try CPPI first
    if entity.CPPIGetOwner then
        return entity:CPPIGetOwner()
    end
    
    -- Fallback to NWEntity owner
    local nwOwner = entity:GetNWEntity("Owner")
    if IsValid(nwOwner) then
        return nwOwner
    end
    
    -- If all else fails, return nil
    return nil
end

-- Move this before the net.Receive("PlayCarRadioStation") handler
local StationQueue = {
    queues = {},
    processing = {},
    
    add = function(self, entity, data)
        if not IsValid(entity) then 
            return 
        end
        
        local entIndex = entity:EntIndex()
        self.queues[entIndex] = self.queues[entIndex] or {}
        
        table.insert(self.queues[entIndex], {
            stationName = data.stationName,
            url = data.url,
            volume = data.volume,
            player = data.player,
            timestamp = CurTime()
        })
        
        self:process(entity)
    end,
    
    process = function(self, entity)
        local entIndex = entity:EntIndex()
        
        if self.processing[entIndex] then
            return
        end
        
        local queue = self.queues[entIndex]
        if not queue or #queue == 0 then
            return
        end
        
        self.processing[entIndex] = true
        
        local function processNext()
            local request = table.remove(queue, 1)
            if request and IsValid(entity) then
                if RadioManager.active[entIndex] then
                    net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                    net.Broadcast()
                    RemoveActiveRadio(entity)
                end

                entity:SetNWString("StationName", request.stationName)
                entity:SetNWString("StationURL", request.url)
                entity:SetNWFloat("Volume", request.volume)
                entity:SetNWBool("IsPlaying", true)
                
                AddActiveRadio(entity, request.stationName, request.url, request.volume)
                
                net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(request.stationName)
                    net.WriteString(request.url)
                    net.WriteFloat(request.volume)
                net.Broadcast()

                if entity.IsPermanent and SavePermanentBoombox then
                    timer.Simple(0.1, function()
                        if IsValid(entity) then
                            SavePermanentBoombox(entity)
                        end
                    end)
                end
            end
            
            self.processing[entIndex] = false
            if queue and #queue > 0 then
                self:process(entity)
            end
        end
        
        timer.Simple(0.1, processNext)
    end,
    
    clear = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        self.queues[entIndex] = nil
        self.processing[entIndex] = nil
    end
}

-- Then update the net.Receive handler to use the queue
net.Receive("PlayCarRadioStation", function(len, ply)
    -- Rate limit check
    if not NetworkRateLimiter:check(ply) then
        ply:ChatPrint("You are sending too many requests. Please wait a moment.")
        return
    end
    
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()
    
    if not IsValid(entity) then return end
    
    -- Validate inputs
    if not Validator.stationName(stationName) or 
       not Validator.url(stationURL) or 
       not Validator.volume(volume) then
        ply:ChatPrint("Invalid station data provided.")
        return
    end
    
    -- Queue the station change
    StationQueue:add(entity, {
        stationName = stationName,
        url = stationURL,
        volume = volume,
        player = ply
    })
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

    -- Remove the cooldown check for stopping a station
    -- This allows players to stop a station without triggering the cooldown

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Check permissions for boomboxes
        if not utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        -- Update the station immediately for client-side responsiveness
        entity:SetNWString("StationName", "")
        entity:SetNWString("StationURL", "")
        entity:SetNWBool("IsPlaying", false)
        entity:SetNWString("Status", "stopped")

        RemoveActiveRadio(entity)

        -- Broadcast the stop command to all clients
        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        -- Update radio status for all clients
        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteString("stopped")
        net.Broadcast()

        -- Debounce the database update
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

        -- Broadcast the stop command to all clients
        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        -- Update radio status for all clients
        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
            net.WriteBool(false)
        net.Broadcast()
    else
        return
    end
end)

-- Add this near the top with other local variables
local volumeUpdateQueue = {}

-- Update the volume update timer code
net.Receive("UpdateRadioVolume", function(len, ply)
    -- Rate limit check
    if not NetworkRateLimiter:check(ply) then
        ply:ChatPrint("You are sending too many volume requests. Please wait a moment.")
        return
    end

    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local radioEntity = lvsVehicle or entity
    local entIndex = radioEntity:EntIndex()

    -- Check permissions for boomboxes
    if (entityClass == "boombox" or entityClass == "golden_boombox") and not utils.canInteractWithBoombox(ply, radioEntity) then
        ply:ChatPrint("You do not have permission to control this boombox's volume.")
        return
    end

    -- For vehicles, check if the player is in the vehicle
    if entity:IsVehicle() and entity:GetDriver() ~= ply then
        ply:ChatPrint("You must be in the vehicle to control its radio volume.")
        return
    end

    -- Validate volume
    if not Validator.volume(volume) then
        ply:ChatPrint("Invalid volume level.")
        return
    end

    -- Queue the volume update
    volumeUpdateQueue[entIndex] = {
        entity = radioEntity,
        volume = volume,
        player = ply,
        entityClass = entityClass
    }

    -- If there's no timer running for this entity, create one
    if not timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            local updateData = volumeUpdateQueue[entIndex]
            if updateData then
                local updateEntity = updateData.entity
                local updateVolume = updateData.volume

                if IsValid(updateEntity) then
                    updateEntity:SetNWFloat("Volume", updateVolume)
                    
                    -- Broadcast the volume update to all clients
                    net.Start("UpdateRadioVolume")
                        net.WriteEntity(updateEntity)
                        net.WriteFloat(updateVolume)
                    net.Broadcast()

                    -- Update the RadioManager if it exists for this entity
                    if RadioManager.active[entIndex] then
                        RadioManager.active[entIndex].volume = updateVolume
                    end

                    -- Save to database if permanent (for boomboxes)
                    if updateEntity.IsPermanent and SavePermanentBoombox and 
                       (updateData.entityClass == "boombox" or updateData.entityClass == "golden_boombox") then
                        SavePermanentBoombox(updateEntity)
                    end
                end

                -- Clear the queue for this entity
                volumeUpdateQueue[entIndex] = nil
            end
        end)
    end
end)

-- Update the cleanup hook to include volumeUpdateQueue
hook.Add("EntityRemoved", "CleanupVolumeUpdateTimers", function(entity)
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end
    volumeUpdateQueue[entIndex] = nil
end)

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity

    if RadioManager.active[mainEntity:EntIndex()] then
        RemoveActiveRadio(mainEntity)
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
        ent:CPPISetOwner(ply)  -- Assign the owner using CPPI if available
    end

    -- Set the owner as a networked entity so the client can access it
    ent:SetNWEntity("Owner", ply)
end

-- Hook into InitPostEntity to ensure everything is initialized
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

-- Clean up player data on disconnect
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
    timer.Simple(0.5, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity)
    SafeCleanupTimers(entity)
end)

hook.Add("PlayerDisconnected", "CleanupPlayerVolumeUpdateData", function(ply)
    for entIndex, updateData in pairs(LatestVolumeUpdates) do
        if updateData.ply == ply then
            LatestVolumeUpdates[entIndex] = nil
            if VolumeUpdateTimers[entIndex] then
                timer.Remove(VolumeUpdateTimers[entIndex])
                VolumeUpdateTimers[entIndex] = nil
            end
        end
    end
end)

hook.Add("EntityRemoved", "CleanupRadioTimers", function(entity)
    if IsValid(entity) then
        TimerManager.cleanup(entity:EntIndex())
    end
end)

_G.AddActiveRadio = AddActiveRadio

hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function()
    if not _G.AddActiveRadio then
        _G.AddActiveRadio = AddActiveRadio
    end
end)

-- Replace the CleanupInactiveRadios function
local function CleanupInactiveRadios()
    -- Only run cleanup if we have more than threshold players or radios
    local playerCount = #player.GetAll()
    if playerCount <= CLEANUP_PLAYER_THRESHOLD and RadioManager.count <= CLEANUP_RADIO_THRESHOLD then
        return
    end

    local currentTime = CurTime()
    for entIndex, radio in pairs(RadioManager.active) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then  -- 1 hour inactivity
            RemoveActiveRadio(Entity(entIndex))
        end
    end
end

-- Replace the cleanup timer with a smarter version that adjusts interval based on server load
local function GetCleanupInterval()
    local playerCount = #player.GetAll()
    return playerCount > CLEANUP_PLAYER_THRESHOLD and 300 or 600  -- 5 or 10 minutes
end

timer.Create("CleanupInactiveRadios", GetCleanupInterval(), 0, function()
    CleanupInactiveRadios()
    timer.Adjust("CleanupInactiveRadios", GetCleanupInterval())
end)

local NetworkQueue = {
    volume = {},
    processing = false,
    
    add = function(self, entity, volume)
        local entIndex = entity:EntIndex()
        self.volume[entIndex] = {
            entity = entity,
            volume = volume,
            timestamp = CurTime()
        }
        
        if not self.processing then
            self:process()
        end
    end,
    
    process = function(self)
        self.processing = true
        
        timer.Create("NetworkQueue_Process", VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            local batch = net.CreateBatch()
            
            for entIndex, data in pairs(self.volume) do
                if IsValid(data.entity) then
                    batch:Start("UpdateRadioVolume")
                        net.WriteEntity(data.entity)
                        net.WriteFloat(data.volume)
                    batch:End()
                end
            end
            
            batch:Broadcast()
            self.volume = {}
            self.processing = false
        end)
    end
}

local PermissionCache = {
    cache = {},
    timeout = 5, -- 5 seconds cache
    
    check = function(self, ply, entity)
        local entIndex = entity:EntIndex()
        local steamID = ply:SteamID()
        local key = steamID .. "_" .. entIndex
        local cached = self.cache[key]
        
        if cached and cached.time > CurTime() - self.timeout then
            return cached.result
        end
        
        local result = utils.canInteractWithBoombox(ply, entity)
        self.cache[key] = {
            result = result,
            time = CurTime()
        }
        
        return result
    end,
    
    clear = function(self, ply)
        local steamID = ply:SteamID()
        for key in pairs(self.cache) do
            if key:StartWith(steamID) then
                self.cache[key] = nil
            end
        end
    end
}

-- Add cleanup hook
hook.Add("PlayerDisconnected", "ClearPermissionCache", function(ply)
    PermissionCache:clear(ply)
end)

local RadioState = {
    STOPPED = "stopped",
    TUNING = "tuning",
    PLAYING = "playing",
    ERROR = "error",
    BUFFERING = "buffering"
}

local RadioStateMachine = {
    states = {},
    
    transition = function(self, entity, newState, data)
        if not IsValid(entity) then return false end
        local entIndex = entity:EntIndex()
        
        local currentState = self.states[entIndex] or RadioState.STOPPED
        local isValidTransition = self:validateTransition(currentState, newState)
        
        if not isValidTransition then
            return false
        end
        
        self.states[entIndex] = newState
        entity:SetNWString("Status", newState)
        
        -- Broadcast state change
        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString(data and data.stationName or "")
            net.WriteBool(newState == RadioState.PLAYING)
            net.WriteString(newState)
        net.Broadcast()
        
        return true
    end,
    
    validateTransition = function(self, currentState, newState)
        local validTransitions = {
            [RadioState.STOPPED] = {[RadioState.TUNING] = true},
            [RadioState.TUNING] = {[RadioState.PLAYING] = true, [RadioState.ERROR] = true},
            [RadioState.PLAYING] = {[RadioState.STOPPED] = true, [RadioState.BUFFERING] = true, [RadioState.ERROR] = true},
            [RadioState.BUFFERING] = {[RadioState.PLAYING] = true, [RadioState.ERROR] = true},
            [RadioState.ERROR] = {[RadioState.STOPPED] = true, [RadioState.TUNING] = true}
        }
        
        return validTransitions[currentState] and validTransitions[currentState][newState]
    end,
    
    getCurrentState = function(self, entity)
        return self.states[entity:EntIndex()] or RadioState.STOPPED
    end,
    
    cleanup = function(self, entity)
        self.states[entity:EntIndex()] = nil
    end
}

local function CleanupDisconnectedPlayer(ply)
    -- Clear all rate limiting data
    NetworkRateLimiter:clear(ply)
    
    -- Clear permission cache
    PermissionCache:clear(ply)
    
    -- Clear cooldowns and retry attempts
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    
    -- Clean up player's radios
    local steamID = ply:SteamID()
    for entIndex, radio in pairs(RadioManager.active) do
        if IsValid(radio.entity) then
            local owner = GetEntityOwner(radio.entity)
            if IsValid(owner) and owner:SteamID() == steamID then
                RemoveActiveRadio(radio.entity)
                StationQueue:clear(radio.entity)
                RadioStateMachine:cleanup(radio.entity)
            end
        end
    end
end

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", CleanupDisconnectedPlayer)

local EntityPool = {
    pool = {},
    maxPoolSize = 50,
    
    initialize = function(self)
        self.pool = {}
    end,
    
    acquire = function(self, entityType)
        -- Try to get an entity from the pool
        local pooled = self.pool[entityType] and table.remove(self.pool[entityType])
        if pooled and IsValid(pooled) then
            pooled:Spawn()
            return pooled
        end
        
        -- Create new entity if none available
        local ent = ents.Create(entityType)
        if IsValid(ent) then
            ent:Spawn()
        end
        return ent
    end,
    
    release = function(self, entity)
        if not IsValid(entity) then return end
        
        local entityType = entity:GetClass()
        self.pool[entityType] = self.pool[entityType] or {}
        
        -- Only pool if we haven't reached the limit
        if #self.pool[entityType] < self.maxPoolSize then
            entity:SetNoDraw(true)
            entity:SetNotSolid(true)
            table.insert(self.pool[entityType], entity)
        else
            entity:Remove()
        end
    end,
    
    cleanup = function(self)
        for _, typePool in pairs(self.pool) do
            for _, entity in ipairs(typePool) do
                if IsValid(entity) then
                    entity:Remove()
                end
            end
        end
        self.pool = {}
    end
}

hook.Add("InitPostEntity", "InitializeEntityPool", function()
    EntityPool:initialize()
end)

hook.Add("ShutDown", "CleanupEntityPool", function()
    EntityPool:cleanup()
end)

-- Also update any other places where TimerManager is used to ensure proper error checking
local function SafeCleanupTimers(entity)
    if IsValid(entity) and TimerManager and TimerManager.cleanup then
        TimerManager.cleanup(entity:EntIndex())
    end
end

-- Replace existing cleanup hooks with the safe version
hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity)
    SafeCleanupTimers(entity)
end)

-- After the StationQueue definition, add:
_G.StationQueue = StationQueue

-- After RadioManager definition in sv_core.lua, add:
_G.RadioManager = RadioManager

