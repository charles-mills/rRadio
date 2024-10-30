--[[
    Radio Addon Client-Side Core Functionality
    Author: Charles Mills
    Description: This file implements the main client-side features of the Radio Addon.
                 It includes the user interface for the radio menu, handles playback of
                 radio stations, manages favorites, and processes network messages from
                 the server. It also includes various utility functions for UI elements,
                 sound management, and entity interactions.
    Date: October 30, 2024
]]--

-- ------------------------------
--          Imports
-- ------------------------------
include("radio/shared/sh_config.lua")
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
local themes = include("radio/client/cl_themes.lua") or {}
local keyCodeMapping = include("radio/client/cl_key_names.lua")
local utils = include("radio/shared/sh_utils.lua")

-- ------------------------------
--      Global Variables
-- ------------------------------

-- Global table to store boombox statuses
BoomboxStatuses = BoomboxStatuses or {}

-- Favorite countries and stations stored as tables for JSON compatibility
local favoriteCountries = {}
local favoriteStations = {}

local dataDir = "rradio"
local favoriteCountriesFile = dataDir .. "/favorite_countries.json"
local favoriteStationsFile = dataDir .. "/favorite_stations.json"

-- Ensure the data directory exists
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

local currentFrame = nil
local settingsMenuOpen = false
local entityVolumes = {}
local openRadioMenu

local lastIconUpdate = 0
local iconUpdateDelay = 0.1
local pendingIconUpdate = nil
local isUpdatingIcon = false

local lastKeyPress = 0
local keyPressDelay = 0.2  -- Delay between key presses to prevent spamming

local favoritesMenuOpen = false

-- Add near the top with other local variables
local VOLUME_ICONS = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}

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
    Includes error handling and data validation.
]]
local function loadFavorites()
    -- Load favorite countries
    if file.Exists(favoriteCountriesFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(favoriteCountriesFile, "DATA"))
        end)
        
        if success and data then
            favoriteCountries = {}
            -- Validate each country entry
            for _, country in ipairs(data) do
                if type(country) == "string" then
                    favoriteCountries[country] = true
                end
            end
        else
            print("[Radio] Error loading favorite countries, resetting file")
            favoriteCountries = {}
            saveFavorites() -- Reset the file with empty data
        end
    end

    -- Load favorite stations
    if file.Exists(favoriteStationsFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(favoriteStationsFile, "DATA"))
        end)
        
        if success and data then
            favoriteStations = {}
            -- Validate each station entry
            for country, stations in pairs(data) do
                if type(country) == "string" and type(stations) == "table" then
                    favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if type(stationName) == "string" and type(isFavorite) == "boolean" then
                            favoriteStations[country][stationName] = isFavorite
                        end
                    end
                    -- Clean up empty country entries
                    if next(favoriteStations[country]) == nil then
                        favoriteStations[country] = nil
                    end
                end
            end
        else
            print("[Radio] Error loading favorite stations, resetting file")
            favoriteStations = {}
            saveFavorites() -- Reset the file with empty data
        end
    end
end

