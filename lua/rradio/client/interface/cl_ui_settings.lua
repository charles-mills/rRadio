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
    return rRadio.config.Lang[themeName] or themeName:gsub("^%l", string.upper)
end

local function refreshThemeControls(parentFrame, backButton)
    if IsValid(parentFrame.stopButton) then parentFrame.stopButton:SetColors(rRadio.config.UI.TextColor, rRadio.config.UI.CloseButtonColor, rRadio.config.UI.CloseButtonHoverColor) end
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
    createSectionHeader(scrollPanel, rRadio.config.Lang["ThemeSelection"] or "Theme Selection", true)
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
    themeDropdown:SetData(rRadio.config.Lang["SelectTheme"] or "Select Theme", themeChoices, currentThemeName, function(self, _, _, themeKey)
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
    createSectionHeader(scrollPanel, rRadio.config.Lang["KeyBinds"] or "Key Binds", false)
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
    label:SetText(rRadio.config.Lang["SelectKey"] or "Select Key")
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

function rRadio.cl.settingsUI.addGeneralOptions(scrollPanel)
    createSectionHeader(scrollPanel, rRadio.config.Lang["GeneralOptions"] or "General Options", false)
    local options = {
        {
            label = rRadio.config.Lang["ShowCarMessages"] or "Show Car Radio Animation",
            convar = "rammel_rradio_vehicle_animation"
        },
        {
            label = rRadio.config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD",
            convar = "rammel_rradio_boombox_hud"
        },
        {
            label = rRadio.config.Lang["BasicBoomboxHUD"] or "Basic Boombox HUD",
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
    createSectionHeader(scrollPanel, rRadio.config.Lang["SuperadminSettings"] or "Superadmin Settings", false)
    local permanentCheckbox = vgui.Create("rRadioCheckbox", scrollPanel)
    permanentCheckbox:Setup(rRadio.config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent", nil, currentEntity:GetNWBool("IsPermanent", false), function(self, value)
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
    local footerHeight = Scale(60)
    local footer = vgui.Create("DPanel", settingsFrame)
    footer:SetSize(settingsFrame:GetWide(), footerHeight)
    footer:SetPos(0, settingsFrame:GetTall() - footerHeight)
    footer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        local gap = Scale(8)
        draw.SimpleText("rRadio by Rammel", "Default", w - Scale(10), h / 2 - gap, rRadio.config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("v" .. rRadio.config.RadioVersion, "Default", w - Scale(10), h / 2 + gap, rRadio.config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    rRadio.interface.MakeIconButton(footer, "hud/steam.png", "https://steamcommunity.com/id/rammel", Scale(10))
end
