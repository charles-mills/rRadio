--[[ 
    rRadio Addon for Garry's Mod - Client Radio Script
    Description: Manages client-side radio functionalities and UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-05
]]

-- Include necessary files
include("misc/key_names.lua")
include("misc/config.lua")
local utils = include("misc/utils.lua")

-- Localization and language management
local countryTranslations = include("localisation/country_translations.lua")
local LanguageManager = include("localisation/language_manager.lua")

-- Initialize favoriteCountries as a set
local favoriteCountries = setmetatable({}, { __index = function(t, k) return false end })

-- Initialize favoriteStations as a nested set
local favoriteStations = setmetatable({}, {
    __index = function(t, k)
        t[k] = setmetatable({}, { __index = function(t, station) return false end })
        return t[k]
    end
})

local savePending = false
local lastKeyCheckTime = 0
local keyCheckInterval = 0.05 -- Check every 0.1 seconds
local lastPlayerVehicle = nil
local lastMainEntity = nil

-- Define throttle variables
local lastThinkTime = 0
local thinkThrottleInterval = 0.05 -- Throttle interval in seconds (0.05s = 20 times per second)

local ConsolidatedStations = {}

-- Cache frequently used functions
local IsValid = IsValid
local GetConVar = GetConVar
local gsub = string.gsub
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local math_Clamp = math.Clamp
local util_JSONToTable = util.JSONToTable
local util_TableToJSON = util.TableToJSON
local file_Exists = file.Exists
local file_Read = file.Read
local file_Write = file.Write
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local draw_SimpleText = draw.SimpleText

-- Define local materials
local radioMaterial = Material("hud/radio.png")
local volumeMaterial = Material("hud/volume.png")
local flagMaterial = Material("hud/flag.png")

-- Define data directory and file paths
local dataDir = "rradio"
local favoriteCountriesFile = dataDir .. "/favorite_countries.json"
local favoriteStationsFile = dataDir .. "/favorite_stations.json"

-- Ensure the data directory exists
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

-- -------------------------------
-- 1. Caching ConVars as Locals
-- -------------------------------
-- Cache ConVars for improved performance
local radioShowMessagesConVar = GetConVar("radio_show_messages")
local radioLanguageConVar = GetConVar("radio_language")
local radioMaxVolumeConVar = GetConVar("radio_max_volume")
local radioOpenKeyConVar = GetConVar("radio_open_key")
-- --------------------------------

-- Initialize entityVolumes table
local entityVolumes = {}

-- Load favorites from file
local function loadFavorites()
    if file.Exists(favoriteCountriesFile, "DATA") then
        local countriesData = file.Read(favoriteCountriesFile, "DATA")
        if countriesData then
            local decoded = util.JSONToTable(countriesData)
            if decoded then
                -- Reassign the metatable
                setmetatable(decoded, { __index = function(t, k) return false end })
                favoriteCountries = decoded
            else
                utils.PrintError("Failed to decode favorite countries file.", 2)
            end
        else
            utils.PrintError("Failed to read favorite countries file.", 2)
        end
    end

    if file.Exists(favoriteStationsFile, "DATA") then
        local stationsData = file.Read(favoriteStationsFile, "DATA")
        if stationsData then
            local decoded = util.JSONToTable(stationsData)
            if decoded then
                -- Reassign the metatable for nested tables
                for country, stations in pairs(decoded) do
                    setmetatable(stations, { __index = function(t, station) return false end })
                end
                setmetatable(decoded, {
                    __index = function(t, k)
                        t[k] = setmetatable({}, { __index = function(t, station) return false end })
                        return t[k]
                    end
                })
                favoriteStations = decoded
            else
                utils.PrintError("Failed to decode favorite stations file.", 2)
            end
        else
            utils.PrintError("Failed to read favorite stations file.", 2)
        end
    end
end

-- Table to store IsSitAnywhereSeat status for vehicles
local vehicleSitAnywhereStatus = {}

net.Receive("rRadio_UpdateIsSitAnywhereSeat", function()
    local vehicle = net.ReadEntity()
    local isSitAnywhereSeat = net.ReadBool()

    if IsValid(vehicle) then
        vehicleSitAnywhereStatus[vehicle] = isSitAnywhereSeat
        print("[rRadio] Received IsSitAnywhereSeat update for vehicle:", vehicle, isSitAnywhereSeat)
    else
        vehicleSitAnywhereStatus[vehicle] = nil
        print("[rRadio] Received IsSitAnywhereSeat update for invalid vehicle.")
    end
end)

-- Save favorites to file
local function saveFavorites()
    local successCountries = file.Write(favoriteCountriesFile, util.TableToJSON(favoriteCountries, true)) -- Pretty print JSON
    local successStations = file.Write(favoriteStationsFile, util.TableToJSON(favoriteStations, true))     -- Pretty print JSON

    if not successCountries then
        utils.PrintError("Failed to save favorite countries to file.", 2)
    end

    if not successStations then
        utils.PrintError("Failed to save favorite stations to file.", 2)
    end
