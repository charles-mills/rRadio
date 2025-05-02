-- rRadio Menu System
-- Enhanced with blur effects, modern UI, optimized logic, and fixed network error

-- Initialize global tables
BoomboxStatuses = BoomboxStatuses or {}
currentRadioSources = currentRadioSources or {}
local entityVolumes = entityVolumes or {}

-- Constants
local VOLUME_ICONS = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}
local PERMISSION_MESSAGE_COOLDOWN = 3
local MAX_CLIENT_STATIONS = 10
local KEY_PRESS_DELAY = 0.2

-- State variables
local currentFrame = nil
local settingsMenuOpen = false
local radioMenuOpen = false
local selectedCountry = nil
local favoritesMenuOpen = false
local stationDataLoaded = false
local lastStationSelectTime = 0
local lastPermissionMessage = 0
local currentlyPlayingStations = {}
local StationData = {}

-- Utility functions
local function Scale(value)
    return value * (ScrW() / 2560)
end

local blur = Material("pp/blurscreen")
local function drawBlur(panel)
    local d = 5
    local x, y = panel:LocalToScreen(0, 0)
    local scrw, scrh = ScrW(), ScrH()
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blur)
    for i = 1, d do
        blur:SetFloat("$blur", (i / 3) * 5)
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, scrw, scrh)
    end
end

local function createFonts()
    surface.CreateFont("RadioFont", {
        font = "Roboto",
        size = ScreenScale(6),
        weight = 500
    })
    surface.CreateFont("RadioHeader", {
        font = "Roboto",
        size = ScreenScale(9),
        weight = 700
    })
end
createFonts()

local function LoadStationData()
    if stationDataLoaded then return end
    StationData = {}
    local files = file.Find("radio/client/stations/*.lua", "LUA")
    for _, f in ipairs(files) do
        local data = include("radio/client/stations/" .. f)
        if data then
            for country, stations in pairs(data) do
                local baseCountry = country:gsub("_(%d+)$", "")
                StationData[baseCountry] = StationData[baseCountry] or {}
                for _, station in ipairs(stations) do
                    table.insert(StationData[baseCountry], {name = station.n, url = station.u})
                end
            end
        else
            ErrorNoHalt("[rRadio] Failed to load station file: " .. f .. "\n")
        end
    end
    stationDataLoaded = true
end
LoadStationData()

local function IsUrlAllowed(url)
    if not rRadio.config.SecureStationLoad then return true end
    for country, stations in pairs(StationData) do
        for _, station in ipairs(stations) do
            if station.url == url then return true end
        end
    end
    local favorites = rRadio.interface.favoriteStations or {}
    for country, favData in pairs(favorites) do
        for stationName, _ in pairs(favData) do
            for _, station in ipairs(StationData[country] or {}) do
                if station.name == stationName and station.url == url then return true end
            end
        end
    end
    return false
end

local function toggleFavorite(list, key, subkey)
    list[key] = list[key] or {}
    if subkey then
        list[key][subkey] = not list[key][subkey] or nil
        if not next(list[key]) then list[key] = nil end
    else
        list[key] = not list[key] or nil
    end
    rRadio.interface.saveFavorites()
end

local function createStarIcon(parent, country, station, updateList)
    local star = vgui.Create("DImageButton", parent)
    star:SetSize(Scale(24), Scale(24))
    star:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    local isFavorite = station and rRadio.interface.favoriteStations[country] and rRadio.interface.favoriteStations[country][station.name] or
                       rRadio.interface.favoriteCountries[country]
    star:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
    star.DoClick = function()
        toggleFavorite(station and rRadio.interface.favoriteStations or rRadio.interface.favoriteCountries, country, station and station.name)
        isFavorite = not isFavorite
        star:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
        if updateList then updateList() end
        surface.PlaySound("UI/buttonclick.wav")
    end
    return star
end

