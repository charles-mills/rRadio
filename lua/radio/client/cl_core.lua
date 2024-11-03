--[[
    Radio Addon Client-Side Core Functionality
    Author: Charles Mills
    Description: This file implements the main client-side features of the Radio Addon.
                 It includes the user interface for the radio menu, handles playback of
                 radio stations, manages favorites, and processes network messages from
                 the server.
    Date: October 31, 2024
]]--

-- ------------------------------
--          Imports
-- ------------------------------
include("radio/shared/sh_config.lua")
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
local themeModule = include("radio/client/cl_themes.lua")
local keyCodeMapping = include("radio/client/cl_key_names.lua")
local utils = include("radio/shared/sh_utils.lua")
local Misc = include("radio/client/cl_misc.lua")

if not StateManager then
    error("[rRadio] Failed to load StateManager")
end

StateManager:Initialize()

local function getSafeState(key, default)
    if not StateManager then
        print("[rRadio] Warning: StateManager not initialized when getting state:", key)
        return default
    end
    
    if not StateManager.initialized then
        print("[rRadio] Warning: StateManager not yet initialized when getting state:", key)
        return default
    end
    
    if not StateManager.GetState then
        print("[rRadio] Warning: StateManager.GetState not available when getting state:", key)
        return default
    end
    
    return StateManager:GetState(key) or default
end

local function setSafeState(key, value)
    if not StateManager then
        print("[rRadio] Warning: StateManager not initialized when setting state:", key)
        return
    end
    
    if not StateManager.initialized then
        print("[rRadio] Warning: StateManager not yet initialized when setting state:", key)
        return
    end
    
    if not StateManager.SetState then
        print("[rRadio] Warning: StateManager.SetState not available when setting state:", key)
        return
    end
    
    StateManager:SetState(key, value)
end

local favoriteCountries = getSafeState("favoriteCountries", {})
local favoriteStations = getSafeState("favoriteStations", {})
local entityVolumes = getSafeState("entityVolumes", {})
local lastKeyPress = getSafeState("lastKeyPress", 0)

local currentFrame = nil
local settingsMenuOpen = false
local openRadioMenu

local lastIconUpdate = 0
local iconUpdateDelay = 0.1
local pendingIconUpdate = nil
local isUpdatingIcon = false
local isMessageAnimating = false

local favoritesMenuOpen = false

local VOLUME_ICONS = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}

local lastPermissionMessage = 0
local PERMISSION_MESSAGE_COOLDOWN = 3

local MAX_CLIENT_STATIONS = 10
local streamsEnabled = true

local lastStreamUpdate = 0
local STREAM_UPDATE_INTERVAL = 0.1

local isLoadingStations = false
local STATION_CHUNK_SIZE = 100
local loadingProgress = 0

hook.Add("OnPlayerChat", "RadioStreamToggleCommands", function(ply, text, teamChat, isDead)
    if ply ~= LocalPlayer() then return end
    
    text = string.lower(text)
    
    if text == "!disablestreams" then
        if not streamsEnabled then
            chat.AddText(Color(255, 0, 0), "[Radio] Streams are already disabled.")
            return true
        end
        
        -- Stop all current streams
        for entity, source in pairs(currentRadioSources) do
            if IsValid(source) then
                source:Stop()
            end
        end
        
        -- Clear states
        currentRadioSources = {}
        StreamManager.activeStreams = {}
        
        streamsEnabled = false
        chat.AddText(Color(0, 255, 0), "[Radio] All radio streams have been disabled for this session.")
        return true
    end
    
    if text == "!enablestreams" then
        if streamsEnabled then
            chat.AddText(Color(255, 0, 0), "[Radio] Streams are already enabled.")
            return true
        end
        
        streamsEnabled = true
        chat.AddText(Color(0, 255, 0), "[Radio] Radio streams have been re-enabled.")
        return true
    end
end)

local function transitionContent(panel, direction, onComplete)
    if not IsValid(panel) then return end
    
    -- Store panel reference
    local panelRef = panel
    
    -- Use the Transitions module for sliding with safety check
    Misc.Transitions:SlideElement(panel, 0.3, direction, function()
        if IsValid(panelRef) and onComplete then
            onComplete()
        end
    end)
    
    -- Handle fade effect with safety check
    Misc.Transitions:FadeElement(panel, direction, 0.2, function()
        if not IsValid(panelRef) then return false end
    end)
end


-- ------------------------------
--      Station Data Loading
-- ------------------------------

--[[
    Function: LoadStationData
    Loads station data from files asynchronously to prevent UI freezing.
    Uses chunked loading with progress tracking.
]]
local function LoadStationData()
    if stationDataLoaded or isLoadingStations then return end
    
    StationData = {}
    isLoadingStations = true
    loadingProgress = 0
    
    -- Get all data files first
    local dataFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
    local totalFiles = #dataFiles
    local currentFileIndex = 1
    local currentStationIndex = 1
    local currentCountry = nil
    local currentStations = nil
    
    -- Create temporary storage for file data
    local fileData = {}
    
    -- Process files in chunks
    timer.Create("LoadStationDataChunks", 0.05, 0, function()
        -- Process current chunk
        local startTime = SysTime()
        
        while (SysTime() - startTime) < 0.016 and currentFileIndex <= totalFiles do
            local filename = dataFiles[currentFileIndex]
            
            -- Load file data if not already loaded
            if not fileData[filename] then
                local success, data = pcall(include, "radio/client/stations/" .. filename)
                if success and data then
                    fileData[filename] = data
                else
                    print("[rRadio] Error loading station data from: " .. filename)
                    fileData[filename] = {}
                end
            end
            
            -- Process stations from current file
            local data = fileData[filename]
            for country, stations in pairs(data) do
                -- Extract base country name
                local baseCountry = country:gsub("_(%d+)$", "")
                if not StationData[baseCountry] then
                    StationData[baseCountry] = {}
                end
                
                -- Process stations in chunks
                for i = 1, #stations, STATION_CHUNK_SIZE do
                    local endIndex = math.min(i + STATION_CHUNK_SIZE - 1, #stations)
                    for j = i, endIndex do
                        local station = stations[j]
                        table.insert(StationData[baseCountry], {
                            name = station.n,
                            url = station.u
                        })
                    end
                    
                    -- Update progress
                    loadingProgress = (currentFileIndex / totalFiles) * 100
                    
                    -- Emit progress event
                    StateManager:Emit(StateManager.Events.STATION_LOAD_PROGRESS, {
                        progress = loadingProgress,
                        currentFile = filename,
                        totalFiles = totalFiles
                    })
                    
                    -- Break chunk processing if time exceeded
                    if (SysTime() - startTime) >= 0.016 then
                        return
                    end
                end
            end
            
            currentFileIndex = currentFileIndex + 1
        end
        
        -- Check if loading is complete
        if currentFileIndex > totalFiles then
            timer.Remove("LoadStationDataChunks")
            stationDataLoaded = true
            isLoadingStations = false
            loadingProgress = 100
            
            -- Update state
            StateManager:SetState("stationDataLoaded", true)
            StateManager:SetState("stationData", StationData)
            
            -- Emit completion event
            StateManager:Emit(StateManager.Events.STATION_LOAD_COMPLETE, {
                totalStations = table.Count(StationData)
            })
            
            -- Clear temporary storage
            fileData = nil
        end
    end)
end

-- Initialize station data
LoadStationData()

-- ------------------------------
--      Stream Management
-- ------------------------------

--[[
    Function: updateStationCount
    Updates and validates the count of active radio stations.
    Cleans up invalid entries and returns the current count.
    
    Returns:
    - number: The current number of active stations
]]
local function updateStationCount()
    local count = StateManager:UpdateStationCount()
    return count
end

-- Update the StreamManager definition
local StreamManager = {
    activeStreams = {},
    cleanupQueue = {},
    lastCleanup = 0,
    CLEANUP_INTERVAL = 0.2, -- 200ms between cleanups
    
    -- Add validity cache
    _validityCache = {},
    _lastValidityCheck = 0,
    VALIDITY_CHECK_INTERVAL = 0.5, -- Check validity every 0.5 seconds
    
    UpdateValidityCache = function(self)
        local currentTime = CurTime()
        if (currentTime - self._lastValidityCheck) < self.VALIDITY_CHECK_INTERVAL then
            return
        end
        
        self._lastValidityCheck = currentTime
        self._validityCache = {}
        
        for entIndex, streamData in pairs(self.activeStreams) do
            if IsValid(streamData.entity) and IsValid(streamData.stream) then
                self._validityCache[entIndex] = true
            else
                self:QueueCleanup(entIndex, "invalid_reference")
            end
        end
    end,
    
    IsStreamValid = function(self, entIndex)
        return self._validityCache[entIndex] == true
    end,
    
    -- Simple cleanup function
    CleanupStream = function(self, entIndex)
        local streamData = self.activeStreams[entIndex]
        if not streamData then return end
        
        -- Stop sound
        if IsValid(streamData.stream) then
            streamData.stream:Stop()
        end
        
        -- Clear states
        self.activeStreams[entIndex] = nil
        
        -- Clear UI state
        if IsValid(streamData.entity) then
            utils.clearRadioStatus(streamData.entity)
        end
    end,
    
    -- Add QueueCleanup function
    QueueCleanup = function(self, entIndex, reason)
        self.cleanupQueue[entIndex] = {
            reason = reason,
            timestamp = CurTime()
        }
        
        -- Process queue if enough time has passed
        if CurTime() - self.lastCleanup >= self.CLEANUP_INTERVAL then
            self:ProcessCleanupQueue()
        end
    end,
    
    -- Add ProcessCleanupQueue function
    ProcessCleanupQueue = function(self)
        self.lastCleanup = CurTime()
        
        for entIndex, cleanupData in pairs(self.cleanupQueue) do
            self:CleanupStream(entIndex)
        end
        
        -- Clear cleanup queue
        self.cleanupQueue = {}
    end,
    
    -- Register new stream
    RegisterStream = function(self, entity, stream, data)
        if not IsValid(entity) or not IsValid(stream) then return false end
        
        local entIndex = entity:EntIndex()
        
        -- Cleanup any existing stream first
        self:CleanupStream(entIndex)
        
        -- Register new stream
        self.activeStreams[entIndex] = {
            stream = stream,
            entity = entity,
            data = data,
            startTime = CurTime()
        }
        
        -- Update validity cache immediately
        self._validityCache[entIndex] = true
        
        return true
    end
}

-- Essential cleanup hooks
hook.Add("EntityRemoved", "RadioStreamCleanup", function(entity)
    if IsValid(entity) then
        StreamManager:CleanupStream(entity:EntIndex())
    end
end)

hook.Add("ShutDown", "RadioStreamCleanup", function()
    for entIndex, _ in pairs(StreamManager.activeStreams) do
        StreamManager:CleanupStream(entIndex)
    end
end)

-- ------------------------------
--      Utility Functions
-- ------------------------------

local function LerpColor(t, col1, col2)
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        Lerp(t, col1.a or 255, col2.a or 255)
    )