end

-- Debounce func for saving favorites
local function saveFavoritesDebounced()
    if not savePending then
        savePending = true
        timer.Simple(1, function()
            saveFavorites()
            savePending = false
        end)
    end
end

local function RequestOpenRadioMenu(entity)
    entity = utils.getMainVehicleEntity(entity)
    if IsValid(entity) then
        net.Start("rRadio_RequestOpenMenu")
        net.WriteEntity(entity)
        net.SendToServer()
    end
end

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

-- State Variables
local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStations = {}  -- Initialize the currentlyPlayingStations table
local currentRadioSources = {}
local lastMessageTime = -math.huge
local lastStationSelectTime = 0  -- Variable to store the time of the last station selection

-- Utility Functions
local function Scale(value)
    return value * (ScrW() / 2560)
end

local function getEntityConfig(entity)
    local entityClass = entity:GetClass()

    local configMapping = {
        ["golden_boombox"] = Config.GoldenBoombox,
        ["boombox"] = Config.Boombox
    }

    if configMapping[entityClass] then
        return configMapping[entityClass]
    elseif entity:IsVehicle() or string.find(entityClass, "lvs_") then
        return Config.VehicleRadio
    else
        return nil
    end
end

local function isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicleSitAnywhereStatus[vehicle] or false
end

local function formatCountryName(name)
    local formattedName = gsub(gsub(name, "_", " "), "(%a)([%w_']*)", function(a, b)
        return a:upper() .. b:lower()
    end)
    local lang = radioLanguageConVar:GetString() or "en"
    return countryTranslations:GetCountryName(lang, formattedName) or formattedName
end

local function getEffectiveVolume(entity, volume)
    local maxVolume = radioMaxVolumeConVar:GetFloat() -- Use cached ConVar
    return math.min(volume, maxVolume)
end

local function calculateAdjustedVolume(distance, minDistance, maxDistance, effectiveVolume)
    if distance <= minDistance then
        return effectiveVolume
    elseif distance <= maxDistance then
        return effectiveVolume * (1 - (distance - minDistance) / (maxDistance - minDistance))
    else
        return 0
    end
end

local function updateStationVolume(station, volume)
    if volume <= 0.02 then
        station:SetVolume(0)
    else
        station:SetVolume(volume)
    end
end

