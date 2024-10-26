local MemoryManager = {
    -- Configuration
    CLEANUP_INTERVAL = 30, -- Run cleanup every 30 seconds
    RESOURCE_TIMEOUT = 300, -- Consider resources older than 5 minutes as potentially orphaned
    EMERGENCY_CLEANUP_THRESHOLD = 50, -- Maximum number of sound objects before emergency cleanup
    MIN_CLEANUP_INTERVAL = 5, -- Minimum time between cleanups
    
    -- Tracking tables
    activeTimers = {},
    activeHooks = {},
    soundObjects = {},
    lastCleanupTime = 0,
    emergencyCleanupTime = 0,
    
    -- Statistics
    memoryStats = {
        peakSoundObjects = 0,
        totalCleanups = 0,
        emergencyCleanups = 0,
        orphanedTimersRemoved = 0,
        orphanedHooksRemoved = 0,
        invalidSoundsRemoved = 0,
        lastMemoryUsage = 0
    },
    
    -- Debug flags
    debugMode = CreateConVar("radio_memory_debug", "0", FCVAR_ARCHIVE, "Enable memory manager debug output"),
    emergencyMode = false
}

-- Debug logging function
function MemoryManager:DebugLog(...)
    if self.debugMode:GetBool() then
        print("[Radio Memory Manager]", ...)
    end
end

-- Check if emergency cleanup is needed
function MemoryManager:CheckEmergencyCleanup()
    local currentCount = table.Count(self.soundObjects)
    if currentCount > self.EMERGENCY_CLEANUP_THRESHOLD then
        local currentTime = CurTime()
        if currentTime - self.emergencyCleanupTime >= self.MIN_CLEANUP_INTERVAL then
            self.emergencyMode = true
            self:DebugLog("Emergency cleanup triggered! Active sounds:", currentCount)
            self:PerformCleanup(true)
            self.emergencyCleanupTime = currentTime
            self.memoryStats.emergencyCleanups = self.memoryStats.emergencyCleanups + 1
        end
    end
end

-- Enhanced sound tracking
function MemoryManager:TrackSound(entity, soundObj)
    if not IsValid(entity) or not IsValid(soundObj) then return end
    local entIndex = entity:EntIndex()
    
    -- Clean up existing sound if present
    if self.soundObjects[entIndex] and IsValid(self.soundObjects[entIndex].sound) then
        self.soundObjects[entIndex].sound:Stop()
        self:DebugLog("Cleaned up existing sound for entity", entIndex)
    end
    
    self.soundObjects[entIndex] = {
        entity = entity,
        sound = soundObj,
        createdAt = CurTime(),
        lastUsed = CurTime(),
        memoryUsage = collectgarbage("count")
    }
    
    -- Update statistics
    self.memoryStats.peakSoundObjects = math.max(self.memoryStats.peakSoundObjects, table.Count(self.soundObjects))
    self:CheckEmergencyCleanup()
end

-- Enhanced timer tracking
function MemoryManager:TrackTimer(name, entity)
    if self.activeTimers[name] then
        timer.Remove(name)
        self:DebugLog("Removed existing timer:", name)
    end
    
    self.activeTimers[name] = {
        entity = entity,
        createdAt = CurTime(),
        name = name
    }
end

-- Enhanced hook tracking
function MemoryManager:TrackHook(event, name, entity)
    local hookId = event .. "_" .. name
    if self.activeHooks[hookId] then
        hook.Remove(event, name)
        self:DebugLog("Removed existing hook:", hookId)
    end
    
    self.activeHooks[hookId] = {
        entity = entity,
        createdAt = CurTime(),
        event = event,
        name = name
    }
end

