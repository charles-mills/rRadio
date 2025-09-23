if SERVER then return end

local Radio = rRadio
local Utils = Radio.utils
local Interface = Radio.interface
local Config = Radio.config

Radio.cl = Radio.cl or {}


local Scale = Radio.cl.Scale
local uiState = Radio.cl.uiState
local timing = Radio.cl.timing
local icons = Radio.cl.icons
local cvars = Radio.cl.cvars

local cachedMainFrame, cachedSettingsFrame

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

local function getHeaderIcon()
    if uiState.settingsMenuOpen then
        return icons.settings_b
    elseif uiState.globalView then
        return icons.globe
    elseif not uiState.selectedCountry then
        return icons.europe
    elseif uiState.selectedCountry == "favorites" then
        return icons.star.EMPTY
    else
        return icons.radio
    end
end

local function buildRawGlobalList()
    local rawList = {}
    for _, rec in ipairs(Radio.cl.nameIndex) do
        rawList[#rawList + 1] = {
            station    = rec.ref,
            countryKey = rec.country,
            displayKey = rec.ref.name
        }
    end
    return rawList
end

local function filterGlobalList(rawList, filterText)
    if filterText == "" then
        local limit, out = Radio.cl.MAX_SEARCH_RESULTS, {}
        for i = 1, math.min(limit, #rawList) do out[i] = rawList[i] end
        return out
    end

    return Interface.fuzzyFilter(
        filterText,
        rawList,
        function(item) return item.station.name end,
        0
    )
end

local function addStationButtons(parent, stations, limit, updateCallback)
    for i = 1, math.min(limit, #stations) do
        local entry = stations[i]
        entry.station.countryKey = entry.countryKey
        local btn = Radio.cl.uiComponents.createPlayableStationButton(
            parent,
            entry.station,
            entry.displayKey,
            updateCallback
        )
        parent:Add(btn)
    end
end

local function appendItems(dest, src)
    if not src then return end
    for _, v in ipairs(src) do dest[#dest + 1] = v end
end

function Radio.cl.populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not IsValid(stationListPanel) then return end

    if (not IsValid(backButton)) and uiState.currentFrame then
        backButton = uiState.currentFrame.backButton
    end

    searchBox = searchBox or uiState.searchBox

    local function updateKeep()  Radio.cl.populateList(stationListPanel, backButton, searchBox, false) end
    local function updateClear() Radio.cl.populateList(stationListPanel, backButton, searchBox, true)  end

    local filterText = prepareList(stationListPanel, searchBox, resetSearch)
    if uiState.globalView then
        local rawList   = buildRawGlobalList()
        local filtered  = filterGlobalList(rawList, filterText)
        local showLimit = (uiState.isSearching and Radio.cl.MAX_SEARCH_RESULTS) or #filtered

        addStationButtons(stationListPanel, filtered, showLimit, updateKeep)

        if backButton then
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
        end
        return
    end

    local items = {}

    if not uiState.selectedCountry then
        appendItems(items, Radio.cl.uiComponents.populateFavorites(stationListPanel, updateClear))
        appendItems(items, Radio.cl.uiComponents.populateCountries(stationListPanel, filterText, updateClear))
    else
        appendItems(items,
            Radio.cl.uiComponents.populateStations(
                stationListPanel,
                uiState.selectedCountry,
                filterText,
                updateKeep,
                backButton,
                searchBox
            )
        )
    end

    for _, v in ipairs(items) do stationListPanel:Add(v) end

    if backButton then
        local visible = uiState.selectedCountry ~= nil
        backButton:SetVisible(visible)
        backButton:SetEnabled(visible)
    end
end

function Radio.cl.openSettingsMenu(parentFrame, backButton, selectedTheme)
    if IsValid(uiState.settingsFrame) then
        uiState.settingsFrame:Remove()
    end
    
    uiState.settingsFrame = cachedSettingsFrame
    if not IsValid(uiState.settingsFrame) then
        uiState.settingsFrame = vgui.Create("DPanel", parentFrame)
        cachedSettingsFrame = uiState.settingsFrame
    else
        uiState.settingsFrame:SetParent(parentFrame)
    end
    
    uiState.settingsFrame:SetVisible(true)
    uiState.settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), 
        parentFrame:GetTall() - Scale(50) - Scale(10))
    uiState.settingsFrame:SetPos(Scale(10), Scale(50))
    uiState.settingsFrame.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.BackgroundColor)
        surface.DrawRect(0, 0, w, h)
    end
    
    local scrollPanel = vgui.Create("DScrollPanel", uiState.settingsFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
    Interface.StyleVBar(scrollPanel:GetVBar())
    
    Radio.cl.settingsUI.addThemeSelector(scrollPanel, parentFrame, backButton, selectedTheme)
    Radio.cl.settingsUI.addKeyBindSelector(scrollPanel)
    Radio.cl.settingsUI.addGeneralOptions(scrollPanel)
    Radio.cl.settingsUI.addSuperadminOptions(scrollPanel, LocalPlayer().currentRadioEntity)
    Radio.cl.settingsUI.buildFooter(uiState.settingsFrame)
end

local function createRadioFrame()
    local frame = cachedMainFrame
    if not IsValid(frame) then
        frame = vgui.Create("DFrame")
        cachedMainFrame = frame
    end
    
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    
    return frame
end

local function cleanupRadioMenu()
    if timer.Exists("rRadio.SearchDebounce") then
        timer.Remove("rRadio.SearchDebounce")
    end

    uiState.radioMenuOpen = false
    uiState.settingsMenuOpen = false
    uiState.favoritesMenuOpen = false
    uiState.selectedCountry = nil
    uiState.globalView = false
    uiState.lastView = nil
    
    if IsValid(uiState.settingsFrame) then 
        uiState.settingsFrame:SetVisible(false) 
    end
    
    uiState.currentFrame = nil
    
    if uiState.goldThemeActive then
        Interface.loadSavedSettings()
        uiState.goldThemeActive = false
    end
end

local function setupFrameEventHandlers(frame)
    local oldKeyPress = frame.OnKeyCodePressed
    frame.OnKeyCodePressed = function(self, code)
        local menuKey = cvars.menuKey:GetInt()
        if code == menuKey then
            if CurTime() - timing.lastKeyPress <= timing.keyPressDelay then return end
            Radio.cl.toggleCarRadioMenu()
            timing.lastKeyPress = CurTime()
            return
        end
        if oldKeyPress then oldKeyPress(self, code) end
    end
    
    frame.OnClose = function()
        cleanupRadioMenu()
    end
end

local function getHeaderText()
    if uiState.settingsMenuOpen then
        return Config.Lang["Settings"] or "Settings"
    elseif uiState.selectedCountry then
        if uiState.selectedCountry == "favorites" then
            return Config.Lang["FavoriteStations"] or "Favorite Stations"
        else
            return Utils.FormatAndTranslateCountry(uiState.selectedCountry)
        end
    else
        return Config.Lang["SelectCountry"] or "Select Country"
    end
end

local function setupFramePaint(frame)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), Config.UI.HeaderColor, true, true, false, false)
        local headerHeight = Scale(40)
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        local iconOffsetY = headerHeight / 2 - iconSize / 2
        
        surface.SetMaterial(getHeaderIcon())
        surface.SetDrawColor(Config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
        local headerText = getHeaderText()
        draw.SimpleText(headerText, "rRadio.Roboto8", iconOffsetX + iconSize + Scale(5), 
            headerHeight / 2 + Scale(2), Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function createStationListPanel(frame)
    local panel = vgui.Create("DScrollPanel", frame)
    panel:SetPos(Scale(5), Scale(90))
    panel:SetSize(
        Scale(Config.UI.FrameSize.width) - Scale(20),
        Scale(Config.UI.FrameSize.height) - Scale(200)
    )
    panel:SetVisible(not uiState.settingsMenuOpen)
    Interface.StyleVBar(panel:GetVBar())
    
    return panel
end

local function createSearchBox(parent, width, onChange)
    local searchBox = vgui.Create("DTextEntry", parent)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(width, Scale(30))
    searchBox:SetFont("rRadio.Roboto5")
    searchBox:SetPlaceholderText(Config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetDrawBackground(false)
    searchBox:SetTextColor(Config.UI.TextColor)
    
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
        self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)
        if self:GetText() == "" then
            draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h/2, 
                Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    
    searchBox.OnGetFocus = function() uiState.isSearching = true end
    searchBox.OnLoseFocus = function() uiState.isSearching = false end
    searchBox.OnValueChange = function() onChange() end
    searchBox.OnChange = searchBox.OnValueChange
    
    return searchBox
end

local function createGlobalButton(parent, searchBox, width, onClick)
    local margin = Scale(5)
    local height = Scale(30)
    local text = Config.Lang["Global"] or "GLOBAL"
    local font = Interface.calculateFontSizeForGlobalButton(text, width, height)
    
    local btn = vgui.Create("DButton", parent)
    btn:SetText(text)
    btn:SetFont(font)
    btn:SetTextColor(Config.UI.TextColor)
    btn:SetPos(searchBox:GetX() + searchBox:GetWide() + margin, searchBox:GetY())
    btn:SetSize(width, height)
    btn.lerp = 0
    
    btn.Think = function(self)
        local tgt = (self:IsHovered() or uiState.globalView) and 1 or 0
        self.lerp = math.Approach(self.lerp, tgt, FrameTime() * 10)
    end
    
    btn.Paint = function(self, w, h)
        local col = Interface.LerpColor(self.lerp, 
            Config.UI.ButtonColor, Config.UI.ButtonHoverColor)
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    
    btn.DoClick = onClick
    
    return btn
end

local function handleGlobalToggle(searchBox, stationListPanel, backButton)
    Interface.playSound("ButtonPressMain")
    
    if not uiState.globalView then
        uiState.lastView = {
            selectedCountry = uiState.selectedCountry,
            favoritesMenuOpen = uiState.favoritesMenuOpen,
            searchText = searchBox:GetText()
        }
        uiState.globalView = true
        uiState.selectedCountry = Config.Lang["Global"] or "global"
        uiState.favoritesMenuOpen = false
        uiState.settingsMenuOpen = false
        searchBox:SetText("")
    else
        if uiState.lastView then
            uiState.selectedCountry = uiState.lastView.selectedCountry
            uiState.favoritesMenuOpen = uiState.lastView.favoritesMenuOpen
            searchBox:SetText(uiState.lastView.searchText or "")
        end
        uiState.globalView = false
        uiState.lastView = nil
    end
    
    Radio.cl.populateList(stationListPanel, backButton, searchBox, true)
end

local function handleSearchChange(stationListPanel, backButton, searchBox)
    if timer.Exists("rRadio.SearchDebounce") then
        timer.Adjust("rRadio.SearchDebounce", Config.SearchDebounceSeconds)
    else
        timer.Create("rRadio.SearchDebounce", Config.SearchDebounceSeconds, 1, function()
            if not IsValid(stationListPanel) or not uiState.isSearching then return end
            Radio.cl.populateList(stationListPanel, backButton, searchBox, false)
        end)
    end
end

local function createSearchControls(frame, stationListPanel, backButton)
    local margin = Scale(5)
    local btnWidth = Scale(80)
    local fullWidth = Scale(Config.UI.FrameSize.width) - Scale(20)
    
    local searchBox = createSearchBox(frame, fullWidth - btnWidth - margin, function()
        handleSearchChange(stationListPanel, backButton, searchBox)
    end)
    local globalBtn = createGlobalButton(frame, searchBox, btnWidth, function()
        handleGlobalToggle(searchBox, stationListPanel, backButton)
    end)
    
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

local function handleBackButton(stationListPanel, searchBox, backButton)
    Interface.playSound("MenuClosed")

    if uiState.settingsMenuOpen then
        uiState.settingsMenuOpen = false

        if IsValid(uiState.settingsFrame) then
            uiState.settingsFrame:Remove()
            uiState.settingsFrame = nil
        end

        if IsValid(searchBox) then
            searchBox:SetVisible(true)
        end

        stationListPanel:SetVisible(true)
        Radio.cl.populateList(stationListPanel, backButton, searchBox, true)

    else
        uiState.globalView   = false
        uiState.lastView     = nil
        uiState.selectedCountry = nil
        uiState.favoritesMenuOpen = false

        if backButton then
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
        end

        Radio.cl.populateList(stationListPanel, backButton, searchBox, true)
    end
end

local function openSettingsView(frame, backButton, stationListPanel, searchBox)
    Interface.playSound("MenuClosed")
    uiState.settingsMenuOpen = true
    Radio.cl.openSettingsMenu(frame, backButton, nil)
    
    if backButton then
        backButton:SetVisible(true)
        backButton:SetEnabled(true)
    end
    
    searchBox:SetVisible(false)
    stationListPanel:SetVisible(false)
end

local function createNavigationButtons(frame, stationListPanel, searchBox)
    local buttons = {}
    local buttonSize = Scale(25)
    local topMargin = Scale(7)
    local buttonPadding = Scale(5)
    local xPos = frame:GetWide() - buttonSize - Scale(10)
    
    buttons.close = createNavButton(frame, xPos, topMargin, "hud/close.png", function()
        Interface.playSound("MenuClosed")
        frame:Close()
    end)
    
    xPos = xPos - buttonSize - buttonPadding
    
    buttons.settings = createNavButton(frame, xPos, topMargin, "hud/settings.png", function()
        openSettingsView(frame, buttons.back, stationListPanel, searchBox)
    end)
    
    xPos = xPos - buttonSize - buttonPadding
    
    buttons.back = createNavButton(frame, xPos, topMargin, "hud/return.png", function()
        handleBackButton(stationListPanel, searchBox, buttons.back)
    end)

    buttons.back:MoveToFront()
    buttons.settings:MoveToFront()
    buttons.close:MoveToFront()

    buttons.back:SetVisible((uiState.selectedCountry ~= nil and uiState.selectedCountry ~= "") or 
                           uiState.settingsMenuOpen)
    buttons.back:SetEnabled((uiState.selectedCountry ~= nil and uiState.selectedCountry ~= "") or 
                           uiState.settingsMenuOpen)
    
    return buttons
end

local function handleStopButton(stationListPanel, backButton, searchBox)
    Interface.playSound("ButtonPressSecondary")
    local entity = LocalPlayer().currentRadioEntity
    
    if IsValid(entity) then
        net.Start("rRadio.StopStation")
        net.WriteEntity(entity)
        net.SendToServer()
        
        Radio.cl.currentlyPlayingStations[entity] = nil
        Radio.cl.populateList(stationListPanel, backButton, searchBox, false)
        
        if backButton then
            backButton:SetVisible(uiState.selectedCountry ~= nil or uiState.settingsMenuOpen)
            backButton:SetEnabled(uiState.selectedCountry ~= nil or uiState.settingsMenuOpen)
        end
    end
end

local function createStopButton(frame, stationListPanel, backButton, searchBox)
    local height = Scale(Config.UI.FrameSize.width) / 8
    local width = Scale(Config.UI.FrameSize.width) / 4
    local text = Config.Lang["StopRadio"] or "STOP"
    local font = Interface.calculateFontSizeForStopButton(text, width, height)
    
    local btn = vgui.Create("rRadioAnimatedButton", frame)
    btn:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(90))
    btn:SetSize(width, height)
    btn:SetText(text)
    btn:SetFont(font)
    btn:SetColors(
        Config.UI.TextColor,
        Config.UI.CloseButtonColor,
        Config.UI.CloseButtonHoverColor
    )
    
    btn.DoClick = function()
        handleStopButton(stationListPanel, backButton, searchBox)
    end
    
    return btn
end

local function createVolumePanel(parent, stopButtonWidth, height)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
    panel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, height)
    
    panel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
    end
    
    return panel