end

--[[
    Function: reopenRadioMenu
    Reopens the radio menu with optional settings flag.

    Parameters:
    - openSettingsMenuFlag: Boolean to determine if settings menu should be opened.
]]
local function reopenRadioMenu(openSettingsMenuFlag)
    if openRadioMenu then
        if IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
            timer.Simple(0.1, function()
                openRadioMenu(openSettingsMenuFlag)
            end)
        end
    else
        print("Error: openRadioMenu function not found")
    end
end

--[[
    Function: ClampVolume
    Clamps the volume to a maximum value (server-side convar).

    Parameters:
    - volume: The volume to clamp.

    Returns:
    - The clamped volume.
]]
local function ClampVolume(volume)
    local maxVolume = Config.MaxVolume()
    return math.Clamp(volume, 0, maxVolume)
end

--[[
    Function: loadFavorites
    Loads favorite countries and stations from JSON files.
    Includes error handling, data validation, and backup recovery.
]]
local function loadFavorites()
    -- Ensure StationData is loaded
    LoadStationData()
    
    -- Load favorites through StateManager
    StateManager:LoadFavorites()
    
    -- Update local references
    favoriteCountries = getFavoriteCountries()
    favoriteStations = getFavoriteStations()
end

--[[
    Function: saveFavorites
    Saves favorite countries and stations to JSON files.
    Includes error handling, validation, and backup system.
]]
local function saveFavorites()
    -- Update StateManager state
    StateManager:SetState("favoriteCountries", favoriteCountries)
    StateManager:SetState("favoriteStations", favoriteStations)
    
    -- Save through StateManager
    return StateManager:SaveFavorites()
end

-- ------------------------------
--          UI Setup
-- ------------------------------

local function createFonts()
    surface.CreateFont("Roboto18", {
        font = "Roboto",
        size = ScreenScale(5),
        weight = 500,
    })

    surface.CreateFont("HeaderFont", {
        font = "Roboto",
        size = ScreenScale(8),
        weight = 700,
    })
end

createFonts()

-- ------------------------------
--      State Variables
-- ------------------------------

local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil
local lastMessageTime = -math.huge
local lastStationSelectTime = 0
local currentlyPlayingStations = {}
local settingsMenuOpen = false
local formattedCountryNames = {}
local stationDataLoaded = false
local isSearching = false

-- ------------------------------
--      Helper Functions
-- ------------------------------

--[[
    Function: GetVehicleEntity
    Retrieves the vehicle entity from a given entity.

    Parameters:
    - entity: The entity to check.

    Returns:
    - The vehicle entity or the original entity if not a vehicle.
]]
local function GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

--[[
    Function: Scale
    Scales a value based on the screen width.

    Parameters:
    - value: The value to scale.

    Returns:
    - The scaled value.
]]
local function Scale(value)
    return value * (ScrW() / 2560)
end

--[[
    Function: getEntityConfig
    Retrieves the configuration for a given entity.

    Parameters:
    - entity: The entity to get the config for.

    Returns:
    - The configuration table for the entity.
]]
local function getEntityConfig(entity)
    return utils.GetEntityConfig(entity)
end

--[[
    Function: formatCountryName
    Formats and translates a country name, with caching per language.

    Parameters:
    - name: The original country name.

    Returns:
    - The formatted and translated country name.
]]
local function formatCountryName(name)
    local lang = GetConVar("radio_language"):GetString() or "en"
    local cacheKey = name .. "_" .. lang

    if formattedCountryNames[cacheKey] then
        return formattedCountryNames[cacheKey]
    end

    local translatedName = LanguageManager:GetCountryTranslation(lang, name)

    formattedCountryNames[cacheKey] = translatedName
    return translatedName
end

--[[
    Function: playStation
    Plays a specified radio station on a given entity.

    Parameters:
    - entity: The entity on which to play the station.
    - station: The station data containing name and URL.
    - volume: The volume level for playback.

    Returns:
    - None: This function does not return a value, but it updates the state and sends network messages.
]]

local function playStation(entity, station, volume)
    if not IsValid(entity) then return end
    if not station or not station.name or not station.url then 
        print("[rRadio] Invalid station data")
        return 
    end

    -- Validate volume range
    volume = math.Clamp(volume, 0, Config.MaxVolume())

    -- Track retry attempts
    local retryCount = 0
    local MAX_RETRIES = 3
    local RETRY_DELAY = 2
    local TIMEOUT_DURATION = 10

    -- Function to handle stream creation and retries
    local function startNewStream()
        if not IsValid(entity) then return end

        -- Update server state
        net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(station.name)
            net.WriteString(station.url)
            net.WriteFloat(volume)
        net.SendToServer()

        -- Create local stream with timeout handling
        local timeoutTimer = timer.Create("RadioTimeout_" .. entity:EntIndex(), TIMEOUT_DURATION, 1, function()
            if retryCount < MAX_RETRIES then
                print("[rRadio] Stream timeout, retrying... (" .. (retryCount + 1) .. "/" .. MAX_RETRIES .. ")")
                retryCount = retryCount + 1
                timer.Simple(RETRY_DELAY, startNewStream)
            else
                print("[rRadio] Stream failed after " .. MAX_RETRIES .. " attempts")
                utils.playErrorSound("connection")
                utils.clearRadioStatus(entity)
                
                -- Notify user of failure
                chat.AddText(Color(255, 0, 0), "[Radio] Failed to connect to station after multiple attempts")
                
                -- Clean up any partial streams
                StreamManager:CleanupStream(entity:EntIndex())
            end
        end)

        sound.PlayURL(station.url, "3d noblock", function(stream, errorID, errorName)
            -- Clear timeout timer if we got a response
            if timer.Exists("RadioTimeout_" .. entity:EntIndex()) then
                timer.Remove("RadioTimeout_" .. entity:EntIndex())
            end

            if not IsValid(stream) then
                print("[rRadio] Error creating sound stream:", errorName)
                
                if retryCount < MAX_RETRIES then
                    print("[rRadio] Retrying... (" .. (retryCount + 1) .. "/" .. MAX_RETRIES .. ")")
                    retryCount = retryCount + 1
                    timer.Simple(RETRY_DELAY, startNewStream)
                else
                    utils.playErrorSound("connection")
                    if IsValid(entity) then
                        utils.clearRadioStatus(entity)
                    end
                end
                return
            end

            if not IsValid(entity) then
                stream:Stop()
                return

            end

            -- Register with StreamManager
            if not StreamManager:RegisterStream(entity, stream, {
                name = station.name,
                url = station.url,
                volume = volume,
                startTime = CurTime()
            }) then
                stream:Stop()
                return
            end

            -- Configure and start stream
            stream:SetPos(entity:GetPos())
            stream:SetVolume(volume)
            
            -- Add error handling for stream start
            local success, err = pcall(function()
                stream:Play()
            end)
            
            if not success then
                print("[rRadio] Error starting stream:", err)
                StreamManager:CleanupStream(entity:EntIndex())
                utils.playErrorSound("playback")
                return
            end

            -- Update state
            StateManager:SetState("currentlyPlayingStations", {
                [entity] = station
            })
            StateManager:SetState("lastStationSelectTime", CurTime())
            
            -- Emit stream started event
            StateManager:Emit(StateManager.Events.STREAM_STARTED, {
                entity = entity,
                station = station,
                stream = stream
            })
        end)
    end

    -- Stop current playback first
    if currentlyPlayingStations[entity] then
        -- Stop on server
        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.SendToServer()

        -- Stop locally through StreamManager
        local streamData = StreamManager.activeStreams[entity:EntIndex()]
        if streamData and IsValid(streamData.stream) then
            streamData.stream:Stop()
        end

        -- Clean up through StreamManager
        StreamManager:CleanupStream(entity:EntIndex())

        -- Add delay before starting new stream
        timer.Simple(0.2, function()
            startNewStream()
        end)
    else
        startNewStream()
    end
end