-- Enhanced cleanup function
function MemoryManager:CleanupEntity(entity, emergency)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Clean up sound with error handling
    if self.soundObjects[entIndex] then
        pcall(function()
            if IsValid(self.soundObjects[entIndex].sound) then
                self.soundObjects[entIndex].sound:Stop()
            end
        end)
        self.soundObjects[entIndex] = nil
        self.memoryStats.invalidSoundsRemoved = self.memoryStats.invalidSoundsRemoved + 1
    end
    
    -- Clean up timers with verification
    for name, data in pairs(self.activeTimers) do
        if data.entity == entity then
            if timer.Exists(name) then
                timer.Remove(name)
                self:DebugLog("Removed timer:", name)
            end
            self.activeTimers[name] = nil
            self.memoryStats.orphanedTimersRemoved = self.memoryStats.orphanedTimersRemoved + 1
        end
    end
    
    -- Clean up hooks with verification
    for hookId, data in pairs(self.activeHooks) do
        if data.entity == entity then
            pcall(function()
                hook.Remove(data.event, data.name)
                self:DebugLog("Removed hook:", hookId)
            end)
            self.activeHooks[hookId] = nil
            self.memoryStats.orphanedHooksRemoved = self.memoryStats.orphanedHooksRemoved + 1
        end
    end
    
    if emergency then
        collectgarbage("collect")
    end
end

-- Enhanced periodic cleanup
function MemoryManager:PerformCleanup(emergency)
    local currentTime = CurTime()
    if not emergency and currentTime - self.lastCleanupTime < self.CLEANUP_INTERVAL then return end
    
    self.lastCleanupTime = currentTime
    local initialMemory = collectgarbage("count")
    local cleanupCount = 0
    
    -- Clean up invalid sound objects
    for entIndex, data in pairs(self.soundObjects) do
        if not IsValid(data.entity) or not IsValid(data.sound) or
           (currentTime - data.lastUsed > self.RESOURCE_TIMEOUT) or
           (emergency and currentTime - data.lastUsed > self.MIN_CLEANUP_INTERVAL) then
            self:CleanupEntity(data.entity, emergency)
            cleanupCount = cleanupCount + 1
        end
    end
    
    -- Verify and clean up timers
    for name, data in pairs(self.activeTimers) do
        if not IsValid(data.entity) or 
           (currentTime - data.createdAt > self.RESOURCE_TIMEOUT) or
           (emergency and currentTime - data.createdAt > self.MIN_CLEANUP_INTERVAL) then
            if timer.Exists(name) then
                timer.Remove(name)
            end
            self.activeTimers[name] = nil
            self.memoryStats.orphanedTimersRemoved = self.memoryStats.orphanedTimersRemoved + 1
            cleanupCount = cleanupCount + 1
        end
    end
    
    -- Force garbage collection if needed
    if emergency or cleanupCount > 10 then
        collectgarbage("collect")
    end
    
    -- Update statistics
    self.memoryStats.totalCleanups = self.memoryStats.totalCleanups + 1
    self.memoryStats.lastMemoryUsage = collectgarbage("count") - initialMemory
    
    if self.debugMode:GetBool() then
        self:DebugLog(string.format(
            "Cleanup completed: Removed %d objects, Memory delta: %.2f KB, Emergency: %s",
            cleanupCount,
            self.memoryStats.lastMemoryUsage,
            emergency and "Yes" or "No"
        ))
    end
    
    self.emergencyMode = false
end

-- Enhanced stats function
function MemoryManager:GetStats()
    return {
        activeSounds = table.Count(self.soundObjects),
        activeTimers = table.Count(self.activeTimers),
        activeHooks = table.Count(self.activeHooks),
        memoryUsage = collectgarbage("count"),
        stats = table.Copy(self.memoryStats),
        emergencyMode = self.emergencyMode
    }
end

-- Add cleanup hooks
hook.Add("Think", "RadioMemoryManagerCleanup", function()
    MemoryManager:PerformCleanup(false)
end)

hook.Add("ShutDown", "RadioMemoryManagerShutdown", function()
    MemoryManager:PerformCleanup(true)
end)

return MemoryManager
