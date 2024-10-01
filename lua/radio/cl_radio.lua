-- Include necessary files and modules
include("radio/key_names.lua")
include("radio/config.lua")
include("radio/utils.lua")
local countryTranslations = include("country_translations.lua")
local languageManager = include("language_manager.lua")

-- Declare local variables and functions
local favoriteCountries = {}
local favoriteStations = {}
local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil
local currentRadioSources = {}
local entityVolumes = {}
local lastMessageTime = -math.huge
local lastStationSelectTime = 0
local dataDir = "rradio"
local favoriteCountriesFile = dataDir .. "/favorite_countries.txt"
local favoriteStationsFile = dataDir .. "/favorite_stations.txt"

-- Function declarations for forward referencing
local loadFavorites
local saveFavorites
local createFonts
local Scale
local calculateFontSizeForStopButton
local updateRadioVolume
local printCarRadioMessage
local createStarIcon
local createStationStarIcon
local populateList
local openRadioMenu

-- Ensure the data directory exists
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

--[[
    Load favorites from file.
    This function loads the user's favorite countries and stations from saved files.
]]
function loadFavorites()
    if file.Exists(favoriteCountriesFile, "DATA") then
        favoriteCountries = util.JSONToTable(file.Read(favoriteCountriesFile, "DATA")) or {}
    end

    if file.Exists(favoriteStationsFile, "DATA") then
        favoriteStations = util.JSONToTable(file.Read(favoriteStationsFile, "DATA")) or {}
    end
end

--[[
    Save favorites to file.
    This function saves the user's favorite countries and stations to files for persistence.
]]
function saveFavorites()
    file.Write(favoriteCountriesFile, util.TableToJSON(favoriteCountries))
    file.Write(favoriteStationsFile, util.TableToJSON(favoriteStations))
end

--[[
    Create custom fonts used in the UI.
]]
function createFonts()
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

--[[
    Scale UI elements proportionally to the screen width.
    @param value (number): The original size value.
    @return (number): The scaled size value.
]]
function Scale(value)
    return value * (ScrW() / 2560)
end

--[[
    Calculate the appropriate font size for the stop button text.
    @param text (string): The text to display.
    @param buttonWidth (number): The width of the button.
    @param buttonHeight (number): The height of the button.
    @return (string): The name of the dynamically created font.
]]
function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local fontName = "DynamicStopButtonFont"

    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    })

    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)

    while textWidth > buttonWidth * 0.9 do
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
    Update the radio volume based on distance and context.
    @param station (IGModAudioChannel): The audio channel of the radio station.
    @param distance (number): The distance between the player and the entity.
    @param isPlayerInCar (boolean): Whether the player is in the car.
    @param entity (Entity): The entity associated with the radio.
]]
function updateRadioVolume(station, distance, isPlayerInCar, entity)
    local entityConfig = utils.getEntityConfig(entity)
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

--[[
    Display a chat message prompting the player to open the radio menu.
]]
function printCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local vehicle = LocalPlayer():GetVehicle()
    if not IsValid(vehicle) or utils.isSitAnywhereSeat(vehicle) then
        return
    end

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
net.Receive("CarRadioMessage", printCarRadioMessage)

--[[
    Create a star icon for favorite countries.
    @param parent (Panel): The parent panel.
    @param country (string): The country code.
    @param stationListPanel (Panel): The station list panel.
    @param backButton (Button): The back button.
    @param searchBox (DTextEntry): The search box.
    @return (DImageButton): The created star icon button.
]]
function createStarIcon(parent, country, stationListPanel, backButton, searchBox)
    local starIcon = vgui.Create("DImageButton", parent)
    local iconSize = Scale(24)
    starIcon:SetSize(iconSize, iconSize)
    starIcon:SetPos(Scale(8), (Scale(40) - iconSize) / 2)
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

--[[
    Create a star icon for favorite stations.
    @param parent (Panel): The parent panel.
    @param country (string): The country code.
    @param station (table): The station data.
    @param stationListPanel (Panel): The station list panel.
    @param backButton (Button): The back button.
    @param searchBox (DTextEntry): The search box.
    @return (DImageButton): The created star icon button.
]]
function createStationStarIcon(parent, country, station, stationListPanel, backButton, searchBox)
    local starIcon = vgui.Create("DImageButton", parent)
    local iconSize = Scale(24)
    starIcon:SetSize(iconSize, iconSize)
    starIcon:SetPos(Scale(8), (Scale(40) - iconSize) / 2)
    local isFavorite = favoriteStations[country] and table.HasValue(favoriteStations[country], station.name)
    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")

    starIcon.DoClick = function()
        favoriteStations[country] = favoriteStations[country] or {}

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