--[[
    Function: updateRadioVolume
    Updates the volume of the radio station based on distance and whether the player is in the car.
]]
local function updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    if not entityConfig then 
        print("[rRadio] Warning: No entity config found for", entity)
        return 
    end

    -- Early distance check
    local maxDist = entityConfig.MaxHearingDistance()
    if distanceSqr > (maxDist * maxDist) then
        station:SetVolume(0)
        return
    end

    -- Get the user-set volume
    local userVolume = ClampVolume(entity:GetNWFloat("Volume", entityConfig.Volume()))

    if userVolume <= 0.02 then
        station:SetVolume(0)
        return
    end

    -- If player is in the vehicle, use full user-set volume and disable 3D
    if isPlayerInCar then
        station:Set3DEnabled(false)
        station:SetVolume(userVolume)
        return
    end

    -- Enable 3D audio when outside
    station:Set3DEnabled(true)
    local minDist = entityConfig.MinVolumeDistance()
    station:Set3DFadeDistance(minDist, maxDist)

    -- Calculate distance-based volume only if within audible range
    local finalVolume = userVolume
    if distanceSqr > minDist * minDist then
        local dist = math.sqrt(distanceSqr)
        local falloff = 1 - math.Clamp((dist - minDist) / (maxDist - minDist), 0, 1)
        finalVolume = userVolume * falloff
    end

    station:SetVolume(finalVolume)

    -- Update stream activity timestamp
    local streamData = StreamManager.activeStreams[entity:EntIndex()]
    if streamData then
        streamData.lastActivity = CurTime()
    end
end

--[[
    Function: PrintCarRadioMessage
    Displays an animated notification about how to open the car radio.
]]
local function PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end
    
    local currentTime = CurTime()
    local cooldownTime = Config.MessageCooldown()

    if isMessageAnimating or (lastMessageTime and currentTime - lastMessageTime < cooldownTime) then
        return
    end

    lastMessageTime = currentTime
    isMessageAnimating = true

    local openKey = GetConVar("car_radio_open_key"):GetInt()
    local keyName = GetKeyName(openKey)

    -- Create notification panel
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth = Scale(300)
    local panelHeight = Scale(70)
    local panel = vgui.Create("DButton")
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPos(scrW, scrH * 0.2)
    panel:SetText("")
    panel:SetAlpha(0)
    panel:MoveToFront()
    
    -- Add text label
    local textLabel = vgui.Create("DLabel", panel)
    textLabel:SetText("Play Radio")
    textLabel:SetFont("Roboto18")
    textLabel:SetTextColor(Config.UI.TextColor)
    textLabel:SizeToContents()
    textLabel:SetPos(Scale(70), panelHeight/2 - textLabel:GetTall()/2)
    
    -- Slide in animation with safety check
    local panelRef = panel
    Misc.Animations:CreateTween(0.5, scrW, scrW - panelWidth, function(value)
        if IsValid(panelRef) then
            panelRef:SetPos(value, scrH * 0.2)
        else
            return false -- Stop animation if panel is invalid
        end
    end)
    
    -- Fade in animation with safety check
    Misc.Animations:CreateTween(0.3, 0, 255, function(value)
        if IsValid(panelRef) then
            panelRef:SetAlpha(value)
        else
            return false
        end
    end)
    
    -- Auto hide after delay with safety checks
    timer.Simple(3, function()
        if IsValid(panelRef) then
            -- Slide out animation
            Misc.Animations:CreateTween(0.5, panelRef:GetX(), scrW, function(value)
                if IsValid(panelRef) then
                    panelRef:SetPos(value, scrH * 0.2)
                else
                    return false
                end
            end)
            
            -- Fade out animation
            Misc.Animations:CreateTween(0.3, 255, 0, function(value)
                if IsValid(panelRef) then
                    panelRef:SetAlpha(value)
                else
                    return false
                end
            end, function()
                if IsValid(panelRef) then
                    panelRef:Remove()
                end
            end)
        end
    end)
    
    local animDuration = 1
    local showDuration = 2
    local startTime = CurTime()
    local alpha = 0
    local pulseValue = 0
    local isDismissed = false

    panel.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function(self, w, h)
        local bgColor = Config.UI.MessageBackgroundColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(
            math.min(bgColor.r * hoverBrightness, 255),
            math.min(bgColor.g * hoverBrightness, 255),
            math.min(bgColor.b * hoverBrightness, 255),
            bgColor.a or 255
        )
        
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)

        local keyWidth = Scale(40)
        local keyHeight = Scale(30)
        local keyX = Scale(20)
        local keyY = h/2 - keyHeight/2
        local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
        local adjustedKeyWidth = keyWidth * pulseScale
        local adjustedKeyHeight = keyHeight * pulseScale
        local adjustedKeyX = keyX - (adjustedKeyWidth - keyWidth) / 2
        local adjustedKeyY = keyY - (adjustedKeyHeight - keyHeight) / 2
        
        -- Draw key background
        draw.RoundedBox(6, adjustedKeyX, adjustedKeyY, adjustedKeyWidth, adjustedKeyHeight, 
            Config.UI.KeyHighlightColor)

        -- Draw the key name
        draw.SimpleText(keyName, "Roboto18", adjustedKeyX + adjustedKeyWidth/2, adjustedKeyY + adjustedKeyHeight/2, 
            Config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Draw subtle divider line
        surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 40))  -- 40 alpha for subtle effect
        surface.DrawLine(
            Scale(70) - Scale(5),  -- Slightly left of text
            h * 0.3,               -- Start from 30% height
            Scale(70) - Scale(5),  -- Same X position
            h * 0.7                -- End at 70% height
        )
    end

    panel.Think = function(self)
        local time = CurTime() - startTime
        
        pulseValue = (pulseValue + FrameTime() * 1.5) % 1

        if time < animDuration then
            local progress = time / animDuration
            local easedProgress = math.ease.OutQuint(progress)
            self:SetPos(Lerp(easedProgress, scrW, scrW - panelWidth), scrH * 0.2)
            alpha = math.ease.InOutQuad(progress)
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos(scrW - panelWidth, scrH * 0.2)
        elseif not isDismissed or time >= animDuration + showDuration then
            local progress = (time - (animDuration + showDuration)) / animDuration
            local easedProgress = math.ease.InOutQuint(progress)
            self:SetPos(Lerp(easedProgress, scrW - panelWidth, scrW), scrH * 0.2)
            alpha = 1 - math.ease.InOutQuad(progress)
            
            if progress >= 1 then
                isMessageAnimating = false
                self:Remove()
            end
        end
    end

    panel.OnRemove = function()
        isMessageAnimating = false
    end
end

-- ------------------------------
--      UI Helper Functions
-- ------------------------------

--[[
    Function: calculateFontSizeForStopButton
    Dynamically calculates the font size for the stop button text.

    Parameters:
    - text: The text to display.
    - buttonWidth: The width of the button.
    - buttonHeight: The height of the button.

    Returns:
    - The name of the font to use.
]]
local function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local fontName = "DynamicStopButtonFont"

    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    })

    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)

    while textWidth > buttonWidth * 0.9 and maxFontSize > 10 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        })
        surface.SetFont(fontName)
        textWidth = surface.GetTextSize(text)
    end

    return fontName
end

--[[
    Function: createStarIcon
    Creates a star icon for favorites (both countries and stations).

    Parameters:
    - parent: The parent UI element.
    - country: The country code.
    - station: (Optional) The station data. If nil, treats as country favorite.
    - updateList: The function to update the list.

    Returns:
    - The created star icon UI element.
]]
local function createStarIcon(parent, country, station, updateList)
    local starIcon = vgui.Create("DImageButton", parent)
    starIcon:SetSize(Scale(24), Scale(24))
    starIcon:SetPos(Scale(12), (Scale(40) - Scale(24)) / 2)

    local isFavorite = station and 
        (getSafeState("favoriteStations", {})[country] and 
         getSafeState("favoriteStations", {})[country][station.name]) or 
        (not station and getSafeState("favoriteCountries", {})[country])

    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
    
    -- Update star icon color
    starIcon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.FavoriteStarColor)
        surface.SetMaterial(Material(isFavorite and "hud/star_full.png" or "hud/star.png"))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    starIcon.DoClick = function()
        if station then
            local currentFavoriteStations = getSafeState("favoriteStations", {})
            if not currentFavoriteStations[country] then
                currentFavoriteStations[country] = {}
            end

            if currentFavoriteStations[country][station.name] then
                currentFavoriteStations[country][station.name] = nil
                if next(currentFavoriteStations[country]) == nil then
                    currentFavoriteStations[country] = nil
                end
            else
                currentFavoriteStations[country][station.name] = true
            end

            StateManager:SetState("favoriteStations", currentFavoriteStations)
        else
            local currentFavoriteCountries = getSafeState("favoriteCountries", {})
            if currentFavoriteCountries[country] then
                currentFavoriteCountries[country] = nil
            else
                currentFavoriteCountries[country] = true
            end

            StateManager:SetState("favoriteCountries", currentFavoriteCountries)
        end

        saveFavorites()

        local newIsFavorite = station and 
            (getSafeState("favoriteStations", {})[country] and 
             getSafeState("favoriteStations", {})[country][station.name]) or 
            (not station and getSafeState("favoriteCountries", {})[country])
        
        starIcon:SetImage(newIsFavorite and "hud/star_full.png" or "hud/star.png")

        -- Force refresh of favorites list if we're in the favorites view
        if selectedCountry == "favorites" then
            -- Invalidate cache and force refresh
            StateManager:InvalidateCache("favorites")
            populateList(stationListPanel, backButton, searchBox, false)
        end

        if updateList then
            updateList()
        end

        -- Notify state change
        StateManager:Emit(StateManager.Events.FAVORITES_CHANGED, {
            type = station and "station" or "country",
            country = country,
            station = station,
            isFavorite = newIsFavorite
        })
    end

    return starIcon
