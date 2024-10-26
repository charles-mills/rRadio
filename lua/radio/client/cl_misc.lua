-- This file is the product of several (now merged) files to reduce file count
-- KeyNames, Themes, ErrorHandler, UiPerformance, MemoryManager, Settings

local languageManager = include("radio/client/lang/cl_language_manager.lua")

local misc = {
    KeyNames = {},
    Themes = {},
    ErrorHandler = {},
    UIPerformance = {},
    MemoryManager = {},
    Settings = {}
}

-- KeyNames mapping for various keys
misc.KeyNames = {
    mapping = {
        [KEY_A] = "A",
        [KEY_B] = "B",
        [KEY_C] = "C",
        [KEY_D] = "D",
        [KEY_E] = "E",
        [KEY_F] = "F",
        [KEY_G] = "G",
        [KEY_H] = "H",
        [KEY_I] = "I",
        [KEY_J] = "J",
        [KEY_K] = "K",
        [KEY_L] = "L",
        [KEY_M] = "M",
        [KEY_N] = "N",
        [KEY_O] = "O",
        [KEY_P] = "P",
        [KEY_Q] = "Q",
        [KEY_R] = "R",
        [KEY_S] = "S",
        [KEY_T] = "T",
        [KEY_U] = "U",
        [KEY_V] = "V",
        [KEY_W] = "W",
        [KEY_X] = "X",
        [KEY_Y] = "Y",
        [KEY_Z] = "Z",
        [KEY_0] = "0",
        [KEY_1] = "1",
        [KEY_2] = "2",
        [KEY_3] = "3",
        [KEY_4] = "4",
        [KEY_5] = "5",
        [KEY_6] = "6",
        [KEY_7] = "7",
        [KEY_8] = "8",
        [KEY_9] = "9",
        [KEY_PAD_0] = "Numpad 0",
        [KEY_PAD_1] = "Numpad 1",
        [KEY_PAD_2] = "Numpad 2",
        [KEY_PAD_3] = "Numpad 3",
        [KEY_PAD_4] = "Numpad 4",
        [KEY_PAD_5] = "Numpad 5",
        [KEY_PAD_6] = "Numpad 6",
        [KEY_PAD_7] = "Numpad 7",
        [KEY_PAD_8] = "Numpad 8",
        [KEY_PAD_9] = "Numpad 9",
        [KEY_PAD_DIVIDE] = "Numpad /",
        [KEY_PAD_MULTIPLY] = "Numpad *",
        [KEY_PAD_MINUS] = "Numpad -",
        [KEY_PAD_PLUS] = "Numpad +",
        [KEY_PAD_ENTER] = "Numpad Enter",
        [KEY_PAD_DECIMAL] = "Numpad .",
        [KEY_LSHIFT] = "Left Shift",
        [KEY_RSHIFT] = "Right Shift",
        [KEY_LALT] = "Left Alt",
        [KEY_RALT] = "Right Alt",
        [KEY_LCONTROL] = "Left Ctrl",
        [KEY_RCONTROL] = "Right Ctrl",
        [KEY_SPACE] = "Space",
        [KEY_ENTER] = "Enter",
        [KEY_BACKSPACE] = "Backspace",
        [KEY_TAB] = "Tab",
        [KEY_CAPSLOCK] = "Caps Lock",
        [KEY_ESCAPE] = "Escape",
        [KEY_INSERT] = "Insert",
        [KEY_DELETE] = "Delete",
        [KEY_HOME] = "Home",
        [KEY_END] = "End",
        [KEY_PAGEUP] = "Page Up",
        [KEY_PAGEDOWN] = "Page Down",
        [KEY_F1] = "F1",
        [KEY_F2] = "F2",
        [KEY_F3] = "F3",
        [KEY_F4] = "F4",
        [KEY_F5] = "F5",
        [KEY_F6] = "F6",
        [KEY_F7] = "F7",
        [KEY_F8] = "F8",
        [KEY_F9] = "F9",
        [KEY_F10] = "F10",
        [KEY_F11] = "F11",
        [KEY_F12] = "F12"
    },

    -- Retrieves the name of the key based on its code
    GetKeyName = function(self, keyCode)
        return self.mapping[keyCode] or "the Open Key"
    end
}

