if SERVER then return end

local Radio = rRadio
local Utils = Radio.utils
local Interface = Radio.interface
local Config = Radio.config

Radio.cl = Radio.cl or {}
Radio.cl.settingsUI = {}

local Scale = Radio.cl.Scale
local uiState = Radio.cl.uiState
local icons = Radio.cl.icons

local function updateTextColours(panel)
    if not IsValid(panel) then return end

    if panel.SetTextColor then
        panel:SetTextColor(Config.UI.TextColor)
    end

    for _, child in ipairs(panel:GetChildren()) do
        updateTextColours(child)
    end
end

function Radio.cl.settingsUI.addThemeSelector(scrollPanel, parentFrame, backButton, selectedTheme)
    local header = vgui.Create("rRadioHeader", scrollPanel)
    header:SetTextLabel(Config.Lang["ThemeSelection"] or "Theme Selection")
    header:SetIsFirst(true)
    
    local themeChoices = {}
    if Radio.themes then
        for themeName, data in pairs(Radio.themes) do
            if not data.Hidden then
                local displayName = Config.Lang[themeName] or 
                                   themeName:gsub("^%l", string.upper)
                table.insert(themeChoices, {name = displayName, data = themeName})
            end
        end
    end
    
    local currentTheme = selectedTheme or GetConVar("rammel_rradio_menu_theme"):GetString()
    local currentThemeName = Config.Lang[currentTheme] or 
                            currentTheme:gsub("^%l", string.upper)
    
    local previousTheme
    local selectionMade = false
    local themeDropdown = vgui.Create("rRadioDropdown", scrollPanel)
    themeDropdown:SetData(
        Config.Lang["SelectTheme"] or "Select Theme",
        themeChoices,
        currentThemeName,
        function(self, _, _, themeKey)
            local key = themeKey:lower()
            if key == currentTheme then
                Interface.playSound("SettingsMenuError")
            else
                if Radio.themes and Radio.themes[key] then
                    selectionMade = true
                    RunConsoleCommand("rammel_rradio_menu_theme", key)
                    Interface.applyTheme(key)

                    if IsValid(parentFrame.stopButton) then
                        parentFrame.stopButton:SetColors(
                            Config.UI.TextColor,
                            Config.UI.CloseButtonColor,
                            Config.UI.CloseButtonHoverColor
                        )
                    end

                    local buttons = {parentFrame.closeButton, parentFrame.settingsButton, backButton}
                    for _, btn in ipairs(buttons) do
                        if IsValid(btn) then
                            btn.hoverColour = Config.UI.ButtonHoverColor
                        end
                    end

                    Radio.cl.openSettingsMenu(parentFrame, backButton, key)
                end
            end
        end,
        function(themeKey)
            local key = themeKey:lower()
            if Radio.themes and Radio.themes[key] then
                Interface.applyTheme(key)

                if IsValid(parentFrame.stopButton) then
                    parentFrame.stopButton:SetColors(
                        Config.UI.TextColor,
                        Config.UI.CloseButtonColor,
                        Config.UI.CloseButtonHoverColor
                    )
                end

                local buttons = {parentFrame.closeButton, parentFrame.settingsButton, backButton}
                for _, btn in ipairs(buttons) do
                    if IsValid(btn) then
                        btn.hoverColour = Config.UI.ButtonHoverColor
                    end
                end

                updateTextColours(parentFrame)
                if IsValid(themeDropdown.dropdown.Menu) then
                    updateTextColours(themeDropdown.dropdown.Menu)
                end
            end
        end,
        function()
            selectionMade = false
            previousTheme = GetConVar("rammel_rradio_menu_theme"):GetString()
        end,
        function()
            if not selectionMade and previousTheme then
                Interface.applyTheme(previousTheme)

                if IsValid(parentFrame.stopButton) then
                    parentFrame.stopButton:SetColors(
                        Config.UI.TextColor,
                        Config.UI.CloseButtonColor,
                        Config.UI.CloseButtonHoverColor
                    )
                end

                local buttons = {parentFrame.closeButton, parentFrame.settingsButton, backButton}
                for _, btn in ipairs(buttons) do
                    if IsValid(btn) then
                        btn.hoverColour = Config.UI.ButtonHoverColor
                    end
                end

                updateTextColours(parentFrame)
                if IsValid(themeDropdown.dropdown.Menu) then
                    updateTextColours(themeDropdown.dropdown.Menu)
                end
            end
        end
    )
    
    themeDropdown.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Config.UI.ButtonColor)
    end
end

