--[[
    Radio Addon Stream Management System
    Author: Charles Mills
    Description: Manages all radio stream lifecycle events and state
    Date: November 3, 2024
]]--

local utils = include("radio/shared/sh_utils.lua")
local Debug = RadioDebug

local StreamManager = {
    _streams = {},
    _validityCache = {},
    _retryAttempts = {},
    _lastValidityCheck = 0, -- Initialize timing variables
    _lastPositionUpdate = 0,
    _lastHistoryCleanup = 0,
    
    -- Configuration
    Config = {
        MAX_RETRIES = 3,
        RETRY_DELAY = 2,
        VALIDITY_CHECK_INTERVAL = 0.5,
        CLEANUP_INTERVAL = 0.2,
        POSITION_UPDATE_INTERVAL = 0.1,
        MAX_INACTIVE_TIME = 30,
    },
    
    -- Event system
    Events = {
        STREAM_CREATED = "StreamCreated",
        STREAM_STARTED = "StreamStarted",
        STREAM_STOPPED = "StreamStopped",
        STREAM_ERROR = "StreamError",
        STREAM_RETRY = "StreamRetry",
        STREAM_CLEANUP = "StreamCleanup",
        VOLUME_CHANGED = "VolumeChanged",
        POSITION_UPDATED = "PositionUpdated",
        STATE_CHANGED = "StateChanged"
    },
    
    -- Enhanced state tracking
    _streamHistory = {}, -- Track historical data
    _streamStats = {     -- Track statistics
        totalStreams = 0,
        totalErrors = 0,
        totalRetries = 0,
        averageUptime = 0
    },
    
    -- Stream state constants
    States = {
        INITIALIZING = "initializing",
        CONNECTING = "connecting",
        BUFFERING = "buffering",
        PLAYING = "playing",
        PAUSED = "paused",
        STOPPED = "stopped",
        ERROR = "error",
        RETRYING = "retrying"
    },
    
    -- Add rate limiting configuration
    RateLimit = {
        CREATE_INTERVAL = 0.5, -- Minimum time between stream creations
        lastCreate = 0,
        BULK_CLEANUP_SIZE = 50, -- Number of history entries to keep
        HISTORY_CLEANUP_INTERVAL = 60 -- Cleanup history every minute
    },
    
    -- Update the Emit method definition (add near the top with other core methods)
    Emit = function(self, event, ...)
        if not self._eventHandlers[event] then return end
        
        for _, handler in ipairs(self._eventHandlers[event]) do
            local success, err = pcall(handler, ...)
            if not success then
                Debug:Error("Error in event handler for", event, ":", err)
            end
        end
    end,
    
    ValidateEntity = function(self, entity)
        return IsValid(entity) and not entity:IsWorld() and utils.canUseRadio(entity)
    end,
    
    -- Add to StreamManager table properties
    _cleanupQueue = {},
    _lastCleanup = 0,
    
    -- Add QueueCleanup method
    QueueCleanup = function(self, entIndex, reason)
        self._cleanupQueue[entIndex] = {
            reason = reason,
            timestamp = CurTime()
        }
        
        -- Process queue if enough time has passed
        if CurTime() - self._lastCleanup >= self.Config.CLEANUP_INTERVAL then
            self:ProcessCleanupQueue()
        end
    end,
    
    -- Add ProcessCleanupQueue method
    ProcessCleanupQueue = function(self)
        self._lastCleanup = CurTime()
        
        for entIndex, cleanupData in pairs(self._cleanupQueue) do
            Debug:Log("Processing cleanup for entity", entIndex, "(Reason:", cleanupData.reason, ")")
            self:CleanupStream(entIndex)
        end
        
        -- Clear cleanup queue
        self._cleanupQueue = {}
    end,
}

-- Initialize event system
StreamManager._eventHandlers = {}

function StreamManager:On(event, handler)
    self._eventHandlers[event] = self._eventHandlers[event] or {}
    table.insert(self._eventHandlers[event], handler)
end

