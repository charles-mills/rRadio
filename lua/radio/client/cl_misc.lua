--[[
    Radio Addon Client-Side Miscellaneous Functionality
    Author: Charles Mills
    Description: This file combines various utility modules including key mappings,
                 themes, error handling, UI performance, and memory management into
                 a single organized file.
    Date: October 26, 2024
]]--

local Misc = {
    KeyNames = {},
    Themes = {},
    ErrorHandler = {},
    UIPerformance = {},
    MemoryManager = {},
}

-- ============================
--        Key Names
-- ============================

Misc.KeyNames = {
    mapping = {
        [KEY_A] = "A", [KEY_B] = "B", [KEY_C] = "C", [KEY_D] = "D",
        [KEY_E] = "E", [KEY_F] = "F", [KEY_G] = "G", [KEY_H] = "H",
        [KEY_I] = "I", [KEY_J] = "J", [KEY_K] = "K", [KEY_L] = "L",
        [KEY_M] = "M", [KEY_N] = "N", [KEY_O] = "O", [KEY_P] = "P",
        [KEY_Q] = "Q", [KEY_R] = "R", [KEY_S] = "S", [KEY_T] = "T",
        [KEY_U] = "U", [KEY_V] = "V", [KEY_W] = "W", [KEY_X] = "X",
        [KEY_Y] = "Y", [KEY_Z] = "Z",
        [KEY_0] = "0", [KEY_1] = "1", [KEY_2] = "2", [KEY_3] = "3",
        [KEY_4] = "4", [KEY_5] = "5", [KEY_6] = "6", [KEY_7] = "7",
        [KEY_8] = "8", [KEY_9] = "9",
        [KEY_PAD_0] = "Numpad 0", [KEY_PAD_1] = "Numpad 1",
        [KEY_PAD_2] = "Numpad 2", [KEY_PAD_3] = "Numpad 3",
        [KEY_PAD_4] = "Numpad 4", [KEY_PAD_5] = "Numpad 5",
        [KEY_PAD_6] = "Numpad 6", [KEY_PAD_7] = "Numpad 7",
        [KEY_PAD_8] = "Numpad 8", [KEY_PAD_9] = "Numpad 9",
        [KEY_PAD_DIVIDE] = "Numpad /", [KEY_PAD_MULTIPLY] = "Numpad *",
        [KEY_PAD_MINUS] = "Numpad -", [KEY_PAD_PLUS] = "Numpad +",
        [KEY_PAD_ENTER] = "Numpad Enter", [KEY_PAD_DECIMAL] = "Numpad .",
        [KEY_LSHIFT] = "Left Shift", [KEY_RSHIFT] = "Right Shift",
        [KEY_LALT] = "Left Alt", [KEY_RALT] = "Right Alt",
        [KEY_LCONTROL] = "Left Ctrl", [KEY_RCONTROL] = "Right Ctrl",
        [KEY_SPACE] = "Space", [KEY_ENTER] = "Enter",
        [KEY_BACKSPACE] = "Backspace", [KEY_TAB] = "Tab",
        [KEY_CAPSLOCK] = "Caps Lock", [KEY_ESCAPE] = "Escape",
        [KEY_INSERT] = "Insert", [KEY_DELETE] = "Delete",
        [KEY_HOME] = "Home", [KEY_END] = "End",
        [KEY_PAGEUP] = "Page Up", [KEY_PAGEDOWN] = "Page Down",
        [KEY_F1] = "F1", [KEY_F2] = "F2", [KEY_F3] = "F3",
        [KEY_F4] = "F4", [KEY_F5] = "F5", [KEY_F6] = "F6",
        [KEY_F7] = "F7", [KEY_F8] = "F8", [KEY_F9] = "F9",
        [KEY_F10] = "F10", [KEY_F11] = "F11", [KEY_F12] = "F12"
    },

    GetKeyName = function(self, keyCode)
        return self.mapping[keyCode] or "the Open Key"
    end
}

