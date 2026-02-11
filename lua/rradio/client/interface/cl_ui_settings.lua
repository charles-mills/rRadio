if SERVER then return end
rRadio.cl.settingsUI = {}
local Scale = rRadio.cl.Scale
local uiState = rRadio.cl.uiState
local function updateTextColours(panel)
    if not IsValid(panel) then return end
    if panel.SetTextColor then panel:SetTextColor(rRadio.config.UI.TextColor) end
    for _, child in ipairs(panel:GetChildren()) do
        updateTextColours(child)
    end
end

local function createSectionHeader(parent, text, isFirst)
    local header = vgui.Create("rRadioHeader", parent)
    header:SetTextLabel(text)
    header:SetIsFirst(isFirst)
end

local function getThemeDisplayName(themeName)
    return rRadio.L(themeName, themeName:gsub("^%l", string.upper))
end

local function refreshThemeControls(parentFrame, backButton)
    if not IsValid(parentFrame) then return end
    if IsValid(parentFrame.stopButton) then
        parentFrame.stopButton:SetColors(rRadio.config.UI.TextColor, rRadio.config.UI.CloseButtonColor, rRadio.config.UI.CloseButtonHoverColor)
    end
    if IsValid(parentFrame.menuScaleResetButton) then
        parentFrame.menuScaleResetButton:SetColors(rRadio.config.UI.TextColor, rRadio.config.UI.CloseButtonColor, rRadio.config.UI.CloseButtonHoverColor)
    end
    local buttons = {parentFrame.closeButton, parentFrame.settingsButton, backButton}
    for _, btn in ipairs(buttons) do
        if IsValid(btn) then btn.hoverColour = rRadio.config.UI.ButtonHoverColor end
    end
end

local function applyThemePreview(themeKey, parentFrame, backButton, themeDropdown)
    local key = themeKey:lower()
    if not (rRadio.themes and rRadio.themes[key]) then return end
    rRadio.interface.applyTheme(key)
    refreshThemeControls(parentFrame, backButton)
    updateTextColours(parentFrame)
    if IsValid(themeDropdown.dropdown.Menu) then updateTextColours(themeDropdown.dropdown.Menu) end
end

local function sendEntityMessage(messageName, entity)
    net.Start(messageName)
    net.WriteEntity(entity)
    net.SendToServer()
end

local function formatScaleValue(value)
    return string.format("%.2f", value)
end

local function styleScaleSlider(slider)
    slider:SetText("")
    slider:SetDecimals(2)
    slider.TextArea:SetVisible(false)
    if IsValid(slider.Label) then
        slider.Label:SetVisible(false)
        slider.Label:SetWide(0)
    end

    local function updateKnobSize()
        if not (IsValid(slider.Slider) and IsValid(slider.Slider.Knob)) then return end
        local knobSize = math.max(Scale(12), math.floor(slider:GetTall() * 0.55))
        if slider.Slider.Knob:GetWide() ~= knobSize or slider.Slider.Knob:GetTall() ~= knobSize then
            slider.Slider.Knob:SetSize(knobSize, knobSize)
        end
    end

    local oldPerformLayout = slider.PerformLayout
    slider.PerformLayout = function(self, w, h)
        if oldPerformLayout then oldPerformLayout(self, w, h) end
        updateKnobSize()
    end

    slider.Slider.Paint = function(self, w, h)
        local trackHeight = math.max(Scale(4), math.floor(h * 0.24))
        local y = math.floor((h - trackHeight) / 2)
        local knobInset = IsValid(self.Knob) and math.floor(self.Knob:GetWide() * 0.5) or 0
        local trackW = math.max(Scale(10), w - knobInset * 2)
        draw.RoundedBox(math.floor(trackHeight / 2), knobInset, y, trackW, trackHeight, rRadio.config.UI.TextColor)
    end

    slider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(math.floor(math.min(w, h) / 2), 0, 0, w, h, rRadio.config.UI.BackgroundColor)
    end
end