end

local function createVolumeIcon(parent)
    local size = Scale(50)
    local icon = vgui.Create("DImage", parent)
    icon:SetPos(Scale(10), (parent:GetTall() - size) / 2)
    icon:SetSize(size, size)
    icon:SetMaterial(Interface.GetVolumeIcon(1.0))
    
    icon.Paint = function(self, w, h)
        surface.SetDrawColor(Config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end
    
    return icon
end

local function getCurrentEntityVolume(entity)
    if not IsValid(entity) then return 0.5 end
    
    local entityConfig = Interface.getEntityConfig(entity)
    local defaultVolume = (entityConfig and entityConfig.Volume) or 0.5
    local currentVolume = entity:GetNWFloat("Volume", defaultVolume)
    
    Radio.cl.entityVolumes[entity] = currentVolume
    
    local maxVol = Config.MaxVolume or 1.0
    return math.min(currentVolume, maxVol)
end

local function setupVolumeSliderEvents(knob)
    local origPress = knob.OnMousePressed
    knob.OnMousePressed = function(self, mcode)
        if origPress then origPress(self, mcode) end
    end
    
    local origRelease = knob.OnMouseReleased
    knob.OnMouseReleased = function(self, mcode)
        if origRelease then origRelease(self, mcode) end
        Radio.cl.sendPendingVolume()
    end
end

local function createVolumeSlider(parent, stopButtonWidth, initialValue, onChange)
    local slider = vgui.Create("DNumSlider", parent)
    slider:SetPos(-Scale(170), Scale(5))
    slider:SetSize(
        Scale(Config.UI.FrameSize.width) + Scale(120) - stopButtonWidth,
        parent:GetTall() - Scale(20)
    )
    slider:SetText("")
    slider:SetMin(0)
    slider:SetMax(Config.MaxVolume or 1.0)
    slider:SetDecimals(2)
    slider:SetValue(initialValue)

    slider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, h / 2 - 4, w, 16, Config.UI.TextColor)
    end
    slider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
    end

    slider.TextArea:SetVisible(false)

    slider.OnValueChanged = function(self, newValue)
        if onChange then
            onChange(newValue)
        end
    end

    setupVolumeSliderEvents(slider.Slider)

    return slider