-- ============================
--         Themes
-- ============================

Misc.Themes = {
    list = {
        ["dark"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(20, 20, 20),
            HeaderColor = Color(50, 50, 50),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(60, 60, 60),
            ButtonHoverColor = Color(80, 80, 80),
            PlayingButtonColor = Color(30, 30, 30),
            CloseButtonColor = Color(50, 50, 50),
            CloseButtonHoverColor = Color(70, 70, 70),
            ScrollbarColor = Color(60, 60, 60),
            ScrollbarGripColor = Color(100, 100, 100),
            SearchBoxColor = Color(50, 50, 50),
        },
        ["light"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(245, 245, 245),
            HeaderColor = Color(220, 220, 220),
            TextColor = Color(30, 30, 30),
            ButtonColor = Color(230, 230, 230),
            ButtonHoverColor = Color(200, 200, 200),
            PlayingButtonColor = Color(180, 180, 180),
            CloseButtonColor = Color(220, 220, 220),
            CloseButtonHoverColor = Color(200, 200, 200),
            ScrollbarColor = Color(210, 210, 210),
            ScrollbarGripColor = Color(180, 180, 180),
            SearchBoxColor = Color(230, 230, 230),
        },
        ["ocean"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(20, 60, 100),
            HeaderColor = Color(15, 45, 75),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(25, 75, 125),
            ButtonHoverColor = Color(30, 90, 150),
            PlayingButtonColor = Color(10, 50, 90),
            CloseButtonColor = Color(15, 45, 75),
            CloseButtonHoverColor = Color(30, 90, 150),
            ScrollbarColor = Color(20, 60, 100),
            ScrollbarGripColor = Color(30, 90, 150),
            SearchBoxColor = Color(15, 45, 75),
        },
        ["forest"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(34, 60, 34),
            HeaderColor = Color(40, 85, 40),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(45, 100, 45),
            ButtonHoverColor = Color(50, 110, 50),
            PlayingButtonColor = Color(30, 70, 30),
            CloseButtonColor = Color(40, 85, 40),
            CloseButtonHoverColor = Color(50, 110, 50),
            ScrollbarColor = Color(45, 100, 45),
            ScrollbarGripColor = Color(60, 120, 60),
            SearchBoxColor = Color(40, 85, 40),
        },
        ["solarized"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(0, 43, 54),
            HeaderColor = Color(7, 54, 66),
            TextColor = Color(131, 148, 150),
            ButtonColor = Color(88, 110, 117),
            ButtonHoverColor = Color(101, 123, 131),
            PlayingButtonColor = Color(42, 161, 152),
            CloseButtonColor = Color(7, 54, 66),
            CloseButtonHoverColor = Color(108, 113, 196),
            ScrollbarColor = Color(88, 110, 117),
            ScrollbarGripColor = Color(133, 153, 0),
            SearchBoxColor = Color(7, 54, 66),
        },
        ["midnight"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(10, 10, 35),
            HeaderColor = Color(20, 20, 50),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(30, 30, 60),
            ButtonHoverColor = Color(50, 50, 100),
            PlayingButtonColor = Color(15, 15, 45),
            CloseButtonColor = Color(20, 20, 50),
            CloseButtonHoverColor = Color(50, 50, 100),
            ScrollbarColor = Color(30, 30, 60),
            ScrollbarGripColor = Color(50, 50, 100),
            SearchBoxColor = Color(20, 20, 50),
        },
        ["coral"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(255, 127, 80),
            HeaderColor = Color(255, 99, 71),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(255, 160, 122),
            ButtonHoverColor = Color(255, 140, 105),
            PlayingButtonColor = Color(205, 92, 92),
            CloseButtonColor = Color(255, 99, 71),
            CloseButtonHoverColor = Color(205, 92, 92),
            ScrollbarColor = Color(255, 160, 122),
            ScrollbarGripColor = Color(255, 140, 105),
            SearchBoxColor = Color(255, 99, 71),
        },
        ["main"] = {
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(15, 15, 15),
            HeaderColor = Color(25, 25, 25),
            TextColor = Color(228, 161, 15),
            ButtonColor = Color(35, 35, 35),
            ButtonHoverColor = Color(22, 22, 22),
            PlayingButtonColor = Color(8, 8, 8),
            CloseButtonColor = Color(25, 25, 25),
            CloseButtonHoverColor = Color(39, 39, 39),
            ScrollbarColor = Color(35, 35, 35),
            ScrollbarGripColor = Color(228, 161, 15),
            SearchBoxColor = Color(25, 25, 25),
            AccentColor = Color(228, 161, 15),
        }
    },

    GetTheme = function(self, name)
        return self.list[name] or self.list["main"]
    end,

    GetAllThemes = function(self)
        local themes = {}
        for name, _ in pairs(self.list) do
            table.insert(themes, name)
        end
        return themes
    end
}