end

-- ------------------------------
--      UI Population
-- ------------------------------

--[[
    Function: populateList
    Populates the station or country list in the UI.

    Parameters:
    - stationListPanel: The panel to populate.
    - backButton: The back button UI element.
    - searchBox: The search box UI element.
    - resetSearch: Boolean indicating whether to reset the search box.
]]
local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then return end

    stationListPanel:Clear()
    if resetSearch then searchBox:SetText("") end

    local filterText = searchBox:GetText():lower()
    local lang = GetConVar("radio_language"):GetString() or "en"
    local selectedCountry = getSafeState("selectedCountry", nil)

    local function updateList()
        populateList(stationListPanel, backButton, searchBox, false)
    end

    local function createStyledButton(parent, text, onClick)
        local button = vgui.Create("DButton", parent)
        button:Dock(TOP)
        button:DockMargin(Scale(10), Scale(5), Scale(10), 0)
        button:SetTall(Scale(40))
        button:SetText(text)
        button:SetFont("Roboto18")
        button:SetTextColor(Config.UI.TextColor)
        button:SetTextInset(Scale(40), 0)
        
        -- Animation states
        button.hoverProgress = 0
        button.clickScale = 1
        
        button.Paint = function(self, w, h)
            -- Scale animation for click feedback
            local matrix = Matrix()
            matrix:Translate(Vector(w/2, h/2, 0))
            matrix:Scale(Vector(self.clickScale, self.clickScale, 1))
            matrix:Translate(Vector(-w/2, -h/2, 0))
            
            cam.PushModelMatrix(matrix)
            
            -- Background with hover animation
            local baseColor = Config.UI.ButtonColor
            local hoverColor = Config.UI.ButtonHoverColor
            local currentColor = LerpColor(self.hoverProgress, baseColor, hoverColor)
            
            draw.RoundedBox(8, 0, 0, w, h, currentColor)
            
            cam.PopModelMatrix()
        end
        
        button.Think = function(self)
            if self:IsHovered() then
                self.hoverProgress = math.Approach(self.hoverProgress, 1, FrameTime() * 5)
            else
                self.hoverProgress = math.Approach(self.hoverProgress, 0, FrameTime() * 5)
            end
        end
        
        button.DoClick = onClick
        
        return button
    end

    -- Create a separator line
    local function createSeparator()
        local separator = vgui.Create("DPanel", stationListPanel)
        separator:Dock(TOP)
        separator:DockMargin(Scale(10), Scale(5), Scale(10), Scale(5))
        separator:SetTall(Scale(2))
        separator.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Config.UI.SeparatorColor)
        end
        return separator
    end

    if selectedCountry == nil then
        local hasFavorites = false
        for country, stations in pairs(favoriteStations) do
            for stationName, isFavorite in pairs(stations) do
                if isFavorite then
                    hasFavorites = true
                    break
                end
            end
            if hasFavorites then break end
        end

        if hasFavorites then
            createSeparator()

            local favoritesButton = createStyledButton(
                stationListPanel,
                Config.Lang["FavoriteStations"] or "Favorite Stations",
                function()
                    StateManager:SetState("selectedCountry", "favorites")
                    StateManager:SetState("favoritesMenuOpen", true)
                    selectedCountry = "favorites"
                    favoritesMenuOpen = true
                    
                    if backButton then 
                        backButton:SetVisible(true)
                        backButton:SetEnabled(true)
                    end
                    updateList()
                end
            )

            favoritesButton:SetTextInset(Scale(40), 0)

            favoritesButton.PaintOver = function(self, w, h)
                surface.SetMaterial(Material("hud/star_full.png"))
                surface.SetDrawColor(Config.UI.TextColor)
                
                local iconSize = Scale(24)
                local iconX = Scale(8)
                local iconY = (h - iconSize) / 2
                
                surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
            end

            createSeparator()
        end

        local countries = {}
        for country, _ in pairs(StationData) do
            -- Format and translate the country name
            local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
                return first:upper() .. rest:lower()
            end)
            
            local translatedCountry = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry

            if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
                local isFavorite = getSafeState("favoriteCountries", {})[country] or false
                
                table.insert(countries, { 
                    original = country,        -- Original country code
                    formatted = formattedCountry, -- Formatted but untranslated name
                    translated = translatedCountry, -- Translated name for display
                    isPrioritized = isFavorite 
                })
            end
        end

        -- Sort countries with favorites first, using translated names
        table.sort(countries, function(a, b)
            if a.isPrioritized ~= b.isPrioritized then
                return a.isPrioritized
            end
            return a.translated < b.translated
        end)

        -- Create country buttons
        for _, country in ipairs(countries) do
            local countryButton = createStyledButton(
                stationListPanel,
                country.translated, -- Use translated name for display
                function()
                    local countryCode = country.original
                    StateManager:SetState("selectedCountry", countryCode)
                    selectedCountry = countryCode
                    
                    if backButton then 
                        backButton:SetVisible(true)
                        backButton:SetEnabled(true)
                    end
                    
                    if searchBox then
                        searchBox:SetText("")
                    end
                    
                    updateList()
                end
            )

            -- Pass the raw country code to the star icon
            createStarIcon(countryButton, country.original, nil, updateList)
        end

        if backButton then
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
        end

    elseif selectedCountry == "favorites" then
        -- Get cached favorites list
        local favoritesList = StateManager:GetFavoritesList(lang, filterText)

        for _, favorite in ipairs(favoritesList) do
            local stationButton = createStyledButton(
                stationListPanel,
                favorite.countryName .. " - " .. favorite.station.name,
                function(button)
                    local currentTime = CurTime()
                    -- Get last station time with a default value of 0
                    local lastStationTime = getSafeState("lastStationSelectTime", 0)
                    
                    -- Ensure we have valid numbers for comparison
                    if type(currentTime) ~= "number" or type(lastStationTime) ~= "number" then
                        print("[rRadio] Warning: Invalid time values in station button handler")
                        lastStationTime = 0
                    end

                    if (currentTime - lastStationTime) < 2 then return end

                    surface.PlaySound("buttons/button17.wav")
                    local entity = LocalPlayer().currentRadioEntity
                    if not IsValid(entity) then return end

                    -- Get and validate volume
                    local entityConfig = getEntityConfig(entity)
                    local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
                    volume = ClampVolume(volume)

                    -- Play the station
                    playStation(entity, favorite.station, volume)
                    
                    -- Update UI
                    updateList()
                end
            )

            createStarIcon(stationButton, favorite.country, favorite.station, updateList)
        end
    else
        -- Regular station list for selected country
        local stations = StationData[selectedCountry] or {}
        local stationsList = {}

        -- Filter and prepare stations
        for _, station in ipairs(stations) do
            if station and station.name and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                local isFavorite = favoriteStations[selectedCountry] and favoriteStations[selectedCountry][station.name]
                table.insert(stationsList, { station = station, favorite = isFavorite })
            end
        end

        -- Sort stations (favorites first, then alphabetically)
        table.sort(stationsList, function(a, b)
            if a.favorite ~= b.favorite then
                return a.favorite
            end
            return (a.station.name or "") < (b.station.name or "")
        end)

        -- Create station buttons
        for _, stationData in ipairs(stationsList) do
            local station = stationData.station
            local stationButton = createStyledButton(
                stationListPanel,
                station.name,
                function(button)
                    local currentTime = CurTime()
                    -- Get last station time with a default value of 0
                    local lastStationTime = getSafeState("lastStationSelectTime", 0)
                    
                    -- Ensure we have valid numbers for comparison
                    if type(currentTime) ~= "number" or type(lastStationTime) ~= "number" then
                        print("[rRadio] Warning: Invalid time values in station button handler")
                        lastStationTime = 0
                    end

                    if (currentTime - lastStationTime) < 2 then return end

                    surface.PlaySound("buttons/button17.wav")
                    local entity = LocalPlayer().currentRadioEntity
                    if not IsValid(entity) then return end

                    -- Get and validate volume
                    local entityConfig = getEntityConfig(entity)
                    local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
                    volume = ClampVolume(volume)

                    -- Play the station
                    playStation(entity, station, volume)
                    
                    -- Update UI
                    updateList()
                end
            )

            -- Add paint function for visual state
            stationButton.Paint = function(self, w, h)
                local entity = LocalPlayer().currentRadioEntity
                if IsValid(entity) and currentlyPlayingStations[entity] and 
                   currentlyPlayingStations[entity].name == station.name then
                    -- Base playing station color
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.StatusIndicatorColor)
                else
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                    if self:IsHovered() then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end

                -- Add connection status indicator
                local streamData = StreamManager.activeStreams[entity:EntIndex()]
                if streamData then
                    if streamData.stream and not streamData.stream:IsValid() then
                        surface.SetDrawColor(Config.UI.CloseButtonColor)
                        surface.DrawRect(w * 0.9, 0, w * 0.1, h)
                    end
                end
            end

            -- Always use raw country code when creating star icons
            createStarIcon(stationButton, selectedCountry, station, updateList)
        end

        if backButton then
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
        end
    end
end