end

local function handleVolumeChange(entity, value, icon)
    if not IsValid(entity) then return end
    
    if not Utils.IsBoombox(entity) then
        entity = Utils.GetVehicle(entity)
    end
    
    local maxVol = Config.MaxVolume or 1.0
    value = math.min(value, maxVol)
    
    Radio.cl.entityVolumes[entity] = value
    
    if Radio.cl.radioSources[entity] and IsValid(Radio.cl.radioSources[entity]) then
        Radio.cl.radioSources[entity]:SetVolume(value)
    end
    
    Radio.cl.updateVolumeIcon(icon, value)
    Radio.cl.pendingVolume = value
    Radio.cl.pendingEntity = entity
end

local function createVolumeControls(frame, stopButton)
    local stopButtonWidth = stopButton:GetWide()
    local stopButtonHeight = stopButton:GetTall()
    
    local panel = createVolumePanel(frame, stopButtonWidth, stopButtonHeight)
    local icon = createVolumeIcon(panel)
    
    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = getCurrentEntityVolume(entity)
    Radio.cl.updateVolumeIcon(icon, currentVolume)
    
    local slider = createVolumeSlider(panel, stopButtonWidth, currentVolume, function(value)
        handleVolumeChange(entity, value, icon)
    end)
    
    return panel, icon, slider
