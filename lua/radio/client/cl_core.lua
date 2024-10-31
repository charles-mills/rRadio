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

-- ------------------------------
--      Station Data Loading
-- ------------------------------

--[[
    Function: LoadStationData
    Loads station data from files, ensuring it's loaded only once.
]]
local function LoadStationData()
    if stationDataLoaded then return end
    StationData = {}
    
    local dataFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
    for _, filename in ipairs(dataFiles) do
        local success, data = pcall(include, "radio/client/stations/" .. filename)
        if success and data then
            for country, stations in pairs(data) do
                -- Extract base country name by removing any suffixes like '_number'
                local baseCountry = country:gsub("_(%d+)$", "")
                if not StationData[baseCountry] then
                    StationData[baseCountry] = {}
                end
                for _, station in ipairs(stations) do
                    table.insert(StationData[baseCountry], { name = station.n, url = station.u })
                end
            end
        else
            print("[rRadio] Error loading station data from: " .. filename)
        end
    end
    
    stationDataLoaded = true
    StateManager:SetState("stationDataLoaded", true)
    StateManager:SetState("stationData", StationData)
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
        
        -- Cleanup any existing stream first
        self:CleanupStream(entity:EntIndex())
        
        -- Register new stream
        self.activeStreams[entity:EntIndex()] = {
            stream = stream,
            entity = entity,
            data = data,
            startTime = CurTime()
        }
        
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

        -- Wait for cleanup to complete
        timer.Simple(0.2, function()
            if not IsValid(entity) then return end

            -- Start new playback
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(station.name)
                net.WriteString(station.url)
                net.WriteFloat(volume)
            net.SendToServer()

            -- Update state
            StateManager:SetState("currentlyPlayingStations", {
                [entity] = station
            })
            StateManager:SetState("lastStationSelectTime", CurTime())
        end)
    else
        -- If no station is playing, start playback immediately
        net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(station.name)
            net.WriteString(station.url)
            net.WriteFloat(volume)
        net.SendToServer()

        -- Update state
        StateManager:SetState("currentlyPlayingStations", {
            [entity] = station
        })
        StateManager:SetState("lastStationSelectTime", CurTime())
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
    panel:MoveToFront()

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
        local bgColor = Config.UI.HeaderColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(
            math.min(bgColor.r * hoverBrightness, 255),
            math.min(bgColor.g * hoverBrightness, 255),
            math.min(bgColor.b * hoverBrightness, 255),
            alpha * 255
        )
        
        -- Main background with rounded corners only on the left side
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)

        -- Key highlight box with pulse animation
        local keyWidth = Scale(40)
        local keyHeight = Scale(30)
        local keyX = Scale(20)
        local keyY = h/2 - keyHeight/2
        local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
        local adjustedKeyWidth = keyWidth * pulseScale
        local adjustedKeyHeight = keyHeight * pulseScale
        local adjustedKeyX = keyX - (adjustedKeyWidth - keyWidth) / 2
        local adjustedKeyY = keyY - (adjustedKeyHeight - keyHeight) / 2
        
        draw.RoundedBox(6, adjustedKeyX, adjustedKeyY, adjustedKeyWidth, adjustedKeyHeight, 
            ColorAlpha(Config.UI.ButtonColor, alpha * 255))

        -- Separator line
        surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, alpha * 50))
        surface.DrawLine(keyX + keyWidth + Scale(7), h * 0.3, 
                        keyX + keyWidth + Scale(7), h * 0.7)

        -- Draw key text
        draw.SimpleText(keyName, "Roboto18", keyX + keyWidth/2, h/2, 
            ColorAlpha(Config.UI.TextColor, alpha * 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Draw message text
        local messageX = keyX + keyWidth + Scale(15)
        draw.SimpleText(Config.Lang["ToOpenRadio"] or "to open radio", "Roboto18", 
            messageX, h/2, ColorAlpha(Config.UI.TextColor, alpha * 255), 
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)

    local isFavorite = station and 
        (getSafeState("favoriteStations", {})[country] and 
         getSafeState("favoriteStations", {})[country][station.name]) or 
        (not station and getSafeState("favoriteCountries", {})[country])

    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")

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

    -- Create a button with consistent styling
    local function createStyledButton(parent, text, onClick)
        local button = vgui.Create("DButton", parent)
        button:Dock(TOP)
        button:DockMargin(Scale(5), Scale(5), Scale(5), 0)
        button:SetTall(Scale(40))
        button:SetText(text)
        button:SetFont("Roboto18")
        button:SetTextColor(Config.UI.TextColor)

        button.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor
            draw.RoundedBox(8, 0, 0, w, h, bgColor)
        end

        if onClick then
            button.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                onClick(button)
            end
        end

        return button
    end

    -- Create a separator line
    local function createSeparator()
        local separator = vgui.Create("DPanel", stationListPanel)
        separator:Dock(TOP)
        separator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        separator:SetTall(Scale(2))
        separator.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonColor)
        end
        return separator
    end

    if selectedCountry == nil then
        -- Check for favorites first
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

        -- Create favorites section if needed
        if hasFavorites then
            createSeparator()

            local favoritesButton = createStyledButton(
                stationListPanel,
                Config.Lang["FavoriteStations"] or "Favorite Stations",
                function()
                    StateManager:SetState("selectedCountry", "favorites")
                    StateManager:SetState("favoritesMenuOpen", true)
                    if backButton then 
                        backButton:SetVisible(true)
                        backButton:SetEnabled(true)
                    end
                    updateList()
                end
            )

            -- Move text to the right to make room for icon
            favoritesButton:SetTextInset(Scale(40), 0)

            -- Add favorites icon with proper positioning and scaling
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

        -- Populate countries list
        local countries = {}
        for country, _ in pairs(StationData) do
            -- Format and translate the country name
            local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
                return first:upper() .. rest:lower()
            end)
            
            local translatedCountry = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry

            if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
                -- Check if country is in favorites using StateManager
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
                    -- Always use the raw country code for storage
                    local countryCode = country.original  -- This should be the unformatted code
                    
                    StateManager:SetState("selectedCountry", countryCode)
                    if backButton then backButton:SetVisible(true) end
                    
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
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                else
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                    if self:IsHovered() then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end

                -- Add visual indicators for stream status
                local streamData = StreamManager.activeStreams[entity:EntIndex()]
                if streamData then
                    if streamData.stream and not streamData.stream:IsValid() then
                        -- Red indicator for invalid stream
                        surface.SetDrawColor(255, 0, 0, 50)
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
        dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        dropdown:SetValue(currentValue)
        dropdown:SetTextColor(Config.UI.TextColor)
        dropdown:SetFont("Roboto18")

        dropdown.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
            self:DrawTextEntryText(Config.UI.TextColor, Config.UI.ButtonHoverColor, Config.UI.TextColor)
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

        -- Add state management and validation
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

    addDropdown(Config.Lang["SelectLanguage"] or "Select Language", languageChoices, currentLanguageName, function(_, _, _, data)
        if not data then return end
        
        -- Validate language selection
        if not LanguageManager:IsValidLanguage(data) then
            print("[rRadio] Warning: Invalid language selected:", data)
            return
        end

        RunConsoleCommand("radio_language", data)
        LanguageManager:SetLanguage(data)
        Config.Lang = LanguageManager.translations[data]
        
        StateManager:SetState("currentLanguage", data)
        StateManager:Emit(StateManager.Events.LANGUAGE_CHANGED, data)

        -- Reset cached country names
        StateManager:SetState("formattedCountryNames", {})

        -- Reload station data
        stationDataLoaded = false
        LoadStationData()

        -- Safely close and reopen the menu
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

    addHeader(Config.Lang["SelectKeyToOpenRadioMenu"] or "Select Key to Open Radio Menu")
    local keyChoices = {}
    if keyCodeMapping then
        for keyCode, keyName in pairs(keyCodeMapping) do
            table.insert(keyChoices, {name = keyName, data = keyCode})
        end
        table.sort(keyChoices, function(a, b) return a.name < b.name end)
    else
        table.insert(keyChoices, {name = "K", data = KEY_K})
    end

    local currentKey = GetConVar("car_radio_open_key"):GetInt()
    local currentKeyName = (keyCodeMapping and keyCodeMapping[currentKey]) or "K"

    addDropdown(Config.Lang["SelectKey"] or "Select Key", keyChoices, currentKeyName, function(_, _, _, data)
        RunConsoleCommand("car_radio_open_key", data)
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

        -- Get header text based on menu state
        local headerText
        if settingsMenuOpen then
            headerText = Config.Lang["Settings"] or "Settings"
        elseif selectedCountry then
            if selectedCountry == "favorites" then
                headerText = Config.Lang["FavoriteStations"] or "Favorite Stations"
            else
                -- Format and translate the country name
                local formattedCountry = selectedCountry:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) 
                    return string.upper(a) .. string.lower(b) 
                end)
                local lang = GetConVar("radio_language"):GetString() or "en"
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
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(200))
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
            if IsValid(entity) then
                net.Start("StopCarRadioStation")
                    net.WriteEntity(entity)
                net.SendToServer()
                currentlyPlayingStation = nil
                currentlyPlayingStations[entity] = nil
                populateList(stationListPanel, backButton, searchBox, false)
                if backButton then
                    backButton:SetVisible(selectedCountry ~= nil or settingsMenuOpen)
                    backButton:SetEnabled(selectedCountry ~= nil or settingsMenuOpen)
                end
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
        surface.SetDrawColor(Config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = 0.5

    if IsValid(entity) then
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
    end

    updateVolumeIcon(volumeIcon, currentVolume)
    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(-Scale(170), Scale(5))
    volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) + Scale(120) - stopButtonWidth, volumePanel:GetTall() - Scale(20))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(Config.MaxVolume())
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)

    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, h / 2 - 4, w, 16, Config.UI.TextColor)
    end

    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
    end

    volumeSlider.TextArea:SetVisible(false)

    local lastServerUpdate = 0
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then return end

        entity = utils.GetVehicle(entity) or entity
        value = math.min(value, Config.MaxVolume())
        
        -- Update local volume immediately for responsive UI
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
        
        updateVolumeIcon(volumeIcon, value)

        -- Send to server with debounce
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
        surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
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
        surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
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
                settingsMenuOpen = false
                StateManager:SetState("settingsMenuOpen", false)
                if IsValid(settingsFrame) then
                    settingsFrame:Remove()
                    settingsFrame = nil
                end
                searchBox:SetVisible(true)
                stationListPanel:SetVisible(true)

                stationDataLoaded = false
                LoadStationData()
                timer.Simple(0, function()
                    populateList(stationListPanel, backButton, searchBox, true)
                end)
                
                backButton:SetVisible(StateManager:GetState("selectedCountry") ~= nil)
                backButton:SetEnabled(StateManager:GetState("selectedCountry") ~= nil)
            else
                -- Reset country selection and update UI
                StateManager:SetState("selectedCountry", nil)
                StateManager:SetState("favoritesMenuOpen", false)
                backButton:SetVisible(false)
                backButton:SetEnabled(false)
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    )
    backButton.Paint = function(self, w, h)
        if self:IsVisible() then
            surface.SetMaterial(Material("hud/return.png"))
            surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
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

    -- Create new sound stream with error handling
    sound.PlayURL(url, "3d noblock", function(station, errorID, errorName)
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
    
    entity = utils.GetVehicle(entity)
    if not IsValid(entity) then return end

    -- Queue cleanup through StreamManager
    StreamManager:QueueCleanup(entity:EntIndex(), "user_stopped")
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
