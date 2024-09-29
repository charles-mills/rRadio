-- RadioAddon Module
local RadioAddon = {}

-- Include required files
include("radio/key_names.lua")
include("radio/config.lua")
local countryTranslations = include("country_translations.lua")
local LanguageManager = include("language_manager.lua")

-- Variables for favorites
-- Using sets for O(1) lookup instead of arrays
RadioAddon.favoriteCountries = {}
RadioAddon.favoriteStations = {}

-- Data directory and files
RadioAddon.dataDir = "rradio"
RadioAddon.favoriteCountriesFile = RadioAddon.dataDir .. "/favorite_countries.json"
RadioAddon.favoriteStationsFile = RadioAddon.dataDir .. "/favorite_stations.json"

-- Ensure the data directory exists
if not file.IsDir(RadioAddon.dataDir, "DATA") then
    file.CreateDir(RadioAddon.dataDir)
end

-- Load favorites from file
function RadioAddon.loadFavorites()
    -- Load favorite countries
    local countriesJSON = file.Read(RadioAddon.favoriteCountriesFile, "DATA")
    if countriesJSON then
        local countries = util.JSONToTable(countriesJSON) or {}
        RadioAddon.favoriteCountries = {}
        for _, country in ipairs(countries) do
            RadioAddon.favoriteCountries[country] = true
        end
    end

    -- Load favorite stations
    local stationsJSON = file.Read(RadioAddon.favoriteStationsFile, "DATA")
    if stationsJSON then
        local stations = util.JSONToTable(stationsJSON) or {}
        RadioAddon.favoriteStations = {}
        for country, stationList in pairs(stations) do
            RadioAddon.favoriteStations[country] = {}
            for _, station in ipairs(stationList) do
                RadioAddon.favoriteStations[country][station] = true
            end
        end
    end
end

-- Save favorites to file
function RadioAddon.saveFavorites()
    -- Convert favoriteCountries set to array for JSON serialization
    local countries = {}
    for country, _ in pairs(RadioAddon.favoriteCountries) do
        table.insert(countries, country)
    end
    file.Write(RadioAddon.favoriteCountriesFile, util.TableToJSON(countries, true))  -- Pretty format

    -- Convert favoriteStations set to nested arrays for JSON serialization
    local stations = {}
    for country, stationSet in pairs(RadioAddon.favoriteStations) do
        stations[country] = {}
        for station, _ in pairs(stationSet) do
            table.insert(stations[country], station)
        end
    end
    file.Write(RadioAddon.favoriteStationsFile, util.TableToJSON(stations, true))
end

-- Font creation
function RadioAddon.createFonts()
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

    -- Cache dynamically created fonts to prevent re-creation
    RadioAddon.dynamicFonts = {}
end

RadioAddon.createFonts()

-- State Variables
RadioAddon.selectedCountry = nil
RadioAddon.radioMenuOpen = false
RadioAddon.currentlyPlayingStations = {}
RadioAddon.currentRadioSources = {}
RadioAddon.entityVolumes = {}
RadioAddon.lastMessageTime = -math.huge
RadioAddon.lastStationSelectTime = 0
RadioAddon.debounceTimer = {}
RadioAddon.debounceDelay = 0.2
RadioAddon.cacheExpiry = 300  -- Cache TTL: 5 minutes
RadioAddon.cacheCheckInterval = 60  -- Cache check interval

-- Caches for entity configurations
RadioAddon.entityConfigs = {}
RadioAddon.entityConfigCacheTimes = {}

-- Utility Functions
local ScrW = ScrW
local ScrH = ScrH
local CurTime = CurTime
local IsValid = IsValid
local input = input
local GetConVar = GetConVar
local file = file
local util = util
local net = net
local vgui = vgui
local surface = surface
local Color = Color
local Material = Material
local draw = draw
local timer = timer
local string = string
local math = math
local pairs = pairs
local ipairs = ipairs
local hook = hook
local table = table
local LocalPlayer = LocalPlayer