--[[
    Populate the station list panel with countries or stations.
    @param stationListPanel (Panel): The station list panel.
    @param backButton (Button): The back button.
    @param searchBox (DTextEntry): The search box.
    @param resetSearch (boolean): Whether to reset the search box text.
]]
function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then return end

    if backButton and not selectedCountry then
        backButton:SetVisible(false)
    end

    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText()
    local lang = GetConVar("radio_language"):GetString() or "en"

    if not selectedCountry then
        -- Populate with countries
        local countries = {}
        for country, _ in pairs(Config.RadioStations) do
            local translatedCountry = utils.formatCountryName(country)
            translatedCountry = countryTranslations:GetCountryName(lang, translatedCountry)
            if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        -- Sort countries with favorites on top
        table.sort(countries, function(a, b)
            local aFavorite = table.HasValue(favoriteCountries, a.original)
            local bFavorite = table.HasValue(favoriteCountries, b.original)

            if aFavorite ~= bFavorite then
                return aFavorite
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
                local buttonColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor
                draw.RoundedBox(8, 0, 0, w, h, buttonColor)
            end

            -- Add the star icon
            createStarIcon(countryButton, country.original, stationListPanel, backButton, searchBox)

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        -- Populate with stations
        local stations = {}
        for _, station in ipairs(Config.RadioStations[selectedCountry]) do
            if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
                local isFavorite = favoriteStations[selectedCountry] and table.HasValue(favoriteStations[selectedCountry], station.name)
                table.insert(stations, { station = station, favorite = isFavorite })
            end
        end

        -- Sort stations with favorites on top
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
            stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            stationButton:SetTall(Scale(40))
            stationButton:SetText(station.name)
            stationButton:SetFont("Roboto18")
            stationButton:SetTextColor(Config.UI.TextColor)

            stationButton.Paint = function(self, w, h)
                local isPlaying = station == currentlyPlayingStation
                local buttonColor = isPlaying and Config.UI.PlayingButtonColor or (self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor)
                draw.RoundedBox(8, 0, 0, w, h, buttonColor)
            end

            -- Add the star icon
            createStationStarIcon(stationButton, selectedCountry, station, stationListPanel, backButton, searchBox)

            stationButton.DoClick = function()
                local currentTime = CurTime()

                -- Check for cooldown
                if currentTime - lastStationSelectTime < 2 then
                    return
                end

                surface.PlaySound("buttons/button17.wav")
                local entity = LocalPlayer().currentRadioEntity

                if not IsValid(entity) then
                    return
                end

                if currentlyPlayingStation then
                    net.Start("StopCarRadioStation")
                    net.WriteEntity(entity)
                    net.SendToServer()
                end

                local volume = entityVolumes[entity] or utils.getEntityConfig(entity).Volume
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(station.name)
                net.WriteString(station.url)
                net.WriteFloat(volume)
                net.SendToServer()

                currentlyPlayingStation = station
                lastStationSelectTime = currentTime
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    end
end

--[[
    Open the radio menu UI.
]]
function openRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

    local frameWidth = Scale(Config.UI.FrameSize.width)
    local frameHeight = Scale(Config.UI.FrameSize.height)

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(frameWidth, frameHeight)
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

        draw.SimpleText(selectedCountry and countryTranslations:GetCountryName(GetConVar("radio_language"):GetString() or "en", utils.formatCountryName(selectedCountry)) or countryText, "HeaderFont", iconOffsetX + iconSize + Scale(5), iconOffsetY, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(frameWidth - Scale(20), Scale(30))
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
    stationListPanel:SetSize(frameWidth - Scale(10), frameHeight - Scale(200))

    local stopButtonWidth = frameWidth / 4
    local stopButtonHeight = frameWidth / 8
    local stopButtonText = Config.Lang["StopRadio"] or "STOP"
    local stopButtonFont = calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), frameHeight - Scale(90))
    stopButton:SetSize(stopButtonWidth, stopButtonHeight)
    stopButton:SetText(stopButtonText)
    stopButton:SetFont(stopButtonFont)
    stopButton:SetTextColor(Config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        local buttonColor = self:IsHovered() and Config.UI.CloseButtonHoverColor or Config.UI.CloseButtonColor
        draw.RoundedBox(8, 0, 0, w, h, buttonColor)
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
    volumePanel:SetPos(Scale(20) + stopButtonWidth, frameHeight - Scale(90))
    volumePanel:SetSize(frameWidth - Scale(30) - stopButtonWidth, stopButtonHeight)
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

    local currentVolume = entityVolumes[entity] or utils.getEntityConfig(entity).Volume
    volumeSlider:SetValue(currentVolume)

    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, h / 2 - 4, w, 16, Config.UI.TextColor)
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
        local buttonColor = self:IsHovered() and Config.UI.CloseButtonHoverColor or Config.UI.CloseButtonColor
        draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, buttonColor, false, true, false, false)
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
end

-- Hook to open the radio menu
hook.Add("Think", "OpenCarRadioMenu", function()
    local openKey = GetConVar("car_radio_open_key"):GetInt()
    local vehicle = LocalPlayer():GetVehicle()

    if input.IsKeyDown(openKey) and not radioMenuOpen and IsValid(vehicle) and not utils.isSitAnywhereSeat(vehicle) then
        LocalPlayer().currentRadioEntity = vehicle
        openRadioMenu()
    end
end)

-- Network message handlers for playing and stopping stations
net.Receive("PlayCarRadioStation", function()
    local entity = net.ReadEntity()
    local url = net.ReadString()
    local volume = net.ReadFloat()

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

        local entityConfig = utils.getEntityConfig(entity)

        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:Stop()
        end

        local function tryPlayStation(playAttempt)
            sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
                if IsValid(station) and IsValid(entity) then
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

-- Load favorites on initialization
loadFavorites()