local function createScaleSlider(parent, titleText, minVal, maxVal, currentVal, onLive, onCommit)
    local container = vgui.Create("DPanel", parent)
    container:Dock(TOP)
    container:SetTall(Scale(58))
    container:DockMargin(0, 0, 0, Scale(5))
    container.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor) end

    local header = vgui.Create("DPanel", container)
    header:Dock(TOP)
    header:SetTall(Scale(22))
    header.Paint = nil

    local title = vgui.Create("DLabel", header)
    title:Dock(LEFT)
    title:DockMargin(Scale(10), 0, 0, 0)
    title:SetFont("rRadio.Roboto5")
    title:SetTextColor(rRadio.config.UI.TextColor)
    title:SetContentAlignment(4)
    title:SetText(titleText)
    title:SizeToContents()

    local valueLabel = vgui.Create("DLabel", header)
    valueLabel:Dock(RIGHT)
    valueLabel:DockMargin(0, 0, Scale(10), 0)
    valueLabel:SetFont("rRadio.Roboto5")
    valueLabel:SetTextColor(rRadio.config.UI.TextColor)
    valueLabel:SetContentAlignment(6)

    local slider = vgui.Create("DNumSlider", container)
    slider:Dock(FILL)
    slider:DockMargin(Scale(10), 0, Scale(10), Scale(6))
    slider:SetMin(minVal)
    slider:SetMax(maxVal)
    styleScaleSlider(slider)

    container.Think = function()
        local rowHeight = Scale(58)
        if container:GetTall() ~= rowHeight then container:SetTall(rowHeight) end
        header:SetTall(Scale(22))
        title:DockMargin(Scale(10), 0, 0, 0)
        valueLabel:DockMargin(0, 0, Scale(10), 0)
        slider:DockMargin(Scale(10), 0, Scale(10), Scale(6))
    end

    local function updateValueLabel(v)
        valueLabel:SetText(formatScaleValue(v))
        valueLabel:SizeToContents()
    end

    local initializing = true
    local pendingCommitValue
    local wasEditing = false

    local function commitValue(value)
        if not onCommit then return end
        value = math.Clamp(tonumber(value) or currentVal, minVal, maxVal)
        onCommit(value)
    end

    slider.OnValueChanged = function(self, value)
        value = math.Clamp(value, minVal, maxVal)
        updateValueLabel(value)
        if initializing then return end
        pendingCommitValue = value
        if onLive then onLive(value) end
    end

    local oldThink = slider.Think
    slider.Think = function(self)
        if oldThink then oldThink(self) end
        local editing = self:IsEditing()
        if wasEditing and not editing and pendingCommitValue ~= nil then
            commitValue(pendingCommitValue)
            pendingCommitValue = nil
        end
        wasEditing = editing
    end

    local oldOnRemove = slider.OnRemove
    slider.OnRemove = function(self)
        if pendingCommitValue ~= nil then
            commitValue(pendingCommitValue)
            pendingCommitValue = nil
        end
        if oldOnRemove then oldOnRemove(self) end
    end

    slider:SetValue(currentVal)
    initializing = false
    updateValueLabel(currentVal)
    return slider
end

local function styleMenuKeyBinder(binder)
    local oldOnMousePressed = binder.OnMousePressed
    function binder:OnMousePressed(code)
        if oldOnMousePressed then oldOnMousePressed(self, code) end
        self._waiting = true
        rRadio.interface.playSound("ButtonPressSecondary")
    end

    binder.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
        if self._waiting then return end
        draw.SimpleText(rRadio.GetKeyName(self:GetValue()), "rRadio.Roboto5", Scale(10), h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local oldOnChange = binder.OnChange
    function binder:OnChange(code)
        if rRadio.RejectBlockedMenuKey(self) then
            self._waiting = false
            self:SetText("")
            return
        end

        if oldOnChange then oldOnChange(self, code) end
        self._waiting = false
        rRadio.interface.playSound("SettingsMenuSuccess")
        RunConsoleCommand("rammel_rradio_menu_key", code)
        self:SetText("")
    end
end

function rRadio.cl.settingsUI.addThemeSelector(scrollPanel, parentFrame, backButton, selectedTheme)
    createSectionHeader(scrollPanel, rRadio.L("ThemeSelection", "Theme Selection"), true)
    local themeChoices = {}
    if rRadio.themes then
        for themeName, data in pairs(rRadio.themes) do
            if not data.Hidden then
                themeChoices[#themeChoices + 1] = {
                    name = getThemeDisplayName(themeName),
                    data = themeName
                }
            end
        end
    end

    local currentTheme = selectedTheme or GetConVar("rammel_rradio_menu_theme"):GetString()
    local currentThemeName = getThemeDisplayName(currentTheme)
    local previousTheme
    local selectionMade = false
    local themeDropdown = vgui.Create("rRadioDropdown", scrollPanel)
    themeDropdown:SetData(rRadio.L("SelectTheme", "Select Theme"), themeChoices, currentThemeName, function(self, _, _, themeKey)
        local key = themeKey:lower()
        if key == currentTheme then
            rRadio.interface.playSound("SettingsMenuError")
            return
        end

        if not (rRadio.themes and rRadio.themes[key]) then return end
        selectionMade = true
        RunConsoleCommand("rammel_rradio_menu_theme", key)
        rRadio.interface.applyTheme(key)
        refreshThemeControls(parentFrame, backButton)
        rRadio.cl.openSettingsMenu(parentFrame, backButton, key)
    end, function(themeKey) applyThemePreview(themeKey, parentFrame, backButton, themeDropdown) end, function()
        selectionMade = false
        previousTheme = GetConVar("rammel_rradio_menu_theme"):GetString()
    end, function() if not selectionMade and previousTheme then applyThemePreview(previousTheme, parentFrame, backButton, themeDropdown) end end)

    themeDropdown.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.ButtonColor) end