local function updateRadioVolume(station, distance, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    if not entityConfig then return end

    local volume = entityVolumes[entity] or entityConfig.Volume
    local effectiveVolume = getEffectiveVolume(entity, volume)

    if isPlayerInCar then
        updateStationVolume(station, effectiveVolume)
    else
        local adjustedVolume = calculateAdjustedVolume(distance, entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance, effectiveVolume)
        updateStationVolume(station, adjustedVolume)
    end
end

local function shouldShowRadioMessage()
    return radioShowMessagesConVar:GetBool() -- Use cached ConVar
end

local function isValidVehicle(vehicle)
    return IsValid(vehicle) and not isSitAnywhereSeat(vehicle)
end

local function isMessageCooldownActive(currentTime)
    return (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge
end

local function updateLastMessageTime(currentTime)
    lastMessageTime = currentTime
end

local function getOpenKeyName()
    local openKey = radioOpenKeyConVar:GetInt() -- Use cached ConVar
    return input.GetKeyName(openKey) or "unknown key"
end

-- Function to create the notification panel with dynamic width
local function createNotificationPanel(message)
    -- Create the notification panel
    local notificationPanel = vgui.Create("DPanel")
    
    -- Calculate the width based on the text size
    surface.SetFont("Roboto18")  -- Ensure we're using the correct font
    local textWidth = surface.GetTextSize(message)
    local panelWidth = Scale(textWidth + 50)  -- Adjusted padding calculation

    notificationPanel:SetSize(panelWidth, Scale(50))  -- Set size of the panel
    notificationPanel:SetPos(ScrW(), ScrH() * 0.3 - Scale(25))  -- Start off-screen to the right
    notificationPanel:SetVisible(true)  -- Ensure the panel is visible

    notificationPanel.Paint = function(self, w, h)
        -- Draw the background with a solid color
        draw.RoundedBox(0, 0, 0, w, h, Config.UI.BackgroundColor)  -- Simple background
        
        -- Draw left border
        draw.RoundedBox(0, 0, 0, Scale(5), h, Config.UI.ButtonHoverColor)  -- Left border with darker color

        -- Draw drop shadow for the text
        draw.SimpleText(message, "Roboto18", Scale(10) + 1, h / 2 + 1, Color(0, 0, 0, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)  -- Shadow
        draw.SimpleText(message, "Roboto18", Scale(10), h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)  -- Main text
    end

    -- Animation function to slide the panel in and out
    local function animatePanel()
        -- Slide in from the right
        local targetX = ScrW() - panelWidth  -- Target position for sliding in
        notificationPanel:MoveTo(targetX, notificationPanel:GetY(), 0.5, 0, -1, function()
            -- Pause for a moment before sliding out
            timer.Simple(2, function()
                -- Slide out to the right
                notificationPanel:MoveTo(ScrW(), notificationPanel:GetY(), 0.5, 0, -1, function()
                    notificationPanel:Remove()  -- Remove the panel after sliding out
                end)
            end)
        end)
    end

    animatePanel()  -- Start the animation
end

-- Function to get the radio message with capitalized key name
local function getRadioMessage(keyName)
    keyName = string.upper(keyName)  -- Capitalize the key name
    return (Config.Lang["PressKeyToOpen"] or "Press {key} to open the radio menu"):gsub("{key}", keyName)
end

local function PrintrRadio_ShowCarRadioMessage()
    -- Ensure the convar is set to show messages
    if not shouldShowRadioMessage() then return end

    local vehicle = LocalPlayer():GetVehicle()

    -- Ensure vehicle is valid
    if not IsValid(vehicle) then return end

    -- Cooldown management to avoid message spam
    local currentTime = CurTime()
    if isMessageCooldownActive(currentTime) then return end

    -- Update the last message time
    updateLastMessageTime(currentTime)

    -- Get the radio open key and the message
    local keyName = getOpenKeyName()
    local message = getRadioMessage(keyName)

    -- Create and display the notification panel
    createNotificationPanel(message)
end

-- Network receiver for showing the "press key to open stations" animation
net.Receive("rRadio_ShowCarRadioMessage", function()
    PrintrRadio_ShowCarRadioMessage()
end)

local function createFont(fontName, fontSize)
    surface.CreateFont(fontName, {
        font = "Roboto",
        size = fontSize,
        weight = 700,
    })
end

local function getTextWidth(fontName, text)
    surface.SetFont(fontName)
    local textWidth, _ = surface.GetTextSize(text)
    return textWidth
end

local function adjustFontSizeToFit(text, buttonWidth, maxFontSize)
    local fontName = "DynamicStopButtonFont"
    createFont(fontName, maxFontSize)
    local textWidth = getTextWidth(fontName, text)

    while textWidth > buttonWidth * 0.9 and maxFontSize > 6 do -- Prevent font size from going too small
        maxFontSize = maxFontSize - 1
        createFont(fontName, maxFontSize)
        textWidth = getTextWidth(fontName, text)
    end

    return fontName
end

local function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    return adjustFontSizeToFit(text, buttonWidth, maxFontSize)
end

-- Table to store custom radio stations
local CustomRadioStations = {}

-- Network receiver for custom radio stations
net.Receive("rRadio_CustomStations", function()
    local newCustomStations = net.ReadTable()
    
    -- Merge new stations with existing ones
    for country, stations in pairs(newCustomStations) do
        if not CustomRadioStations[country] then
            CustomRadioStations[country] = {}
        end
        for _, station in ipairs(stations) do
            table.insert(CustomRadioStations[country], station)
        end
    end
end)

-- Request custom stations from the server when the script initializes
hook.Add("InitPostEntity", "RequestCustomStations", function()
    net.Start("rRadio_RequestCustomStations")
    net.SendToServer()
    print("[rRadio] Requested custom stations from server")
end)

-- Add this function to load the consolidated stations
local function loadConsolidatedStations()
    local files = file.Find("radio/stations/data_*.lua", "LUA")

    for _, filename in ipairs(files) do
        local stations = include("radio/stations/" .. filename)
        
        for country, countryStations in pairs(stations) do
            local baseName = string.match(country, "(.+)_%d+$") or country
            baseName = utils.formatCountryNameForComparison(baseName)
            
            if not ConsolidatedStations[baseName] then
                ConsolidatedStations[baseName] = {}
            end
            
            for _, station in ipairs(countryStations) do
                table.insert(ConsolidatedStations[baseName], {name = station.n, url = station.u})
            end
        end
    end
end

-- Call this function to load the stations
loadConsolidatedStations()

-- Update the getSortedStations function to use ConsolidatedStations instead of _G.ConsolidatedStations
local function getSortedStations(filterText)
    local stations = {}
    local favoriteStationsList = {}
    local nonFavoriteStationsList = {}
    local formattedSelectedCountry = utils.formatCountryNameForComparison(selectedCountry)
    
    -- Function to add stations to the appropriate list
    local function addStations(stationList)
        for _, station in ipairs(stationList or {}) do
            if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
                local isFavorite = favoriteStations[selectedCountry] and favoriteStations[selectedCountry][station.name] or false
                if isFavorite then
                    table.insert(favoriteStationsList, { station = station, favorite = true })
                else
                    table.insert(nonFavoriteStationsList, { station = station, favorite = false })
                end
            end
        end
    end

    -- Add stations from ConsolidatedStations
    if ConsolidatedStations[formattedSelectedCountry] then
        addStations(ConsolidatedStations[formattedSelectedCountry])
    else
    end

    -- Add custom stations if they exist for the selected country
    if CustomRadioStations[formattedSelectedCountry] then
        addStations(CustomRadioStations[formattedSelectedCountry])
    else
    end

    -- Sort favorite stations alphabetically
    table.sort(favoriteStationsList, function(a, b)
        return a.station.name < b.station.name
    end)

    -- Sort non-favorite stations alphabetically
    table.sort(nonFavoriteStationsList, function(a, b)
        return a.station.name < b.station.name
    end)

    -- Combine favorite and non-favorite stations
    for _, station in ipairs(favoriteStationsList) do
        table.insert(stations, station)
    end
    for _, station in ipairs(nonFavoriteStationsList) do
        table.insert(stations, station)
    end

    return stations
end

-- Function to create a favorite icon for countries and stations
local function createFavoriteIcon(parent, item, itemType, stationListPanel, backButton, searchBox)
    local starIcon = vgui.Create("DImageButton", parent)
    starIcon:SetSize(Scale(24), Scale(24))
    starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)

    -- Determine favorite status based on itemType
    local isFavorite
    if itemType == "country" then
        isFavorite = favoriteCountries[item.original] or false
        starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
        if not isFavorite then
            starIcon:SetColor(Config.UI.TextColor)
        end

        starIcon.DoClick = function()
            favoriteCountries[item.original] = not isFavorite
            saveFavoritesDebounced()
            -- Update the star icon and repopulate the list
            isFavorite = not isFavorite
            starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
            if not isFavorite then
                starIcon:SetColor(Config.UI.TextColor)
            else
                starIcon:SetColor(Color(255, 255, 255))
            end
            if stationListPanel then
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    elseif itemType == "station" then
        isFavorite = favoriteStations[selectedCountry] and favoriteStations[selectedCountry][item.name] or false
        starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
        if not isFavorite then
            starIcon:SetColor(Config.UI.TextColor)
        end

        starIcon.DoClick = function()
            if not favoriteStations[selectedCountry] then
                favoriteStations[selectedCountry] = {}
            end

            favoriteStations[selectedCountry][item.name] = not isFavorite
            saveFavoritesDebounced()

            -- Update the star icon and repopulate the list
            isFavorite = not isFavorite
            starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
            if not isFavorite then
                starIcon:SetColor(Config.UI.TextColor)
            else
                starIcon:SetColor(Color(255, 255, 255))
            end
            if stationListPanel then
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    end

    return starIcon
end

-- Function to create a country button
local function createCountryButton(stationListPanel, country, backButton, searchBox)
    local countryButton = vgui.Create("DButton", stationListPanel)
    countryButton:Dock(TOP)
    countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
    countryButton:SetTall(Scale(40))
    countryButton:SetText("")  -- We'll draw the text manually
    countryButton:SetFont("Roboto18")
    countryButton:SetTextColor(Config.UI.TextColor)

    local favoriteIcon = createFavoriteIcon(countryButton, country, "country", stationListPanel, backButton, searchBox)
    local iconWidth = favoriteIcon:GetWide()
    local padding = Scale(5)

    countryButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
        end

        -- Draw text with proper positioning and clipping
        local textX = iconWidth + padding * 2
        local maxTextWidth = w - textX - padding
        local text = country.translated
        surface.SetFont("Roboto18")
        local textW, textH = surface.GetTextSize(text)
        
        if textW > maxTextWidth then
            text = string.sub(text, 1, surface.GetTextSize(text) / textW * maxTextWidth)
            text = text .. "..."
        end

        -- Center the text within the available space, accounting for the icon and padding
        local availableWidth = w - textX - padding
        local centerX = (textX + availableWidth / 2) - Scale(10)
        draw.SimpleText(text, "Roboto18", centerX, h/2, Config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    countryButton.DoClick = function()
        surface.PlaySound("buttons/button3.wav")
        selectedCountry = country.original
        if backButton then backButton:SetVisible(true) end
        populateList(stationListPanel, backButton, searchBox, true)
    end

    return countryButton
end

-- Function to handle station button click
local function handleStationButtonClick(stationListPanel, backButton, searchBox, station)
    local currentTime = CurTime()

    -- Check if the cooldown has passed
    if currentTime - lastStationSelectTime < 2 then
        return  -- Exit the function if the cooldown hasn't passed
    end

    surface.PlaySound("buttons/button17.wav")
    local entity = LocalPlayer().currentRadioEntity
    local mainEntity = utils.getMainVehicleEntity(entity) or entity
    if not IsValid(mainEntity) then
        return
    end

    if currentlyPlayingStations[mainEntity] then
        net.Start("rRadio_StopRadioStation")
        net.WriteEntity(mainEntity)
        net.SendToServer()
    end

    local volume = entityVolumes[mainEntity] or getEntityConfig(mainEntity).Volume
    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(mainEntity)
    net.WriteString(station.name)
    net.WriteString(station.url)
    net.WriteFloat(volume)
    net.WriteString(selectedCountry)
    net.SendToServer()

    currentlyPlayingStations[mainEntity] = station
    lastStationSelectTime = currentTime  -- Update the last station select time
    populateList(stationListPanel, backButton, searchBox, false)
end

-- Function to create a station button
local function createStationButton(stationListPanel, stationData, backButton, searchBox)
    local station = stationData.station
    local stationButton = vgui.Create("DButton", stationListPanel)
    stationButton:Dock(TOP)
    stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
    stationButton:SetTall(Scale(40))
    stationButton:SetText("")  -- We'll draw the text manually
    stationButton:SetFont("Roboto18")
    stationButton:SetTextColor(Config.UI.TextColor)

    local favoriteIcon = createFavoriteIcon(stationButton, station, "station", stationListPanel, backButton, searchBox)
    local iconWidth = favoriteIcon:GetWide()
    local padding = Scale(20)

    stationButton.Paint = function(self, w, h)
        if station == currentlyPlayingStations[LocalPlayer().currentRadioEntity] then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
        else
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
            if self:IsHovered() then
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
            end
        end

        -- Draw text with proper positioning and clipping
        local textX = iconWidth + padding * 2
        local maxTextWidth = w - textX - padding * 2  -- Reduce available width for text
        local text = station.name
        surface.SetFont("Roboto18")
        local textW, textH = surface.GetTextSize(text)
        
        if textW > maxTextWidth then
            local ellipsis = "..."
            local ellipsisWidth = surface.GetTextSize(ellipsis)
            local availableWidth = maxTextWidth - ellipsisWidth
            local ratio = availableWidth / textW
            local truncatedLength = math.floor(#text * ratio)
            text = string.sub(text, 1, truncatedLength) .. ellipsis
        end

        -- Center the text within the available space, accounting for the icon and padding
        local centerX = textX + (w - textX - padding * 2) / 2
        draw.SimpleText(text, "Roboto18", centerX, h/2, Config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    stationButton.DoClick = function()
        handleStationButtonClick(stationListPanel, backButton, searchBox, station)
    end

    return stationButton
end

-- Function to get sorted countries
local function getSortedCountries(filterText)
    local countries = {}
    local favoriteCountriesList = {}
    local nonFavoriteCountriesList = {}

    for country, _ in pairs(ConsolidatedStations) do
        local translatedCountry = formatCountryName(country)
        local formattedCountry = utils.formatCountryNameForComparison(country)
        if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
            local countryData = { original = country, formatted = formattedCountry, translated = translatedCountry }
            if favoriteCountries[country] then
                table.insert(favoriteCountriesList, countryData)
            else
                table.insert(nonFavoriteCountriesList, countryData)
            end
        end
    end

    -- Sort favorite countries alphabetically
    table.sort(favoriteCountriesList, function(a, b)
        return a.translated < b.translated
    end)

    -- Sort non-favorite countries alphabetically
    table.sort(nonFavoriteCountriesList, function(a, b)
        return a.translated < b.translated
    end)

    -- Combine favorite and non-favorite countries
    for _, country in ipairs(favoriteCountriesList) do
        table.insert(countries, country)
    end
    for _, country in ipairs(nonFavoriteCountriesList) do
        table.insert(countries, country)
    end

    return countries
end

-- Function to populate the list with countries
local function populateCountryList(stationListPanel, backButton, searchBox, filterText)
    local countries = getSortedCountries(filterText)
    for _, country in ipairs(countries) do
        createCountryButton(stationListPanel, country, backButton, searchBox)
    end
end

-- Function to populate the list with stations
local function populateStationList(stationListPanel, backButton, searchBox, filterText)
    local stations = getSortedStations(filterText)
    for _, stationData in ipairs(stations) do
        createStationButton(stationListPanel, stationData, backButton, searchBox)
    end
end

-- Main function to populate the list
function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then return end

    if backButton and selectedCountry == nil then
        backButton:SetVisible(false)
    end

    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText()

    if selectedCountry == nil then
        populateCountryList(stationListPanel, backButton, searchBox, filterText)
    else
        populateStationList(stationListPanel, backButton, searchBox, filterText)
    end
end
local function createFrame()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function() radioMenuOpen = false end

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), Config.UI.HeaderColor, true, true, false, false)
        
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        
        surface.SetFont("HeaderFont")
        local textHeight = select(2, surface.GetTextSize("H"))
        
        local iconOffsetY = Scale(2) + textHeight - iconSize
        
        local currentMaterial
        if selectedCountry == nil then
            currentMaterial = flagMaterial
        else
            currentMaterial = radioMaterial
        end
        
        surface.SetMaterial(currentMaterial)
        surface.SetDrawColor(Config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
        
        local countryText = Config.Lang["SelectCountry"] or "Select Country"
        draw.SimpleText(selectedCountry and formatCountryName(selectedCountry) or countryText, "HeaderFont", iconOffsetX + iconSize + Scale(5), iconOffsetY, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    return frame
end

local function createSearchBox(frame)
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

    return searchBox
end

local function createStationListPanel(frame)
    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(200))

    local sbar = stationListPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    return stationListPanel
end

local function createStopButton(frame, stationListPanel, backButton, searchBox)
    local stopButtonHeight = Scale(Config.UI.FrameSize.width) / 8
    local stopButtonWidth = Scale(Config.UI.FrameSize.width) / 4
    local stopButtonText = Config.Lang["StopRadio"] or "STOP"
    local stopButtonFont = calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(90))
    stopButton:SetSize(stopButtonWidth, stopButtonHeight)
    stopButton:SetText(stopButtonText)
    stopButton:SetFont(stopButtonFont)
    stopButton:SetTextColor(Config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonHoverColor)
        end
    end

    stopButton.DoClick = function()
        surface.PlaySound("buttons/button6.wav")
        local entity = LocalPlayer().currentRadioEntity
        if IsValid(entity) then
            net.Start("rRadio_StopRadioStation")
            net.WriteEntity(entity)
            net.SendToServer()
            
            -- Immediately stop the sound locally
            if IsValid(currentRadioSources[entity]) then
                currentRadioSources[entity]:Stop()
                currentRadioSources[entity] = nil
            end
            
            currentlyPlayingStations[entity] = nil
            entity:SetNWString("CurrentRadioStation", "")
            entity:SetNWString("Country", "")
            
            -- Repopulate the list to reflect the changes
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end

    return stopButton
end

local function createVolumePanel(frame, stopButtonHeight, stopButtonWidth)
    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
    volumePanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
    end

    return volumePanel
end

local lastVolumeChangeTime = 0
local volumeChangeDebounceTime = 0.1 -- 100ms debounce time

local function createVolumeSlider(volumePanel, entity)
    local mainEntity = utils.getMainVehicleEntity(entity) or entity
    local volumeIconSize = Scale(50)
    local volumeIcon = vgui.Create("DPanel", volumePanel)

    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
    volumeIcon:SetSize(volumeIconSize, volumeIconSize)
    volumeIcon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.TextColor)
        surface.SetMaterial(volumeMaterial)
        surface.DrawTexturedRect(0, 0, w, h)
    end

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    -- Updated positioning for better alignment
    volumeSlider:SetPos(volumeIcon:GetPos() + volumeIcon:GetWide() - Scale(220), Scale(10))
    volumeSlider:SetSize(Scale(560), Scale(50))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)
    
    local currentVolume = entityVolumes[entity] or (getEntityConfig and getEntityConfig(entity) and getEntityConfig(entity).Volume) or 1
    volumeSlider:SetValue(currentVolume)
    
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, h/2 - 4, w, 16, Config.UI.TextColor)
    end
    
    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w*1.5, h*1.5, Config.UI.BackgroundColor)
    end
    
    volumeSlider.TextArea:SetVisible(false)

    volumeSlider.OnValueChanged = function(_, value)
        local currentTime = CurTime()
        if currentTime - lastVolumeChangeTime >= volumeChangeDebounceTime then
            lastVolumeChangeTime = currentTime

            -- Send the volume change to the server
            net.Start("rRadio_VolumeChange")
            net.WriteEntity(mainEntity)
            net.WriteFloat(value)
            net.SendToServer()
        end
    end

    return volumeSlider