local function createButton(parent, x, y, w, h, text, font, clickFunc)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(text)
    button:SetFont(font)
    button:SetTextColor(rRadio.config.UI.TextColor)
    button.lerp = 0
    button.Paint = function(self, w, h)
        local color = rRadio.interface.LerpColor(self.lerp, rRadio.config.UI.ButtonColor, rRadio.config.UI.ButtonHoverColor)
        draw.RoundedBox(8, 0, 0, w, h, color)
        draw.SimpleText(text, font, w / 2, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    button.Think = function(self)
        self.lerp = math.Approach(self.lerp, self:IsHovered() and 1 or 0, FrameTime() * 8)
    end
    button.DoClick = function()
        surface.PlaySound("buttons/button3.wav")
        clickFunc()
        local anim = button:NewAnimation(0.1, 0, -1)
        anim.Size = button:GetSize()
        anim.Think = function(_, _, frac)
            local scale = 1 + math.sin(frac * math.pi) * 0.1
            button:SetSize(anim.Size[1] * scale, anim.Size[2] * scale)
            button:CenterHorizontal()
        end
    end
    return button
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not IsValid(stationListPanel) then return end
    stationListPanel:Clear()
    if resetSearch then searchBox:SetText("") end
    local filterText = searchBox:GetText():lower()

    local function updateList()
        populateList(stationListPanel, backButton, searchBox, false)
    end

    if not selectedCountry then
        local hasFavorites = next(rRadio.interface.favoriteStations or {}) ~= nil
        if hasFavorites then
            local separator = vgui.Create("DPanel", stationListPanel)
            separator:Dock(TOP)
            separator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            separator:SetTall(Scale(2))
            separator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, rRadio.config.UI.ButtonColor)
            end

            local favoritesButton = createButton(
                stationListPanel,
                0, 0, stationListPanel:GetWide(), Scale(40),
                rRadio.config.Lang["FavoriteStations"] or "Favorite Stations",
                "RadioFont",
                function()
                    selectedCountry = "favorites"
                    favoritesMenuOpen = true
                    if backButton then
                        backButton:SetVisible(true)
                        backButton:SetEnabled(true)
                    end
                    populateList(stationListPanel, backButton, searchBox, true)
                end
            )
            favoritesButton:Dock(TOP)
            favoritesButton:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        end

        local countries = {}
        for country, _ in pairs(StationData) do
            local formatted = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
            local translated = rRadio.LanguageManager:GetCountryTranslation(formatted) or formatted
            if filterText == "" or translated:lower():find(filterText, 1, true) then
                table.insert(countries, {
                    original = country,
                    translated = translated,
                    isPrioritized = rRadio.interface.favoriteCountries[country]
                })
            end
        end
        table.sort(countries, function(a, b)
            if a.isPrioritized ~= b.isPrioritized then return a.isPrioritized end
            return a.translated < b.translated
        end)

        for _, country in ipairs(countries) do
            local button = createButton(
                stationListPanel,
                0, 0, stationListPanel:GetWide(), Scale(40),
                country.translated,
                "RadioFont",
                function()
                    selectedCountry = country.original
                    if backButton then backButton:SetVisible(true) end
                    populateList(stationListPanel, backButton, searchBox, true)
                end
            )
            button:Dock(TOP)
            button:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            createStarIcon(button, country.original, nil, updateList)
        end
        if backButton then
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
        end
    elseif selectedCountry == "favorites" then
        local favoritesList = {}
        for country, stations in pairs(rRadio.interface.favoriteStations) do
            for _, station in ipairs(StationData[country] or {}) do
                if stations[station.name] and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                    table.insert(favoritesList, {
                        station = station,
                        country = country,
                        countryName = rRadio.utils.FormatAndTranslateCountry(country)
                    })
                end
            end
        end
        table.sort(favoritesList, function(a, b)
            if a.countryName == b.countryName then return a.station.name < b.station.name end
            return a.countryName < b.countryName
        end)

        for _, favorite in ipairs(favoritesList) do
            local button = createButton(
                stationListPanel,
                0, 0, stationListPanel:GetWide(), Scale(40),
                favorite.countryName .. " - " .. favorite.station.name,
                "RadioFont",
                function()
                    local currentTime = CurTime()
                    if currentTime - lastStationSelectTime < 2 then return end
                    local entity = LocalPlayer().currentRadioEntity
                    if not IsValid(entity) then return end
                    if currentlyPlayingStations[entity] then
                        net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                        net.SendToServer()
                    end
                    local volume = entityVolumes[entity] or rRadio.interface.getEntityConfig(entity).Volume() or 0.5
                    net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(favorite.station.name)
                    net.WriteString(favorite.station.url)
                    net.WriteFloat(volume)
                    net.SendToServer()
                    currentlyPlayingStations[entity] = favorite.station
                    lastStationSelectTime = currentTime
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            )
            button:Dock(TOP)
            button:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            button.Paint = function(self, w, h)
                local entity = LocalPlayer().currentRadioEntity
                local color = currentlyPlayingStations[entity] and currentlyPlayingStations[entity].name == favorite.station.name and
                             rRadio.config.UI.PlayingButtonColor or
                             rRadio.interface.LerpColor(self.lerp, rRadio.config.UI.ButtonColor, rRadio.config.UI.ButtonHoverColor)
                draw.RoundedBox(8, 0, 0, w, h, color)
                draw.SimpleText(self:GetText(), "RadioFont", w / 2, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            createStarIcon(button, favorite.country, favorite.station, updateList)
        end
    else
        local stations = StationData[selectedCountry] or {}
        local favoriteStationsList = {}
        for _, station in ipairs(stations) do
            if station and station.name and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                table.insert(favoriteStationsList, {
                    station = station,
                    favorite = rRadio.interface.favoriteStations[selectedCountry] and rRadio.interface.favoriteStations[selectedCountry][station.name]
                })
            end
        end
        table.sort(favoriteStationsList, function(a, b)
            if a.favorite ~= b.favorite then return a.favorite end
            return a.station.name < b.station.name
        end)

        for _, data in ipairs(favoriteStationsList) do
            local station = data.station
            local button = createButton(
                stationListPanel,
                0, 0, stationListPanel:GetWide(), Scale(40),
                station.name,
                "RadioFont",
                function()
                    local currentTime = CurTime()
                    if currentTime - lastStationSelectTime < 2 then return end
                    local entity = LocalPlayer().currentRadioEntity
                    if not IsValid(entity) then return end
                    if currentlyPlayingStations[entity] then
                        net.Start("StopCarRadioStation")
                        net.WriteEntity(entity)
                        net.SendToServer()
                    end
                    local volume = entityVolumes[entity] or rRadio.interface.getEntityConfig(entity).Volume() or 0.5
                    net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(station.name)
                    net.WriteString(station.url)
                    net.WriteFloat(volume)
                    net.SendToServer()
                    currentlyPlayingStations[entity] = station
                    lastStationSelectTime = currentTime
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            )
            button:Dock(TOP)
            button:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            button.Paint = function(self, w, h)
                local entity = LocalPlayer().currentRadioEntity
                local color = currentlyPlayingStations[entity] == station and rRadio.config.UI.PlayingButtonColor or
                             rRadio.interface.LerpColor(self.lerp, rRadio.config.UI.ButtonColor, rRadio.config.UI.ButtonHoverColor)
                draw.RoundedBox(8, 0, 0, w, h, color)
                draw.SimpleText(self:GetText(), "RadioFont", w / 2, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            createStarIcon(button, selectedCountry, station, updateList)
        end
        if backButton then
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
        end
    end
end

local function openSettingsMenu(parentFrame, backButton)
    local settingsFrame = vgui.Create("DPanel", parentFrame)
    settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50))
    settingsFrame:SetPos(Scale(10), Scale(50))
    settingsFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.BackgroundColor)
    end

    local scrollPanel = vgui.Create("DScrollPanel", settingsFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
    local sbar = scrollPanel:GetVBar()
    sbar:SetWide(Scale(8))
    sbar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, rRadio.config.UI.ScrollbarColor) end
    sbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, rRadio.config.UI.ScrollbarGripColor) end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end

    local function addHeader(text, isFirst)
        local header = vgui.Create("DLabel", scrollPanel)
        header:SetText(text)
        header:SetFont("RadioHeader")
        header:SetTextColor(rRadio.config.UI.TextColor)
        header:Dock(TOP)
        header:DockMargin(0, isFirst and Scale(5) or Scale(10), 0, Scale(5))
        header:SizeToContents()
    end

    local function addDropdown(text, choices, currentValue, onSelect)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(50))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor) end

        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetFont("RadioFont")
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:Dock(LEFT)
        label:DockMargin(Scale(10), 0, 0, 0)
        label:SizeToContents()

        local dropdown = vgui.Create("DComboBox", container)
        dropdown:Dock(RIGHT)
        dropdown:SetWide(Scale(150))
        dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        dropdown:SetValue(currentValue)
        dropdown:SetFont("RadioFont")
        dropdown:SetSortItems(false)
        dropdown.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            self:DrawTextEntryText(rRadio.config.UI.TextColor, rRadio.config.UI.ButtonHoverColor, rRadio.config.UI.TextColor)
        end
        for _, choice in ipairs(choices) do dropdown:AddChoice(choice.name, choice.data) end
        dropdown.OnSelect = onSelect
        return dropdown
    end

    local function addCheckbox(text, convar)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(40))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor) end

        local checkbox = vgui.Create("DCheckBox", container)
        checkbox:SetPos(Scale(10), (container:GetTall() - Scale(20)) / 2)
        checkbox:SetSize(Scale(20), Scale(20))
        checkbox:SetConVar(convar)
        checkbox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            if self:GetChecked() then
                surface.SetDrawColor(rRadio.config.UI.TextColor)
                surface.DrawRect(Scale(4), Scale(4), w - Scale(8), h - Scale(8))
            end
        end

        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetFont("RadioFont")
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:SizeToContents()
        label:SetPos(Scale(40), (container:GetTall() - label:GetTall()) / 2)
        return checkbox
    end

    addHeader(rRadio.config.Lang["ThemeSelection"] or "Theme Selection", true)
    local themeChoices = {}
    for themeName, _ in pairs(rRadio.themes or {}) do
        table.insert(themeChoices, {name = rRadio.config.Lang[themeName] or themeName:gsub("^%l", string.upper), data = themeName})
    end
    local currentTheme = GetConVar("rammel_rradio_menu_theme"):GetString()
    addDropdown(
        rRadio.config.Lang["SelectTheme"] or "Select Theme",
        themeChoices,
        rRadio.config.Lang[currentTheme] or currentTheme:gsub("^%l", string.upper),
        function(_, _, _, themeKey)
            RunConsoleCommand("rammel_rradio_menu_theme", themeKey:lower())
            rRadio.config.UI = rRadio.themes[themeKey:lower()]
            parentFrame:Close()
            timer.Simple(0.1, function() openRadioMenu(true) end)
        end
    )

    addHeader(rRadio.config.Lang["KeyBinds"] or "Key Binds")
    local keyChoices = {}
    for keyCode, keyName in pairs(rRadio.keyCodeMapping or {{name = "K", data = KEY_K}}) do
        table.insert(keyChoices, {name = keyName, data = keyCode})
    end
    table.sort(keyChoices, function(a, b) return a.name < b.name end)
    local currentKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    addDropdown(
        rRadio.config.Lang["SelectKey"] or "Select Key",
        keyChoices,
        rRadio.keyCodeMapping and rRadio.keyCodeMapping[currentKey] or "K",
        function(_, _, _, data) RunConsoleCommand("rammel_rradio_menu_key", data) end
    )

    addHeader(rRadio.config.Lang["GeneralOptions"] or "General Options")
    addCheckbox(rRadio.config.Lang["ShowCarMessages"] or "Show Car Radio Animation", "rammel_rradio_vehicle_animation")
    addCheckbox(rRadio.config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD", "rammel_rradio_boombox_hud")

    if LocalPlayer():IsSuperAdmin() then
        local entity = LocalPlayer().currentRadioEntity
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            addHeader(rRadio.config.Lang["SuperadminSettings"] or "Superadmin Settings")
            local permanentCheckbox = addCheckbox(rRadio.config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent", "")
            permanentCheckbox:SetChecked(entity:GetNWBool("IsPermanent", false))
            permanentCheckbox.OnChange = function(self, value)
                if not IsValid(entity) then
                    self:SetChecked(false)
                    return
                end
                net.Start(value and "MakeBoomboxPermanent" or "RemoveBoomboxPermanent")
                net.WriteEntity(entity)
                net.SendToServer()
            end
        end
    end
end

function openRadioMenu(openSettings)
    if not GetConVar("rammel_rradio_enabled"):GetBool() or radioMenuOpen or not rRadio.config then return end
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    if not IsValid(entity) or not rRadio.utils.canUseRadio(entity) then
        chat.AddText(Color(255, 0, 0), "[rRadio] Cannot use radio from this seat.")
        return
    end
    if hook.Run("rRadio.CanOpenMenu", ply, entity) == false then return end

    radioMenuOpen = true
    local frame = vgui.Create("DFrame")
    currentFrame = frame
    frame:SetSize(Scale(rRadio.config.UI.FrameSize.width), Scale(rRadio.config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function()
        radioMenuOpen = false
        settingsMenuOpen = false
        selectedCountry = nil
        favoritesMenuOpen = false
    end
    frame.Paint = function(self, w, h)
        drawBlur(self)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 180))
        surface.SetDrawColor(50, 50, 50, 120)
        surface.SetTexture(surface.GetTextureID("gui/gradient"))
        surface.DrawTexturedRect(0, 0, w, h)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(50), rRadio.config.UI.HeaderColor, true, true, false, false)
        draw.SimpleText(
            settingsMenuOpen and (rRadio.config.Lang["Settings"] or "Settings") or
            selectedCountry == "favorites" and (rRadio.config.Lang["FavoriteStations"] or "Favorite Stations") or
            selectedCountry and rRadio.utils.FormatAndTranslateCountry(selectedCountry) or
            rRadio.config.Lang["SelectCountry"] or "Select Country",
            "RadioHeader",
            Scale(10), Scale(25),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(60))
    searchBox:SetSize(frame:GetWide() - Scale(20), Scale(30))
    searchBox:SetFont("RadioFont")
    searchBox:SetPlaceholderText(rRadio.config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetTextColor(rRadio.config.UI.TextColor)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
        self:DrawTextEntryText(rRadio.config.UI.TextColor, rRadio.config.UI.ButtonHoverColor, rRadio.config.UI.TextColor)
    end
    searchBox.OnChange = function() populateList(stationListPanel, backButton, searchBox, false) end
    searchBox:SetVisible(not openSettings)

    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(10), Scale(100))
    stationListPanel:SetSize(frame:GetWide() - Scale(20), frame:GetTall() - Scale(200))
    stationListPanel:SetVisible(not openSettings)

    local stopButton = createButton(
        frame,
        Scale(10), frame:GetTall() - Scale(90),
        frame:GetWide() / 4, Scale(40),
        rRadio.config.Lang["StopRadio"] or "STOP",
        "RadioFont",
        function()
            local entity = LocalPlayer().currentRadioEntity
            if IsValid(entity) then
                net.Start("StopCarRadioStation")
                net.WriteEntity(entity)
                net.SendToServer()
                currentlyPlayingStations[entity] = nil
                populateList(stationListPanel, backButton, searchBox, false)
            end
        end
    )

    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButton:GetWide(), frame:GetTall() - Scale(90))
    volumePanel:SetSize(frame:GetWide() - Scale(30) - stopButton:GetWide(), Scale(40))
    volumePanel.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor) end

    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - Scale(30)) / 2)
    volumeIcon:SetSize(Scale(30), Scale(30))
    local function updateVolumeIcon(value)
        if not IsValid(volumeIcon) then return end
        volumeIcon:SetMaterial(value < 0.01 and VOLUME_ICONS.MUTE or value <= 0.65 and VOLUME_ICONS.LOW or VOLUME_ICONS.HIGH)
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = IsValid(entity) and (entityVolumes[entity] or rRadio.interface.getEntityConfig(entity).Volume() or 0.5) or 0.5
    updateVolumeIcon(currentVolume)

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(Scale(50), Scale(5))
    volumeSlider:SetSize(volumePanel:GetWide() - Scale(60), Scale(30))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(rRadio.config.MaxVolume())
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)
    volumeSlider.Slider.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, h / 2 - 2, w, 4, rRadio.config.UI.TextColor)
    end
    volumeSlider.Slider.Knob.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonHoverColor)
    end
    volumeSlider.TextArea:SetVisible(false)
    local lastServerUpdate = 0
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then return end
        value = math.min(value, rRadio.config.MaxVolume())
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
        updateVolumeIcon(value)
        local currentTime = CurTime()
        if currentTime - lastServerUpdate >= 0.5 then
            lastServerUpdate = currentTime
            net.Start("UpdateRadioVolume")
            net.WriteEntity(entity)
            net.WriteFloat(value)
            net.SendToServer()
        end
    end

    local closeButton = createButton(
        frame,
        frame:GetWide() - Scale(40), Scale(10),
        Scale(30), Scale(30),
        "X",
        "RadioFont",
        function() frame:Close() end
    )
    closeButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.interface.LerpColor(self.lerp, Color(255, 0, 0, 180), Color(200, 0, 0, 220)))
        draw.SimpleText("X", "RadioFont", w / 2, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local settingsButton = createButton(
        frame,
        closeButton:GetX() - Scale(40), Scale(10),
        Scale(30), Scale(30),
        "⚙",
        "RadioFont",
        function()
            settingsMenuOpen = true
            openSettingsMenu(frame, backButton)
            searchBox:SetVisible(false)
            stationListPanel:SetVisible(false)
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
        end
    )

    local backButton = createButton(
        frame,
        settingsButton:GetX() - Scale(40), Scale(10),
        Scale(30), Scale(30),
        "←",
        "RadioFont",
        function()
            if settingsMenuOpen then
                settingsMenuOpen = false
                searchBox:SetVisible(true)
                stationListPanel:SetVisible(true)
                stationDataLoaded = false
                LoadStationData()
                populateList(stationListPanel, backButton, searchBox, true)
            else
                selectedCountry = nil
                favoritesMenuOpen = false
            end
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
            populateList(stationListPanel, backButton, searchBox, true)
        end
    )
    backButton:SetVisible(openSettings or selectedCountry or favoritesMenuOpen)
    backButton:SetEnabled(openSettings or selectedCountry or favoritesMenuOpen)

    if openSettings then
        settingsMenuOpen = true
        openSettingsMenu(frame, backButton)
        searchBox:SetVisible(false)
        stationListPanel:SetVisible(false)
    else
        populateList(stationListPanel, backButton, searchBox, true)
    end
end

-- Hooks and network receivers
hook.Add("Think", "rRadio.OpenCarRadioMenu", function()
    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local ply = LocalPlayer()
    local currentTime = CurTime()
    if not input.IsKeyDown(openKey) or ply:IsTyping() or currentTime - lastPermissionMessage <= KEY_PRESS_DELAY then return end
    lastPermissionMessage = currentTime

    if radioMenuOpen then
        currentFrame:Close()
        return
    end

    local vehicle = ply:GetVehicle()
    if IsValid(vehicle) then
        local mainVehicle = rRadio.utils.GetVehicle(vehicle)
        if IsValid(mainVehicle) and (not rRadio.config.DriverPlayOnly or mainVehicle:GetDriver() == ply) and
           not rRadio.utils.isSitAnywhereSeat(mainVehicle) then
            ply.currentRadioEntity = mainVehicle
            openRadioMenu()
        end
    end
end)

-- Fixed to prevent bit underflow error by validating available bits
net.Receive("UpdateRadioStatus", function(len)
    -- Ensure enough bits for entity (16+), strings (8+ each), and bool (1)
    if len < 32 then
        ErrorNoHalt("[rRadio] UpdateRadioStatus message too short: " .. len .. " bits\n")
        return
    end

    local entity = net.ReadEntity()
    if not IsValid(entity) then
        ErrorNoHalt("[rRadio] UpdateRadioStatus received invalid entity\n")
        return
    end

    local stationName = ""
    if net.BitsLeft() >= 8 then
        stationName = net.ReadString()
    else
        ErrorNoHalt("[rRadio] UpdateRadioStatus missing stationName\n")
        return
    end

    local isPlaying = false
    if net.BitsLeft() >= 1 then
        isPlaying = net.ReadBool()
    else
        ErrorNoHalt("[rRadio] UpdateRadioStatus missing isPlaying\n")
        return
    end

    local status = ""
    if net.BitsLeft() >= 8 then
        status = net.ReadString()
    else
        ErrorNoHalt("[rRadio] UpdateRadioStatus missing status\n")
        return
    end

    BoomboxStatuses[entity:EntIndex()] = {
        stationStatus = status,
        stationName = stationName
    }
    entity:SetNWString("Status", status)
    entity:SetNWString("StationName", stationName)
    entity:SetNWBool("IsPlaying", isPlaying)
    currentlyPlayingStations[entity] = status == "playing" and {name = stationName} or nil
end)

net.Receive("PlayCarRadioStation", function()
    if not GetConVar("rammel_rradio_enabled"):GetBool() then return end
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end
    entity = rRadio.interface.GetVehicleEntity(entity)
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    if rRadio.config.SecureStationLoad and not IsUrlAllowed(url) then return end
    if rRadio.interface.updateStationCount() >= MAX_CLIENT_STATIONS then return end
    if currentRadioSources[entity] then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
    end
    sound.PlayURL(url, "3d mono", function(station, errID, errName)
        if not IsValid(station) or not IsValid(entity) then return end
        station:SetPos(entity:GetPos())
        station:SetVolume(volume)
        station:Play()
        currentRadioSources[entity] = station
        local cfg = rRadio.interface.getEntityConfig(entity)
        if cfg then station:Set3DFadeDistance(cfg.MinVolumeDistance(), cfg.MaxHearingDistance()) end
    end)
end)

net.Receive("StopCarRadioStation", function()
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end
    entity = rRadio.interface.GetVehicleEntity(entity)
    if currentRadioSources[entity] then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
    end
    if rRadio.utils.IsBoombox(entity) then rRadio.utils.clearRadioStatus(entity) end
end)

hook.Add("Think", "rRadio.UpdateAllStations", function()
    for ent, station in pairs(currentRadioSources) do
        if not IsValid(ent) or not IsValid(station) then
            if station then station:Stop() end
            currentRadioSources[ent] = nil
        else
            local actual = rRadio.utils.IsBoombox(ent) and ent or ent:GetParent() or ent
            station:SetPos(actual:GetPos())
            local plyPos = LocalPlayer():GetPos()
            local distSqr = plyPos:DistToSqr(actual:GetPos())
            local inCar = LocalPlayer():GetVehicle() == ent or table.HasValue(ents.FindByClass("prop_vehicle_prisoner_pod"), LocalPlayer():GetVehicle())
            rRadio.interface.updateRadioVolume(station, distSqr, inCar, actual)
        end
    end
end)

net.Receive("OpenRadioMenu", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) or not rRadio.utils.IsBoombox(ent) then return end
    LocalPlayer().currentRadioEntity = ent
    if not radioMenuOpen then openRadioMenu() end
end)