end

local function validateRadioMenuOpen()
    if not cvars.enabled:GetBool() or uiState.radioMenuOpen then
        return false
    end
    
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    
    if not IsValid(entity) then
        return false
    end
    
    if not Utils.CanUseRadio(entity) then
        chat.AddText(Color(255, 0, 0), "[rRADIO] This seat cannot use the radio.")
        return false
    end
    
    local shouldOpen = hook.Run("rRadio.CanOpenMenu", ply, entity)
    if shouldOpen == false then
        return false
    end
    
    return true
end

local function applyEntityTheme(entity)
    if not IsValid(entity) then return end
    
    uiState.goldThemeActive = (entity:GetClass() == "rammel_boombox_gold")
    if uiState.goldThemeActive then
        Interface.applyTheme("gold")
    end
end

function Radio.cl.openRadioMenu(openSettings, opts)
    opts = opts or {}
    
    if opts.delay and IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
        timer.Simple(0.1, function() Radio.cl.openRadioMenu(openSettings, {}) end)
        return
    end
    
    if not validateRadioMenuOpen() then return end
    
    applyEntityTheme(LocalPlayer().currentRadioEntity)
    
    local frame = createRadioFrame()
    uiState.currentFrame = frame
    uiState.radioMenuOpen = true
    
    setupFrameEventHandlers(frame)
    setupFramePaint(frame)
    
    local stationListPanel = createStationListPanel(frame)
    local searchBox, globalBtn = createSearchControls(frame, stationListPanel)
    local buttons = createNavigationButtons(frame, stationListPanel, searchBox)

    globalBtn.DoClick = function()
        handleGlobalToggle(searchBox, stationListPanel, buttons.back)
    end
    local stopButton = createStopButton(frame, stationListPanel, buttons.back, searchBox)
    local volumePanel, volumeIcon, volumeSlider = createVolumeControls(frame, stopButton)
    
    frame.closeButton = buttons.close
    frame.settingsButton = buttons.settings
    frame.backButton = buttons.back
    frame.stopButton = stopButton
    
    if not uiState.settingsMenuOpen then
        Radio.cl.populateList(stationListPanel, buttons.back, searchBox, true)
    else
        Radio.cl.openSettingsMenu(frame, buttons.back, nil)
    end
end

function Radio.cl.toggleCarRadioMenu()
    local ply = LocalPlayer()
    
    if uiState.radioMenuOpen then
        Interface.playSound("MenuClosed")
        uiState.currentFrame:Close()
        uiState.radioMenuOpen = false
        uiState.selectedCountry = nil
        uiState.settingsMenuOpen = false
        uiState.favoritesMenuOpen = false
        uiState.globalView = false
        uiState.lastView = nil
        return
    end
    
    local vehicle = ply:GetVehicle()
    if not IsValid(vehicle) then return end
    
    local mainVehicle = Utils.GetVehicle(vehicle)
    if not IsValid(mainVehicle) then return end
    
    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then return end
    
    if Config.DriverPlayOnly then
        local isPlayerDriving = (mainVehicle:GetDriver() == ply)
        if not isPlayerDriving then return end
    end
    
    if not Utils.IsSitAnywhereSeat(mainVehicle) then
        ply.currentRadioEntity = mainVehicle
        Radio.cl.openRadioMenu()
    end
end

openRadioMenu = Radio.cl.openRadioMenu
toggleCarRadioMenu = Radio.cl.toggleCarRadioMenu
    