-- ============================
--      Error Handler
-- ============================

Misc.ErrorHandler = {
    MAX_RETRIES = 3,
    RETRY_DELAY = 2,
    CONNECTION_TIMEOUT = 10,
    retryAttempts = {},
    timeoutTimers = {},
    
    ErrorTypes = {
        TIMEOUT = "timeout",
        CONNECTION_FAILED = "connection_failed",
        INVALID_URL = "invalid_url",
        STREAM_ERROR = "stream_error",
        UNKNOWN = "unknown"
    },
    
    ErrorMessages = {
        [1] = "Failed to connect to radio station",
        [2] = "Invalid radio station URL",
        [3] = "Stream not found or unavailable",
        [4] = "Connection timed out",
        [5] = "Network error",
        timeout = "Connection timed out",
        connection_failed = "Failed to connect to station",
        invalid_url = "Invalid station URL",
        stream_error = "Stream error occurred",
        unknown = "Unknown error occurred"
    },

    InitEntity = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        self.retryAttempts[entIndex] = self.retryAttempts[entIndex] or {
            count = 0,
            lastAttempt = 0,
            currentUrl = "",
            currentStation = ""
        }
    end,

    ClearEntity = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        self.retryAttempts[entIndex] = nil
        if self.timeoutTimers[entIndex] then
            timer.Remove("RadioTimeout_" .. entIndex)
            self.timeoutTimers[entIndex] = nil
        end
    end,

    HandleError = function(self, entity, errorType, errorID, errorName, retryCallback)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        self:InitEntity(entity)
        local attempts = self.retryAttempts[entIndex]
        
        if entity:GetClass() == "boombox" then
            entity:SetNWString("Status", "error")
            BoomboxStatuses[entIndex] = {
                stationStatus = "error",
                stationName = attempts.currentStation,
                errorMessage = self.ErrorMessages[errorType] or self.ErrorMessages.unknown
            }
        end
        
        local errorMsg = self.ErrorMessages[errorType] or self.ErrorMessages[errorID] or self.ErrorMessages.unknown
        chat.AddText(
            Color(255, 50, 50), "[Radio Error] ",
            Color(255, 255, 255), errorMsg,
            Color(200, 200, 200), " (Station: " .. attempts.currentStation .. ")"
        )
        
        if attempts.count < self.MAX_RETRIES then
            attempts.count = attempts.count + 1
            attempts.lastAttempt = CurTime()
            
            chat.AddText(
                Color(255, 165, 0), "[Radio] ",
                Color(255, 255, 255), string.format("Retrying connection... (Attempt %d/%d)", 
                attempts.count, self.MAX_RETRIES)
            )
            
            timer.Simple(self.RETRY_DELAY, function()
                if IsValid(entity) then
                    retryCallback()
                end
            end)
        else
            chat.AddText(
                Color(255, 50, 50), "[Radio] ",
                Color(255, 255, 255), "Failed to connect after multiple attempts. Please try again later."
            )
            self:ClearEntity(entity)
        end
    end,

    StartTimeout = function(self, entity, timeoutCallback)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        if self.timeoutTimers[entIndex] then
            timer.Remove("RadioTimeout_" .. entIndex)
        end
        
        self.timeoutTimers[entIndex] = true
        timer.Create("RadioTimeout_" .. entIndex, self.CONNECTION_TIMEOUT, 1, function()
            if IsValid(entity) then
                self:HandleError(entity, self.ErrorTypes.TIMEOUT, nil, nil, timeoutCallback)
            end
        end)
    end,

    StopTimeout = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        if self.timeoutTimers[entIndex] then
            timer.Remove("RadioTimeout_" .. entIndex)
            self.timeoutTimers[entIndex] = nil
        end
    end,

    TrackAttempt = function(self, entity, stationName, url)
        if not IsValid(entity) then return end
        self:InitEntity(entity)
        
        local entIndex = entity:EntIndex()
        self.retryAttempts[entIndex].currentStation = stationName
        self.retryAttempts[entIndex].currentUrl = url
    end
}