end

local function createBackButton(frame, stationListPanel, searchBox)
    local backButton = vgui.Create("DButton", frame)
    backButton:SetSize(Scale(30), Scale(30))
    backButton:SetPos(frame:GetWide() - Scale(79), Scale(5))
    backButton:SetText("")

    backButton.Paint = function(self, w, h)
        draw.NoTexture()
        local arrowSize = Scale(15)
        local arrowOffset = Scale(8)
        local arrowColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.TextColor

        surface.SetDrawColor(arrowColor)
        surface.DrawPoly({
            { x = arrowOffset, y = h / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 - arrowSize / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 + arrowSize / 2 },
        })
    end

    backButton.DoClick = function()
        surface.PlaySound("buttons/lightswitch2.wav")
        selectedCountry = nil
        backButton:SetVisible(false)
        populateList(stationListPanel, backButton, searchBox, true)
    end

    return backButton
end

local function createCloseButton(frame)
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetFont("Roboto18")
    closeButton:SetTextColor(Config.UI.TextColor)
    closeButton:SetSize(Scale(40), Scale(40))
    closeButton:SetPos(frame:GetWide() - Scale(40), 0)
    closeButton.Paint = function(self, w, h)
        local cornerRadius = 8
        draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonColor, false, true, false, false)
        if self:IsHovered() then
            draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonHoverColor, false, true, false, false)
        end
    end
    closeButton.DoClick = function()
        surface.PlaySound("buttons/lightswitch2.wav")
        frame:Close()
    end

    return closeButton