--[[
    Function: saveFavorites
    Saves favorite countries and stations to JSON files.
    Includes error handling and backup system.
]]
local function saveFavorites()
    -- Save favorite countries
    local favCountriesList = {}
    for country, _ in pairs(favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    
    local countriesJson = util.TableToJSON(favCountriesList, true) -- Pretty print for readability
    if countriesJson then
        -- Create backup of existing file if it exists
        if file.Exists(favoriteCountriesFile, "DATA") then
            file.Write(favoriteCountriesFile .. ".bak", file.Read(favoriteCountriesFile, "DATA"))
        end
        file.Write(favoriteCountriesFile, countriesJson)
    else
        print("[Radio] Error converting favorite countries to JSON")
    end

    -- Save favorite stations
    local favStationsTable = {}
    for country, stations in pairs(favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and type(isFavorite) == "boolean" then
                    favStationsTable[country][stationName] = isFavorite
                end
            end
            -- Clean up empty country entries
            if next(favStationsTable[country]) == nil then
                favStationsTable[country] = nil
            end
        end
    end
    
    local stationsJson = util.TableToJSON(favStationsTable, true) -- Pretty print for readability
    if stationsJson then
        -- Create backup of existing file if it exists
        if file.Exists(favoriteStationsFile, "DATA") then
            file.Write(favoriteStationsFile .. ".bak", file.Read(favoriteStationsFile, "DATA"))
        end
        file.Write(favoriteStationsFile, stationsJson)
    else
        print("[Radio] Error converting favorite stations to JSON")
    end
end

-- ------------------------------
--          UI Setup
-- ------------------------------

-- Font creation
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
local currentRadioSources = {}
local lastMessageTime = -math.huge
local lastStationSelectTime = 0
local currentlyPlayingStations = {}
local settingsMenuOpen = false

-- Caching formatted country names per language
local formattedCountryNames = {}
-- Flag to ensure station data is loaded only once
local stationDataLoaded = false

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
    if not IsValid(entity) then return nil end

    local entityClass = entity:GetClass()

    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    else
        return Config.VehicleRadio
    end
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

    -- Use the LanguageManager to get the translated country name
    local translatedName = LanguageManager:GetCountryTranslation(lang, name)

    formattedCountryNames[cacheKey] = translatedName
    return translatedName
end

--[[
    Function: updateRadioVolume
    Updates the volume of the radio station based on distance and whether the player is in the car.

    Parameters:
    - station: The sound station object.
    - distanceSqr: The squared distance between the player and the radio entity.
    - isPlayerInCar: Boolean indicating if the player is in the car.
    - entity: The radio entity.
]]
local function updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    if not entityConfig then return end

    local volume = ClampVolume(entityVolumes[entity] or entityConfig.Volume())
    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    -- Apply global volume limit
    local maxVolume = Config.MaxVolume()
    local effectiveVolume = math.min(volume, maxVolume)

    local minVolumeDistance = entityConfig.MinVolumeDistance()
    local maxHearingDistance = entityConfig.MaxHearingDistance()

    local distance = math.sqrt(distanceSqr)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    else
        if distance <= minVolumeDistance then
            station:SetVolume(effectiveVolume)
        elseif distance <= maxHearingDistance then
            local exponent = Config.VolumeAttenuationExponent
            local attenuationFactor = ((maxHearingDistance - distance) / (maxHearingDistance - minVolumeDistance)) ^ exponent
            attenuationFactor = math.Clamp(attenuationFactor, 0, 1)
            local adjustedVolume = effectiveVolume * attenuationFactor
            station:SetVolume(adjustedVolume)
        else
            station:SetVolume(0)
        end
    end
end

--[[
    Function: PrintCarRadioMessage
    Displays an animated notification about how to open the car radio.
]]
local function PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local vehicle = LocalPlayer():GetVehicle()
    if not IsValid(vehicle) or utils.isSitAnywhereSeat(vehicle) then return end

    local currentTime = CurTime()
    if (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge then
        return
    end

    lastMessageTime = currentTime

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

    -- Animation variables
    local animDuration = 0.3
    local showDuration = 3
    local startTime = CurTime()
    local alpha = 0
    local pulseValue = 0
    local isDismissed = false

    -- Click handler for the main panel
    panel.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        openRadioMenu()
        isDismissed = true
    end

    -- Main panel paint function
    panel.Paint = function(self, w, h)
        -- Background with dynamic alpha and hover effect
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

    -- Animation think
    panel.Think = function(self)
        local time = CurTime() - startTime
        
        -- Update pulse animation
        pulseValue = (pulseValue + FrameTime() * 2) % 1

        -- Slide in
        if time < animDuration then
            local progress = time / animDuration
            local easedProgress = math.ease.OutBack(progress)
            self:SetPos(Lerp(easedProgress, scrW, scrW - panelWidth), scrH * 0.2)
            alpha = progress
        -- Show
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos(scrW - panelWidth, scrH * 0.2)  -- Keep it at the edge
        -- Slide out
        elseif not isDismissed or time >= animDuration + showDuration then
            local progress = (time - (animDuration + showDuration)) / animDuration
            local easedProgress = math.ease.InQuint(progress)
            self:SetPos(Lerp(easedProgress, scrW - panelWidth, scrW), scrH * 0.2)
            alpha = 1 - easedProgress
            
            if progress >= 1 then
                self:Remove()
            end
        end
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

    -- Check if it's a station or country favorite
    local isFavorite = station and 
        (favoriteStations[country] and favoriteStations[country][station.name]) or 
        (not station and favoriteCountries[country])

    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        if station then
            -- Handle station favorite
            if not favoriteStations[country] then
                favoriteStations[country] = {}
            end

            if favoriteStations[country][station.name] then
                favoriteStations[country][station.name] = nil
                if next(favoriteStations[country]) == nil then
                    favoriteStations[country] = nil
                end
            else
                favoriteStations[country][station.name] = true
            end
        else
            -- Handle country favorite
            if favoriteCountries[country] then
                favoriteCountries[country] = nil
            else
                favoriteCountries[country] = true
            end
        end

        saveFavorites()

        -- Update the star icon
        local newIsFavorite = station and 
            (favoriteStations[country] and favoriteStations[country][station.name]) or 
            (not station and favoriteCountries[country])
        starIcon:SetImage(newIsFavorite and "hud/star_full.png" or "hud/star.png")

        -- Call the updateList function to refresh the list
        if updateList then
            updateList()
        end
    end

    return starIcon
end

-- ------------------------------
--      Station Data Loading
-- ------------------------------

-- Load station data
local StationData = {}

--[[
    Function: LoadStationData
    Loads station data from files, ensuring it's loaded only once.
]]
local function LoadStationData()
    if stationDataLoaded then return end
    
    -- Clear existing station data
    StationData = {}
    
    local dataFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
    for _, filename in ipairs(dataFiles) do
        local data = include("radio/client/stations/" .. filename)
        for country, stations in pairs(data) do
            -- Extract base country name by removing any suffixes like '_number' at the end
            local baseCountry = country:gsub("_(%d+)$", "")
            if not StationData[baseCountry] then
                StationData[baseCountry] = {}
            end
            for _, station in ipairs(stations) do
                table.insert(StationData[baseCountry], { name = station.n, url = station.u })
            end
        end
    end
    stationDataLoaded = true
end

-- Call LoadStationData at the beginning
LoadStationData()

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
    if not stationListPanel then
        return
    end

    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText():lower()
    local lang = GetConVar("radio_language"):GetString() or "en"

    local function updateList()
        populateList(stationListPanel, backButton, searchBox, false)
    end

    if selectedCountry == nil then
        -- Add Favorite Stations button at the top
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
            -- Add a top separator
            local topSeparator = vgui.Create("DPanel", stationListPanel)
            topSeparator:Dock(TOP)
            topSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            topSeparator:SetTall(Scale(2))
            topSeparator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonColor)
            end

            local favoritesButton = vgui.Create("DButton", stationListPanel)
            favoritesButton:Dock(TOP)
            favoritesButton:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            favoritesButton:SetTall(Scale(40))
            favoritesButton:SetText(Config.Lang["FavoriteStations"] or "Favorite Stations")
            favoritesButton:SetFont("Roboto18")
            favoritesButton:SetTextColor(Config.UI.TextColor)

            favoritesButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor
                draw.RoundedBox(8, 0, 0, w, h, bgColor)
                
                -- Add a star icon
                surface.SetMaterial(Material("hud/star_full.png"))
                surface.SetDrawColor(Config.UI.TextColor)
                surface.DrawTexturedRect(Scale(10), h/2 - Scale(12), Scale(24), Scale(24))
            end

            favoritesButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = "favorites"
                favoritesMenuOpen = true
                if backButton then 
                    backButton:SetVisible(true)
                    backButton:SetEnabled(true)
                end
                populateList(stationListPanel, backButton, searchBox, true)
            end

            local bottomSeparator = vgui.Create("DPanel", stationListPanel)
            bottomSeparator:Dock(TOP)
            bottomSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            bottomSeparator:SetTall(Scale(2))
            bottomSeparator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonColor)
            end
        end

        local countries = {}
        for country, _ in pairs(StationData) do
            -- Convert from lowercase_with_underscores to Title Case With Spaces
            local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
                return first:upper() .. rest:lower()
            end)
            
            local translatedCountry = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry

            if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
                table.insert(countries, { 
                    original = country, 
                    translated = translatedCountry, 
                    isPrioritized = favoriteCountries[country] 
                })
            end
        end

        table.sort(countries, function(a, b)
            if a.isPrioritized ~= b.isPrioritized then
                return a.isPrioritized
            end
            return a.translated < b.translated
        end)

        for _, country in ipairs(countries) do
            local countryButton = vgui.Create("DButton", stationListPanel)
            countryButton:Dock(TOP)
            countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            countryButton:SetTall(Scale(40))
            countryButton:SetText(country.translated)
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end

            -- Add the star icon with the updateList function
            createStarIcon(countryButton, country.original, nil, updateList)

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end

        -- Set back button visibility
        if backButton then
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
        end
    elseif selectedCountry == "favorites" then
        -- Display all favorite stations
        local favoritesList = {}
        
        for country, stations in pairs(favoriteStations) do
            if StationData[country] then
                for _, station in ipairs(StationData[country]) do
                    if stations[station.name] and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                        -- Format country name the same way
                        local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
                            return first:upper() .. rest:lower()
                        end)
                        
                        local translatedName = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry

                        table.insert(favoritesList, {
                            station = station,
                            country = country,
                            countryName = translatedName
                        })
                    end
                end
            end
        end

        -- Sort favorites by country name then station name
        table.sort(favoritesList, function(a, b)
            if a.countryName == b.countryName then
                return a.station.name < b.station.name
            end
            return a.countryName < b.countryName
        end)

        for _, favorite in ipairs(favoritesList) do
            local stationButton = vgui.Create("DButton", stationListPanel)
            stationButton:Dock(TOP)
            stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            stationButton:SetTall(Scale(40))
            stationButton:SetText(favorite.countryName .. " - " .. favorite.station.name)
            stationButton:SetFont("Roboto18")
            stationButton:SetTextColor(Config.UI.TextColor)

            stationButton.Paint = function(self, w, h)
                local entity = LocalPlayer().currentRadioEntity
                if IsValid(entity) and currentlyPlayingStations[entity] and 
                   currentlyPlayingStations[entity].name == favorite.station.name then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                else
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                    if self:IsHovered() then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end
            end

            createStarIcon(stationButton, favorite.country, favorite.station, updateList)

            stationButton.DoClick = function()
                local currentTime = CurTime()

                -- Check if the cooldown has passed
                if currentTime - lastStationSelectTime < 2 then
                    return  -- Exit the function if the cooldown hasn't passed
                end

                surface.PlaySound("buttons/button17.wav")
                local entity = LocalPlayer().currentRadioEntity

                if not IsValid(entity) then
                    return
                end

                -- Stop any existing station first
                if currentlyPlayingStations[entity] then
                    net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                    net.SendToServer()
                end

                -- Get the current entity config and volume
                local entityConfig = getEntityConfig(entity)
                local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5

                -- Start a new net message after the stop message is complete
                timer.Simple(0, function()
                    if not IsValid(entity) then return end
                    
                    net.Start("PlayCarRadioStation")
                        net.WriteEntity(entity)
                        net.WriteString(favorite.station.name)
                        net.WriteString(favorite.station.url)
                        net.WriteFloat(volume) -- Write the actual float value, not the function
                    net.SendToServer()

                    currentlyPlayingStations[entity] = favorite.station
                    lastStationSelectTime = currentTime
                    populateList(stationListPanel, backButton, searchBox, false)
                end)
            end
        end
    else
        local stations = StationData[selectedCountry] or {}
        local favoriteStationsList = {}

        for _, station in ipairs(stations) do
            if station and station.name and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                local isFavorite = favoriteStations[selectedCountry] and favoriteStations[selectedCountry][station.name]
                table.insert(favoriteStationsList, { station = station, favorite = isFavorite })
            end
        end

        table.sort(favoriteStationsList, function(a, b)
            if a.favorite ~= b.favorite then
                return a.favorite
            end
            return (a.station.name or "") < (b.station.name or "")
        end)

        for _, stationData in ipairs(favoriteStationsList) do
            local station = stationData.station
            local stationButton = vgui.Create("DButton", stationListPanel)
            stationButton:Dock(TOP)
            stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            stationButton:SetTall(Scale(40))
            stationButton:SetText(station.name)
            stationButton:SetFont("Roboto18")
            stationButton:SetTextColor(Config.UI.TextColor)

            stationButton.Paint = function(self, w, h)
                local entity = LocalPlayer().currentRadioEntity
                if IsValid(entity) and station == currentlyPlayingStations[entity] then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                else
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                    if self:IsHovered() then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end
            end

            createStarIcon(stationButton, selectedCountry, station, updateList)

            stationButton.DoClick = function()
                local currentTime = CurTime()

                -- Check if the cooldown has passed
                if currentTime - lastStationSelectTime < 2 then
                    return  -- Exit the function if the cooldown hasn't passed
                end

                surface.PlaySound("buttons/button17.wav")
                local entity = LocalPlayer().currentRadioEntity

                if not IsValid(entity) then
                    return
                end

                -- Stop any existing station first
                if currentlyPlayingStations[entity] then
                    net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                    net.SendToServer()
                end

                -- Get the current entity config and volume
                local entityConfig = getEntityConfig(entity)
                local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5

                -- Start a new net message after the stop message is complete
                timer.Simple(0, function()
                    if not IsValid(entity) then return end
                    
                    net.Start("PlayCarRadioStation")
                        net.WriteEntity(entity)
                        net.WriteString(station.name)
                        net.WriteString(station.url)
                        net.WriteFloat(volume) -- Write the actual float value, not the function
                    net.SendToServer()

                    currentlyPlayingStations[entity] = station
                    lastStationSelectTime = currentTime
                    populateList(stationListPanel, backButton, searchBox, false)
                end)
            end
        end

        -- Set back button visibility
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
        dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))  -- Reduced vertical margins
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

        checkbox.OnChange = function(self, value)
            RunConsoleCommand(convar, value and "1" or "0")
        end

        return checkbox
    end

    -- Theme Selection
    addHeader(Config.Lang["ThemeSelection"] or "Theme Selection", true)  -- Set isFirst to true for the first header
    local themeChoices = {}
    if themes then
        for themeName, _ in pairs(themes) do
            table.insert(themeChoices, {name = themeName:gsub("^%l", string.upper), data = themeName})
        end
    end
    local currentTheme = GetConVar("radio_theme"):GetString()
    local currentThemeName = currentTheme:gsub("^%l", string.upper)
    addDropdown(Config.Lang["SelectTheme"] or "Select Theme", themeChoices, currentThemeName, function(_, _, value)
        local lowerValue = value:lower()
        if themes and themes[lowerValue] then
            RunConsoleCommand("radio_theme", lowerValue)
            Config.UI = themes[lowerValue]
            parentFrame:Close()
            reopenRadioMenu(true)  -- Reopen and open settings menu
        end
    end)

    -- Language Selection
    addHeader(Config.Lang["LanguageSelection"] or "Language Selection")
    local languageChoices = {}
    for code, name in pairs(LanguageManager:GetAvailableLanguages()) do
        table.insert(languageChoices, {name = name, data = code})
    end

    local currentLanguage = GetConVar("radio_language"):GetString()
    local currentLanguageName = LanguageManager:GetLanguageName(currentLanguage)

    addDropdown(Config.Lang["SelectLanguage"] or "Select Language", languageChoices, currentLanguageName, function(_, _, _, data)
        RunConsoleCommand("radio_language", data)
        LanguageManager:SetLanguage(data)
        Config.Lang = LanguageManager.translations[data]
        
        -- Clear the formatted country names cache
        formattedCountryNames = {}
        
        -- Reset station data loaded flag to force reload
        stationDataLoaded = false
        LoadStationData()
        
        -- Close and reopen the menu to apply changes
        if IsValid(currentFrame) then
            currentFrame:Close()
            timer.Simple(0.1, function()
                if openRadioMenu then
                    -- Force a full menu reset
                    radioMenuOpen = false
                    selectedCountry = nil
                    settingsMenuOpen = false
                    favoritesMenuOpen = false
                    
                    openRadioMenu(true)  -- Reopen with settings menu
                end
            end)
        end
    end)

    -- Key Selection
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

    -- General Options
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

            -- Listen for confirmation from the server
            net.Receive("BoomboxPermanentConfirmation", function()
                local message = net.ReadString()
                chat.AddText(Color(0, 255, 0), "[Boombox] ", Color(255, 255, 255), message)

                -- Update the checkbox state based on the message
                if string.find(message, "marked as permanent") then
                    permanentCheckbox:SetChecked(true)
                elseif string.find(message, "permanence has been removed") then
                    permanentCheckbox:SetChecked(false)
                end
            end)
        end
    end

    -- Add footer
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
    
    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        if not utils.canInteractWithBoombox(ply, entity) then
            chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
            return
        end
    end
    
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
                headerText = LanguageManager:GetCountryTranslation(lang, formattedCountry)
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
    volumeIcon:SetMaterial(VOLUME_ICONS.HIGH) -- Set default icon

    -- Function to update the volume icon based on the current volume
    local function updateVolumeIcon(volumeIcon, value)
        if not IsValid(volumeIcon) then return end
        
        local iconMat
        if type(value) == "function" then
            value = value()
        end
        
        if value < 0.01 then
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

    -- Override the Paint function of volumeIcon to apply the text color
    volumeIcon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    -- Get the current entity and its volume
    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = 0.5 -- Default volume

    if IsValid(entity) then
        currentVolume = entityVolumes[entity] or (getEntityConfig(entity) and getEntityConfig(entity).Volume) or 0.5
    end

    -- Set initial icon
    updateVolumeIcon(volumeIcon, currentVolume)

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(-Scale(170), Scale(5))
    volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) + Scale(120) - stopButtonWidth, volumePanel:GetTall() - Scale(20))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
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
        local currentTime = CurTime()

        if IsValid(entity) and entity:GetClass() == "prop_vehicle_prisoner_pod" and entity:GetParent():IsValid() then
            local parent = entity:GetParent()
            if string.find(parent:GetClass(), "lvs_") then
                entity = parent -- Set the entity to the parent entity if it's an LVS vehicle
            elseif string.find(parent:GetClass(), "ses_") then
                entity = parent -- Set the entity to the parent entity if it's an SES vehicle
            end
        end

        -- Apply global volume limit
        value = math.min(value, Config.MaxVolume())

        -- Immediately update client-side volume
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end

        -- Update the icon
        updateVolumeIcon(volumeIcon, value)

        -- Debounce server communication
        if currentTime - lastServerUpdate >= 0.1 then
            lastServerUpdate = currentTime

            -- Send volume update to server
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

    -- Modify the close, settings, and back buttons to use the new animated button function
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
                if IsValid(settingsFrame) then
                    settingsFrame:Remove()
                    settingsFrame = nil
                end
                searchBox:SetVisible(true)
                stationListPanel:SetVisible(true)
                
                -- Force reload station data and repopulate list
                stationDataLoaded = false
                LoadStationData()
                timer.Simple(0, function()
                    populateList(stationListPanel, backButton, searchBox, true)
                end)
                
                backButton:SetVisible(selectedCountry ~= nil or favoritesMenuOpen)
                backButton:SetEnabled(selectedCountry ~= nil or favoritesMenuOpen)
            elseif selectedCountry or favoritesMenuOpen then
                selectedCountry = nil
                favoritesMenuOpen = false
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

    -- Set the visibility and interactivity of the back button
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
    local currentTime = CurTime()

    -- Only process key press with proper delay and when not typing
    if not (input.IsKeyDown(openKey) and not ply:IsTyping() and currentTime - lastKeyPress > keyPressDelay) then
        return
    end
    lastKeyPress = currentTime

    -- Handle menu closing if it's open
    if radioMenuOpen then
        surface.PlaySound("buttons/lightswitch2.wav")
        currentFrame:Close()
        radioMenuOpen = false
        selectedCountry = nil
        settingsMenuOpen = false
        favoritesMenuOpen = false  -- Reset favorites menu state
        return
    end

    -- Only allow key press to work for vehicles
    local vehicle = ply:GetVehicle()
    if IsValid(vehicle) and not utils.isSitAnywhereSeat(vehicle) then
        ply.currentRadioEntity = vehicle
        openRadioMenu()
    end