-- Themes configuration
misc.Themes = {
    list = {
        dark = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(50, 50, 50)
        },
        light = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(230, 230, 230)
        },
        ocean = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(15, 45, 75)
        },
        forest = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(40, 85, 40)
        },
        solarized = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(7, 54, 66)
        },
        midnight = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            SearchBoxColor = Color(20, 20, 50)
        },
        coral = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            AccentColor = Color(228, 161, 15)
        },
        main = {
            FrameSize = {
                width = 600,
                height = 800
            },
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
            AccentColor = Color(228, 161, 15)
        }
    },

    -- Retrieves a theme by name, defaults to 'main' if not found
    GetTheme = function(self, name)
        return self.list[name] or self.list["main"]
    end,

    -- Retrieves a list of all available themes
    GetAllThemes = function(self)
        local themes = {}
        for name, _ in pairs(self.list) do
            table.insert(themes, name)
        end
        return themes
    end
}

-- ErrorHandler for managing radio-related errors
misc.ErrorHandler = {
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

    -- Initializes tracking for an entity
    InitEntity = function(self, entity)
        if not IsValid(entity) then
            return
        end
        local entIndex = entity:EntIndex()
        self.retryAttempts[entIndex] = self.retryAttempts[entIndex] or {
            count = 0,
            lastAttempt = 0,
            currentUrl = "",
            currentStation = ""
        }
    end,

    -- Clears tracking data for an entity
    ClearEntity = function(self, entity)
        if not IsValid(entity) then
            return
        end
        local entIndex = entity:EntIndex()
        self.retryAttempts[entIndex] = nil
        if self.timeoutTimers[entIndex] then
            timer.Remove("RadioTimeout_" .. entIndex)
            self.timeoutTimers[entIndex] = nil
        end
    end,

    -- Handles errors and manages retries
    HandleError = function(self, entity, errorType, errorID, errorName, retryCallback)
        if not IsValid(entity) then
            return
        end
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
        chat.AddText(Color(255, 50, 50), "[Radio Error] ", Color(255, 255, 255), errorMsg, Color(200, 200, 200), " (Station: " .. attempts.currentStation .. ")")

        if attempts.count < self.MAX_RETRIES then
            attempts.count = attempts.count + 1
            attempts.lastAttempt = CurTime()
            chat.AddText(Color(255, 165, 0), "[Radio] ", Color(255, 255, 255), string.format("Retrying connection... (Attempt %d/%d)", attempts.count, self.MAX_RETRIES))
            timer.Simple(self.RETRY_DELAY, function()
                if IsValid(entity) then
                    retryCallback()
                end
            end)
        else
            chat.AddText(Color(255, 50, 50), "[Radio] ", Color(255, 255, 255), "Failed to connect after multiple attempts. Please try again later.")
            self:ClearEntity(entity)
        end
    end,

    -- Starts a timeout timer for an entity
    StartTimeout = function(self, entity, timeoutCallback)
        if not IsValid(entity) then
            return
        end
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

    -- Stops the timeout timer for an entity
    StopTimeout = function(self, entity)
        if not IsValid(entity) then
            return
        end
        local entIndex = entity:EntIndex()
        if self.timeoutTimers[entIndex] then
            timer.Remove("RadioTimeout_" .. entIndex)
            self.timeoutTimers[entIndex] = nil
        end
    end,

    -- Tracks a connection attempt for an entity
    TrackAttempt = function(self, entity, stationName, url)
        if not IsValid(entity) then
            return
        end
        self:InitEntity(entity)
        local entIndex = entity:EntIndex()
        self.retryAttempts[entIndex].currentStation = stationName
        self.retryAttempts[entIndex].currentUrl = url
    end
}