end

function rRadio.cl.settingsUI.addKeyBindSelector(scrollPanel)
    createSectionHeader(scrollPanel, rRadio.L("KeyBinds", "Key Binds"), false)
    local container = vgui.Create("DPanel", scrollPanel)
    container:Dock(TOP)
    container:SetTall(Scale(50))
    container:DockMargin(0, 0, 0, Scale(5))
    container.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor) end
    local label = vgui.Create("DLabel", container)
    label:Dock(LEFT)
    label:DockMargin(Scale(10), 0, 0, 0)
    label:SetFont("rRadio.Roboto5")
    label:SetTextColor(rRadio.config.UI.TextColor)
    label:SetText(rRadio.L("SelectKey", "Select Key"))
    label:SizeToContents()
    label:SetContentAlignment(4)
    local binder = vgui.Create("DBinder", container)
    binder:Dock(RIGHT)
    binder:DockMargin(0, Scale(5), Scale(10), Scale(5))
    binder:SetWide(Scale(150))
    binder:SetConVar("rammel_rradio_menu_key")
    local curKey = rRadio.cl.cvars.menuKey:GetInt()
    binder:SetValue(curKey)
    binder:SetText("")
    binder:SetFont("rRadio.Roboto5")
    binder._waiting = false
    styleMenuKeyBinder(binder)
end

function rRadio.cl.settingsUI.addMenuScaleOptions(scrollPanel, parentFrame)
    createSectionHeader(scrollPanel, rRadio.L("MenuScale", "Menu Scale"), false)
    local minScale, maxScale = rRadio.interface.GetMenuScaleRange()
    local minWidthScale, maxWidthScale = rRadio.interface.GetMenuWidthScaleRange()

    local function relayoutMenu()
        if isfunction(rRadio.cl.relayoutRadioMenu) then rRadio.cl.relayoutRadioMenu(false) end
    end

    local scaleSlider = createScaleSlider(scrollPanel, rRadio.L("MenuScaleSize", "Menu Size"), minScale, maxScale, rRadio.interface.GetMenuScale(), function(value)
        rRadio.interface.SetMenuScale(value, false)
        relayoutMenu()
    end, function(value)
        rRadio.interface.SetMenuScale(value, true)
        relayoutMenu()
        rRadio.interface.playSound("SettingsMenuSuccess")
    end)

    local widthSlider = createScaleSlider(scrollPanel, rRadio.L("MenuScaleWidth", "Menu Width"), minWidthScale, maxWidthScale, rRadio.interface.GetMenuWidthScale(), function(value)
        rRadio.interface.SetMenuWidthScale(value, false)
        relayoutMenu()
    end, function(value)
        rRadio.interface.SetMenuWidthScale(value, true)
        relayoutMenu()
        rRadio.interface.playSound("SettingsMenuSuccess")
    end)

    local resetButton = vgui.Create("rRadioAnimatedButton", scrollPanel)
    resetButton:Dock(TOP)
    resetButton:SetTall(Scale(36))
    resetButton:DockMargin(0, 0, 0, Scale(5))
    resetButton:SetText(rRadio.L("MenuScaleReset", "Reset Menu Scale"))
    resetButton:SetFont("rRadio.Roboto5")
    resetButton:SetColors(rRadio.config.UI.TextColor, rRadio.config.UI.CloseButtonColor, rRadio.config.UI.CloseButtonHoverColor)
    if IsValid(parentFrame) then parentFrame.menuScaleResetButton = resetButton end
    resetButton.DoClick = function()
        local defaultScale = rRadio.interface.GetMenuScaleDefault()
        local defaultWidthScale = rRadio.interface.GetMenuWidthScaleDefault()
        rRadio.interface.SetMenuScale(defaultScale, true)
        rRadio.interface.SetMenuWidthScale(defaultWidthScale, true)
        if IsValid(scaleSlider) then scaleSlider:SetValue(defaultScale) end
        if IsValid(widthSlider) then widthSlider:SetValue(defaultWidthScale) end
        relayoutMenu()
        rRadio.interface.playSound("SettingsMenuSuccess")
    end