function Radio.cl.settingsUI.addKeyBindSelector(scrollPanel)
    local header = vgui.Create("rRadioHeader", scrollPanel)
    header:SetTextLabel(Config.Lang["KeyBinds"] or "Key Binds")
    header:SetIsFirst(false)
    
    local container = vgui.Create("DPanel", scrollPanel)
    container:Dock(TOP)
    container:SetTall(Scale(50))
    container:DockMargin(0, 0, 0, Scale(5))
    container.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
    end
    
    local label = vgui.Create("DLabel", container)
    label:Dock(LEFT)
    label:DockMargin(Scale(10), 0, 0, 0)
    label:SetFont("rRadio.Roboto5")
    label:SetTextColor(Config.UI.TextColor)
    label:SetText(Config.Lang["SelectKey"] or "Select Key")
    label:SizeToContents()
    label:SetContentAlignment(4)
    
    local binder = vgui.Create("DBinder", container)
    binder:Dock(RIGHT)
    binder:DockMargin(0, Scale(5), Scale(10), Scale(5))
    binder:SetWide(Scale(150))
    binder:SetConVar("rammel_rradio_menu_key")
    local curKey = Radio.cl.cvars.menuKey:GetInt()
    binder:SetValue(curKey)
    binder:SetText("")
    binder:SetFont("rRadio.Roboto5")
    binder._waiting = false
    
    if not binder._patched then
        local _oldOnMousePressed = binder.OnMousePressed
        function binder:OnMousePressed(code)
            _oldOnMousePressed(self, code)
            self._waiting = true
            Interface.playSound("ButtonPressSecondary")
        end
        
        binder.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
            if not self._waiting then
                draw.SimpleText(Radio.cl.getKeyName(self:GetValue()), "rRadio.Roboto5", 
                    Scale(10), h/2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        
        local _oldOnChange = binder.OnChange
        function binder:OnChange(code)
            _oldOnChange(self, code)
            self._waiting = false
            Interface.playSound("SettingsMenuSuccess")
            RunConsoleCommand("rammel_rradio_menu_key", code)
            self:SetText("")
        end
        binder._patched = true
    end
end

function Radio.cl.settingsUI.addGeneralOptions(scrollPanel)
    local header = vgui.Create("rRadioHeader", scrollPanel)
    header:SetTextLabel(Config.Lang["GeneralOptions"] or "General Options")
    header:SetIsFirst(false)
    
    local options = {
        {
            label = Config.Lang["ShowCarMessages"] or "Show Car Radio Animation",
            convar = "rammel_rradio_vehicle_animation"
        },
        {
            label = Config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD",
            convar = "rammel_rradio_boombox_hud"
        },
        {
            label = Config.Lang["BasicBoomboxHUD"] or "Basic Boombox HUD",
            convar = "rammel_rradio_basic_hud"
        }
    }
    
    for _, opt in ipairs(options) do
        local cvar = GetConVar(opt.convar)
        local cb = vgui.Create("rRadioCheckbox", scrollPanel)
        cb:Setup(
            opt.label,
            opt.convar,
            cvar:GetBool(),
            function() Interface.playSound("SettingsMenuSuccess") end
        )
    end
end

function Radio.cl.settingsUI.addSuperadminOptions(scrollPanel, currentEntity)
    if not (LocalPlayer():IsSuperAdmin() and Utils.IsBoombox(currentEntity)) then 
        return 
    end
    
    local header = vgui.Create("rRadioHeader", scrollPanel)
    header:SetTextLabel(Config.Lang["SuperadminSettings"] or "Superadmin Settings")
    header:SetIsFirst(false)
    
    local permanentCheckbox = vgui.Create("rRadioCheckbox", scrollPanel)
    permanentCheckbox:Setup(
        Config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent",
        nil,
        currentEntity:GetNWBool("IsPermanent", false),
        function(self, value)
            if not IsValid(currentEntity) then
                self:SetChecked(false)
                return
            end
            
            if value then
                net.Start("rRadio.SetPersistent")
                net.WriteEntity(currentEntity)
                net.SendToServer()
            else
                net.Start("rRadio.RemovePersistent")
                net.WriteEntity(currentEntity)
                net.SendToServer()
            end
        end
    )
    
    uiState.permanentCheckboxRef = permanentCheckbox
end

function Radio.cl.settingsUI.buildFooter(settingsFrame)
    local footerHeight = Scale(60)
    local footer = vgui.Create("DPanel", settingsFrame)
    footer:SetSize(settingsFrame:GetWide(), footerHeight)
    footer:SetPos(0, settingsFrame:GetTall() - footerHeight)
    footer:SetText("")
    
    footer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
        local gap = Scale(8)
        draw.SimpleText("rRadio by Rammel", "Default", w - Scale(10), h/2 - gap,
            Config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("v" .. Config.RadioVersion, "Default", w - Scale(10), h/2 + gap,
            Config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    
    local links = {
        {icon = "hud/github.png", url = "https://github.com/charles-mills/rRadio", x = Scale(10)},
        {icon = "hud/steam.png", url = "https://steamcommunity.com/id/rammel", x = Scale(50)},
        {icon = "hud/discord.png", url = "https://discordapp.com/users/1265373956685299836", x = Scale(90)}
    }
    
    for _, link in ipairs(links) do
        Interface.MakeIconButton(footer, link.icon, link.url, link.x)
    end
end