-- UIPerformance handles UI scaling and optimization
misc.UIPerformance = {
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

    -- Retrieves scaled value based on screen resolution
    GetScale = function(self, value)
        if not self.cachedScales[value] then
            self.cachedScales[value] = value * (ScrW() / 2560)
        end
        return self.cachedScales[value]
    end,

    -- Retrieves or caches a material
    GetMaterial = function(self, path)
        if not self.cachedMaterials[path] then
            self.cachedMaterials[path] = Material(path, "smooth")
        end
        return self.cachedMaterials[path]
    end,

    -- Queues a panel update with throttling
    QueuePanelUpdate = function(self, panel, updateFn)
        if not IsValid(panel) then
            return
        end
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

    -- Processes deferred panel updates
    ProcessDeferredUpdates = function(self)
        local currentTime = RealTime()
        for panel, updateFn in pairs(self.deferredUpdates) do
            if IsValid(panel) and self.panelUpdateQueue[panel] and currentTime - self.panelUpdateQueue[panel].lastUpdate >= self.frameUpdateThreshold then
                updateFn()
                self.panelUpdateQueue[panel].lastUpdate = currentTime
                self.deferredUpdates[panel] = nil
            end
        end
    end,

    -- Removes a panel from the update queue
    RemovePanel = function(self, panel)
        self.panelUpdateQueue[panel] = nil
        self.deferredUpdates[panel] = nil
    end,

    -- Optimizes the paint function of a panel to reduce redraws
    OptimizePaintFunction = function(self, panel, paintFn)
        local lastPaint = 0
        local cachedResult = nil
        return function(self, w, h)
            local currentTime = RealTime()
            if not lastPaint or not cachedResult or (currentTime - lastPaint) >= misc.UIPerformance.frameUpdateThreshold then
                cachedResult = paintFn(self, w, h)
                lastPaint = currentTime
                misc.UIPerformance.stats.totalRedraws = misc.UIPerformance.stats.totalRedraws + 1
            else
                misc.UIPerformance.stats.skippedRedraws = misc.UIPerformance.stats.skippedRedraws + 1
            end
            return cachedResult
        end
    end
}