-- Core stream management functions
function StreamManager:CreateStream(entity, data)
    if not self.initialized then
        Debug:Error("StreamManager not initialized")
        return false
    end
    
    -- Add validation for data parameters
    if not data or not data.url or not data.name then
        Debug:Error("Invalid stream data provided")
        return false
    end
    
    if not self:ValidateEntity(entity) then 
        Debug:Error("Invalid entity for streaming")
        return false 
    end
    
    local entIndex = entity:EntIndex()
    Debug:Log("Creating stream for entity", entIndex)
    Debug:Log("- Name:", data.name)
    Debug:Log("- URL:", data.url)
    
    -- Clean up existing stream if present
    self:CleanupStream(entIndex)
    
    -- Create new stream entry with enhanced metadata
    self._streams[entIndex] = {
        entity = entity,
        data = data,
        startTime = CurTime(),
        lastActivity = CurTime(),
        retryCount = 0,
        state = self.States.INITIALIZING,
        stateHistory = {},
        metadata = {
            entityClass = entity:GetClass(),
            entityPos = entity:GetPos(),
            config = utils.GetEntityConfig(entity),
            createdAt = os.time(),
            sessionId = util.CRC(tostring(CurTime()) .. entity:EntIndex())
        }
    }
    
    -- Update statistics
    self._streamStats.totalStreams = self._streamStats.totalStreams + 1
    
    -- Initialize sound stream
    sound.PlayURL(data.url, "3d noblock", function(stream, errorID, errorName)
        -- Check if stream entry still exists
        if not self._streams[entIndex] then
            Debug:Log("Stream entry no longer exists for", entIndex)
            if IsValid(stream) then stream:Stop() end
            return false
        end

        -- Handle stream creation failure
        if not IsValid(stream) then
            Debug:Error("Failed to create stream:", errorName)
            self:HandleStreamError(entIndex, errorID, errorName)
            return false
        end
        
        Debug:Log("Stream created successfully for", entIndex)
        
        -- Store stream reference before any other operations
        self._streams[entIndex].stream = stream
        self._streams[entIndex].state = self.States.CONNECTING
        
        Debug:Log("Stream state updated to CONNECTING for", entIndex)
        
        -- Configure stream
        stream:SetPos(entity:GetPos())
        stream:Set3DFadeDistance(data.minDist or 200, data.maxDist or 1000)
        stream:SetVolume(data.volume or 1)
        
        -- Start playback
        local success, err = pcall(function()
            stream:Play()
        end)
        
        if not success then
            Debug:Error("Failed to start playback:", err)
            self:HandleStreamError(entIndex, "playback_error", err)
            return false
        end
        
        -- Update state to playing
        self._streams[entIndex].state = self.States.PLAYING
        
        Debug:Log("Stream state updated to PLAYING for", entIndex)
        
        -- Emit success events
        self:Emit(self.Events.STREAM_STARTED, entity, data)
        self:Emit(self.Events.STATE_CHANGED, {
            type = "stream_created",
            entity = entity,
            data = data
        })
        
        return true
    end)
    
    return true
end

function StreamManager:HandleStreamError(entIndex, errorID, errorName)
    local streamData = self._streams[entIndex]
    if not streamData then return end
    
    Debug:Error("Stream error for entity", entIndex)
    Debug:Error("- Error ID:", errorID)
    Debug:Error("- Error Name:", errorName)
    Debug:Error("- Retry Count:", streamData.retryCount)
    
    -- Check retry attempts
    if streamData.retryCount < self.Config.MAX_RETRIES then
        streamData.retryCount = streamData.retryCount + 1
        streamData.state = self.States.RETRYING
        
        Debug:Log("Retrying stream creation", streamData.retryCount, "of", self.Config.MAX_RETRIES)
        
        -- Emit retry event
        self:Emit(self.Events.STREAM_RETRY, streamData.entity, streamData.retryCount)
        
        -- Schedule retry
        timer.Simple(self.Config.RETRY_DELAY, function()
            if self:IsValid(entIndex) then
                self:CreateStream(streamData.entity, streamData.data)
            end
        end)
    else
        Debug:Log("Max retries reached, cleaning up stream", entIndex)
        -- Clean up after max retries
        self:CleanupStream(entIndex)
        
        -- Emit error event
        self:Emit(self.Events.STREAM_ERROR, streamData.entity, errorID, errorName)
    end
end

