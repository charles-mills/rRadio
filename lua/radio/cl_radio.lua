include("radio/key_names.lua")
include("radio/config.lua")
local countryTranslations = include("country_translations.lua")
local LanguageManager = include("language_manager.lua")

local favoriteCountries = {}
local favoriteStations = {}

local dataDir = "rradio"
local favoriteCountriesFile = dataDir .. "/favorite_countries.txt"
local favoriteStationsFile = dataDir .. "/favorite_stations.txt"

-- Ensure the data directory exists
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

-- Load favorites from file
local function loadFavorites()
    if file.Exists(favoriteCountriesFile, "DATA") then
        favoriteCountries = util.JSONToTable(file.Read(favoriteCountriesFile, "DATA")) or {}
    end

    if file.Exists(favoriteStationsFile, "DATA") then
        favoriteStations = util.JSONToTable(file.Read(favoriteStationsFile, "DATA")) or {}
    end
end

-- Save favorites to file
local function saveFavorites()
    file.Write(favoriteCountriesFile, util.TableToJSON(favoriteCountries))
    file.Write(favoriteStationsFile, util.TableToJSON(favoriteStations))
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
local currentlyPlayingStation = nil
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
    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    end
    return nil
end

local function formatCountryName(name)
    -- Reformat and then translate the country name
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_\']*)", function(a, b) 
        return string.upper(a) .. string.lower(b) 
    end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    return countryTranslations:GetCountryName(lang, formattedName)
end

local function updateRadioVolume(station, distance, isPlayerInCar, entity)
    local entityConfig = getEntityConfig(entity)
    if not entityConfig then return end

    local volume = entityVolumes[entity] or entityConfig.Volume
    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    local maxVolume = GetConVar("radio_max_volume"):GetFloat()
    local effectiveVolume = math.min(volume, maxVolume)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    else
        if distance <= entityConfig.MinVolumeDistance then
            station:SetVolume(effectiveVolume)
        elseif distance <= entityConfig.MaxHearingDistance then
            local adjustedVolume = effectiveVolume * (1 - (distance - entityConfig.MinVolumeDistance) / (entityConfig.MaxHearingDistance - entityConfig.MinVolumeDistance))
            station:SetVolume(adjustedVolume)
        else
            station:SetVolume(0)
        end
    end
end

local function PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local currentTime = CurTime()
    if (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge then
        return
    end

    lastMessageTime = currentTime

    local openKey = GetConVar("car_radio_open_key"):GetInt()
    local keyName = GetKeyName(openKey)
    local message = Config.Lang["PressKeyToOpen"]:gsub("{key}", keyName)

    chat.AddText(
        Color(0, 255, 128), "[CAR RADIO] ",
        Color(255, 255, 255), message
    )
end

-- Network Handlers
net.Receive("CarRadioMessage", PrintCarRadioMessage)

local function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local fontName = "DynamicStopButtonFont"

    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    })

    surface.SetFont(fontName)
    local textWidth, _ = surface.GetTextSize(text)

    while textWidth > buttonWidth * 0.9 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        })
        surface.SetFont(fontName)
        textWidth, _ = surface.GetTextSize(text)
    end

    return fontName
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
        net.Start("ToggleFavoriteCountry")
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
    local lang = GetConVar("radio_language"):GetString() or "en"

    if selectedCountry == nil then
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

            -- Add the star icon
            local starIcon = createStarIcon(countryButton, country.original, stationListPanel, backButton, searchBox)

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        -- List favorite stations first
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

        for _, stationData in ipairs(stations) do
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
                local currentTime = CurTime()

                -- Check if the cooldown has passed
                if currentTime - lastStationSelectTime < 1 then
                    return  -- Exit the function if the cooldown hasn't passed
                end

                surface.PlaySound("buttons/button17.wav")
                local entity = LocalPlayer().currentRadioEntity

                if not IsValid(entity) then
                    return
                end

                if currentlyPlayingStations[entity] then
                    net.Start("StopCarRadioStation")
                    net.WriteEntity(entity)
                    net.SendToServer()
                end

                local volume = entityVolumes[entity] or getEntityConfig(entity).Volume
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(station.name)
                net.WriteString(station.url)
                net.WriteFloat(volume)
                net.SendToServer()

                currentlyPlayingStations[entity] = station
                lastStationSelectTime = currentTime  -- Update the last station select time
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    end
end