-- ============================
--     UI Performance
-- ============================

Misc.UIPerformance = {
    cachedScales = {},
    cachedFonts = {},
    cachedMaterials = {},
    lastFrameTime = 0,
    frameUpdateThreshold = 0.016,
    panelUpdateQueue = {},
    deferredUpdates = {},
    stats = {
        totalRedraws = 0,
        skippedRedraws = 0,
        cachedDraws = 0
    },

    GetScale = function(self, value)
        if not self.cachedScales[value] then
            self.cachedScales[value] = value * (ScrW() / 2560)
        end
        return self.cachedScales[value]
    end,

    GetMaterial = function(self, path)
        if not self.cachedMaterials[path] then
            self.cachedMaterials[path] = Material(path, "smooth")
        end
        return self.cachedMaterials[path]
    end,

    QueuePanelUpdate = function(self, panel, updateFn)
        if not IsValid(panel) then return end
        
        local currentTime = RealTime()
        if not self.panelUpdateQueue[panel] then
            self.panelUpdateQueue[panel] = {
                lastUpdate = 0,
                fn = updateFn
            }
        end
        
        if currentTime - self.panelUpdateQueue[panel].lastUpdate >= self.frameUpdateThreshold then
            updateFn()
            self.panelUpdateQueue[panel].lastUpdate = currentTime
        else
            self.deferredUpdates[panel] = updateFn
        end
    end,

    ProcessDeferredUpdates = function(self)
        local currentTime = RealTime()
        
        for panel, updateFn in pairs(self.deferredUpdates) do
            if IsValid(panel) and self.panelUpdateQueue[panel] and 
               currentTime - self.panelUpdateQueue[panel].lastUpdate >= self.frameUpdateThreshold then
                updateFn()
                self.panelUpdateQueue[panel].lastUpdate = currentTime
                self.deferredUpdates[panel] = nil
            end
        end
    end,

    RemovePanel = function(self, panel)
        self.panelUpdateQueue[panel] = nil
        self.deferredUpdates[panel] = nil
    end,

    OptimizePaintFunction = function(self, panel, paintFn)
        local lastPaint = 0
        local cachedResult = nil
        
        return function(self, w, h)
            local currentTime = RealTime()
            
            if not lastPaint or not cachedResult or 
               (currentTime - lastPaint) >= Misc.UIPerformance.frameUpdateThreshold then
                cachedResult = paintFn(self, w, h)
                lastPaint = currentTime
                Misc.UIPerformance.stats.totalRedraws = Misc.UIPerformance.stats.totalRedraws + 1
            else
                Misc.UIPerformance.stats.skippedRedraws = Misc.UIPerformance.stats.skippedRedraws + 1
            end
            
            return cachedResult
        end
    end
}

-- ============================
--    Memory Manager
-- ============================