function StreamManager:UpdateStreamPosition(entIndex)
    local streamData = self._streams[entIndex]
    if not streamData or not IsValid(streamData.stream) then return end
    
    local entity = streamData.entity
    if not IsValid(entity) then
        self:CleanupStream(entIndex)
        return
    end
    
    -- Update position
    streamData.stream:SetPos(entity:GetPos())
    
    -- Calculate volume based on distance
    local ply = LocalPlayer()
    local distance = ply:GetPos():Distance(entity:GetPos())
    
    -- Update volume based on distance and settings
    self:UpdateStreamVolume(entIndex, distance)
    
    -- Update last activity
    streamData.lastActivity = CurTime()
end

function StreamManager:UpdateStreamVolume(entIndex, distance)
    local streamData = self._streams[entIndex]
    if not streamData or not IsValid(streamData.stream) then return end
    
    local volume = streamData.data.volume or 1
    local minDist = streamData.data.minDist or 200
    local maxDist = streamData.data.maxDist or 1000
    
    -- Calculate distance-based volume
    if distance > minDist then
        local falloff = 1 - math.Clamp((distance - minDist) / (maxDist - minDist), 0, 1)
        volume = volume * falloff
    end
    
    -- Apply volume
    streamData.stream:SetVolume(volume)
    
    -- Emit volume change event
    self:Emit(self.Events.VOLUME_CHANGED, streamData.entity, volume)
end

function StreamManager:CleanupStream(entIndex)
    local streamData = self._streams[entIndex]
    if not streamData then return end
    
    -- Stop stream if valid
    if IsValid(streamData.stream) then
        streamData.stream:Stop()
    end
    
    -- Clear timers
    timer.Remove("StreamRetry_" .. entIndex)
    timer.Remove("StreamUpdate_" .. entIndex)
    
    -- Clear state
    self._streams[entIndex] = nil
    self._validityCache[entIndex] = nil
    self._retryAttempts[entIndex] = nil
    
    -- Emit cleanup event
    self:Emit(self.Events.STREAM_CLEANUP, streamData.entity)
end

function StreamManager:IsValid(entIndex)
    local streamData = self._streams[entIndex]
    if not streamData then return false end
    
    -- Always check entity validity
    if not IsValid(streamData.entity) then return false end
    
    -- During initialization or connecting states, don't require valid stream
    if streamData.state == self.States.INITIALIZING or 
       streamData.state == self.States.CONNECTING then
        Debug:Log("Stream in initialization/connecting state for", entIndex)
        return true
    end
    
    -- For playing state, require valid stream
    if streamData.state == self.States.PLAYING then
        local isValid = IsValid(streamData.stream)
        if not isValid then
            Debug:Log("Invalid stream for playing state", entIndex)
        end
        return isValid
    end
    
    -- For other states, don't require valid stream yet
    return true
end

function StreamManager:UpdateValidityCache()
    self._lastValidityCheck = CurTime()
    self._validityCache = {}
    
    for entIndex, streamData in pairs(self._streams) do
        -- Only validate entity initially
        if not IsValid(streamData.entity) then
            Debug:Log("Invalid entity in validity cache update for", entIndex)
            self:QueueCleanup(entIndex, "invalid_entity")
            continue
        end
        
        -- Set cache based on state
        if streamData.state == self.States.INITIALIZING or 
           streamData.state == self.States.CONNECTING then
            Debug:Log("Stream in initialization/connecting state for", entIndex)
            self._validityCache[entIndex] = true
            continue
        end
        
        -- For playing state, check stream validity
        if streamData.state == self.States.PLAYING then
            if not IsValid(streamData.stream) then
                Debug:Log("Invalid stream in playing state for", entIndex)
                self:QueueCleanup(entIndex, "invalid_stream_playing")
                continue
            end
        end
        
        self._validityCache[entIndex] = true
    end
end

