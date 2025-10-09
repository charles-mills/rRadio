local Radio, Interface, Config = rRadio:Import("Radio", "!interface", "config", "!tools")

local surface, draw = surface, draw
local TAC = TEXT_ALIGN_CENTER

cvars.AddChangeCallback("rammel_rradio_menu_theme", function(_, _, new)
    local chosen = Radio.themes[new] and new or "dark"
    if chosen ~= new then RunConsoleCommand("rammel_rradio_menu_theme", chosen) end
    Interface.applyTheme(chosen)
end, "rRadioThemeCallback")

local function createReportButton(parent)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(TOP)
    btn:DockMargin(10, 10, 10, 10)
    btn:SetText("Report Issue")
    function btn:DoClick()
        gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741")
    end
end

local function buildGeneralForm(parent)
    local form = vgui.Create("DForm", parent)
    form:SetName("General Settings")
    form:Dock(TOP)
    form:DockMargin(0, 10, 0, 10)
    form:CheckBox("Enable rRadio", "rammel_rradio_enabled")
    form:Help("Toggle the rRadio addon globally on or off.")
    form:CheckBox("Vehicle Animation", "rammel_rradio_vehicle_animation")
    form:Help("Play an animation when you enter a vehicle.")
    form:CheckBox("Boombox HUD", "rammel_rradio_boombox_hud")
    form:Help("Display a HUD overlay on boomboxes when nearby.")
    form:CheckBox("Basic Boombox HUD", "rammel_rradio_basic_hud")
    form:Help("Simpler HUD without animations.")
    form:NumSlider("Global Volume Cap", "rammel_rradio_max_volume", 0, 1, 2)
    form:Help("Maximum global radio volume (0.0 – 1.0).")
    return form
end

local function createKeyRow()
    local row = vgui.Create("DPanel")
    row:SetTall(24)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 10)
    row.Paint = nil

    local lbl = vgui.Create("DLabel", row)
    lbl:Dock(LEFT)
    lbl:DockMargin(0, 4, 8, 0)
    lbl:SetText("Menu Key")
    lbl:SizeToContents()

    local binder = vgui.Create("DBinder", row)
    binder:Dock(RIGHT)
    binder:DockMargin(0, 2, 0, 0)
    binder:SetWide(180)
    binder:SetConVar("rammel_rradio_menu_key")
    local cv = GetConVar("rammel_rradio_menu_key")
    if cv then
        binder:SetValue(cv:GetInt())
        binder:SetText(Radio.cl.getKeyName(binder:GetValue()))
    end
    function binder:OnChange(code)
        DBinder.OnChange(self, code)
        self:SetText(Radio.cl.getKeyName(code))
    end

    return row
end

local function buildThemeDropdown(parentForm)
    local dd = parentForm:ComboBox("Menu Theme", "rammel_rradio_menu_theme")
    local choices = {}
    for name, data in pairs(Radio.themes) do
        if not data.Hidden then choices[#choices + 1] = name end
    end
    table.sort(choices, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(choices) do
        dd:AddChoice(name, name)
    end
    function dd:OnSelect(_, _, value)
        RunConsoleCommand("rammel_rradio_menu_theme", value)
        Interface.applyTheme(value)
    end
    return dd
end

local function createPreviewPanel()
    local pnl = vgui.Create("DPanel")
    pnl:SetTall(150)
    pnl:Dock(TOP)
    pnl:DockMargin(0, 0, 0, 10)
    function pnl:Paint(w, h)
        local ui = Config.UI
        local bg = ui.BackgroundColor
        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
        surface.DrawRect(0, 0, w, h)

        local header = ui.HeaderColor or bg
        surface.SetDrawColor(header.r, header.g, header.b, header.a)
        surface.DrawRect(0, 0, w, 30)

        draw.SimpleText("rRadio Preview", "rRadio.Roboto24", w * 0.5, 15, ui.TextColor, TAC, TAC)

        local btn = ui.ButtonColor
        surface.SetDrawColor(btn.r, btn.g, btn.b, btn.a)
        surface.DrawRect(10, 40, w - 20, 25)
        draw.SimpleText("Sample Button", "rRadio.Roboto24", w * 0.5, 52, ui.TextColor, TAC, TAC)

        local hl = ui.Highlight
        surface.SetDrawColor(hl.r, hl.g, hl.b, hl.a)
        surface.DrawRect(0, h - 6, w, 6)
    end
    return pnl
end

local function buildMenuForm(parent)
    local form = vgui.Create("DForm", parent)
    form:SetName("Menu Settings")
    form:Dock(TOP)
    form:DockMargin(0, 0, 0, 10)
    form:AddItem(createKeyRow())
    buildThemeDropdown(form)
    form:AddItem(createPreviewPanel())
    return form
end

hook.Add("PopulateToolMenu", "rRadio.ToolMenu", function()
    spawnmenu.AddToolMenuOption("Options", "Rammel", "rRadio", "rRadio", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Have an issue? Report it on the Steam Workshop page.")
        createReportButton(panel)
        buildGeneralForm(panel)
        panel:Help("")
        buildMenuForm(panel)
    end)
end)