--[[
    Function: openSettingsMenu
    Opens the settings menu within the radio menu.

    Parameters:
    - parentFrame: The parent frame of the settings menu.
    - backButton: The back button to return to the main menu.
]]
local function openSettingsMenu(parentFrame, backButton)
    settingsFrame = vgui.Create("DPanel", parentFrame)
    settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50) - Scale(10))
    settingsFrame:SetPos(Scale(10), Scale(50))
    settingsFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
    end

    local scrollPanel = vgui.Create("DScrollPanel", settingsFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))

    local function addHeader(text, isFirst)
        local header = vgui.Create("DLabel", scrollPanel)
        header:SetText(text)
        header:SetFont("Roboto18")
        header:SetTextColor(Config.UI.TextColor)
        header:Dock(TOP)
        if isFirst then
            header:DockMargin(0, Scale(5), 0, Scale(0))
        else
            header:DockMargin(0, Scale(10), 0, Scale(5))
        end
        header:SetContentAlignment(4)
    end

    local function addDropdown(text, choices, currentValue, onSelect)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(50))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        end

        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetFont("Roboto18")
        label:SetTextColor(Config.UI.TextColor)
        label:Dock(LEFT)
        label:DockMargin(Scale(10), 0, 0, 0)
        label:SetContentAlignment(4)
        label:SizeToContents()

        local dropdown = vgui.Create("DComboBox", container)
        dropdown:Dock(RIGHT)
        dropdown:SetWide(Scale(150))
        dropdown:DockMargin(0, Scale(10), Scale(10), Scale(10))
        dropdown:SetValue(currentValue)
        dropdown:SetTextColor(Config.UI.TextColor)
        dropdown:SetFont("Roboto18")
        
        -- Style the dropdown
        dropdown.Paint = function(self, w, h)
            -- Main background
            draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
            
            -- Draw arrow indicator
            surface.SetDrawColor(Config.UI.TextColor)
            local arrowSize = Scale(8)
            local margin = Scale(8)
            local x = w - arrowSize - margin
            local y = h/2 - arrowSize/2
            
            surface.DrawLine(x, y, x + arrowSize/2, y + arrowSize)
            surface.DrawLine(x + arrowSize/2, y + arrowSize, x + arrowSize, y)
        end
        
        -- Style the dropdown choices
        dropdown.OpenMenu = function(self, pControlOpener)
            if IsValid(self.Menu) then
                self.Menu:Remove()
                self.Menu = nil
            end

            local menu = DermaMenu()
            menu:SetMinimumWidth(self:GetWide())
            
            -- Create scroll panel for menu content
            local scrollPanel = vgui.Create("DScrollPanel", menu)
            scrollPanel:Dock(FILL)
            local maxHeight = Scale(300)
            
            -- Style scrollbar
            local sbar = scrollPanel:GetVBar()
            sbar:SetWide(Scale(8))
            sbar:SetHideButtons(true)
            function sbar:Paint(w, h) 
                draw.RoundedBox(4, 0, 0, w, h, Config.UI.ScrollbarColor) 
            end
            function sbar.btnGrip:Paint(w, h) 
                draw.RoundedBox(4, 0, 0, w, h, Config.UI.ScrollbarGripColor) 
            end
            
            -- Style menu
            menu.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
                surface.SetDrawColor(Config.UI.ButtonColor)
                surface.DrawRect(0, 0, w, 1)
            end

            -- Add choices with styling
            local totalHeight = 0
            local optionHeight = Scale(30)
            
            for _, choice in ipairs(choices) do
                local panel = vgui.Create("DPanel", scrollPanel)
                panel:SetTall(optionHeight)
                panel:Dock(TOP)
                panel.Paint = function(_, w, h)
                    if panel:IsHovered() then
                        draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end
                
                local button = vgui.Create("DButton", panel)
                button:Dock(FILL)
                button:SetText(choice.name)
                button:SetTextColor(Config.UI.TextColor)
                button:SetFont("Roboto18")
                button.Paint = function() end -- No background
                
                -- Store the choice data
                button.choiceData = choice.data
                
                button.DoClick = function()
                    self:SetValue(choice.name)
                    if onSelect then
                        onSelect(self, choice.name, button.choiceData)
                    end
                    menu:Remove()
                end
                
                totalHeight = totalHeight + optionHeight
            end

            -- Set menu size
            local menuHeight = math.min(totalHeight + Scale(2), maxHeight)
            menu:SetTall(menuHeight)
            scrollPanel:SetTall(menuHeight)

            -- Position the menu
            local x, y = self:LocalToScreen(0, self:GetTall())
            
            -- Ensure menu doesn't go off screen
            local screenH = ScrH()
            if y + menuHeight > screenH then
                y = y - menuHeight - self:GetTall() -- Show above instead
            end
            
            menu:SetPos(x, y)
            menu:MakePopup()
            self.Menu = menu
        end

        for _, choice in ipairs(choices) do
            dropdown:AddChoice(choice.name, choice.data)
        end

        dropdown.OnSelect = onSelect

        return dropdown
    end

    local function addCheckbox(text, convar)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(40))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        end

        local checkbox = vgui.Create("DCheckBox", container)
        checkbox:SetPos(Scale(10), (container:GetTall() - Scale(20)) / 2)
        checkbox:SetSize(Scale(20), Scale(20))
        checkbox:SetConVar(convar)

        checkbox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Config.UI.SearchBoxColor)
            if self:GetChecked() then
                surface.SetDrawColor(Config.UI.TextColor)
                surface.DrawRect(Scale(4), Scale(4), w - Scale(8), h - Scale(8))
            end
        end

        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetTextColor(Config.UI.TextColor)
        label:SetFont("Roboto18")
        label:SizeToContents()
        label:SetPos(Scale(40), (container:GetTall() - label:GetTall()) / 2)

        checkbox.OnChange = function(self, value)
            if not ConVarExists(convar) then
                print("[rRadio] Warning: ConVar " .. convar .. " does not exist")
                return
            end

            RunConsoleCommand(convar, value and "1" or "0")
            StateManager:SetState("settings_" .. convar, value)
            
            -- Emit settings change event
            StateManager:Emit(StateManager.Events.SETTINGS_CHANGED, {
                setting = convar,
                value = value
            })
        end

        return checkbox
    end

    -- Theme Selection
    addHeader(Config.Lang["ThemeSelection"] or "Theme Selection", true)
    local themeChoices = {}
    
    -- Validate themes table
    if type(themeModule.themes) == "table" then
        for themeName, themeData in pairs(themeModule.themes) do
            if type(themeData) == "table" then
                table.insert(themeChoices, {
                    name = themeName:gsub("^%l", string.upper),
                    data = themeName
                })
            end
        end
    else
        print("[rRadio] Warning: Themes table is invalid")
        themeModule.themes = {}
    end

    local currentTheme = GetConVar("radio_theme"):GetString()
    local currentThemeName = currentTheme:gsub("^%l", string.upper)
    
    addDropdown(Config.Lang["SelectTheme"] or "Select Theme", themeChoices, currentThemeName, function(_, _, value)
        local lowerValue = value:lower()
        if themeModule.themes and themeModule.themes[lowerValue] then
            RunConsoleCommand("radio_theme", lowerValue)
            Config.UI = themeModule.themes[lowerValue]
            
            StateManager:SetState("currentTheme", lowerValue)
            StateManager:Emit(StateManager.Events.THEME_CHANGED, lowerValue)
            
            -- Safely close and reopen the menu
            if IsValid(parentFrame) then
                parentFrame:Close()
                timer.Simple(0.1, function()
                    reopenRadioMenu(true)
                end)
            end
        else
            print("[rRadio] Warning: Invalid theme selected:", value)
        end
    end)

    -- Language Selection
    addHeader(Config.Lang["LanguageSelection"] or "Language Selection")
    local languageChoices = {}
    local availableLanguages = LanguageManager:GetAvailableLanguages()
    
    if type(availableLanguages) == "table" then
        for code, name in pairs(availableLanguages) do
            if type(code) == "string" and type(name) == "string" then
                table.insert(languageChoices, {name = name, data = code})
            end
        end
    else
        print("[rRadio] Warning: Available languages table is invalid")
    end

    local currentLanguage = GetConVar("radio_language"):GetString()
    local currentLanguageName = LanguageManager:GetLanguageName(currentLanguage)

    addDropdown(Config.Lang["SelectLanguage"] or "Select Language", languageChoices, currentLanguageName, function(_, _, name, data)
        if not data then return end
        
        -- Update convar and language
        RunConsoleCommand("radio_language", data)
        LanguageManager:SetLanguage(data)
        Config.Lang = LanguageManager.translations[data]
        
        -- Update state
        StateManager:SetState("currentLanguage", data)
        StateManager:Emit(StateManager.Events.LANGUAGE_CHANGED, data)

        -- Reset cached country names
        StateManager:SetState("formattedCountryNames", {})

        -- Reload station data
        stationDataLoaded = false
        LoadStationData()

        -- Close and reopen menu
        if IsValid(currentFrame) then
            currentFrame:Close()
            timer.Simple(0.1, function()
                if openRadioMenu then
                    radioMenuOpen = false
                    StateManager:SetState("selectedCountry", nil)
                    StateManager:SetState("settingsMenuOpen", false)
                    StateManager:SetState("favoritesMenuOpen", false)
                    openRadioMenu(true)
                end
            end)
        end
    end)

    -- Key Selection
    addHeader(Config.Lang["SelectKeyToOpenRadioMenu"] or "Select Key to Open Radio Menu")
    local keyChoices = {}

    -- Sort keys into categories
    local letterKeys = {}
    local numberKeys = {}
    local functionKeys = {}
    local otherKeys = {}

    for keyCode, keyName in pairs(keyCodeMapping) do
        if type(keyName) == "string" then
            local entry = {code = keyCode, name = keyName}
            
            if keyName:match("^%a$") then -- Single letter
                table.insert(letterKeys, entry)
            elseif keyName:match("^%d$") then -- Single number
                table.insert(numberKeys, entry)
            elseif keyName:match("^F%d+$") then -- Function keys
                table.insert(functionKeys, entry)
            else
                table.insert(otherKeys, entry)
            end
        end
    end

    -- Sort each category
    table.sort(letterKeys, function(a, b) return a.name < b.name end)
    table.sort(numberKeys, function(a, b) return tonumber(a.name) < tonumber(b.name) end)
    table.sort(functionKeys, function(a, b) 
        return tonumber(a.name:match("%d+")) < tonumber(b.name:match("%d+"))
    end)
    table.sort(otherKeys, function(a, b) return a.name < b.name end)

    -- Combine all categories in desired order
    local sortedKeys = {}
    for _, key in ipairs(letterKeys) do table.insert(sortedKeys, key) end
    for _, key in ipairs(numberKeys) do table.insert(sortedKeys, key) end
    for _, key in ipairs(functionKeys) do table.insert(sortedKeys, key) end
    for _, key in ipairs(otherKeys) do table.insert(sortedKeys, key) end

    -- Convert to choices format
    for _, key in ipairs(sortedKeys) do
        table.insert(keyChoices, {
            name = key.name,
            data = key.code -- Use the actual key code directly
        })
    end

    local currentKey = GetConVar("car_radio_open_key"):GetInt()
    local currentKeyName = keyCodeMapping[currentKey] or "K"

    addDropdown(Config.Lang["SelectKey"] or "Select Key", keyChoices, currentKeyName, function(_, _, name, data)
        -- data is now the actual key code
        if not data then return end
        
        -- Update convar with the key code
        RunConsoleCommand("car_radio_open_key", data)
        
        -- Update state
        StateManager:SetState("lastKeyPress", 0)
        StateManager:Emit(StateManager.Events.KEY_CHANGED, {
            key = data,
            keyName = name
        })
        
        -- Play feedback sound
        surface.PlaySound("buttons/button15.wav")
    end)

    addHeader(Config.Lang["GeneralOptions"] or "General Options")
    addCheckbox(Config.Lang["ShowCarMessages"] or "Show Car Radio Messages", "car_radio_show_messages")
    addCheckbox(Config.Lang["ShowBoomboxHUD"] or "Show Boombox Hover Text", "boombox_show_text")

    -- Superadmin: Permanent Boombox Section
    if LocalPlayer():IsSuperAdmin() then
        local currentEntity = LocalPlayer().currentRadioEntity
        local isBoombox = IsValid(currentEntity) and (currentEntity:GetClass() == "boombox" or currentEntity:GetClass() == "golden_boombox")

        if isBoombox then
            addHeader(Config.Lang["SuperadminSettings"] or "Superadmin Settings")

            local permanentCheckbox = addCheckbox(Config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent", "")
            permanentCheckbox:SetChecked(currentEntity:GetNWBool("IsPermanent", false))

            permanentCheckbox.OnChange = function(self, value)
                if not IsValid(currentEntity) then
                    self:SetChecked(false)
                    return
                end

                if value then
                    net.Start("MakeBoomboxPermanent")
                        net.WriteEntity(currentEntity)
                    net.SendToServer()
                else
                    net.Start("RemoveBoomboxPermanent")
                        net.WriteEntity(currentEntity)
                    net.SendToServer()
                end
            end

            net.Receive("BoomboxPermanentConfirmation", function()
                local message = net.ReadString()
                chat.AddText(Color(0, 255, 0), "[Boombox] ", Color(255, 255, 255), message)
                if string.find(message, "marked as permanent") then
                    permanentCheckbox:SetChecked(true)
                elseif string.find(message, "permanence has been removed") then
                    permanentCheckbox:SetChecked(false)
                end
            end)
        end
    end

    local footerHeight = Scale(60)
    local footer = vgui.Create("DButton", settingsFrame)
    footer:SetSize(settingsFrame:GetWide(), footerHeight)
    footer:SetPos(0, settingsFrame:GetTall() - footerHeight)
    footer:SetText("")
    footer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Config.UI.BackgroundColor or Config.UI.BackgroundColor)
    end
    footer.DoClick = function()
        gui.OpenURL("https://github.com/charles-mills/rRadio")
    end

    local githubIcon = vgui.Create("DImage", footer)
    githubIcon:SetSize(Scale(32), Scale(32))
    githubIcon:SetPos(Scale(10), (footerHeight - Scale(32)) / 2)
    githubIcon:SetImage("hud/github.png")
    githubIcon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.TextColor)
        surface.SetMaterial(Material("hud/github.png"))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    local contributeTitleLabel = vgui.Create("DLabel", footer)
    contributeTitleLabel:SetText(Config.Lang["Contribute"] or "Want to contribute?")
    contributeTitleLabel:SetFont("Roboto18")
    contributeTitleLabel:SetTextColor(Config.UI.TextColor)
    contributeTitleLabel:SizeToContents()
    contributeTitleLabel:SetPos(Scale(50), footerHeight / 2 - contributeTitleLabel:GetTall() + Scale(2))

    local contributeSubLabel = vgui.Create("DLabel", footer)
    contributeSubLabel:SetText(Config.Lang["SubmitPullRequest"] or "Submit a pull request :)")
    contributeSubLabel:SetFont("Roboto18")
    contributeSubLabel:SetTextColor(Config.UI.TextColor)
    contributeSubLabel:SizeToContents()
    contributeSubLabel:SetPos(Scale(50), footerHeight / 2 + Scale(2))