-- Cache the scaling factor and update it on screen size changes
local scaleFactor = ScrW() / 2560
hook.Add("Think", "RadioAddon_UpdateScaleFactor", function()
    local newScaleFactor = ScrW() / 2560
    if newScaleFactor ~= scaleFactor then
        scaleFactor = newScaleFactor
        RadioAddon.Scale = function(value)
            return value * scaleFactor
        end
    end
end)

function RadioAddon.Scale(value)
    return value * scaleFactor
end

-- Cache cleanup to remove expired entries
function RadioAddon.cleanCache()
    local currentTime = CurTime()
    for key, timestamp in pairs(RadioAddon.entityConfigCacheTimes) do
        if currentTime - timestamp > RadioAddon.cacheExpiry then
            RadioAddon.entityConfigs[key] = nil
            RadioAddon.entityConfigCacheTimes[key] = nil
        end
    end
end

function RadioAddon.getEntityConfig(entity)
    if not IsValid(entity) then return nil end

    local entityClass = entity:GetClass()
    local config = RadioAddon.entityConfigs[entityClass]

    if config then
        RadioAddon.entityConfigCacheTimes[entityClass] = CurTime()
        return config
    end

    local configMapping = {
        ["golden_boombox"] = Config.GoldenBoombox,
        ["boombox"] = Config.Boombox,
    }

    if configMapping[entityClass] then
        config = configMapping[entityClass]
    elseif entity:IsVehicle() or string.find(entityClass, "lvs_", 1, true) then
        config = Config.VehicleRadio
    else
        config = nil
    end

    if config then
        RadioAddon.entityConfigs[entityClass] = config
        RadioAddon.entityConfigCacheTimes[entityClass] = CurTime()
    end

    return config
end

-- Formats country names
function RadioAddon.formatCountryName(name)
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    return countryTranslations:GetCountryName(lang, formattedName)
end

-- Adjusts the radio volume based on distance
function RadioAddon.updateRadioVolume(station, distance, isPlayerInCar, entity)
    local entityConfig = RadioAddon.getEntityConfig(entity)
    if not entityConfig then return end

    local volume = RadioAddon.entityVolumes[entity] or entityConfig.Volume
    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    local maxVolume = GetConVar("radio_max_volume"):GetFloat()
    local effectiveVolume = math.min(volume, maxVolume)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    elseif distance <= entityConfig.MinVolumeDistance then
        station:SetVolume(effectiveVolume)
    elseif distance <= entityConfig.MaxHearingDistance then
        local adjustedVolume = effectiveVolume * (1 - (distance - entityConfig.MinVolumeDistance) / (entityConfig.MaxHearingDistance - entityConfig.MinVolumeDistance))
        station:SetVolume(adjustedVolume)
    else
        station:SetVolume(0)
    end
end

-- Displays car radio message with rate limiting
function RadioAddon.PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local currentTime = CurTime()
    if (currentTime - RadioAddon.lastMessageTime) < Config.MessageCooldown then
        return
    end

    RadioAddon.lastMessageTime = currentTime

    local openKey = GetConVar("car_radio_open_key"):GetInt()
    local keyName = GetKeyName(openKey)
    local message = Config.Lang["PressKeyToOpen"]:gsub("{key}", keyName)

    chat.AddText(
        Color(0, 255, 128), "[CAR RADIO] ",
        Color(255, 255, 255), message
    )
end

-- Network Handlers
net.Receive("CarRadioMessage", RadioAddon.PrintCarRadioMessage)

-- Calculates the optimal font size for the stop button based on its size
function RadioAddon.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local minFontSize = 10
    local fontName = "DynamicStopButtonFont_" .. buttonWidth .. "_" .. buttonHeight

    -- Check if the font already exists to prevent re-creation
    if not RadioAddon.dynamicFonts[fontName] then
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        })
        RadioAddon.dynamicFonts[fontName] = true
    end

    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)

    -- Adjust font size until text fits within 90% of the button width or minimum font size is reached
    while textWidth > buttonWidth * 0.9 and maxFontSize > minFontSize do
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