-- Initialize hooks
local function StreamManagerThink()
    local currentTime = CurTime()
    
    -- Initialize timing variables if needed
    StreamManager._lastValidityCheck = StreamManager._lastValidityCheck or currentTime
    StreamManager._lastPositionUpdate = StreamManager._lastPositionUpdate or currentTime
    StreamManager._lastHistoryCleanup = StreamManager._lastHistoryCleanup or currentTime
    
    -- Update validity cache
    if (currentTime - StreamManager._lastValidityCheck) >= StreamManager.Config.VALIDITY_CHECK_INTERVAL then
        StreamManager:UpdateValidityCache()
        StreamManager._lastValidityCheck = currentTime
    end
    
    -- Update stream positions
    if (currentTime - StreamManager._lastPositionUpdate) >= StreamManager.Config.POSITION_UPDATE_INTERVAL then
        StreamManager._lastPositionUpdate = currentTime
        
        for entIndex, streamData in pairs(StreamManager._streams) do
            if StreamManager:IsValid(entIndex) then
                StreamManager:UpdateStreamPosition(entIndex)
            end
        end
    end
    
    -- Cleanup history periodically
    if (currentTime - StreamManager._lastHistoryCleanup) >= StreamManager.RateLimit.HISTORY_CLEANUP_INTERVAL then
        StreamManager:CleanupHistory()
        StreamManager._lastHistoryCleanup = currentTime
    end
end

-- Replace multiple Think hooks with one consolidated hook
hook.Remove("Think", "StreamManagerUpdate")
hook.Add("Think", "StreamManagerThink", StreamManagerThink)

-- Cleanup hooks
hook.Add("EntityRemoved", "StreamManagerCleanup", function(entity)
    if IsValid(entity) then
        StreamManager:CleanupStream(entity:EntIndex())
    end
end)

hook.Add("ShutDown", "StreamManagerShutdown", function()
    for entIndex, _ in pairs(StreamManager._streams) do
        StreamManager:CleanupStream(entIndex)
    end
end)

-- Add state transition tracking
function StreamManager:SetStreamState(entIndex, newState, metadata)
    if not self:ValidateState(newState) then
        Debug:Error("Invalid stream state:", newState)
        return false
    end

    local streamData = self._streams[entIndex]
    if not streamData then return false end
    
    local oldState = streamData.state
    streamData.state = newState
    streamData.stateChangedAt = CurTime()
    streamData.lastMetadata = metadata or {}
    
    -- Record state transition in history
    table.insert(self._streamHistory, {
        entIndex = entIndex,
        fromState = oldState,
        toState = newState,
        timestamp = CurTime(),
        metadata = metadata
    })
    
    -- Use bulk cleanup instead of removing one at a time
    self:CleanupHistory()
    
    -- Update statistics
    if newState == self.States.ERROR then
        self._streamStats.totalErrors = self._streamStats.totalErrors + 1
    end
    
    -- Use the correct Emit method
    self:Emit(self.Events.STATE_CHANGED, entIndex, oldState, newState, metadata)
    
    return true
end

-- Add method to get stream statistics
function StreamManager:GetStats()
    -- Calculate average uptime
    local totalUptime = 0
    local activeStreams = 0
    
    for _, streamData in pairs(self._streams) do
        if streamData.state == self.States.PLAYING then
            totalUptime = totalUptime + (CurTime() - streamData.startTime)
            activeStreams = activeStreams + 1
        end
    end
    
    self._streamStats.averageUptime = activeStreams > 0 
        and (totalUptime / activeStreams) 
        or 0
    
    return self._streamStats
end

-- Add method to get stream history
function StreamManager:GetHistory(entIndex)
    if entIndex then
        -- Return history for specific entity
        local entityHistory = {}
        for _, entry in ipairs(self._streamHistory) do
            if entry.entIndex == entIndex then
                table.insert(entityHistory, entry)
            end
        end
        return entityHistory
    end
    
    -- Return all history
    return self._streamHistory
end

-- Add debug information method
function StreamManager:GetDebugInfo(entIndex)
    if entIndex then
        local streamData = self._streams[entIndex]
        if not streamData then return nil end
        
        return {
            state = streamData.state,
            uptime = CurTime() - streamData.startTime,
            retries = streamData.retryCount,
            lastActivity = CurTime() - streamData.lastActivity,
            metadata = streamData.metadata,
            stateHistory = streamData.stateHistory
        }
    end
    
    -- Return overview of all streams
    local info = {
        activeStreams = table.Count(self._streams),
        stats = self:GetStats(),
        states = {}
    }
    
    for state, _ in pairs(self.States) do
        info.states[state] = 0
    end
    
    for _, streamData in pairs(self._streams) do
        info.states[streamData.state] = (info.states[streamData.state] or 0) + 1
    end
    
    return info
