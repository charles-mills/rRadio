if SERVER then return end
local Scale = rRadio.cl.Scale
local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local icons = rRadio.cl.icons
local cvars = rRadio.cl.cvars
local function setButtonState(button, enabled)
    if not IsValid(button) then return end
    button:SetVisible(enabled)
    button:SetEnabled(enabled)
end

local function syncBackButton(backButton)
    setButtonState(backButton, uiState.settingsMenuOpen or uiState.globalView or (uiState.selectedCountry ~= nil and uiState.selectedCountry ~= ""))
end

local function addItems(panel, items)
    for _, item in ipairs(items or {}) do
        panel:Add(item)
    end
end

local function getHeaderIcon()
    if uiState.settingsMenuOpen then return icons.settings_b end
    if uiState.globalView then return icons.globe end
    if not uiState.selectedCountry then return icons.europe end
    if uiState.selectedCountry == "favorites" then return icons.star.EMPTY end
    return icons.radio
end

local function getHeaderText()
    if uiState.settingsMenuOpen then return rRadio.config.Lang["Settings"] or "Settings" end
    if uiState.selectedCountry == "favorites" then return rRadio.config.Lang["FavoriteStations"] or "Favorite Stations" end
    if uiState.selectedCountry then return rRadio.utils.FormatAndTranslateCountry(uiState.selectedCountry) end
    return rRadio.config.Lang["SelectCountry"] or "Select Country"
end

local function prepareList(stationListPanel, searchBox, resetSearch)
    stationListPanel:Clear()
    searchBox = searchBox or uiState.searchBox
    if not IsValid(searchBox) then
        uiState.isSearching = false
        return ""
    end

    if resetSearch then searchBox:SetText("") end
    return searchBox:GetText():lower()
end

local function buildRawGlobalList()
    if rRadio.cl.globalSearchIndex then return rRadio.cl.globalSearchIndex end
    local rawList = {}
    for _, rec in ipairs(rRadio.cl.nameIndex or {}) do
        rawList[#rawList + 1] = {
            station = rec.ref,
            countryKey = rec.country,
            displayKey = rec.ref.name,
            searchText = rec.ref.name,
            searchTextLower = rec.key,
            charMap = rec.ref.charMap
        }
    end
    return rawList
end