-- Updates favorite countries and stations when received from server
net.Receive("SendFavoriteCountries", function()
    local serverFavorites = net.ReadTable()
    if serverFavorites and next(serverFavorites) then
        -- Convert array to set for O(1) lookups
        RadioAddon.favoriteCountries = {}
        for _, country in ipairs(serverFavorites) do
            RadioAddon.favoriteCountries[country] = true
        end
    end

    if RadioAddon.GUI and RadioAddon.GUI.stationListPanel and RadioAddon.populateList then
        RadioAddon.populateList(RadioAddon.GUI.stationListPanel, RadioAddon.GUI.backButton, RadioAddon.GUI.searchBox, false)
    end
end)

-- Creates a star icon for marking favorite countries
function RadioAddon.createStarIcon(parent, country)
    local starIcon = vgui.Create("DImageButton", parent)
    local iconSize = RadioAddon.Scale(24)
    starIcon:SetSize(iconSize, iconSize)
    starIcon:SetPos(RadioAddon.Scale(8), (RadioAddon.Scale(40) - iconSize) / 2)
    starIcon:SetImage(RadioAddon.favoriteCountries[country] and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        net.Start("ToggleFavoriteCountry")
        net.WriteString(country)
        net.SendToServer()

        -- Toggle favorite status in the set
        if RadioAddon.favoriteCountries[country] then
            RadioAddon.favoriteCountries[country] = nil
        else
            RadioAddon.favoriteCountries[country] = true
        end

        RadioAddon.saveFavorites()

        if RadioAddon.GUI and RadioAddon.GUI.stationListPanel then
            RadioAddon.populateList(RadioAddon.GUI.stationListPanel, RadioAddon.GUI.backButton, RadioAddon.GUI.searchBox, false)
        end
    end

    return starIcon
end

-- Creates a star icon for marking favorite stations
function RadioAddon.createStationStarIcon(parent, country, station)
    local starIcon = vgui.Create("DImageButton", parent)
    local iconSize = RadioAddon.Scale(24)
    starIcon:SetSize(iconSize, iconSize)
    starIcon:SetPos(RadioAddon.Scale(8), (RadioAddon.Scale(40) - iconSize) / 2)
    local isFavorite = RadioAddon.favoriteStations[country] and RadioAddon.favoriteStations[country][station.name]
    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        if not RadioAddon.favoriteStations[country] then
            RadioAddon.favoriteStations[country] = {}
        end

        if RadioAddon.favoriteStations[country][station.name] then
            RadioAddon.favoriteStations[country][station.name] = nil
            if next(RadioAddon.favoriteStations[country]) == nil then
                RadioAddon.favoriteStations[country] = nil
            end
        else
            RadioAddon.favoriteStations[country][station.name] = true
        end

        RadioAddon.saveFavorites()

        if RadioAddon.GUI and RadioAddon.GUI.stationListPanel then
            RadioAddon.populateList(RadioAddon.GUI.stationListPanel, RadioAddon.GUI.backButton, RadioAddon.GUI.searchBox, false)
        end
    end

    return starIcon
end

-- Populates the station list
function RadioAddon.populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then return end

    if backButton and not RadioAddon.selectedCountry then
        backButton:SetVisible(false)
    end

    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText():lower()

    if not RadioAddon.selectedCountry then
        local countries = {}
        for country, _ in pairs(Config.RadioStations) do
            local translatedCountry = RadioAddon.formatCountryName(country)
            if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        table.sort(countries, function(a, b)
            local aIsFavorite = RadioAddon.favoriteCountries[a.original]
            local bIsFavorite = RadioAddon.favoriteCountries[b.original]

            if aIsFavorite ~= bIsFavorite then
                return aIsFavorite
            else
                return a.translated < b.translated
            end
        end)

        for _, country in ipairs(countries) do
            local countryButton = vgui.Create("DButton", stationListPanel)
            countryButton:Dock(TOP)
            countryButton:DockMargin(RadioAddon.Scale(5), RadioAddon.Scale(5), RadioAddon.Scale(5), 0)
            countryButton:SetTall(RadioAddon.Scale(40))
            countryButton:SetText(country.translated)
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                local color = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor
                draw.RoundedBox(8, 0, 0, w, h, color)
            end

            RadioAddon.createStarIcon(countryButton, country.original)

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                RadioAddon.selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                RadioAddon.populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        local stations = {}
        local favoriteStations = RadioAddon.favoriteStations[RadioAddon.selectedCountry] or {}

        for _, station in ipairs(Config.RadioStations[RadioAddon.selectedCountry]) do
            if filterText == "" or station.name:lower():find(filterText, 1, true) then
                local isFavorite = favoriteStations[station.name]
                table.insert(stations, { station = station, favorite = isFavorite })
            end
        end

        table.sort(stations, function(a, b)
            if a.favorite ~= b.favorite then
                return a.favorite
            else
                return a.station.name < b.station.name
            end
        end)

        for _, stationData in ipairs(stations) do
            local station = stationData.station
            local stationButton = vgui.Create("DButton", stationListPanel)
            stationButton:Dock(TOP)
            stationButton:DockMargin(RadioAddon.Scale(5), RadioAddon.Scale(5), RadioAddon.Scale(5), 0)
            stationButton:SetTall(RadioAddon.Scale(40))
            stationButton:SetText(station.name)
            stationButton:SetFont("Roboto18")
            stationButton:SetTextColor(Config.UI.TextColor)

            stationButton.Paint = function(self, w, h)
                local entity = LocalPlayer():GetNWEntity("currentRadioEntity")
                local isPlaying = RadioAddon.currentlyPlayingStations[entity] == station
                local color = isPlaying and Config.UI.PlayingButtonColor or (self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor)
                draw.RoundedBox(8, 0, 0, w, h, color)
            end

            RadioAddon.createStationStarIcon(stationButton, RadioAddon.selectedCountry, station)

            stationButton.DoClick = function()
                local currentTime = CurTime()

                if (currentTime - RadioAddon.lastStationSelectTime) < 2 then
                    return
                end

                surface.PlaySound("buttons/button17.wav")
                local entity = LocalPlayer():GetNWEntity("currentRadioEntity")

                if not IsValid(entity) then
                    return
                end

                if RadioAddon.currentlyPlayingStations[entity] then
                    net.Start("StopCarRadioStation")
                    net.WriteEntity(entity)
                    net.SendToServer()
                end

                local volume = RadioAddon.entityVolumes[entity] or (RadioAddon.getEntityConfig(entity) and RadioAddon.getEntityConfig(entity).Volume) or 0.5
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(station.name)
                net.WriteString(station.url)
                net.WriteFloat(volume)
                net.SendToServer()

                RadioAddon.currentlyPlayingStations[entity] = station
                RadioAddon.lastStationSelectTime = currentTime
                RadioAddon.populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    end

    -- Open the radio menu
    function RadioAddon.openRadioMenu()
        if RadioAddon.radioMenuOpen then return end
        RadioAddon.radioMenuOpen = true

        RadioAddon.GUI = {}

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(RadioAddon.Scale(Config.UI.FrameSize.width), RadioAddon.Scale(Config.UI.FrameSize.height))
        frame:Center()
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:MakePopup()
        frame.OnClose = function()
            RadioAddon.radioMenuOpen = false
            RadioAddon.GUI = nil
        end

        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
            draw.RoundedBoxEx(8, 0, 0, w, RadioAddon.Scale(40), Config.UI.HeaderColor, true, true, false, false)

            local iconSize = RadioAddon.Scale(25)
            local iconOffsetX = RadioAddon.Scale(10)

            surface.SetFont("HeaderFont")
            local textHeight = select(2, surface.GetTextSize("H"))

            local iconOffsetY = RadioAddon.Scale(2) + textHeight - iconSize

            surface.SetMaterial(Material("hud/radio"))
            surface.SetDrawColor(Config.UI.TextColor)
            surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)

            local countryText = Config.Lang["SelectCountry"] or "Select Country"
            draw.SimpleText(RadioAddon.selectedCountry and RadioAddon.formatCountryName(RadioAddon.selectedCountry) or countryText, "HeaderFont", iconOffsetX + iconSize + RadioAddon.Scale(5), iconOffsetY, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        -- Create Search Box
        local searchBox = vgui.Create("DTextEntry", frame)
        searchBox:SetPos(RadioAddon.Scale(10), RadioAddon.Scale(50))
        searchBox:SetSize(RadioAddon.Scale(Config.UI.FrameSize.width) - RadioAddon.Scale(20), RadioAddon.Scale(30))
        searchBox:SetFont("Roboto18")
        searchBox:SetPlaceholderText(Config.Lang and Config.Lang["SearchPlaceholder"] or "Search")
        searchBox:SetTextColor(Config.UI.TextColor)
        searchBox:SetDrawBackground(false)
        searchBox.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
            self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)

            if self:GetText() == "" then
                draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), RadioAddon.Scale(5), h / 2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        RadioAddon.GUI.searchBox = searchBox

        -- Create Station List Panel
        local stationListPanel = vgui.Create("DScrollPanel", frame)
        stationListPanel:SetPos(RadioAddon.Scale(5), RadioAddon.Scale(90))
        stationListPanel:SetSize(RadioAddon.Scale(Config.UI.FrameSize.width) - RadioAddon.Scale(20), RadioAddon.Scale(Config.UI.FrameSize.height) - RadioAddon.Scale(200))

        RadioAddon.GUI.stationListPanel = stationListPanel

        -- Create Stop Button
        local stopButtonHeight = RadioAddon.Scale(Config.UI.FrameSize.width) / 8
        local stopButtonWidth = RadioAddon.Scale(Config.UI.FrameSize.width) / 4
        local stopButtonText = Config.Lang["StopRadio"] or "STOP"
        local stopButtonFont = RadioAddon.calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)

        local stopButton = vgui.Create("DButton", frame)
        stopButton:SetPos(RadioAddon.Scale(10), RadioAddon.Scale(Config.UI.FrameSize.height) - RadioAddon.Scale(90))
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
            local entity = RadioAddon.currentRadioEntity
            if IsValid(entity) then
                net.Start("StopCarRadioStation")
                net.WriteEntity(entity)
                net.SendToServer()
                RadioAddon.currentlyPlayingStations[entity] = nil
                RadioAddon.populateList(stationListPanel, backButton, searchBox, false)
            end
        end

        -- Create Volume Panel
        local volumePanel = vgui.Create("DPanel", frame)
        volumePanel:SetPos(RadioAddon.Scale(20) + stopButtonWidth, RadioAddon.Scale(Config.UI.FrameSize.height) - RadioAddon.Scale(90))
        volumePanel:SetSize(RadioAddon.Scale(Config.UI.FrameSize.width) - RadioAddon.Scale(30) - stopButtonWidth, stopButtonHeight)
        volumePanel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
        end

        -- Create Volume Icon
        local volumeIconSize = RadioAddon.Scale(50)

        local volumeIcon = vgui.Create("DImage", volumePanel)
        volumeIcon:SetPos(RadioAddon.Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
        volumeIcon:SetSize(volumeIconSize, volumeIconSize)
        volumeIcon:SetImage("hud/volume")

        -- Create Volume Slider
        local volumeSlider = vgui.Create("DNumSlider", volumePanel)
        volumeSlider:SetPos(RadioAddon.Scale(10) + volumeIconSize + RadioAddon.Scale(10), RadioAddon.Scale(5))
        volumeSlider:SetSize(RadioAddon.Scale(200), RadioAddon.Scale(30))
        volumeSlider:SetText("")
        volumeSlider:SetMin(0)
        volumeSlider:SetMax(1)
        volumeSlider:SetDecimals(2)

        local entity = RadioAddon.currentRadioEntity
        local currentVolume = RadioAddon.entityVolumes[entity] or (RadioAddon.getEntityConfig(entity) and RadioAddon.getEntityConfig(entity).Volume) or 0.5
        volumeSlider:SetValue(currentVolume)

        volumeSlider.Slider.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, h / 2 - 4, w, 16, Config.UI.TextColor)
        end

        volumeSlider.Slider.Knob.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, RadioAddon.Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
        end

        volumeSlider.TextArea:SetVisible(false)

        volumeSlider.OnValueChanged = function(_, value)
            local ent = RadioAddon.currentRadioEntity

            if ent:GetClass() == "prop_vehicle_prisoner_pod" and IsValid(ent:GetParent()) then
                local parent = ent:GetParent()
                if string.find(parent:GetClass(), "lvs_", 1, true) then
                    ent = parent
                end
            end

            RadioAddon.entityVolumes[ent] = value

            -- Debounce per entity to prevent excessive updates
            if not RadioAddon.debounceTimer[ent] or (CurTime() - RadioAddon.debounceTimer[ent] >= RadioAddon.debounceDelay) then
                RadioAddon.debounceTimer[ent] = CurTime()
                if RadioAddon.currentRadioSources[ent] and IsValid(RadioAddon.currentRadioSources[ent]) then
                    RadioAddon.currentRadioSources[ent]:SetVolume(value)
                end
            end
        end

        -- Create Back Button
        local backButton = vgui.Create("DButton", frame)
        backButton:SetSize(RadioAddon.Scale(30), RadioAddon.Scale(30))
        backButton:SetPos(frame:GetWide() - RadioAddon.Scale(79), RadioAddon.Scale(5))
        backButton:SetText("")

        backButton.Paint = function(self, w, h)
            draw.NoTexture()
            local arrowSize = RadioAddon.Scale(15)
            local arrowOffset = RadioAddon.Scale(8)
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
            RadioAddon.selectedCountry = nil
            backButton:SetVisible(false)
            RadioAddon.populateList(stationListPanel, backButton, searchBox, true)
        end

        RadioAddon.GUI.backButton = backButton

        -- Create Close Button
        local closeButton = vgui.Create("DButton", frame)
        closeButton:SetText("X")
        closeButton:SetFont("Roboto18")
        closeButton:SetTextColor(Config.UI.TextColor)
        closeButton:SetSize(RadioAddon.Scale(40), RadioAddon.Scale(40))
        closeButton:SetPos(frame:GetWide() - RadioAddon.Scale(40), 0)
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

        -- Optimize scrollbar rendering by overriding only necessary parts
        local sbar = stationListPanel:GetVBar()
        sbar:SetWide(RadioAddon.Scale(8))
        function sbar:Paint(w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor)
        end
        function sbar.btnUp:Paint(w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor)
        end
        function sbar.btnDown:Paint(w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor)
        end
        function sbar.btnGrip:Paint(w, h)
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor)
        end

        -- Populate the list initially
        RadioAddon.populateList(stationListPanel, backButton, searchBox, true)

        -- Update the list on search box changes
        searchBox.OnChange = function(self)
            RadioAddon.populateList(stationListPanel, backButton, searchBox, false)
        end
    end

    -- Handles key press to open the car radio menu
    hook.Add("Think", "RadioAddon_OpenRadioMenu", function()
        local openKey = GetConVar("car_radio_open_key"):GetInt()
        if input.IsKeyDown(openKey) and not RadioAddon.radioMenuOpen and IsValid(LocalPlayer():GetVehicle()) then
            RadioAddon.currentRadioEntity = LocalPlayer():GetVehicle()
            RadioAddon.openRadioMenu()
        end
    end)

    -- Receives the play car radio station request from the server
    net.Receive("PlayCarRadioStation", function()
        local entity = net.ReadEntity()
        local url = net.ReadString()
        local volume = math.Clamp(net.ReadFloat(), 0, 1)

        local entityRetryAttempts = 5
        local entityRetryDelay = 0.5

        local function attemptPlayStation(attempt)
            if not IsValid(entity) then
                if attempt < entityRetryAttempts then
                    timer.Simple(entityRetryDelay, function()
                        attemptPlayStation(attempt + 1)
                    end)
                end
                return
            end

            local entityConfig = RadioAddon.getEntityConfig(entity)

            if RadioAddon.currentRadioSources[entity] and IsValid(RadioAddon.currentRadioSources[entity]) then
                RadioAddon.currentRadioSources[entity]:Stop()
            end

            local function tryPlayStation(playAttempt)
                sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
                    if IsValid(station) and IsValid(entity) then
                        station:SetPos(entity:GetPos())
                        station:SetVolume(volume)
                        station:Play()
                        RadioAddon.currentRadioSources[entity] = station

                        station:Set3DFadeDistance(entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance)

                        local entIndex = entity:EntIndex()

                        -- Unique hook names to prevent collisions
                        local positionHookName = "RadioAddon_UpdateRadioPosition_" .. entIndex
                        local removeHookName = "RadioAddon_StopRadioOnEntityRemove_" .. entIndex

                        hook.Add("Think", positionHookName, function()
                            if IsValid(entity) and IsValid(station) then
                                station:SetPos(entity:GetPos())

                                local playerPos = LocalPlayer():GetPos()
                                local entityPos = entity:GetPos()
                                local distance = playerPos:Distance(entityPos)
                                local isPlayerInCar = LocalPlayer():GetVehicle() == entity

                                RadioAddon.updateRadioVolume(station, distance, isPlayerInCar, entity)
                            else
                                hook.Remove("Think", positionHookName)
                            end
                        end)

                        hook.Add("EntityRemoved", removeHookName, function(ent)
                            if ent == entity then
                                if IsValid(RadioAddon.currentRadioSources[entity]) then
                                    RadioAddon.currentRadioSources[entity]:Stop()
                                end
                                RadioAddon.currentRadioSources[entity] = nil
                                hook.Remove("EntityRemoved", removeHookName)
                                hook.Remove("Think", positionHookName)
                            end
                        end)
                    else
                        if playAttempt < entityConfig.RetryAttempts then
                            timer.Simple(entityConfig.RetryDelay, function()
                                tryPlayStation(playAttempt + 1)
                            end)
                        end
                    end
                end)
            end

            tryPlayStation(1)
        end

        attemptPlayStation(1)
    end)

    -- Handles stopping the car radio station
    net.Receive("StopCarRadioStation", function()
        local entity = net.ReadEntity()

        if IsValid(entity) and IsValid(RadioAddon.currentRadioSources[entity]) then
            RadioAddon.currentRadioSources[entity]:Stop()
            RadioAddon.currentRadioSources[entity] = nil

            local entIndex = entity:EntIndex()

            hook.Remove("EntityRemoved", "RadioAddon_StopRadioOnEntityRemove_" .. entIndex)
            hook.Remove("Think", "RadioAddon_UpdateRadioPosition_" .. entIndex)
        end
    end)

    -- Opens the radio menu when requested
    net.Receive("OpenRadioMenu", function()
        local entity = net.ReadEntity()
        RadioAddon.currentRadioEntity = entity
        if not RadioAddon.radioMenuOpen then
            RadioAddon.openRadioMenu()
        end
    end)

    -- Loads favorites on script initialization
    RadioAddon.loadFavorites()

    -- Periodically clean up cache to remove expired entries
    timer.Create("RadioAddon_CleanEntityConfigCache", RadioAddon.cacheCheckInterval, 0, function()
        RadioAddon.cleanCache()
    end)