end)

net.Receive("UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local isPlaying = net.ReadBool()
    local status = net.ReadString()

    if IsValid(entity) then
        BoomboxStatuses[entity:EntIndex()] = {
            stationStatus = status,
            stationName = stationName
        }

        -- Immediately update the entity's networked variables
        entity:SetNWString("Status", status)
        entity:SetNWString("StationName", stationName)
        entity:SetNWBool("IsPlaying", isPlaying)

        -- If the status is "playing", update the currently playing stations
        if status == "playing" then
            currentlyPlayingStations[entity] = { name = stationName }
        elseif status == "stopped" then
            currentlyPlayingStations[entity] = nil
        end
    end
end)

net.Receive("PlayCarRadioStation", function()
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) or type(url) ~= "string" or type(volume) ~= "number" then
        print("[Radio Error] Invalid data received")
        return
    end

    -- Set the boombox status to "tuning" immediately
    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
        entity:SetNWString("Status", "tuning")
        entity:SetNWString("StationName", stationName)
        entity:SetNWBool("IsPlaying", true)
        
        -- Update the BoomboxStatuses table immediately
        BoomboxStatuses[entity:EntIndex()] = {
            stationStatus = "tuning",
            stationName = stationName
        }
    end

    -- Stop the current station before playing a new one
    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
    end

    sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
        if IsValid(station) then
            station:SetPos(entity:GetPos())
            station:SetVolume(volume)
            station:Play()
            currentRadioSources[entity] = station
            entity.RadioSource = station  -- Store the sound object on the entity

            -- Set 3D fade distance according to the entity's configuration
            local entityConfig = getEntityConfig(entity)
            if entityConfig then
                -- Get the actual values from the functions
                local minDist = entityConfig.MinVolumeDistance()
                local maxDist = entityConfig.MaxHearingDistance()
                station:Set3DFadeDistance(minDist, maxDist)
            end

            -- Create a timer to check when the station actually starts playing
            local checkAttempts = 0
            local function checkStationState()
                if not IsValid(entity) or not IsValid(station) then
                    return
                end

                local state = station:GetState()
                if state == GMOD_CHANNEL_PLAYING then
                    -- Station is now playing, update status
                    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
                        BoomboxStatuses[entity:EntIndex()] = {
                            stationStatus = "playing",
                            stationName = stationName
                        }
                        entity:SetNWString("Status", "playing")
                        entity:SetNWString("StationName", stationName)
                        entity:SetNWBool("IsPlaying", true)
                    end
                elseif state == GMOD_CHANNEL_STOPPED then
                    -- Station has stopped
                    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
                        BoomboxStatuses[entity:EntIndex()] = {
                            stationStatus = "stopped",
                            stationName = ""
                        }
                        entity:SetNWString("Status", "stopped")
                        entity:SetNWString("StationName", "")
                        entity:SetNWBool("IsPlaying", false)
                    end
                else
                    -- Keep checking for up to 10 seconds (100 attempts * 0.1 seconds)
                    checkAttempts = checkAttempts + 1
                    if checkAttempts < 100 then
                        timer.Simple(0.1, checkStationState)
                    else
                        -- If station hasn't started playing after 10 seconds, mark as stopped
                        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
                            BoomboxStatuses[entity:EntIndex()] = {
                                stationStatus = "stopped",
                                stationName = ""
                            }
                            entity:SetNWString("Status", "stopped")
                            entity:SetNWString("StationName", "")
                            entity:SetNWBool("IsPlaying", false)
                        end
                    end
                end
            end

            -- Start checking the station state
            timer.Simple(0.1, checkStationState)

            -- Update the station's position relative to the entity's movement
            hook.Add("Think", "UpdateRadioPosition_" .. entity:EntIndex(), function()
                if IsValid(entity) and IsValid(station) then
                    station:SetPos(entity:GetPos())

                    local playerPos = LocalPlayer():GetPos()
                    local entityPos = entity:GetPos()
                    local distanceSqr = playerPos:DistToSqr(entityPos)
                    local isPlayerInCar = LocalPlayer():GetVehicle() == entity or 
                                          (IsValid(LocalPlayer():GetVehicle()) and 
                                           LocalPlayer():GetVehicle():GetParent() == entity)

                    updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
                else
                    hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
                end
            end)

            -- Stop the station if the entity is removed
            hook.Add("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex(), function(ent)
                if ent == entity then
                    if IsValid(currentRadioSources[entity]) then
                        currentRadioSources[entity]:Stop()
                    end
                    currentRadioSources[entity] = nil
                    entity.RadioSource = nil  -- Clear the stored sound object
                    hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex())
                    hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
                    BoomboxStatuses[entity:EntIndex()] = nil
                end
            end)
        else
            print("[Radio Error] Failed to create station. Error ID:", errorID, "Error Name:", errorName)
            if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
                BoomboxStatuses[entity:EntIndex()] = {
                    stationStatus = "stopped",
                    stationName = ""
                }
                entity:SetNWString("Status", "stopped")
                entity:SetNWString("StationName", "")
                entity:SetNWBool("IsPlaying", false)
            end
        end
    end)