end

function rRadio.cl.settingsUI.addGeneralOptions(scrollPanel)
    createSectionHeader(scrollPanel, rRadio.L("GeneralOptions", "General Options"), false)
    local options = {
        {
            label = rRadio.L("ShowCarMessages", "Show Car Radio Animation"),
            convar = "rammel_rradio_vehicle_animation"
        },
        {
            label = rRadio.L("ShowBoomboxHUD", "Show Boombox HUD"),
            convar = "rammel_rradio_boombox_hud"
        },
        {
            label = rRadio.L("BasicBoomboxHUD", "Basic Boombox HUD"),
            convar = "rammel_rradio_basic_hud"
        }
    }

    for _, opt in ipairs(options) do
        local cvar = GetConVar(opt.convar)
        local checkbox = vgui.Create("rRadioCheckbox", scrollPanel)
        checkbox:Setup(opt.label, opt.convar, cvar:GetBool(), function() rRadio.interface.playSound("SettingsMenuSuccess") end)
    end
end

function rRadio.cl.settingsUI.addSuperadminOptions(scrollPanel, currentEntity)
    if not (LocalPlayer():IsSuperAdmin() and rRadio.utils.IsBoombox(currentEntity)) then return end
    createSectionHeader(scrollPanel, rRadio.L("SuperadminSettings", "Superadmin Settings"), false)
    local permanentCheckbox = vgui.Create("rRadioCheckbox", scrollPanel)
    permanentCheckbox:Setup(rRadio.L("MakeBoomboxPermanent", "Make Boombox Permanent"), nil, currentEntity:GetNWBool("IsPermanent", false), function(self, value)
        if not IsValid(currentEntity) then
            self:SetChecked(false)
            return
        end

        if value then
            sendEntityMessage("rRadio.SetPersistent", currentEntity)
        else
            sendEntityMessage("rRadio.RemovePersistent", currentEntity)
        end
    end)

    uiState.permanentCheckboxRef = permanentCheckbox
end

function rRadio.cl.settingsUI.buildFooter(settingsFrame)
    local footer = vgui.Create("DPanel", settingsFrame)
    settingsFrame.footer = footer

    function settingsFrame:LayoutFooter()
        if not IsValid(self.footer) then return end
        local footerHeight = Scale(60)
        self.footer:SetSize(self:GetWide(), footerHeight)
        self.footer:SetPos(0, self:GetTall() - footerHeight)
        if IsValid(self.footer.steamButton) then
            local iconSize = rRadio.interface.scaleMenu(32)
            self.footer.steamButton:SetSize(iconSize, iconSize)
            self.footer.steamButton:SetPos(Scale(10), (footerHeight - iconSize) / 2)
        end
    end

    footer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        local gap = Scale(8)
        draw.SimpleText("rRadio by Rammel", "Default", w - Scale(10), h / 2 - gap, rRadio.config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("v" .. rRadio.config.RadioVersion, "Default", w - Scale(10), h / 2 + gap, rRadio.config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    footer.steamButton = rRadio.interface.MakeIconButton(footer, "hud/steam.png", "https://steamcommunity.com/id/rammel", Scale(10))
    settingsFrame:LayoutFooter()
end