net.Receive("CarRadioMessage", function()
    local veh = net.ReadEntity()
    local isDriver = net.ReadBool()
    if IsValid(veh) then
        timer.Simple(0, function() rRadio.interface.DisplayVehicleEnterAnimation(veh, isDriver) end)
    end
end)

net.Receive("RadioConfigUpdate", function()
    for entity, source in pairs(currentRadioSources) do
        if IsValid(entity) and IsValid(source) then
            source:SetVolume(rRadio.interface.ClampVolume(entityVolumes[entity] or rRadio.interface.getEntityConfig(entity).Volume()))
        end
    end
end)

hook.Add("EntityRemoved", "rRadio.CleanupRadioStationCount", function(entity)
    if currentRadioSources[entity] then
        currentRadioSources[entity]:Stop()
        currentRadioSources[entity] = nil
    end
    if rRadio.utils.IsBoombox(entity) then BoomboxStatuses[entity:EntIndex()] = nil end
    if entity == LocalPlayer().currentRadioEntity then LocalPlayer().currentRadioEntity = nil end
end)

timer.Create("ValidateStationCount", 30, 0, function()
    local count = 0
    for ent, source in pairs(currentRadioSources) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            currentRadioSources[ent] = nil
        end
    end
    activeStationCount = count
end)

rRadio.interface.loadFavorites()
hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.addClConVars()
    rRadio.interface.loadSavedSettings()
end)