end

-- Add bulk cleanup for stream history
function StreamManager:CleanupHistory()
    if #self._streamHistory > self.RateLimit.BULK_CLEANUP_SIZE then
        local excess = #self._streamHistory - self.RateLimit.BULK_CLEANUP_SIZE
        for i = 1, excess do
            table.remove(self._streamHistory, 1)
        end
    end
end

-- Add initialization function
function StreamManager:Initialize()
    -- Initialize timing variables
    self._lastValidityCheck = CurTime()
    self._lastPositionUpdate = CurTime()
    self._lastHistoryCleanup = CurTime()
    self.RateLimit.lastCreate = CurTime()
    
    -- Initialize storage
    self._streams = {}
    self._validityCache = {}
    self._retryAttempts = {}
    self._streamHistory = {}
    self._eventHandlers = {}
    
    -- Initialize statistics
    self._streamStats = {
        totalStreams = 0,
        totalErrors = 0,
        totalRetries = 0,
        averageUptime = 0
    }
    
    -- Add Think hook
    hook.Remove("Think", "StreamManagerThink")
    hook.Add("Think", "StreamManagerThink", function()
        self:Think()
    end)
    
    -- Add cleanup hooks
    hook.Add("EntityRemoved", "StreamManagerCleanup", function(entity)
        if IsValid(entity) then
            self:CleanupStream(entity:EntIndex())
        end
    end)
    
    hook.Add("ShutDown", "StreamManagerShutdown", function()
        for entIndex, _ in pairs(self._streams) do
            self:CleanupStream(entIndex)
        end
    end)
    
    self.initialized = true
    return self
end

-- Add Think method
function StreamManager:Think()
    if not self.initialized then return end
    
    local currentTime = CurTime()
    
    -- Update validity cache
    if (currentTime - self._lastValidityCheck) >= self.Config.VALIDITY_CHECK_INTERVAL then
        self:UpdateValidityCache()
        self._lastValidityCheck = currentTime
    end
    
    -- Update stream positions
    if (currentTime - self._lastPositionUpdate) >= self.Config.POSITION_UPDATE_INTERVAL then
        self._lastPositionUpdate = currentTime
        
        for entIndex, streamData in pairs(self._streams) do
            if self:IsValid(entIndex) then
                self:UpdateStreamPosition(entIndex)
            end
        end
    end
    
    -- Process cleanup queue
    if (currentTime - self._lastCleanup) >= self.Config.CLEANUP_INTERVAL then
        self:ProcessCleanupQueue()
    end
    
    -- Cleanup history periodically
    if (currentTime - self._lastHistoryCleanup) >= self.RateLimit.HISTORY_CLEANUP_INTERVAL then
        self:CleanupHistory()
        self._lastHistoryCleanup = currentTime
    end
end

-- Initialize the manager before returning
StreamManager:Initialize()