Misc.MemoryManager = {
    CLEANUP_INTERVAL = 30,
    RESOURCE_TIMEOUT = 300,
    EMERGENCY_CLEANUP_THRESHOLD = 50,
    MIN_CLEANUP_INTERVAL = 5,
    
    activeTimers = {},
    activeHooks = {},
    soundObjects = {},
    lastCleanupTime = 0,
    emergencyCleanupTime = 0,
    
    memoryStats = {
        peakSoundObjects = 0,
        totalCleanups = 0,
        emergencyCleanups = 0,
        orphanedTimersRemoved = 0,
        orphanedHooksRemoved = 0,
        invalidSoundsRemoved = 0,
        lastMemoryUsage = 0
    },
    
    debugMode = CreateConVar("radio_memory_debug", "0", FCVAR_ARCHIVE, "Enable memory manager debug output"),
    emergencyMode = false,

    DebugLog = function(self, ...)
        if self.debugMode:GetBool() then
            print("[Radio Memory Manager]", ...)
        end
    end,

    CheckEmergencyCleanup = function(self)
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
    end,

    TrackSound = function(self, entity, soundObj)
        if not IsValid(entity) or not IsValid(soundObj) then return end
        local entIndex = entity:EntIndex()
        
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
        
        self.memoryStats.peakSoundObjects = math.max(
            self.memoryStats.peakSoundObjects, 
            table.Count(self.soundObjects)
        )
        self:CheckEmergencyCleanup()
    end,

    TrackTimer = function(self, name, entity)
        if self.activeTimers[name] then
            timer.Remove(name)
            self:DebugLog("Removed existing timer:", name)
        end
        
        self.activeTimers[name] = {
            entity = entity,
            createdAt = CurTime(),
            name = name
        }
    end,

    TrackHook = function(self, event, name, entity)
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
    end,

    CleanupEntity = function(self, entity, emergency)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        
        if self.soundObjects[entIndex] then
            pcall(function()
                if IsValid(self.soundObjects[entIndex].sound) then
                    self.soundObjects[entIndex].sound:Stop()
                end
            end)
            self.soundObjects[entIndex] = nil
            self.memoryStats.invalidSoundsRemoved = self.memoryStats.invalidSoundsRemoved + 1
        end
        
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
    end,

    PerformCleanup = function(self, emergency)
        local currentTime = CurTime()
        if not emergency and currentTime - self.lastCleanupTime < self.CLEANUP_INTERVAL then 
            return 
        end
        
        self.lastCleanupTime = currentTime
        local initialMemory = collectgarbage("count")
        local cleanupCount = 0
        
        for entIndex, data in pairs(self.soundObjects) do
            if not IsValid(data.entity) or not IsValid(data.sound) or
               (currentTime - data.lastUsed > self.RESOURCE_TIMEOUT) or
               (emergency and currentTime - data.lastUsed > self.MIN_CLEANUP_INTERVAL) then
                self:CleanupEntity(data.entity, emergency)
                cleanupCount = cleanupCount + 1
            end
        end
        
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
        
        if emergency or cleanupCount > 10 then
            collectgarbage("collect")
        end
        
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
    end,

    GetStats = function(self)
        return {
            activeSounds = table.Count(self.soundObjects),
            activeTimers = table.Count(self.activeTimers),
            activeHooks = table.Count(self.activeHooks),
            memoryUsage = collectgarbage("count"),
            stats = table.Copy(self.memoryStats),
            emergencyMode = self.emergencyMode
        }
    end
}

-- Add hooks for Memory Manager
hook.Add("Think", "RadioMemoryManagerCleanup", function()
    Misc.MemoryManager:PerformCleanup(false)
end)

hook.Add("ShutDown", "RadioMemoryManagerShutdown", function()
    Misc.MemoryManager:PerformCleanup(true)
end)

-- Add hooks for UI Performance
hook.Add("Think", "ProcessDeferredUIUpdates", function()
    Misc.UIPerformance:ProcessDeferredUpdates()
end)

return Misc
