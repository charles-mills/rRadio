include("radio/key_names.lua")
include("radio/config.lua")
local countryTranslations = include("country_translations.lua")
local LanguageManager = include("language_manager.lua")

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

local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil

local currentRadioSources = {}
local entityVolumes = {}

local lastMessageTime = -math.huge

local function getEntityConfig(entity)
    if entity:GetClass() == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entity:GetClass() == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    else
        return nil
    end
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

    local prefixColor = Color(0, 255, 128)
    local keyColor = Color(255, 165, 0)
    local messageColor = Color(255, 255, 255)
    local keyName = GetKeyName(Config.OpenKey)

    local message = Config.Lang["PressKeyToOpen"]:gsub("{key}", keyName)

    chat.AddText(
        prefixColor, "[CAR RADIO] ",
        messageColor, message
    )
end

net.Receive("CarRadioMessage", function()
    PrintCarRadioMessage()
end)

local function Scale(value)
    return value * (ScrW() / 2560)
end

local function formatCountryName(name)
    -- Reformat and then translate the country name
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    local translation = countryTranslations:GetCountryName(lang, formattedName)
    
    return translation
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
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
            local translatedCountry = formatCountryName(country)  -- Reformat and translate the country name
            if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        if Config.UKAndUSPrioritised then
            table.sort(countries, function(a, b)
                local UK_OPTIONS = {"United Kingdom", "The United Kingdom", "The_united_kingdom"}
                local US_OPTIONS = {"United States", "The United States Of America", "The_united_states_of_america"}

                if table.HasValue(UK_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(UK_OPTIONS, b.original) then
                    return false
                elseif table.HasValue(US_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(US_OPTIONS, b.original) then
                    return false 
                else
                    return a.translated < b.translated
                end
            end)
        else
            table.sort(countries, function(a, b) return a.translated < b.translated end)
        end

        for _, country in ipairs(countries) do
            local countryButton = vgui.Create("DButton", stationListPanel)
            countryButton:Dock(TOP)
            countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            countryButton:SetTall(Scale(40))
            countryButton:SetText(country.translated)  -- Use the translated country name
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end

            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then backButton:SetVisible(true) end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        for _, station in ipairs(Config.RadioStations[selectedCountry]) do
            if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
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

                stationButton.DoClick = function()
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
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            end
        end
    end
end

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

local function openRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

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
        if not Config.Lang then
            print("[DEBUG] Language not found")
        end
    end
    
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(Config.Lang and Config.Lang["SearchPlaceholder"] or "Search")
    if not Config.Lang then
        print("[DEBUG] Language not found")
    end
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
end

hook.Add("Think", "OpenCarRadioMenu", function()
    if input.IsKeyDown(Config.OpenKey) and not radioMenuOpen and IsValid(LocalPlayer():GetVehicle()) then
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