end)

net.Receive("StopCarRadioStation", function()
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)

    if not IsValid(entity) then return end

    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
    end
    currentRadioSources[entity] = nil
    entity.RadioSource = nil  -- Clear the stored sound object
    currentlyPlayingStations[entity] = nil
    
    -- Update boombox status to "stopped"
    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        entity:SetNWString("Status", "stopped")
        entity:SetNWString("StationName", "")
        entity:SetNWBool("IsPlaying", false)
    end

    hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex())
    hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
end)

net.Receive("UpdateRadioVolume", function()
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local volume = ClampVolume(net.ReadFloat())

    if not IsValid(entity) then return end

    entityVolumes[entity] = volume

    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:SetVolume(volume)
    end

    if radioMenuOpen and IsValid(currentFrame) then
        local volumeSlider = currentFrame:GetChildren()[6]:GetChildren()[2]
        if IsValid(volumeSlider) and volumeSlider:GetName() == "DNumSlider" then
            volumeSlider:SetValue(volume)
        end
    end
end)

--[[
    Network Receiver: OpenRadioMenu
    Opens the radio menu for the player.
]]
net.Receive("OpenRadioMenu", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local ply = LocalPlayer()
    
    -- Only handle boombox entities
    if ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox" then
        if utils.canInteractWithBoombox(ply, ent) then
            ply.currentRadioEntity = ent
            if not radioMenuOpen then
                openRadioMenu()
            end
        else
            chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
        end
    end
end)