end

local function rRadio_OpenRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

    local frame = createFrame()
    local searchBox = createSearchBox(frame)
    local stationListPanel = createStationListPanel(frame)
    local backButton = createBackButton(frame, stationListPanel, searchBox)
    local stopButton = createStopButton(frame, stationListPanel, backButton, searchBox)
    local volumePanel = createVolumePanel(frame, stopButton:GetTall(), stopButton:GetWide())
    local volumeSlider = createVolumeSlider(volumePanel, LocalPlayer().currentRadioEntity)
    local closeButton = createCloseButton(frame)

    populateList(stationListPanel, backButton, searchBox, true)

    searchBox.OnChange = function()
        populateList(stationListPanel, backButton, searchBox, false)
    end
end

local function SendAuthorizedFriendsToServer(friends)
    net.Start("rRadio_UpdateAuthorizedFriends")
    net.WriteString(util.TableToJSON(friends))
    net.SendToServer()
end

local function SaveAuthorizedFriends(friends)
    local friendsJson = util.TableToJSON(friends)
    safeFileWrite("rradio_authorized_friends.txt", friendsJson)
    
    -- Update cache
    cachedFriends = friends
    lastCacheTime = SysTime()
    
    -- Send the updated list to the server
    SendAuthorizedFriendsToServer(friends)
