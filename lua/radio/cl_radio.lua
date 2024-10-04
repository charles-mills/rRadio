--[[ 
    rRadio Addon for Garry's Mod - Client Radio Script
    Description: Manages client-side radio functionalities and UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

-- Include necessary files
include("misc/key_names.lua")
include("misc/config.lua")
include("misc/utils.lua")

-- Localization and language management
local countryTranslations = include("localisation/country_translations.lua")
local LanguageManager = include("localisation/language_manager.lua")

-- Initialize favorite lists
local favoriteCountries = {}
local favoriteStations = {}

-- Define data directory and file paths
local dataDir = "rradio"
local favoriteCountriesFile = string.format("%s/favorite_countries.txt", dataDir)
local favoriteStationsFile = string.format("%s/favorite_stations.txt", dataDir)

-- Ensure the data directory exists
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

-- Load favorites from file
local function loadFavorites()
    if file.Exists(favoriteCountriesFile, "DATA") then
        local countriesData = file.Read(favoriteCountriesFile, "DATA")
        if countriesData then
            favoriteCountries = util.JSONToTable(countriesData) or {}
        else
            utils.PrintError("Failed to read favorite countries file.", 2)
        end
    end

    if file.Exists(favoriteStationsFile, "DATA") then
        local stationsData = file.Read(favoriteStationsFile, "DATA")
        if stationsData then
            favoriteStations = util.JSONToTable(stationsData) or {}
        else
            utils.PrintError("Failed to read favorite stations file.", 2)
        end
    end
end

-- Save favorites to file
local function saveFavorites()
    local successCountries = file.Write(favoriteCountriesFile, util.TableToJSON(favoriteCountries))
    local successStations = file.Write(favoriteStationsFile, util.TableToJSON(favoriteStations))

    if not successCountries then
        utils.PrintError("Failed to save favorite countries to file.", 2)
    end

    if not successStations then
        utils.PrintError("Failed to save favorite stations to file.", 2)
    end
end

-- Font creation
local function createFonts()
    local success, err = pcall(function()
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
    end)

    if not success then
        utils.PrintError("Failed to create fonts: " .. err, 2)
    end
end

createFonts()

-- State Variables
local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStations = {}  -- Initialize the currentlyPlayingStations table
local currentRadioSources = {}
local entityVolumes = {}
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

local function formatCountryName(name)
    -- Reformat and then translate the country name
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_\']*)", function(a, b)
        return a:upper() .. b:lower()
    end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    return countryTranslations:GetCountryName(lang, formattedName) or formattedName
end

local function getEffectiveVolume(entity, volume)
    local maxVolume = GetConVar("radio_max_volume"):GetFloat()
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
    return GetConVar("radio_show_messages"):GetBool()
end

local function isValidVehicle(vehicle)
    return IsValid(vehicle) and not utils.isSitAnywhereSeat(vehicle)
end

local function isMessageCooldownActive(currentTime)
    return (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge
end

local function updateLastMessageTime(currentTime)
    lastMessageTime = currentTime
end

local function getOpenKeyName()
    local openKey = GetConVar("radio_open_key"):GetInt()
    return input.GetKeyName(openKey) or "unknown key"
end

local function getRadioMessage(keyName)
    return (Config.Lang["PressKeyToOpen"] or "Press {key} to open the radio menu"):gsub("{key}", keyName)
end

local function addChatMessage(message)
    chat.AddText(
        Color(0, 255, 128), "[CAR RADIO] ",
        Color(255, 255, 255), message
    )
end

local function PrintrRadio_ShowCarRadioMessage()
    -- Ensure the convar is set to show messages
    if not shouldShowRadioMessage() then return end

    local vehicle = LocalPlayer():GetVehicle()

    -- Ensure vehicle is valid
    if not IsValid(vehicle) then return end

    -- If the networked variable isn't ready, retry the function after a short delay
    if vehicle:GetNWBool("IsSitAnywhereSeat", false) == nil then
        timer.Simple(0.5, function()
            PrintrRadio_ShowCarRadioMessage()
        end)
        return
    end

    -- Ensure it's not a sit-anywhere seat
    if utils.isSitAnywhereSeat(vehicle) then
        print("Returning because it's a sit-anywhere seat")
        return
    end

    -- Cooldown management to avoid message spam
    local currentTime = CurTime()
    if isMessageCooldownActive(currentTime) then return end

    -- Update the last message time
    updateLastMessageTime(currentTime)

    -- Get the radio open key and the message
    local keyName = getOpenKeyName()
    local message = getRadioMessage(keyName)

    -- Add the message to chat
    addChatMessage(message)
end

-- Network Handlers
net.Receive("rRadio_ShowCarRadioMessage", PrintrRadio_ShowCarRadioMessage)

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

    while textWidth > buttonWidth * 0.9 do
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

-- Update favorite countries and stations when received from server
net.Receive("SendFavoriteCountries", function()
    local serverFavorites = net.ReadTable()
    -- Ensure server data does not overwrite local data if it is empty
    if serverFavorites and next(serverFavorites) then
        favoriteCountries = serverFavorites
    end

    if stationListPanel and populateList then
        populateList(stationListPanel, backButton, searchBox, false)  -- Repopulate the list with updated data
    end
end)

local function createStarIcon(parent, country, stationListPanel, backButton, searchBox)
    local starIcon = vgui.Create("DImageButton", parent)
    starIcon:SetSize(Scale(24), Scale(24))
    starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    starIcon:SetImage(table.HasValue(favoriteCountries, country) and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        net.Start("rRadio_ToggleFavorite")
        net.WriteString(country)
        net.SendToServer()

        -- Update the favorite status immediately on the client-side
        if table.HasValue(favoriteCountries, country) then
            table.RemoveByValue(favoriteCountries, country)
        else
            table.insert(favoriteCountries, country)
        end

        saveFavorites()

        -- Repopulate the list to reflect the change immediately
        if stationListPanel then
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end

    return starIcon
end

local function createStationStarIcon(parent, country, station, stationListPanel, backButton, searchBox)
    local starIcon = vgui.Create("DImageButton", parent)
    starIcon:SetSize(Scale(24), Scale(24))
    starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    starIcon:SetImage(favoriteStations[country] and table.HasValue(favoriteStations[country], station.name) and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        if not favoriteStations[country] then
            favoriteStations[country] = {}
        end

        if table.HasValue(favoriteStations[country], station.name) then
            table.RemoveByValue(favoriteStations[country], station.name)
            if #favoriteStations[country] == 0 then
                favoriteStations[country] = nil
            end
        else
            table.insert(favoriteStations[country], station.name)
        end

        saveFavorites()

        -- Repopulate the list to reflect the change immediately
        if stationListPanel then
            populateList(stationListPanel, backButton, searchBox, false)
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
    countryButton:SetText(country.translated)
    countryButton:SetFont("Roboto18")
    countryButton:SetTextColor(Config.UI.TextColor)

    countryButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
        end
    end

    -- Add the star icon
    local starIcon = createStarIcon(countryButton, country.original, stationListPanel, backButton, searchBox)

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

    if not IsValid(entity) then
        return
    end

    if currentlyPlayingStations[entity] then
        net.Start("rRadio_StopRadioStation")
        net.WriteEntity(entity)
        net.SendToServer()
    end

    local volume = entityVolumes[entity] or getEntityConfig(entity).Volume
    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(entity)
    net.WriteString(station.name)
    net.WriteString(station.url)
    net.WriteFloat(volume)
    net.SendToServer()

    currentlyPlayingStations[entity] = station
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
    stationButton:SetText(station.name)
    stationButton:SetFont("Roboto18")
    stationButton:SetTextColor(Config.UI.TextColor)

    local currentlyPlayingStations = {}

    stationButton.Paint = function(self, w, h)
        if station == currentlyPlayingStations[LocalPlayer().currentRadioEntity] then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
        else
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
            if self:IsHovered() then
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
            end
        end
    end

    -- Add the star icon
    local starIcon = createStationStarIcon(stationButton, selectedCountry, station, stationListPanel, backButton, searchBox)

    stationButton.DoClick = function()
        handleStationButtonClick(stationListPanel, backButton, searchBox, station)
    end

    return stationButton
end

-- Function to get sorted countries
local function getSortedCountries(filterText)
    local countries = {}
    for country, _ in pairs(Config.RadioStations) do
        local translatedCountry = formatCountryName(country)
        if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
            table.insert(countries, { original = country, translated = translatedCountry })
        end
    end

    table.sort(countries, function(a, b)
        local aIsPrioritized = table.HasValue(favoriteCountries, a.original)
        local bIsPrioritized = table.HasValue(favoriteCountries, b.original)

        if aIsPrioritized and not bIsPrioritized then
            return true
        elseif not aIsPrioritized and bIsPrioritized then
            return false
        else
            return a.translated < b.translated
        end
    end)

    return countries
end

-- Function to populate the list with countries
local function populateCountryList(stationListPanel, backButton, searchBox, filterText)
    local countries = getSortedCountries(filterText)
    for _, country in ipairs(countries) do
        createCountryButton(stationListPanel, country, backButton, searchBox)
    end
end

-- Function to get sorted stations
local function getSortedStations(filterText)
    local stations = {}
    for _, station in ipairs(Config.RadioStations[selectedCountry]) do
        if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
            local isFavorite = favoriteStations[selectedCountry] and table.HasValue(favoriteStations[selectedCountry], station.name)
            table.insert(stations, { station = station, favorite = isFavorite })
        end
    end

    table.sort(stations, function(a, b)
        if a.favorite and not b.favorite then
            return true
        elseif not a.favorite and b.favorite then
            return false
        else
            return a.station.name < b.station.name
        end
    end)

    return stations
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
    if not stationListPanel then
        return
    end

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
        
        surface.SetMaterial(Material("hud/radio"))
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
            currentlyPlayingStation = nil
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end

    return stopButton
end

local function createVolumePanel(frame, stopButtonWidth)
    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
    volumePanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonWidth)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
    end

    return volumePanel
end

local function createVolumeSlider(volumePanel, entity)
    local volumeIconSize = Scale(50)
    
    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 5)
    volumeIcon:SetSize(volumeIconSize, volumeIconSize)
    volumeIcon:SetImage("hud/volume")

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(volumeIcon:GetWide() - Scale(200), -Scale(25))
    volumeSlider:SetSize(volumePanel:GetWide() - volumeIcon:GetWide() + Scale(180), volumePanel:GetTall() - Scale(20))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)
    
    local currentVolume = entityVolumes[entity] or getEntityConfig(entity).Volume
    volumeSlider:SetValue(currentVolume)
    
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, h/2 - 4, w, 16, Config.UI.TextColor)
    end
    
    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
    end
    
    volumeSlider.TextArea:SetVisible(false)

    volumeSlider.OnValueChanged = function(_, value)
        -- Check if it's an LVS vehicle by checking the parent entity or other conditions
        if entity:GetClass() == "prop_vehicle_prisoner_pod" and entity:GetParent():IsValid() then
            parent = entity:GetParent()
            if string.find(parent:GetClass(), "lvs_") then
                entity = parent -- Set the entity to the parent entity if is an LVS vehicle
            end
        end

        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
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
    local stopButton = createStopButton(frame, stationListPanel, backButton, searchBox)
    local volumePanel = createVolumePanel(frame, stopButton:GetWide())
    local volumeSlider = createVolumeSlider(volumePanel, LocalPlayer().currentRadioEntity)
    local backButton = createBackButton(frame, stationListPanel, searchBox)
    local closeButton = createCloseButton(frame)

    populateList(stationListPanel, backButton, searchBox, true)

    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end
end

hook.Add("Think", "OpenCarRadioMenu", function()
    local openKey = GetConVar("radio_open_key"):GetInt()
    local vehicle = LocalPlayer():GetVehicle()

    if input.IsKeyDown(openKey) and not radioMenuOpen and IsValid(vehicle) and not utils.isSitAnywhereSeat(vehicle) then
        LocalPlayer().currentRadioEntity = vehicle
        rRadio_OpenRadioMenu()
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
    hook.Add("Think", "UpdateRadioPosition_" .. entity:EntIndex(), function()
        if IsValid(entity) and IsValid(station) then
            station:SetPos(entity:GetPos())

            local playerPos = LocalPlayer():GetPos()
            local entityPos = entity:GetPos()
            local distance = playerPos:Distance(entityPos)
            local isPlayerInCar = LocalPlayer():GetVehicle() == entity

            updateRadioVolume(station, distance, isPlayerInCar, entity)
        else
            hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
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
    sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
        if IsValid(station) and IsValid(entity) then
            station:SetPos(entity:GetPos())
            station:SetVolume(volume)
            station:Play()
            currentRadioSources[entity] = station

            station:Set3DFadeDistance(entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance)
            updateRadioPosition(entity, station)
            stopStationOnEntityRemove(entity)
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

net.Receive("rRadio_PlayRadioStation", function()
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()
    local entityConfig = getEntityConfig(entity)

    attemptPlayStation(entity, url, volume, entityConfig, 1)
end)


net.Receive("rRadio_StopRadioStation", function()
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        utils.PrintError("Received invalid entity in rRadio_StopRadioStation.", 2)
        return
    end

    if IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
        local entIndex = entity:EntIndex()
        hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entIndex)
        hook.Remove("Think", "UpdateRadioPosition_" .. entIndex)
    else
        utils.PrintError("No valid radio source found for entity in rRadio_StopRadioStation.", 2)
    end
end)

net.Receive("rRadio_OpenRadioMenu", function()
    local entity = net.ReadEntity()
    if not IsValid(entity) then
        utils.PrintError("Received invalid entity in rRadio_OpenRadioMenu.", 2)
        return
    end
    LocalPlayer().currentRadioEntity = entity
    if not radioMenuOpen then
        rRadio_OpenRadioMenu()
    end
end)

hook.Add("PlayerInitialSpawn", "ApplySavedThemeAndLanguage", function(ply)
    loadSavedSettings()  -- Load and apply the saved theme and language
end)

loadFavorites()  -- Load the favorite stations and countries when the script initializes

hook.Add("InitPostEntity", "InitializeFavorites", function()
    populateList(stationListPanel, backButton, searchBox, true)  -- Ensure UI is updated with the loaded favorites after entities have loaded
end)