-- MemoryManager handles resource cleanup and memory optimization
misc.MemoryManager = {
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

    -- Logs debug messages if debug mode is enabled
    DebugLog = function(self, ...)
        if self.debugMode:GetBool() then
            print("[Radio Memory Manager]", ...)
        end
    end,

    -- Checks if emergency cleanup is required based on sound object count
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

    -- Tracks a new sound object associated with an entity
    TrackSound = function(self, entity, soundObj)
        if not IsValid(entity) or not IsValid(soundObj) then
            return
        end
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

        self.memoryStats.peakSoundObjects = math.max(self.memoryStats.peakSoundObjects, table.Count(self.soundObjects))
        self:CheckEmergencyCleanup()
    end,

    -- Tracks a timer associated with an entity
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

    -- Tracks a hook associated with an entity
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

    -- Cleans up resources associated with an entity
    CleanupEntity = function(self, entity, emergency)
        if not IsValid(entity) then
            return
        end
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

    -- Performs cleanup of resources, optionally in emergency mode
    PerformCleanup = function(self, emergency)
        local currentTime = CurTime()
        if not emergency and currentTime - self.lastCleanupTime < self.CLEANUP_INTERVAL then
            return
        end
        self.lastCleanupTime = currentTime
        local initialMemory = collectgarbage("count")
        local cleanupCount = 0

        for entIndex, data in pairs(self.soundObjects) do
            if not IsValid(data.entity) or not IsValid(data.sound) or (currentTime - data.lastUsed > self.RESOURCE_TIMEOUT) or (emergency and currentTime - data.lastUsed > self.MIN_CLEANUP_INTERVAL) then
                self:CleanupEntity(data.entity, emergency)
                cleanupCount = cleanupCount + 1
            end
        end

        for name, data in pairs(self.activeTimers) do
            if not IsValid(data.entity) or (currentTime - data.createdAt > self.RESOURCE_TIMEOUT) or (emergency and currentTime - data.createdAt > self.MIN_CLEANUP_INTERVAL) then
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
            self:DebugLog(string.format("Cleanup completed: Removed %d objects, Memory delta: %.2f KB, Emergency: %s", cleanupCount, self.memoryStats.lastMemoryUsage, emergency and "Yes" or "No"))
        end
        self.emergencyMode = false
    end,

    -- Retrieves current memory statistics
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

-- Settings management for the radio UI
misc.Settings = {
    ConVars = {
        ShowMessages = CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages."),
        Language = CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI."),
        ShowBoomboxText = CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox."),
        OpenKey = CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
    },

    -- Applies the selected theme
    ApplyTheme = function(self, themeName)
        if misc.Themes.list[themeName] then
            Config.UI = misc.Themes:GetTheme(themeName)
            hook.Run("ThemeChanged", themeName)
        else
            print("Invalid theme name: " .. themeName)
        end
    end,

    -- Applies the selected language
    ApplyLanguage = function(self, languageCode)
        print("Applying language: " .. languageCode)
        if languageManager.languages[languageCode] then
            Config.Lang = languageManager.translations[languageCode]
            print("Language translations loaded")
            hook.Run("LanguageChanged", languageCode)
            hook.Run("LanguageUpdated")
            self:UpdateCountryList()
        else
            print("Invalid language code: " .. languageCode)
        end
    end,

    -- Updates the country list based on the current language
    UpdateCountryList = function(self)
        if radioMenuOpen and IsValid(currentFrame) then
            local stationListPanel = currentFrame:GetChildren()[3]
            if IsValid(stationListPanel) and stationListPanel:GetName() == "DScrollPanel" then
                populateList(stationListPanel, nil, currentFrame:GetChildren()[2], true)
            end
        end
    end,

    -- Loads saved theme and language settings
    LoadSavedSettings = function(self)
        local themeName = GetConVar("radio_theme"):GetString()
        self:ApplyTheme(themeName)
        local languageCode = GetConVar("radio_language"):GetString()
        self:ApplyLanguage(languageCode)
    end,

    -- Sorts keys into single letters, numbers, and others
    SortKeys = function(self)
        local sortedKeys = {}
        local singleLetterKeys = {}
        local numericKeys = {}
        local otherKeys = {}

        for keyCode, keyName in pairs(misc.KeyNames.mapping) do
            if #keyName == 1 and keyName:match("%a") then
                table.insert(singleLetterKeys, {
                    name = keyName,
                    code = keyCode
                })
            elseif keyName:match("^%d$") then
                table.insert(numericKeys, {
                    name = keyName,
                    code = keyCode
                })
            else
                table.insert(otherKeys, {
                    name = keyName,
                    code = keyCode
                })
            end
        end

        table.sort(singleLetterKeys, function(a, b) return a.name < b.name end)
        table.sort(numericKeys, function(a, b) return tonumber(a.name) < tonumber(b.name) end)
        table.sort(otherKeys, function(a, b) return a.name < b.name end)

        for _, key in ipairs(singleLetterKeys) do
            table.insert(sortedKeys, key)
        end

        for _, key in ipairs(numericKeys) do
            table.insert(sortedKeys, key)
        end

        for _, key in ipairs(otherKeys) do
            table.insert(sortedKeys, key)
        end

        return sortedKeys
    end,

    -- Creates the settings menu UI
    CreateSettingsMenu = function(self, panel)
        panel:ClearControls()
        panel:DockPadding(10, 0, 30, 10)

        -- Theme Selection Section
        local themeHeader = vgui.Create("DLabel", panel)
        themeHeader:SetText("Theme Selection")
        themeHeader:SetFont("Trebuchet18")
        themeHeader:SetTextColor(Color(50, 50, 50))
        themeHeader:Dock(TOP)
        themeHeader:DockMargin(0, 0, 0, 5)
        panel:AddItem(themeHeader)

        local themeDropdown = vgui.Create("DComboBox", panel)
        themeDropdown:SetValue("Select Theme")
        themeDropdown:Dock(TOP)
        themeDropdown:SetTall(30)
        themeDropdown:SetTooltip("Select the theme for the radio UI.")
        for themeName, _ in pairs(misc.Themes.list) do
            themeDropdown:AddChoice(themeName:gsub("^%l", string.upper))
        end

        local currentTheme = GetConVar("radio_theme"):GetString()
        if currentTheme and misc.Themes.list[currentTheme] then
            themeDropdown:SetValue(currentTheme:gsub("^%l", string.upper))
        end
        themeDropdown.OnSelect = function(_, _, value)
            local lowerValue = value:lower()
            if misc.Themes.list[lowerValue] then
                self:ApplyTheme(lowerValue)
                RunConsoleCommand("radio_theme", lowerValue)
            end
        end
        panel:AddItem(themeDropdown)

        -- Language Selection Section
        local languageHeader = vgui.Create("DLabel", panel)
        languageHeader:SetText("Language Selection")
        languageHeader:SetFont("Trebuchet18")
        languageHeader:SetTextColor(Color(50, 50, 50))
        languageHeader:Dock(TOP)
        languageHeader:DockMargin(0, 20, 0, 5)
        panel:AddItem(languageHeader)

        local languageDropdown = vgui.Create("DComboBox", panel)
        languageDropdown:SetValue("Select Language")
        languageDropdown:Dock(TOP)
        languageDropdown:SetTall(30)
        languageDropdown:SetTooltip("Select the language for the radio UI.")
        for code, name in pairs(languageManager.languages) do
            languageDropdown:AddChoice(name, code)
        end

        local currentLanguage = GetConVar("radio_language"):GetString()
        if currentLanguage and languageManager.languages[currentLanguage] then
            languageDropdown:SetValue(languageManager.languages[currentLanguage])
        end
        languageDropdown.OnSelect = function(_, _, value, data)
            self:ApplyLanguage(data)
            RunConsoleCommand("radio_language", data)
        end
        panel:AddItem(languageDropdown)

        -- Key Selection Section
        local keySelectionHeader = vgui.Create("DLabel", panel)
        keySelectionHeader:SetText("Select Key to Open Radio Menu")
        keySelectionHeader:SetFont("Trebuchet18")
        keySelectionHeader:SetTextColor(Color(50, 50, 50))
        keySelectionHeader:Dock(TOP)
        keySelectionHeader:DockMargin(0, 20, 0, 5)
        panel:AddItem(keySelectionHeader)

        local keyDropdown = vgui.Create("DComboBox", panel)
        keyDropdown:SetValue("Select Key")
        keyDropdown:Dock(TOP)
        keyDropdown:SetTall(30)
        keyDropdown:SetTooltip("Select the key to open the car radio menu.")
        local sortedKeys = self:SortKeys()
        for _, key in ipairs(sortedKeys) do
            keyDropdown:AddChoice(key.name, key.code)
        end

        local currentKey = GetConVar("car_radio_open_key"):GetInt()
        if misc.KeyNames.mapping[currentKey] then
            keyDropdown:SetValue(misc.KeyNames.mapping[currentKey])
        end
        keyDropdown.OnSelect = function(_, _, _, data)
            RunConsoleCommand("car_radio_open_key", data)
        end
        panel:AddItem(keyDropdown)

        -- General Options Section
        local generalOptionsHeader = vgui.Create("DLabel", panel)
        generalOptionsHeader:SetText("General Options")
        generalOptionsHeader:SetFont("Trebuchet18")
        generalOptionsHeader:SetTextColor(Color(50, 50, 50))
        generalOptionsHeader:Dock(TOP)
        generalOptionsHeader:DockMargin(0, 20, 0, 5)
        panel:AddItem(generalOptionsHeader)

        local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
        chatMessageCheckbox:SetText("Show Car Radio Messages")
        chatMessageCheckbox:SetConVar("car_radio_show_messages")
        chatMessageCheckbox:Dock(TOP)
        chatMessageCheckbox:DockMargin(0, 0, 0, 5)
        chatMessageCheckbox:SetTextColor(Color(0, 0, 0))
        chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool())
        chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio messages.")
        panel:AddItem(chatMessageCheckbox)

        local showTextCheckbox = vgui.Create("DCheckBoxLabel", panel)
        showTextCheckbox:SetText("Show Boombox Hover Text")
        showTextCheckbox:SetConVar("boombox_show_text")
        showTextCheckbox:Dock(TOP)
        showTextCheckbox:DockMargin(0, 0, 0, 0)
        showTextCheckbox:SetTextColor(Color(0, 0, 0))
        showTextCheckbox:SetValue(GetConVar("boombox_show_text"):GetBool())
        showTextCheckbox:SetTooltip("Enable or disable the display of text above the boombox.")
        panel:AddItem(showTextCheckbox)
    end
}

-- Hook to perform periodic cleanup of memory
hook.Add("Think", "RadioMemoryManagerCleanup", function()
    misc.MemoryManager:PerformCleanup(false)
end)

-- Hook to perform emergency cleanup on shutdown
hook.Add("ShutDown", "RadioMemoryManagerShutdown", function()
    misc.MemoryManager:PerformCleanup(true)
end)

-- Hook to process deferred UI updates
hook.Add("Think", "ProcessDeferredUIUpdates", function()
    misc.UIPerformance:ProcessDeferredUpdates()
end)

-- Hook to apply saved theme and language settings after entities have initialized
hook.Add("InitPostEntity", "ApplySavedThemeAndLanguageOnJoin", function()
    misc.Settings:LoadSavedSettings()
end)

-- Hook to update the country list when the language is updated
hook.Add("LanguageUpdated", "UpdateCountryListOnLanguageChange", function()
    if radioMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)
    end
end)

-- Hook to add the settings menu to the spawn menu
hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Rammel's Radio", "ThemeVolumeSelection", "Settings", "", "", function(panel)
        misc.Settings:CreateSettingsMenu(panel)
    end)
end)

return misc