end

hook.Add("Think", "CheckCarRadioMenuKey", function()
    local currentTime = CurTime()
    if currentTime - lastKeyCheckTime < keyCheckInterval then return end
    lastKeyCheckTime = currentTime

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local openKey = radioOpenKeyConVar:GetInt()
    if input.IsKeyDown(openKey) then
        local playerVehicle = ply:GetVehicle()
        if playerVehicle ~= lastPlayerVehicle then
            lastPlayerVehicle = playerVehicle
            lastMainEntity = utils.getMainVehicleEntity(playerVehicle) or playerVehicle
        end

        local mainEntity = lastMainEntity

        if not IsValid(mainEntity) then return end
        if (mainEntity:IsVehicle() or string.find(mainEntity:GetClass(), "lvs_")) and not isSitAnywhereSeat(mainEntity) then
            if not radioMenuOpen then
                RequestOpenRadioMenu(mainEntity)
            end
        end
    end
end)

local function stopCurrentStation(entity)
    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
        local entIndex = entity:EntIndex()
        hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entIndex)
        hook.Remove("Think", "UpdateRadioPosition_" .. entIndex)
    end
end

local function updateRadioPosition(entity, station)
    local mainEntity = utils.getMainVehicleEntity(entity) or entity

    local playerVehicle = LocalPlayer():GetVehicle()
    local playerMainEntity = utils.getMainVehicleEntity(playerVehicle) or playerVehicle
    local lastPlayerMainEntity = playerMainEntity  -- Initialize with the current vehicle

    hook.Add("Think", "UpdateRadioPosition_" .. mainEntity:EntIndex(), function()
        if IsValid(mainEntity) and IsValid(station) then
            station:SetPos(mainEntity:GetPos())

            -- Only update player's main vehicle entity when it changes
            local currentPlayerVehicle = LocalPlayer():GetVehicle()
            if currentPlayerVehicle ~= playerVehicle then
                playerVehicle = currentPlayerVehicle
                playerMainEntity = utils.getMainVehicleEntity(playerVehicle) or playerVehicle
                lastPlayerMainEntity = playerMainEntity
            end

            local distance = LocalPlayer():GetPos():Distance(mainEntity:GetPos())
            local isPlayerInCar = lastPlayerMainEntity == mainEntity

            updateRadioVolume(station, distance, isPlayerInCar, mainEntity)
        else
            hook.Remove("Think", "UpdateRadioPosition_" .. mainEntity:EntIndex())
        end
    end)