end

-- ------------------------------
--      Main UI Function
-- ------------------------------

--[[
    Function: openRadioMenu
    Opens the radio menu UI for the player.
]]
openRadioMenu = function(openSettings)
    if radioMenuOpen then return end
    
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    
    if not IsValid(entity) then return end
    
    -- Check if entity can use radio
    if not utils.canUseRadio(entity) then
        return
    end
    
    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        if not utils.canInteractWithBoombox(ply, entity) then
            chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
            return
        end
    end
    
    -- Reset states when opening menu
    selectedCountry = nil
    settingsMenuOpen = false
    favoritesMenuOpen = false
    StateManager:SetState("selectedCountry", nil)
    StateManager:SetState("favoritesMenuOpen", false)
    StateManager:SetState("settingsMenuOpen", false)
    
    radioMenuOpen = true
    
    local backButton

    local frame = vgui.Create("DFrame")
    currentFrame = frame
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function()
        radioMenuOpen = false
        -- Reset all menu states when closing
        StateManager:SetState("selectedCountry", nil)
        StateManager:SetState("favoritesMenuOpen", false)
        StateManager:SetState("settingsMenuOpen", false)
        selectedCountry = nil
        settingsMenuOpen = false
        favoritesMenuOpen = false
        
        -- Clean up any abandoned streams
        for entIndex, streamData in pairs(StreamManager.activeStreams) do
            if not IsValid(streamData.entity) then
                StreamManager:QueueCleanup(entIndex, "menu_closed")
            end
        end
    end

    frame.Paint = function(self, w, h)
        -- Normal painting
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), Config.UI.HeaderColor, true, true, false, false)

        local headerHeight = Scale(40)
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        local iconOffsetY = headerHeight/2 - iconSize/2

        -- Draw the icon
        surface.SetMaterial(Material("hud/radio.png"))
        surface.SetDrawColor(Config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)

        -- Get current language and state
        local lang = GetConVar("radio_language"):GetString() or "en"
        local currentCountry = getSafeState("selectedCountry", nil)
        local isSettingsOpen = getSafeState("settingsMenuOpen", false)
        local isFavoritesOpen = getSafeState("favoritesMenuOpen", false)

        -- Determine header text
        local headerText
        if isSettingsOpen then
            headerText = Config.Lang["Settings"] or "Settings"
        elseif currentCountry then
            if currentCountry == "favorites" or isFavoritesOpen then
                headerText = Config.Lang["FavoriteStations"] or "Favorite Stations"
            else
                -- Format and translate country name
                local formattedCountry = currentCountry:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) 
                    return string.upper(a) .. string.lower(b) 
                end)
                headerText = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry
            end
        else
            headerText = Config.Lang["SelectCountry"] or "Select Country"
        end

        -- Draw the header text
        draw.SimpleText(headerText, "HeaderFont", iconOffsetX + iconSize + Scale(5), 
                       headerHeight/2, Config.UI.TextColor, 
                       TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(Config.Lang and Config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetTextColor(Config.UI.TextColor)
    searchBox:SetDrawBackground(false)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
        self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)

        if self:GetText() == "" then
            draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    searchBox:SetVisible(not settingsMenuOpen)

    searchBox.OnGetFocus = function()
        isSearching = true
    end

    searchBox.OnLoseFocus = function()
        isSearching = false
    end

    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(10), Scale(Config.UI.FrameSize.height) - Scale(200))
    stationListPanel:SetVisible(not settingsMenuOpen)

    local stopButtonHeight = Scale(Config.UI.FrameSize.width) / 8
    local stopButtonWidth = Scale(Config.UI.FrameSize.width) / 4
    local stopButtonText = Config.Lang["StopRadio"] or "STOP"
    local stopButtonFont = calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)

    local function createAnimatedButton(parent, x, y, w, h, text, textColor, bgColor, hoverColor, clickFunc)
        local button = vgui.Create("DButton", parent)
        button:SetPos(x, y)
        button:SetSize(w, h)
        button:SetText(text)
        button:SetTextColor(textColor)
        button.bgColor = bgColor
        button.hoverColor = hoverColor
        button.lerp = 0
        
        button.Paint = function(self, w, h)
            local color = LerpColor(self.lerp, self.bgColor, self.hoverColor)
            draw.RoundedBox(8, 0, 0, w, h, color)
        end
        
        button.Think = function(self)
            if self:IsHovered() then
                self.lerp = math.Approach(self.lerp, 1, FrameTime() * 5)
            else
                self.lerp = math.Approach(self.lerp, 0, FrameTime() * 5)
            end
        end
        
        button.DoClick = clickFunc
        
        return button
    end

    local stopButton = createAnimatedButton(
        frame, 
        Scale(10), 
        Scale(Config.UI.FrameSize.height) - Scale(90), 
        stopButtonWidth, 
        stopButtonHeight, 
        stopButtonText, 
        Config.UI.TextColor, 
        Config.UI.CloseButtonColor, 
        Config.UI.CloseButtonHoverColor, 
        function()
            surface.PlaySound("buttons/button6.wav")
            local entity = LocalPlayer().currentRadioEntity
            if not IsValid(entity) then return end

            -- Get actual vehicle entity
            entity = utils.GetVehicle(entity) or entity
            
            -- Send stop request to server
            net.Start("StopCarRadioStation")
                net.WriteEntity(entity)
            net.SendToServer()
            
            -- Clean up local state immediately
            local entIndex = entity:EntIndex()
            StreamManager:CleanupStream(entIndex)
            
            if currentlyPlayingStations[entity] then
                currentlyPlayingStations[entity] = nil
                StateManager:SetState("currentlyPlayingStations", currentlyPlayingStations)
            end
            
            -- Update UI
            populateList(stationListPanel, backButton, searchBox, false)
            if backButton then
                backButton:SetVisible(selectedCountry ~= nil or settingsMenuOpen)
                backButton:SetEnabled(selectedCountry ~= nil or settingsMenuOpen)
            end
        end
    )
    stopButton:SetFont(stopButtonFont)

    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
    volumePanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
    end

    local volumeIconSize = Scale(50)

    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
    volumeIcon:SetSize(volumeIconSize, volumeIconSize)
    volumeIcon:SetMaterial(VOLUME_ICONS.HIGH)

    local function updateVolumeIcon(volumeIcon, value)
        if not IsValid(volumeIcon) then return end
        
        local iconMat
        if type(value) == "function" then
            value = value()
        end
        
        if value < 0.05 then
            iconMat = VOLUME_ICONS.MUTE
        elseif value <= 0.65 then
            iconMat = VOLUME_ICONS.LOW
        else
            iconMat = VOLUME_ICONS.HIGH
        end
        
        if iconMat then
            volumeIcon:SetMaterial(iconMat)
        end
    end

    volumeIcon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.IconColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = 0.5

    if entityVolumes[entity] then
        currentVolume = entityVolumes[entity]
    else
        local entityConfig = getEntityConfig(entity)
        if entityConfig and entityConfig.Volume then
            currentVolume = type(entityConfig.Volume) == "function" 
                and entityConfig.Volume() 
                or entityConfig.Volume
        end
    end

    currentVolume = math.min(currentVolume, Config.MaxVolume())

    updateVolumeIcon(volumeIcon, currentVolume)
    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(-Scale(170), Scale(2))
    volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) + Scale(120) - stopButtonWidth, volumePanel:GetTall() - Scale(4))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(Config.MaxVolume())
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)

    volumeSlider.Slider.Paint = function(self, w, h)
        local centerY = h/2
        local trackHeight = Scale(12)
        local trackY = centerY - trackHeight/2

        draw.RoundedBox(trackHeight/2, 0, trackY, w, trackHeight, ColorAlpha(Config.UI.VolumeSliderColor, 100))
    end

    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        local knobSize = Scale(24)
        local offset = knobSize/2

        local shadowSize = Scale(2)
        local shadowAlpha = 100
        draw.RoundedBox(knobSize/2, shadowSize, shadowSize, knobSize, knobSize, 
            ColorAlpha(Color(0, 0, 0), shadowAlpha))
        
        -- Main knob
        draw.RoundedBox(knobSize/2, 0, 0, knobSize, knobSize, Config.UI.VolumeKnobColor)
        
        -- Hover effect
        if self:IsHovered() then
            draw.RoundedBox(knobSize/2, 0, 0, knobSize, knobSize, 
                ColorAlpha(Config.UI.TextColor, 20))
        end
    end

    volumeSlider.Slider.Knob:SetSize(Scale(24), Scale(24))
    volumeSlider.Slider.Knob:SetTall(Scale(24))

    volumeSlider.TextArea:SetVisible(false)

    local lastServerUpdate = 0
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        entity = utils.GetVehicle(entity) or entity
        value = math.min(value, Config.MaxVolume())

        entityVolumes[entity] = value

        local streamData = StreamManager.activeStreams[entity:EntIndex()]
        if streamData and IsValid(streamData.stream) then
            streamData.stream:SetVolume(value)
        end
        
        updateVolumeIcon(volumeIcon, value)

        local currentTime = CurTime()
        if currentTime - lastServerUpdate >= 0.1 then
            lastServerUpdate = currentTime
            net.Start("UpdateRadioVolume")
                net.WriteEntity(entity)
                net.WriteFloat(value)
            net.SendToServer()
        end
    end

    local sbar = stationListPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    local buttonSize = Scale(25)
    local topMargin = Scale(7)
    local buttonPadding = Scale(5)

    local closeButton = createAnimatedButton(
        frame, 
        frame:GetWide() - buttonSize - Scale(10), 
        topMargin, 
        buttonSize, 
        buttonSize, 
        "", 
        Config.UI.TextColor, 
        Color(0, 0, 0, 0), 
        Config.UI.ButtonHoverColor, 
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            frame:Close()
        end
    )
    closeButton.Paint = function(self, w, h)
        surface.SetMaterial(Material("hud/close.png"))
        surface.SetDrawColor(ColorAlpha(Config.UI.IconColor, 255 * (0.5 + 0.5 * self.lerp)))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    local settingsButton = createAnimatedButton(
        frame, 
        closeButton:GetX() - buttonSize - buttonPadding, 
        topMargin, 
        buttonSize, 
        buttonSize, 
        "", 
        Config.UI.TextColor, 
        Color(0, 0, 0, 0), 
        Config.UI.ButtonHoverColor, 
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            settingsMenuOpen = true
            openSettingsMenu(currentFrame, backButton)
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
            searchBox:SetVisible(false)
            stationListPanel:SetVisible(false)
        end
    )
    settingsButton.Paint = function(self, w, h)
        surface.SetMaterial(Material("hud/settings.png"))
        surface.SetDrawColor(ColorAlpha(Config.UI.IconColor, 255 * (0.5 + 0.5 * self.lerp)))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    backButton = createAnimatedButton(
        frame, 
        settingsButton:GetX() - buttonSize - buttonPadding, 
        topMargin, 
        buttonSize, 
        buttonSize, 
        "", 
        Config.UI.TextColor, 
        Color(0, 0, 0, 0), 
        Config.UI.ButtonHoverColor, 
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            
            if settingsMenuOpen then
                -- Remove settings instantly
                settingsMenuOpen = false
                StateManager:SetState("settingsMenuOpen", false)
                if IsValid(settingsFrame) then
                    settingsFrame:Remove()
                    settingsFrame = nil
                end
                
                -- Show main content immediately
                searchBox:SetVisible(true)
                stationListPanel:SetVisible(true)
                
                local currentCountry = StateManager:GetState("selectedCountry")
                backButton:SetVisible(currentCountry ~= nil)
                backButton:SetEnabled(currentCountry ~= nil)
            else
                -- Handle country/favorites navigation
                local currentCountry = StateManager:GetState("selectedCountry")
                if currentCountry then
                    -- Instantly switch back to country list
                    StateManager:SetState("selectedCountry", nil)
                    StateManager:SetState("favoritesMenuOpen", false)
                    selectedCountry = nil
                    favoritesMenuOpen = false
                    
                    populateList(stationListPanel, backButton, searchBox, true)
                    
                    backButton:SetVisible(false)
                    backButton:SetEnabled(false)
                end
            end
        end
    )
    backButton.Paint = function(self, w, h)
        if self:IsVisible() then
            surface.SetMaterial(Material("hud/return.png"))
            surface.SetDrawColor(ColorAlpha(Config.UI.IconColor, 255 * (0.5 + 0.5 * self.lerp)))
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    backButton:SetVisible((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
    backButton:SetEnabled((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)

    if not settingsMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)
    else
        openSettingsMenu(currentFrame, backButton)
    end

    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end

    _G.openRadioMenu = openRadioMenu
end

-- ------------------------------
--      Hooks and Net Messages
-- ------------------------------

--[[
    Hook: Think
    Opens the car radio menu when the player presses the designated key.
]]
hook.Add("Think", "OpenCarRadioMenu", function()
    local openKey = GetConVar("car_radio_open_key"):GetInt()
    local ply = LocalPlayer()
    
    -- Validate player and key state
    if not IsValid(ply) or not openKey then return end
    if ply:IsTyping() then return end
    
    -- Get current time and last press time with proper default
    local currentTime = CurTime()
    local keyPressDelay = 0.2 -- Define delay constant
    local lastPress = getSafeState("lastKeyPress", 0)

    -- Check if key is pressed and enough time has passed
    if not input.IsKeyDown(openKey) then return end
    if (currentTime - lastPress) <= keyPressDelay then return end
    
    -- Update last key press time
    setSafeState("lastKeyPress", currentTime)

    -- Handle menu close if already open
    if radioMenuOpen and not isSearching then
        surface.PlaySound("buttons/lightswitch2.wav")
        if IsValid(currentFrame) then
            currentFrame:Close()
        end
        radioMenuOpen = false
        selectedCountry = nil
        settingsMenuOpen = false
        favoritesMenuOpen = false
        return
    end

    -- Check vehicle state
    local vehicle = ply:GetVehicle()
    if not IsValid(vehicle) then return end
    
    -- Validate that it's not a sit anywhere seat
    if utils.isSitAnywhereSeat(vehicle) then
        return
    end

    -- Open menu if all checks pass
    ply.currentRadioEntity = vehicle
    openRadioMenu()
end)

--[[
    Network Receiver: UpdateRadioStatus
    Updates the status of the boombox.
]]
net.Receive("UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local isPlaying = net.ReadBool()
    local status = net.ReadString()

    if not IsValid(entity) then return end

    -- Update local state
    local statusData = {
        stationStatus = status,
        stationName = stationName,
        isPlaying = isPlaying
    }

    BoomboxStatuses[entity:EntIndex()] = statusData
    StateManager:SetState("boomboxStatuses", BoomboxStatuses)

    -- Update entity networked vars
    entity:SetNWString("Status", status)
    entity:SetNWString("StationName", stationName)
    entity:SetNWBool("IsPlaying", isPlaying)

    if status == "playing" then
        currentlyPlayingStations[entity] = { name = stationName }
        StateManager:SetState("currentlyPlayingStations", currentlyPlayingStations)
    elseif status == "stopped" then
        currentlyPlayingStations[entity] = nil
        StateManager:SetState("currentlyPlayingStations", currentlyPlayingStations)
    end

    -- Emit status change event
    StateManager:Emit(StateManager.Events.RADIO_STATUS_CHANGED, entity, statusData)
end)

--[[
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station on the client.
]]
net.Receive("PlayCarRadioStation", function()
    if not streamsEnabled then return end
    
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end

    local entIndex = entity:EntIndex()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    -- Update local state immediately
    if not BoomboxStatuses[entIndex] then
        BoomboxStatuses[entIndex] = {}
    end
    BoomboxStatuses[entIndex] = {
        stationStatus = "playing",
        stationName = stationName,
        url = url
    }

    sound.PlayURL(url, "3d", function(station, errorID, errorName)
        if not IsValid(station) then
            print("[Radio] Error creating sound stream:", errorName)
            utils.playErrorSound("connection")
            if IsValid(entity) then
                utils.clearRadioStatus(entity)
            end
            return
        end
        
        if not IsValid(entity) then
            station:Stop()
            utils.playErrorSound("connection")
            return
        end

        -- Register with StreamManager
        if not StreamManager:RegisterStream(entity, station, {
            name = stationName,
            url = url,
            volume = volume
        }) then
            station:Stop()
            return
        end

        -- Configure sound
        station:SetPos(entity:GetPos())
        station:SetVolume(volume)
        station:Play()
    end)
end)

-- Update the stop handler
net.Receive("StopCarRadioStation", function()
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end
    
    -- Get the actual vehicle entity
    entity = utils.GetVehicle(entity) or entity
    if not IsValid(entity) then return end

    -- Clean up through StreamManager
    local entIndex = entity:EntIndex()
    StreamManager:CleanupStream(entIndex)
    
    -- Clear local state
    if currentlyPlayingStations[entity] then
        currentlyPlayingStations[entity] = nil
        StateManager:SetState("currentlyPlayingStations", currentlyPlayingStations)
    end
    
    -- Clear status for boomboxes
    if utils.IsBoombox(entity) then
        utils.clearRadioStatus(entity)
    end
end)

--[[
    Network Receiver: OpenRadioMenu
    Opens the radio menu for a given entity.
]]
net.Receive("OpenRadioMenu", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local ply = LocalPlayer()
    local currentTime = CurTime()

    if ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox" then
        -- Validate interaction permissions
        if utils.canInteractWithBoombox(ply, ent) then
            ply.currentRadioEntity = ent
            StateManager:SetState("currentRadioEntity", ent)
            
            if not radioMenuOpen then
                openRadioMenu()
            end
        else
            -- Rate-limited permission message
            if currentTime - lastPermissionMessage >= PERMISSION_MESSAGE_COOLDOWN then
                chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
                lastPermissionMessage = currentTime
                StateManager:SetState("lastPermissionMessage", currentTime)
            end
        end
    end
end)

net.Receive("CarRadioMessage", function()
    if GetConVar("car_radio_show_messages"):GetBool() then
        PrintCarRadioMessage()
    end
end)

net.Receive("RadioConfigUpdate", function()
    -- Update all active radio volumes with validation
    for entity, source in pairs(currentRadioSources) do
        if IsValid(entity) and IsValid(source) then
            local entityConfig = getEntityConfig(entity)
            if entityConfig and entityConfig.Volume then
                local volume = ClampVolume(entityVolumes[entity] or entityConfig.Volume())
                source:SetVolume(volume)
            end
        else
            -- Cleanup invalid entries
            if IsValid(source) then
                source:Stop()
            end
            currentRadioSources[entity] = nil
            StateManager:SetState("currentRadioSources", currentRadioSources)
        end
    end
    
    -- Update station count after cleanup
    StateManager:SetState("activeStationCount", updateStationCount())
end)

-- ------------------------------
--      Cleanup Hooks
-- ------------------------------

-- Entity cleanup
hook.Add("EntityRemoved", "RadioCleanup", function(entity)
    if IsValid(entity) then
        StreamManager:CleanupStream(entity:EntIndex())
    end
end)

-- Vehicle state cleanup
hook.Add("VehicleChanged", "RadioVehicleCleanup", function(ply, old, new)
    if ply ~= LocalPlayer() then return end
    
    if not new then
        ply.currentRadioEntity = nil
        StateManager:SetState("currentRadioEntity", nil)
    end
end)

-- Periodic validation
timer.Create("RadioStateValidation", 30, 0, function()
    -- Validate and cleanup streams
    for entIndex, streamData in pairs(StreamManager.activeStreams) do
        if not IsValid(streamData.entity) or not IsValid(streamData.stream) then
            StreamManager:CleanupStream(entIndex)
        end
    end
end)

StateManager:On(StateManager.Events.FAVORITES_LOADED, function(data)
    favoriteCountries = data.countries
    favoriteStations = data.stations
end)

-- Initialize theme
local function initializeTheme()
    local themeName = GetConVar("radio_theme"):GetString()
    if themeModule.themes[themeName] and themeModule.factory:validateTheme(themeModule.themes[themeName]) then
        Config.UI = themeModule.themes[themeName]
    else
        -- Fallback to default theme
        Config.UI = themeModule.factory:getDefaultThemeData()
        RunConsoleCommand("radio_theme", themeModule.factory:getDefaultTheme())
    end
end

hook.Add("Initialize", "InitializeRadioTheme", initializeTheme)

hook.Add("Think", "UpdateStreamPositions", function()
    local currentTime = CurTime()
    
    if (currentTime - lastStreamUpdate) < STREAM_UPDATE_INTERVAL then
        return
    end
    
    lastStreamUpdate = currentTime

    local ply = LocalPlayer()
    local plyPos = ply:GetPos()

    -- Cache IsValid results at start
    local validStreams = {}
    for entIndex, streamData in pairs(StreamManager.activeStreams) do
        if IsValid(streamData.entity) and IsValid(streamData.stream) then
            validStreams[entIndex] = streamData
        else
            StreamManager:QueueCleanup(entIndex, "invalid_reference")
        end
    end

    -- Use cached valid streams
    for entIndex, streamData in pairs(validStreams) do
        local entity = streamData.entity
        local stream = streamData.stream
        
        stream:SetPos(entity:GetPos())
        
        local distanceSqr = plyPos:DistToSqr(entity:GetPos())
        local isPlayerInCar = false
        
        if entity:IsVehicle() then
            local vehicle = utils.GetVehicle(entity)
            isPlayerInCar = (vehicle:GetDriver() == ply)
        end
        
        updateRadioVolume(stream, distanceSqr, isPlayerInCar, entity)
    end
end)

hook.Add("Think", "UpdateStreamValidityCache", function()
    StreamManager:UpdateValidityCache()
end)

local UIReferenceTracker = {
    references = {},
    validityCache = {},
    lastCheck = 0,
    CHECK_INTERVAL = 0.5,
    
    Track = function(self, element, id)
        self.references[id] = element
        self.validityCache[id] = true
    end,
    
    Untrack = function(self, id)
        self.references[id] = nil
        self.validityCache[id] = nil
    end,
    
    IsValid = function(self, id)
        return self.validityCache[id] == true
    end,
    
    Update = function(self)
        local currentTime = CurTime()
        if (currentTime - self.lastCheck) < self.CHECK_INTERVAL then
            return
        end
        
        self.lastCheck = currentTime
        
        for id, element in pairs(self.references) do
            self.validityCache[id] = IsValid(element)
            if not self.validityCache[id] then
                self.references[id] = nil
            end
        end
    end
}

hook.Add("Think", "UpdateUIReferences", function()
    UIReferenceTracker:Update()
end)