function StreamManager:PrintDebugInfo()
    Debug:Log("=== Radio Stream Debug Info ===")
    Debug:Log("Active Streams:", table.Count(self._streams))
    
    for entIndex, streamData in pairs(self._streams) do
        local entity = streamData.entity
        if IsValid(entity) then
            Debug:Log("\nEntity", entIndex, "(" .. entity:GetClass() .. "):")
            Debug:Log("- Position:", entity:GetPos())
            Debug:Log("- State:", streamData.state)
            Debug:Log("- Stream Valid:", IsValid(streamData.stream))
            Debug:Log("- Uptime:", math.Round(CurTime() - streamData.startTime, 2), "seconds")
            Debug:Log("- Volume:", streamData.data.volume)
            Debug:Log("- Station:", streamData.data.name)
            Debug:Log("- Retries:", streamData.retryCount)
            
            -- Vehicle-specific info
            if entity:IsVehicle() or utils.GetVehicle(entity) then
                local vehicle = utils.GetVehicle(entity) or entity
                Debug:Log("- Vehicle Info:")
                Debug:Log("  - Framework:", vehicle.LVS and "LVS" or 
                                         vehicle.LFS and "LFS" or 
                                         vehicle.IsScar and "SCars" or 
                                         vehicle.isWacAircraft and "WAC" or "Standard")
                Debug:Log("  - Driver:", IsValid(utils.GetVehicleDriver(vehicle)) and "Yes" or "No")
            end
            
            -- Boombox-specific info
            if utils.IsBoombox(entity) then
                Debug:Log("- Boombox Info:")
                Debug:Log("  - Owner:", IsValid(utils.getOwner(entity)) and utils.getOwner(entity):Nick() or "None")
                Debug:Log("  - Is Golden:", entity:GetClass() == "golden_boombox" and "Yes" or "No")
                Debug:Log("  - Is Permanent:", entity:GetNWBool("IsPermanent", false) and "Yes" or "No")
            end
            
            -- Stream stats
            if streamData.stream and IsValid(streamData.stream) then
                Debug:Log("- Stream Stats:")
                Debug:Log("  - 3D Enabled:", streamData.stream:Get3DEnabled())
                Debug:Log("  - Current Volume:", streamData.stream:GetVolume())
                Debug:Log("  - Is Playing:", streamData.stream:IsPlaying())
            end
            
            -- State history (last 5 entries)
            local history = self:GetHistory(entIndex)
            if history and #history > 0 then
                Debug:Log("- Recent State Changes:")
                for i = math.max(1, #history - 4), #history do
                    local entry = history[i]
                    Debug:Log(string.format("  %s -> %s (%.1fs ago)", 
                        entry.fromState or "none",
                        entry.toState,
                        CurTime() - entry.timestamp))
                end
            end
        end
    end
    
    -- Print overall statistics
    local stats = self:GetStats()
    Debug:Log("\nGlobal Statistics:")
    Debug:Log("- Total Streams Created:", stats.totalStreams)
    Debug:Log("- Total Errors:", stats.totalErrors)
    Debug:Log("- Total Retries:", stats.totalRetries)
    Debug:Log("- Average Uptime:", math.Round(stats.averageUptime, 2), "seconds")
    
    -- Print state distribution
    local stateCount = {}
    for _, streamData in pairs(self._streams) do
        stateCount[streamData.state] = (stateCount[streamData.state] or 0) + 1
    end
    
    Debug:Log("\nCurrent States:")
    for state, count in pairs(stateCount) do
        Debug:Log("-", state .. ":", count)
    end
end

concommand.Add("radio_debug_info", function(ply, cmd, args)
    if not StreamManager.initialized then
        print("[Radio] StreamManager not initialized")
        return
    end
    
    StreamManager:PrintDebugInfo()
end)

function StreamManager:GetStreamState(entIndex)
    return self._streams[entIndex] and self._streams[entIndex].state
end

function StreamManager:GetAllStreamStates()
    local states = {}
    for entIndex, streamData in pairs(self._streams) do
        states[entIndex] = {
            state = streamData.state,
            name = streamData.data.name,
            volume = streamData.data.volume,
            isPlaying = streamData.state == self.States.PLAYING
        }
    end
    return states
end

function StreamManager:GetPlayingStations()
    local playing = {}
    for entIndex, streamData in pairs(self._streams) do
        if streamData.state == self.States.PLAYING then
            playing[streamData.entity] = {
                name = streamData.data.name,
                url = streamData.data.url
            }
        end
    end
    return playing
end

function StreamManager:ValidateState(state)
    -- Convert state to lowercase for consistent comparison
    state = string.lower(state)
    
    -- Check if state exists in States table
    for _, validState in pairs(self.States) do
        if state == string.lower(validState) then
            return true
        end
    end
    
    Debug:Error("Invalid stream state:", state)
    return false
end

-- Add this helper function for state transitions
function StreamManager:TransitionState(entIndex, newState, metadata)
    if not self:ValidateState(newState) then
        return false
    end

    local streamData = self._streams[entIndex]
    if not streamData then return false end

    local oldState = streamData.state
    streamData.state = newState
    streamData.stateChangedAt = CurTime()
    streamData.lastMetadata = metadata or {}

    -- Emit state change event
    self:Emit(self.Events.STATE_CHANGED, entIndex, oldState, newState, metadata)
    
    return true
end

return StreamManager 