net.Receive("CarRadioMessage", function()
    PrintCarRadioMessage()
end)

-- Add with other net receivers
net.Receive("RadioConfigUpdate", function()
    -- Update all active radio volumes to comply with new settings
    for entity, source in pairs(currentRadioSources) do
        if IsValid(entity) and IsValid(source) then
            local volume = ClampVolume(entityVolumes[entity] or getEntityConfig(entity).Volume())
            source:SetVolume(volume)
        end
    end
end)

-- ------------------------------
--      Initialization
-- ------------------------------

-- Load the favorite stations and countries when the script initializes
loadFavorites()

-- Cleanup when the boombox entity is removed
hook.Add("EntityRemoved", "BoomboxCleanup", function(ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        BoomboxStatuses[ent:EntIndex()] = nil
    end
end)

-- Clear currentRadioEntity when leaving vehicle
hook.Add("VehicleChanged", "ClearRadioEntity", function(ply, old, new)
    if ply ~= LocalPlayer() then return end
    if not new then
        ply.currentRadioEntity = nil
    end
end)

-- Clear currentRadioEntity when boombox is removed
hook.Add("EntityRemoved", "ClearRadioEntity", function(ent)
    local ply = LocalPlayer()
    if ent == ply.currentRadioEntity then
        ply.currentRadioEntity = nil
    end
end)

local function updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    if not entityConfig then return end

    local volume = ClampVolume(entityVolumes[entity] or entityConfig.Volume())
    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    -- Apply global volume limit
    local maxVolume = Config.MaxVolume()
    local effectiveVolume = math.min(volume, maxVolume)

    local minVolumeDistance = entityConfig.MinVolumeDistance()
    local maxHearingDistance = entityConfig.MaxHearingDistance()

    local distance = math.sqrt(distanceSqr)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    else
        if distance <= minVolumeDistance then
            station:SetVolume(effectiveVolume)
        elseif distance <= maxHearingDistance then
            local exponent = Config.VolumeAttenuationExponent
            local attenuationFactor = ((maxHearingDistance - distance) / (maxHearingDistance - minVolumeDistance)) ^ exponent
            attenuationFactor = math.Clamp(attenuationFactor, 0, 1)
            local adjustedVolume = effectiveVolume * attenuationFactor
            station:SetVolume(adjustedVolume)
        else
            station:SetVolume(0)
        end
    end
end

-- In the net receiver for volume updates
net.Receive("UpdateRadioVolume", function()
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local volume = ClampVolume(net.ReadFloat())

    if not IsValid(entity) then return end

    entityVolumes[entity] = volume

    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:SetVolume(volume)
    end

    if radioMenuOpen and IsValid(currentFrame) then
        local volumeSlider = currentFrame:GetChildren()[6]:GetChildren()[2]
        if IsValid(volumeSlider) and volumeSlider:GetName() == "DNumSlider" then
            volumeSlider:SetValue(volume)
        end
    end
end)