end

local function stopStationOnEntityRemove(entity)
    hook.Add("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex(), function(ent)
        if ent == entity then
            stopCurrentStation(entity)
        end
    end)
end

local function playStation(entity, url, volume, entityConfig, attempt)
    local mainEntity = utils.getMainVehicleEntity(entity) or entity
    sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
        if IsValid(station) and IsValid(mainEntity) then
            station:SetPos(mainEntity:GetPos())
            station:SetVolume(volume)
            station:Play()
            currentRadioSources[mainEntity] = station

            station:Set3DFadeDistance(entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance)
            updateRadioPosition(mainEntity, station)
            stopStationOnEntityRemove(mainEntity)
        else
            if attempt < entityConfig.RetryAttempts then
                timer.Simple(entityConfig.RetryDelay, function()
                    playStation(entity, url, volume, entityConfig, attempt + 1)
                end)
            end
        end
    end)
end

local function attemptPlayStation(entity, url, volume, entityConfig, attempt)
    if not IsValid(entity) then
        if attempt < 5 then
            timer.Simple(0.5, function()
                attemptPlayStation(entity, url, volume, entityConfig, attempt + 1)
            end)
        end
        return
    end

    stopCurrentStation(entity)
    playStation(entity, url, volume, entityConfig, 1)