local function openRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

    -- Main Radio Menu Frame
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function()
        radioMenuOpen = false
        if customUrlFrame and IsValid(customUrlFrame) then
            customUrlFrame:Close()  -- Close the custom URL panel when the main panel is closed
        end
    end

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

    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(200))

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
            net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
            net.SendToServer()
            currentlyPlayingStation = nil
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end 

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
    volumeIcon:SetImage("hud/volume")

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(volumeIcon:GetWide() - Scale(200), Scale(5))
    volumeSlider:SetSize(volumePanel:GetWide() - volumeIcon:GetWide() + Scale(180), volumePanel:GetTall() - Scale(20))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)
    
    local entity = LocalPlayer().currentRadioEntity
    
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
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
    end    
    
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

    local sbar = stationListPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    populateList(stationListPanel, backButton, searchBox, true)

    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end

    -- Custom URL Panel Frame
    local customUrlFrame = vgui.Create("DFrame")
    customUrlFrame:SetTitle("Custom URL")
    customUrlFrame:SetSize(Scale(Config.UI.FrameSize.width * 0.8), Scale(Config.UI.FrameSize.height * 0.6))

    -- Positioning the custom URL frame to the right of the main frame
    local x, y = frame:GetPos()
    customUrlFrame:SetPos(x + frame:GetWide() + Scale(10), y)  -- Position it to the right of the main frame
    customUrlFrame:SetDraggable(true)
    customUrlFrame:ShowCloseButton(false)
    customUrlFrame:SetParent(frame)  -- Ensure it closes with the main panel
    customUrlFrame:MakePopup()

    customUrlFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
    end

    -- Custom URL Text Entry
    local urlEntry = vgui.Create("DTextEntry", customUrlFrame)
    urlEntry:SetSize(customUrlFrame:GetWide() - Scale(20), Scale(30))
    urlEntry:SetPos(Scale(10), Scale(40))
    urlEntry:SetFont("Roboto18")
    urlEntry:SetPlaceholderText("Enter custom stream URL")
    urlEntry:SetTextColor(Config.UI.TextColor)
    urlEntry:SetDrawBackground(true)
    urlEntry.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
        self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)
    end

    -- Play Custom URL Button
    local playUrlButton = vgui.Create("DButton", customUrlFrame)
    playUrlButton:SetSize(customUrlFrame:GetWide() - Scale(20), Scale(30))
    playUrlButton:SetPos(Scale(10), Scale(80))
    playUrlButton:SetText("Play URL")
    playUrlButton:SetFont("Roboto18")
    playUrlButton:SetTextColor(Config.UI.TextColor)
    playUrlButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
        end
    end

    playUrlButton.DoClick = function()
        local entity = LocalPlayer().currentRadioEntity
        local url = urlEntry:GetText()

        if url == "" then return end

        if IsValid(entity) then
            if currentlyPlayingStation then
                net.Start("StopCarRadioStation")
                net.WriteEntity(entity)
                net.SendToServer()
            end

            local volume = entityVolumes[entity] or getEntityConfig(entity).Volume
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString("Custom URL")
            net.WriteString(url)
            net.WriteFloat(volume)
            net.SendToServer()

            currentlyPlayingStation = { name = "Custom URL", url = url }
        end
    end
end

-- Hook to open the radio menu
hook.Add("Think", "OpenCarRadioMenu", function()
    local openKey = GetConVar("car_radio_open_key"):GetInt()
    if input.IsKeyDown(openKey) and not radioMenuOpen and IsValid(LocalPlayer():GetVehicle()) then
        LocalPlayer().currentRadioEntity = LocalPlayer():GetVehicle()
        openRadioMenu()
    end
end)

net.Receive("PlayCarRadioStation", function()
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    local entityRetryAttempts = 5
    local entityRetryDelay = 0.5  -- Delay in seconds between entity retries

    local function attemptPlayStation(attempt)
        if not IsValid(entity) then
            if attempt < entityRetryAttempts then
                timer.Simple(entityRetryDelay, function()
                    attemptPlayStation(attempt + 1)
                end)
            end
            return
        end

        local entityConfig = getEntityConfig(entity)

        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:Stop()
        end

        local function tryPlayStation(playAttempt)
            sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
                if IsValid(station) then
                    station:SetPos(entity:GetPos())
                    station:SetVolume(volume)
                    station:Play()
                    currentRadioSources[entity] = station

                    -- Set 3D fade distance according to the entity's configuration
                    station:Set3DFadeDistance(entityConfig.MinVolumeDistance, entityConfig.MaxHearingDistance)

                    -- Update the station's position relative to the entity's movement
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

                    -- Stop the station if the entity is removed
                    hook.Add("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex(), function(ent)
                        if ent == entity then
                            if IsValid(currentRadioSources[entity]) then
                                currentRadioSources[entity]:Stop()
                            end
                            currentRadioSources[entity] = nil
                            hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entity:EntIndex())
                            hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
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

net.Receive("StopCarRadioStation", function()
    local entity = net.ReadEntity()

    if IsValid(entity) and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
        local entIndex = entity:EntIndex()
        hook.Remove("EntityRemoved", "StopRadioOnEntityRemove_" .. entIndex)
        hook.Remove("Think", "UpdateRadioPosition_" .. entIndex)
    end
end)

net.Receive("OpenRadioMenu", function()
    local entity = net.ReadEntity()
    LocalPlayer().currentRadioEntity = entity
    if not radioMenuOpen then
        openRadioMenu()
    end
end)

hook.Add("PlayerInitialSpawn", "ApplySavedThemeAndLanguage", function(ply)
    loadSavedSettings()  -- Load and apply the saved theme and language
end)

loadFavorites()  -- Load the favorite stations and countries when the script initializes

hook.Add("InitPostEntity", "InitializeFavorites", function()
    populateList(stationListPanel, backButton, searchBox, true)  -- Ensure UI is updated with the loaded favorites after entities have loaded
end)
