include("radio/key_names.lua")
include("radio/config.lua")

surface.CreateFont("Roboto18", {
    font = "Roboto",
    size = ScreenScale(5),
    weight = 500,
})

local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil

local currentRadioSources = {}
local entityVolumes = {}  -- This will store volume settings for each entity

local lastMessageTime = -math.huge

local function updateRadioVolume(station, distance, isPlayerInCar, entity)
    local volume = entityVolumes[entity] or Config.Volume

    if volume <= 0.02 then
        station:SetVolume(0)
        return
    end

    local maxVolume = GetConVar("radio_max_volume"):GetFloat()
    local effectiveVolume = math.min(volume, maxVolume)

    if isPlayerInCar then
        station:SetVolume(effectiveVolume)
    else
        if distance <= Config.MinVolumeDistance then
            station:SetVolume(effectiveVolume)
        elseif distance <= Config.MaxHearingDistance then
            local adjustedVolume = effectiveVolume * (1 - (distance - Config.MinVolumeDistance) / (Config.MaxHearingDistance - Config.MinVolumeDistance))
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

local CountryTranslations = {
    en = {
        ["the_united_kingdom"] = "United Kingdom",
        ["the_united_states_of_america"] = "United States of America",
    },
    es = {
        ["the_united_kingdom"] = "Reino Unido",
        ["the_united_states_of_america"] = "Estados Unidos de América",
    },
}

local function formatCountryName(name)
    local lang = GetConVar("radio_language"):GetString() or "en"
    local translation = CountryTranslations[lang] and CountryTranslations[lang][name] or name
    return translation:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")
    end

    local filterText = searchBox:GetText()

    if selectedCountry == nil then
        backButton:SetVisible(false)

        local countries = {}
        for country, _ in pairs(Config.RadioStations) do
            local translatedCountry = formatCountryName(country)
            if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        if Config.UKAndUSPrioritised then
            table.sort(countries, function(a, b)
                local UK_OPTIONS = {"United Kingdom", "The United Kingdom", "the_united_kingdom"}
                local US_OPTIONS = {"United States", "The United States Of America", "the_united_states_of_america"}

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
            countryButton:SetText(country.translated)
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end

            countryButton.DoClick = function()
                selectedCountry = country.original
                backButton:SetVisible(true)
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

                stationButton.Paint = function(self, w, h)
                    if station == currentlyPlayingStation then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                    else
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                        if self:IsHovered() then
                            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                        end
                    end
                end

                stationButton.DoClick = function()
                    local entity = LocalPlayer().currentRadioEntity

                    if not IsValid(entity) then
                        print("No valid entity for PlayCarRadioStation")
                        return
                    end

                    if currentlyPlayingStation then
                        net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                        net.SendToServer()
                    end

                    net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(station.url)
                    net.WriteFloat(entityVolumes[entity] or Config.Volume)
                    net.SendToServer()

                    currentlyPlayingStation = station
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            end
        end
    end
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
        draw.RoundedBox(8, 0, 0, w, Scale(30), Config.UI.HeaderColor)
        draw.SimpleText(selectedCountry and formatCountryName(selectedCountry) or Config.Lang["SelectCountry"], "Roboto18", Scale(10), Scale(5), Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(40))
    searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(Config.Lang["SearchPlaceholder"])
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
    stationListPanel:SetPos(Scale(10), Scale(80))
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(190))

    local volumeSlider = vgui.Create("DNumSlider", frame)
    volumeSlider:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(100))
    volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(40))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)

    local entity = LocalPlayer().currentRadioEntity
    volumeSlider:SetValue(entityVolumes[entity] or Config.Volume)

    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, h/2 - 2, w, 4, Config.UI.HeaderColor)
    end

    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
    end

    volumeSlider.TextArea:SetTextColor(Config.UI.TextColor)
    volumeSlider.TextArea:SetFont("Roboto18")
    volumeSlider.Label:SetVisible(false)

    volumeSlider.OnValueChanged = function(_, value)
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
    end

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(50))
    stopButton:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(40))
    stopButton:SetText(Config.Lang["StopRadio"])
    stopButton:SetFont("Roboto18")
    stopButton:SetTextColor(Config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonHoverColor)
        end
    end

    stopButton.DoClick = function()
        if IsValid(entity) then
            net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
            net.SendToServer()
            currentlyPlayingStation = nil
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end
    
    local backButton = vgui.Create("DButton", frame)
    backButton:SetSize(Scale(30), Scale(30))
    backButton:SetPos(frame:GetWide() - Scale(79), 0)
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
        selectedCountry = nil
        backButton:SetVisible(false)
        populateList(stationListPanel, backButton, searchBox, true)
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetFont("Roboto18")
    closeButton:SetTextColor(Config.UI.TextColor)
    closeButton:SetSize(Scale(40), Scale(30))
    closeButton:SetPos(frame:GetWide() - Scale(39), 0)
    closeButton.Paint = function(self, w, h)
        local cornerRadius = 8
        draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonColor, false, true, false, false)
        if self:IsHovered() then
            draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonHoverColor, false, true, false, false)
        end
    end
    closeButton.DoClick = function()
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

    if not IsValid(entity) then
        print("Invalid entity received for PlayCarRadioStation.")
        return
    end

    if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
        currentRadioSources[entity]:Stop()
    end

    local function tryPlayStation(attempt)
        sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
            if IsValid(station) then
                station:SetPos(entity:GetPos())
                station:SetVolume(volume)
                station:Play()
                currentRadioSources[entity] = station

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
                if attempt < Config.RetryAttempts then
                    timer.Simple(Config.RetryDelay, function()
                        tryPlayStation(attempt + 1)
                    end)
                end
            end
        end)
    end

    tryPlayStation(1)
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