end

-- Network receiver for playing a station
net.Receive("rRadio_PlayRadioStation", function()
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()
    local entityConfig = getEntityConfig(entity)

    local mainEntity = utils.getMainVehicleEntity(entity) or entity

    attemptPlayStation(mainEntity, url, volume, entityConfig, 1)
end)

-- Network receiver for stopping a station
net.Receive("rRadio_StopRadioStation", function()
    local entity = net.ReadEntity()
    local mainEntity = utils.getMainVehicleEntity(entity) or entity

    if not IsValid(mainEntity) then
        utils.PrintError("Received invalid entity in rRadio_StopRadioStation.", 2)
        return
    end

    -- Stop the sound
    if IsValid(currentRadioSources[mainEntity]) then
        currentRadioSources[mainEntity]:Stop()
        currentRadioSources[mainEntity] = nil
    end

    -- Update the UI
    if IsValid(mainEntity) then
        mainEntity:SetNWString("CurrentRadioStation", "")
        mainEntity:SetNWString("Country", "")
    end

    -- Remove from currently playing stations
    currentlyPlayingStations[mainEntity] = nil

    -- Update the UI if the radio menu is open
    if radioMenuOpen and LocalPlayer().currentRadioEntity == mainEntity then
        if IsValid(frame) then
            local stationListPanel = frame:FindChild("StationListPanel")
            local backButton = frame:FindChild("BackButton")
            local searchBox = frame:FindChild("SearchBox")
            if IsValid(stationListPanel) and IsValid(backButton) and IsValid(searchBox) then
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    end
end)

net.Receive("rRadio_OpenRadioMenu", function()
    local entity = net.ReadEntity()
    if IsValid(entity) then
        local mainEntity = utils.getMainVehicleEntity(entity) or entity
        LocalPlayer().currentRadioEntity = mainEntity
        rRadio_OpenRadioMenu()
    else
        utils.PrintError("Received invalid entity in rRadio_OpenRadioMenu.", 2)
    end
end)

-- Hook to apply saved theme and language on player spawn
hook.Add("PlayerInitialSpawn", "ApplySavedThemeAndLanguage", function(ply)
    loadSavedSettings()  -- Load and apply the saved theme and language
end)

loadFavorites()

-- Initialize Favorites after all entities have been initialized
hook.Add("InitPostEntity", "InitializeFavorites", function()
    -- Check if the radio menu is currently open
    if radioMenuOpen then
        -- Attempt to find the radio menu frame
        local frame = vgui.GetWorldPanel():FindChild("RadioMenuFrame") -- Ensure the frame has this name
        
        if IsValid(frame) then
            -- Find child elements within the frame by their unique names
            local stationListPanel = frame:FindChild("StationListPanel")
            local backButton = frame:FindChild("BackButton")
            local searchBox = frame:FindChild("SearchBox")
            
            -- Ensure all necessary UI components are found
            if IsValid(stationListPanel) and IsValid(backButton) and IsValid(searchBox) then
                -- Repopulate the list to reflect the loaded favorites
                populateList(stationListPanel, backButton, searchBox, true)
            else
                utils.PrintError("InitializeFavorites: One or more UI components not found in the radio menu frame.", 2)
            end
        else
            utils.PrintError("InitializeFavorites: Radio menu frame 'RadioMenuFrame' not found.", 2)
        end
    end
end)

-- Add a new network receiver for volume changes from the server
net.Receive("rRadio_VolumeUpdate", function()
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    
    if IsValid(entity) then
        entityVolumes[entity] = volume
        
        -- Update the volume of the currently playing station if it exists
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            updateRadioVolume(currentRadioSources[entity], entity:GetPos():Distance(LocalPlayer():GetPos()), LocalPlayer():GetVehicle() == entity, entity)
        end
    end
end)