local function filterGlobalList(rawList, filterText)
    if filterText == "" then
        local limit, out = rRadio.cl.MAX_SEARCH_RESULTS, {}
        for i = 1, math.min(limit, #rawList) do
            out[i] = rawList[i]
        end
        return out
    end
    return rRadio.interface.fuzzyFilter(filterText, rawList, function(item) return item.searchText end, 0)
end

local function addStationButtons(parent, stations, limit, updateCallback)
    for i = 1, math.min(limit, #stations) do
        local entry = stations[i]
        local btn = rRadio.cl.uiComponents.createPlayableStationButton(parent, entry.station, entry.displayKey, updateCallback)
        parent:Add(btn)
    end
end

function rRadio.cl.populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not IsValid(stationListPanel) then return end
    if (not IsValid(backButton)) and uiState.currentFrame then backButton = uiState.currentFrame.backButton end
    searchBox = searchBox or uiState.searchBox
    local function updateKeep()
        rRadio.cl.populateList(stationListPanel, backButton, searchBox, false)
    end

    local function updateClear()
        rRadio.cl.populateList(stationListPanel, backButton, searchBox, true)
    end

    local filterText = prepareList(stationListPanel, searchBox, resetSearch)
    if uiState.globalView then
        local rawList = buildRawGlobalList()
        local filtered = filterGlobalList(rawList, filterText)
        local showLimit = (uiState.isSearching and rRadio.cl.MAX_SEARCH_RESULTS) or #filtered
        addStationButtons(stationListPanel, filtered, showLimit, updateKeep)
        setButtonState(backButton, true)
        return
    end

    if not uiState.selectedCountry then
        addItems(stationListPanel, rRadio.cl.uiComponents.populateFavorites(stationListPanel, updateClear))
        addItems(stationListPanel, rRadio.cl.uiComponents.populateCountries(stationListPanel, filterText, updateClear))
    else
        addItems(stationListPanel, rRadio.cl.uiComponents.populateStations(stationListPanel, uiState.selectedCountry, filterText, updateKeep, backButton))
    end

    syncBackButton(backButton)
end

function rRadio.cl.openSettingsMenu(parentFrame, backButton, selectedTheme)
    if IsValid(uiState.settingsFrame) then uiState.settingsFrame:Remove() end
    uiState.settingsFrame = vgui.Create("DPanel", parentFrame)
    uiState.settingsFrame:SetVisible(true)
    uiState.settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50) - Scale(10))
    uiState.settingsFrame:SetPos(Scale(10), Scale(50))
    uiState.settingsFrame.Paint = function(self, w, h)
        surface.SetDrawColor(rRadio.config.UI.BackgroundColor)
        surface.DrawRect(0, 0, w, h)
    end

    local scrollPanel = vgui.Create("DScrollPanel", uiState.settingsFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
    rRadio.interface.StyleVBar(scrollPanel:GetVBar())
    rRadio.cl.settingsUI.addThemeSelector(scrollPanel, parentFrame, backButton, selectedTheme)
    rRadio.cl.settingsUI.addKeyBindSelector(scrollPanel)
    rRadio.cl.settingsUI.addGeneralOptions(scrollPanel)
    rRadio.cl.settingsUI.addSuperadminOptions(scrollPanel, LocalPlayer().currentRadioEntity)
    rRadio.cl.settingsUI.buildFooter(uiState.settingsFrame)
end

local function cleanupRadioMenu()
    if timer.Exists("rRadio.SearchDebounce") then timer.Remove("rRadio.SearchDebounce") end
    uiState.radioMenuOpen = false
    uiState.settingsMenuOpen = false
    uiState.favoritesMenuOpen = false
    uiState.selectedCountry = nil
    uiState.globalView = false
    uiState.lastView = nil
    if IsValid(uiState.settingsFrame) then uiState.settingsFrame:Remove() end
    uiState.currentFrame = nil
    if uiState.goldThemeActive then
        rRadio.interface.loadSavedSettings()
        uiState.goldThemeActive = false
    end
end

local function createRadioFrame()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(Scale(rRadio.config.UI.FrameSize.width), Scale(rRadio.config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    local oldKeyPress = frame.OnKeyCodePressed
    frame.OnKeyCodePressed = function(self, code)
        local menuKey = cvars.menuKey:GetInt()
        if code == menuKey then
            if CurTime() - timing.lastKeyPress <= timing.keyPressDelay then return end
            rRadio.cl.toggleCarRadioMenu()
            timing.lastKeyPress = CurTime()
            return
        end

        if oldKeyPress then oldKeyPress(self, code) end
    end

    frame.OnClose = function() cleanupRadioMenu() end
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), rRadio.config.UI.HeaderColor, true, true, false, false)
        local headerHeight = Scale(40)
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        local iconOffsetY = headerHeight / 2 - iconSize / 2
        local icon = getHeaderIcon()
        surface.SetMaterial(icon)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
        draw.SimpleText(getHeaderText(), "rRadio.Roboto8", iconOffsetX + iconSize + Scale(5), headerHeight / 2 + Scale(2), rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return frame
end

local function createStationListPanel(frame)
    local panel = vgui.Create("DScrollPanel", frame)
    panel:SetPos(Scale(5), Scale(90))
    panel:SetSize(Scale(rRadio.config.UI.FrameSize.width) - Scale(20), Scale(rRadio.config.UI.FrameSize.height) - Scale(200))
    panel:SetVisible(not uiState.settingsMenuOpen)
    rRadio.interface.StyleVBar(panel:GetVBar())
    return panel
end

local function createSearchBox(parent, width, onChange)
    local searchBox = vgui.Create("DTextEntry", parent)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(width, Scale(30))
    searchBox:SetFont("rRadio.Roboto5")
    searchBox:SetPlaceholderText(rRadio.config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetDrawBackground(false)
    searchBox:SetTextColor(rRadio.config.UI.TextColor)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
        self:DrawTextEntryText(rRadio.config.UI.TextColor, Color(120, 120, 120), rRadio.config.UI.TextColor)
        if self:GetText() == "" then draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end

    searchBox.OnGetFocus = function() uiState.isSearching = true end
    searchBox.OnLoseFocus = function() uiState.isSearching = false end
    searchBox.OnValueChange = function() onChange() end
    searchBox.OnChange = searchBox.OnValueChange
    return searchBox
end

local function createGlobalButton(parent, searchBox, width)
    local margin = Scale(5)
    local height = Scale(30)
    local text = rRadio.config.Lang["Global"] or "GLOBAL"
    local font = rRadio.interface.calculateFontSizeForGlobalButton(text, width, height)
    local btn = vgui.Create("DButton", parent)
    btn:SetText(text)
    btn:SetFont(font)
    btn:SetTextColor(rRadio.config.UI.TextColor)
    btn:SetPos(searchBox:GetX() + searchBox:GetWide() + margin, searchBox:GetY())
    btn:SetSize(width, height)
    btn.lerp = 0
    btn.Think = function(self)
        local tgt = (self:IsHovered() or uiState.globalView) and 1 or 0
        self.lerp = math.Approach(self.lerp, tgt, FrameTime() * 10)
    end

    btn.Paint = function(self, w, h)
        local col = rRadio.interface.LerpColor(self.lerp, rRadio.config.UI.ButtonColor, rRadio.config.UI.ButtonHoverColor)
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    return btn
end

local function queueSearchRefresh(stationListPanel, searchBox)
    local timerName = "rRadio.SearchDebounce"
    local delay = rRadio.config.SearchDebounceSeconds
    if timer.Exists(timerName) then
        timer.Adjust(timerName, delay)
        return
    end

    timer.Create(timerName, delay, 1, function()
        if not IsValid(stationListPanel) or not uiState.isSearching then return end
        rRadio.cl.populateList(stationListPanel, nil, searchBox, false)
    end)
end

local function createSearchControls(frame, stationListPanel)
    local margin = Scale(5)
    local btnWidth = Scale(80)
    local fullWidth = Scale(rRadio.config.UI.FrameSize.width) - Scale(20)
    local searchBox
    searchBox = createSearchBox(frame, fullWidth - btnWidth - margin, function() queueSearchRefresh(stationListPanel, searchBox) end)
    local globalBtn = createGlobalButton(frame, searchBox, btnWidth)
    searchBox:SetVisible(not uiState.settingsMenuOpen)
    uiState.searchBox = searchBox
    return searchBox, globalBtn
end

local function createNavButton(parent, x, y, icon, callback)
    local btn = vgui.Create("rRadioNavButton", parent)
    btn:SetPos(x, y)
    btn:SetIcon(icon)
    btn:SetCallback(callback)
    return btn
end

local function withMenuCloseSound(fn)
    return function(...)
        rRadio.interface.playSound("MenuClosed")
        fn(...)
    end
end

local function createNavigationButtons(frame, stationListPanel, searchBox)
    local buttons = {}
    local buttonSize = Scale(25)
    local topMargin = Scale(7)
    local buttonPadding = Scale(5)
    local xPos = frame:GetWide() - buttonSize - Scale(10)
    buttons.close = createNavButton(frame, xPos, topMargin, "hud/close.png", withMenuCloseSound(function() frame:Close() end))
    xPos = xPos - buttonSize - buttonPadding
    buttons.settings = createNavButton(frame, xPos, topMargin, "hud/settings.png", withMenuCloseSound(function()
        uiState.settingsMenuOpen = true
        rRadio.cl.openSettingsMenu(frame, buttons.back, nil)
        setButtonState(buttons.back, true)
        searchBox:SetVisible(false)
        stationListPanel:SetVisible(false)
    end))

    xPos = xPos - buttonSize - buttonPadding
    buttons.back = createNavButton(frame, xPos, topMargin, "hud/return.png", withMenuCloseSound(function()
        if uiState.settingsMenuOpen then
            uiState.settingsMenuOpen = false
            if IsValid(uiState.settingsFrame) then
                uiState.settingsFrame:Remove()
                uiState.settingsFrame = nil
            end

            if IsValid(searchBox) then searchBox:SetVisible(true) end
            stationListPanel:SetVisible(true)
        else
            uiState.globalView = false
            uiState.lastView = nil
            uiState.selectedCountry = nil
            uiState.favoritesMenuOpen = false
        end

        rRadio.cl.populateList(stationListPanel, buttons.back, searchBox, true)
    end))

    buttons.back:MoveToFront()
    buttons.settings:MoveToFront()
    buttons.close:MoveToFront()
    syncBackButton(buttons.back)
    return buttons
end

local function createStopButton(frame, stationListPanel, backButton, searchBox)
    local height = Scale(rRadio.config.UI.FrameSize.width) / 8
    local width = Scale(rRadio.config.UI.FrameSize.width) / 4
    local text = rRadio.config.Lang["StopRadio"] or "STOP"
    local font = rRadio.interface.calculateFontSizeForStopButton(text, width, height)
    local btn = vgui.Create("rRadioAnimatedButton", frame)
    btn:SetPos(Scale(10), Scale(rRadio.config.UI.FrameSize.height) - Scale(90))
    btn:SetSize(width, height)
    btn:SetText(text)
    btn:SetFont(font)
    btn:SetColors(rRadio.config.UI.TextColor, rRadio.config.UI.CloseButtonColor, rRadio.config.UI.CloseButtonHoverColor)
    btn.DoClick = function()
        rRadio.interface.playSound("ButtonPressSecondary")
        local entity = LocalPlayer().currentRadioEntity
        if IsValid(entity) then
            net.Start("rRadio.StopStation")
            net.WriteEntity(entity)
            net.SendToServer()
            rRadio.cl.currentlyPlayingStations[entity] = nil
            rRadio.cl.populateList(stationListPanel, backButton, searchBox, false)
            syncBackButton(backButton)
        end
    end
    return btn
end

local function createVolumeControls(frame, stopButton)
    local stopButtonWidth = stopButton:GetWide()
    local stopButtonHeight = stopButton:GetTall()
    local panel = vgui.Create("DPanel", frame)
    panel:SetPos(Scale(20) + stopButtonWidth, Scale(rRadio.config.UI.FrameSize.height) - Scale(90))
    panel:SetSize(Scale(rRadio.config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
    panel.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.CloseButtonColor) end
    local iconSize = Scale(50)
    local icon = vgui.Create("DImage", panel)
    icon:SetPos(Scale(10), (panel:GetTall() - iconSize) / 2)
    icon:SetSize(iconSize, iconSize)
    icon:SetMaterial(rRadio.interface.GetVolumeIcon(1.0))
    icon.Paint = function(self, w, h)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume
    if IsValid(entity) then
        local entityConfig = rRadio.interface.getEntityConfig(entity)
        local defaultVolume = (entityConfig and entityConfig.Volume) or 0.5
        currentVolume = entity:GetNWFloat("Volume", defaultVolume)
        rRadio.cl.entityVolumes[entity] = currentVolume
        currentVolume = math.min(currentVolume, rRadio.config.MaxVolume or 1.0)
    else
        currentVolume = 0.5
    end

    rRadio.cl.updateVolumeIcon(icon, currentVolume)
    local slider = vgui.Create("DNumSlider", panel)
    slider:SetPos(-Scale(170), Scale(5))
    slider:SetSize(Scale(rRadio.config.UI.FrameSize.width) + Scale(120) - stopButtonWidth, panel:GetTall() - Scale(20))
    slider:SetText("")
    slider:SetMin(0)
    slider:SetMax(rRadio.config.MaxVolume or 1.0)
    slider:SetDecimals(2)
    slider:SetValue(currentVolume)
    slider.Slider.Paint = function(self, w, h) draw.RoundedBox(8, 0, h / 2 - 4, w, 16, rRadio.config.UI.TextColor) end
    slider.Slider.Knob.Paint = function(self, w, h) draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, rRadio.config.UI.BackgroundColor) end
    slider.TextArea:SetVisible(false)
    slider.OnValueChanged = function(self, value)
        if not IsValid(entity) then return end
        local ent = entity
        if not rRadio.utils.IsBoombox(ent) then ent = rRadio.utils.GetVehicle(ent) end
        local maxVol = rRadio.config.MaxVolume or 1.0
        value = math.min(value, maxVol)
        rRadio.cl.entityVolumes[ent] = value
        if rRadio.cl.radioSources[ent] and IsValid(rRadio.cl.radioSources[ent]) then rRadio.cl.radioSources[ent]:SetVolume(value) end
        rRadio.cl.updateVolumeIcon(icon, value)
        rRadio.cl.pendingVolume = value
        rRadio.cl.pendingEntity = ent
    end

    local origRelease = slider.Slider.OnMouseReleased
    slider.Slider.OnMouseReleased = function(self, mcode)
        if origRelease then origRelease(self, mcode) end
        rRadio.cl.sendPendingVolume()
    end
end

local function validateRadioMenuOpen()
    if not cvars.enabled:GetBool() or uiState.radioMenuOpen then return false end
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    if not IsValid(entity) then return false end
    if not rRadio.utils.CanUseRadio(entity) then
        chat.AddText(Color(255, 0, 0), "[rRADIO] This seat cannot use the radio.")
        return false
    end

    local shouldOpen = hook.Run("rRadio.CanOpenMenu", ply, entity)
    if shouldOpen == false then return false end
    return true
end

local function applyEntityTheme(entity)
    if not IsValid(entity) then return end
    uiState.goldThemeActive = entity:GetClass() == "rammel_boombox_gold"
    if uiState.goldThemeActive then rRadio.interface.applyTheme("gold") end
end

local function toggleGlobalView(searchBox)
    if not uiState.globalView then
        uiState.lastView = {
            selectedCountry = uiState.selectedCountry,
            favoritesMenuOpen = uiState.favoritesMenuOpen,
            searchText = searchBox:GetText()
        }

        uiState.globalView = true
        uiState.selectedCountry = rRadio.config.Lang["Global"] or "global"
        uiState.favoritesMenuOpen = false
        uiState.settingsMenuOpen = false
        searchBox:SetText("")
        return
    end

    if uiState.lastView then
        uiState.selectedCountry = uiState.lastView.selectedCountry
        uiState.favoritesMenuOpen = uiState.lastView.favoritesMenuOpen
        searchBox:SetText(uiState.lastView.searchText or "")
    end

    uiState.globalView = false
    uiState.lastView = nil
end

function rRadio.cl.openRadioMenu(openSettings, opts)
    opts = opts or {}
    if opts.delay and IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
        timer.Simple(0.1, function() rRadio.cl.openRadioMenu(openSettings, {}) end)
        return
    end

    if not validateRadioMenuOpen() then return end
    applyEntityTheme(LocalPlayer().currentRadioEntity)
    local frame = createRadioFrame()
    uiState.currentFrame = frame
    uiState.radioMenuOpen = true
    local stationListPanel = createStationListPanel(frame)
    local searchBox, globalBtn = createSearchControls(frame, stationListPanel)
    local buttons = createNavigationButtons(frame, stationListPanel, searchBox)
    globalBtn.DoClick = function()
        rRadio.interface.playSound("ButtonPressMain")
        toggleGlobalView(searchBox)
        rRadio.cl.populateList(stationListPanel, buttons.back, searchBox, true)
    end

    local stopButton = createStopButton(frame, stationListPanel, buttons.back, searchBox)
    createVolumeControls(frame, stopButton)
    frame.closeButton = buttons.close
    frame.settingsButton = buttons.settings
    frame.backButton = buttons.back
    frame.stopButton = stopButton
    if not uiState.settingsMenuOpen then
        rRadio.cl.populateList(stationListPanel, buttons.back, searchBox, true)
    else
        rRadio.cl.openSettingsMenu(frame, buttons.back, nil)
    end
end

function rRadio.cl.toggleCarRadioMenu()
    local ply = LocalPlayer()
    if uiState.radioMenuOpen then
        rRadio.interface.playSound("MenuClosed")
        uiState.currentFrame:Close()
        return
    end

    local vehicle = ply:GetVehicle()
    if not IsValid(vehicle) then return end
    local mainVehicle = rRadio.utils.GetVehicle(vehicle)
    if not IsValid(mainVehicle) then return end
    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then return end
    if rRadio.config.DriverPlayOnly then
        local isPlayerDriving = mainVehicle:GetDriver() == ply
        if not isPlayerDriving then return end
    end

    if not rRadio.utils.IsSitAnywhereSeat(mainVehicle) then
        ply.currentRadioEntity = mainVehicle
        rRadio.cl.openRadioMenu()
    end
end
