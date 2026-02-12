rRadio.tools = rRadio.tools or {}
local REPORT_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741"
local GENERAL_CHECKBOXES = {
    {
        label = "Enable rRadio",
        convar = "rammel_rradio_enabled",
        help = "Toggle the rRadio addon globally on or off."
    },
    {
        label = "Vehicle Animation",
        convar = "rammel_rradio_vehicle_animation",
        help = "Play an animation when you enter a vehicle."
    },
    {
        label = "Boombox HUD",
        convar = "rammel_rradio_boombox_hud",
        help = "Display a HUD overlay on boomboxes when nearby."
    },
    {
        label = "Basic Boombox HUD",
        convar = "rammel_rradio_basic_hud",
        help = "Simpler HUD without animations."
    }
}

local function createGeneralForm( panel )
    local form = vgui.Create( "DForm", panel )
    form:SetName( "General Settings" )
    form:Dock( TOP )
    form:DockMargin( 0, 10, 0, 10 )
    for _, opt in ipairs( GENERAL_CHECKBOXES ) do
        form:CheckBox( opt.label, opt.convar )
        form:Help( opt.help )
    end

    form:NumSlider(
        rRadio.L( "MaxVolumeCap", "Global Volume Cap" ),
        "rammel_rradio_max_volume",
        0, 1, 2
    )
    form:Help(
        rRadio.L(
            "MaxVolumeCapHelp",
            "Maximum global radio volume (0.0 - 1.0)."
        )
    )
end

local function createMenuForm( panel )
    local menuForm = vgui.Create( "DForm", panel )
    menuForm:SetName( "Menu Settings" )
    menuForm:Dock( TOP )
    menuForm:DockMargin( 0, 0, 0, 10 )
    local keyRow = vgui.Create( "DPanel" )
    keyRow.Paint = function() end
    keyRow:Dock( TOP )
    keyRow:DockMargin( 0, 0, 0, 10 )
    keyRow:SetTall( 24 )
    local keyLabel = vgui.Create( "DLabel", keyRow )
    keyLabel:Dock( LEFT )
    keyLabel:SetText( "Menu Key" )
    keyLabel:SizeToContents()
    keyLabel:DockMargin( 0, 4, 8, 0 )
    keyLabel:SetTextColor( Color( 0, 0, 0, 255 ) )
    local keyBinder = vgui.Create( "DBinder", keyRow )
    keyBinder:Dock( RIGHT )
    keyBinder:DockMargin( 0, 2, 0, 0 )
    keyBinder:SetWide( 180 )
    keyBinder:SetConVar( "rammel_rradio_menu_key" )
    keyBinder:SetValue( GetConVar( "rammel_rradio_menu_key" ):GetInt() )
    keyBinder:SetText( rRadio.GetKeyName( keyBinder:GetValue() ) )
    function keyBinder:OnChange( newCode )
        if rRadio.RejectBlockedMenuKey( self ) then
            self:SetText( rRadio.GetKeyName( self:GetValue() ) )
            return
        end

        DBinder.OnChange( self, newCode )
        self:SetText( rRadio.GetKeyName( newCode ) )
    end

    menuForm:AddItem( keyRow )
    local theme = menuForm:ComboBox( "Menu Theme", "rammel_rradio_menu_theme" )
    for name, data in pairs( rRadio.themes ) do
        if not data.Hidden then theme:AddChoice( name, name ) end
    end

    theme.OnSelect = function( _, _, _, choice )
        RunConsoleCommand( "rammel_rradio_menu_theme", choice )
        rRadio.interface.applyTheme( choice )
    end

    local preview = vgui.Create( "DPanel" )
    preview:SetTall( 150 )
    preview:Dock( TOP )
    preview:DockMargin( 0, 0, 0, 10 )
    menuForm:AddItem( preview )
    preview.Paint = function( _self, w, h )
        local ui = rRadio.config.UI
        surface.SetDrawColor( ui.BackgroundColor.r, ui.BackgroundColor.g, ui.BackgroundColor.b, ui.BackgroundColor.a )
        surface.DrawRect( 0, 0, w, h )
        local headerColor = ui.HeaderColor or ui.BackgroundColor
        surface.SetDrawColor( headerColor.r, headerColor.g, headerColor.b, headerColor.a )
        surface.DrawRect( 0, 0, w, 30 )
        draw.SimpleText(
            "rRadio Preview", "rRadio.Roboto24",
            w / 2, 15, ui.TextColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        surface.SetDrawColor( ui.ButtonColor.r, ui.ButtonColor.g, ui.ButtonColor.b, ui.ButtonColor.a )
        surface.DrawRect( 10, 40, w - 20, 25 )
        draw.SimpleText(
            "Sample Button", "rRadio.Roboto24",
            w / 2, 52, ui.TextColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        surface.SetDrawColor( ui.Highlight.r, ui.Highlight.g, ui.Highlight.b, ui.Highlight.a )
        surface.DrawRect( 0, h - 6, w, 6 )
    end
end

cvars.AddChangeCallback( "rammel_rradio_menu_theme", function( _, _old, new )
    local theme = rRadio.themes[new] and new or "dark"
    if theme ~= new then RunConsoleCommand( "rammel_rradio_menu_theme", theme ) end
    rRadio.interface.applyTheme( theme )
end, "rRadioThemeCallback" )

hook.Add( "PopulateToolMenu", "rRadio.ToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "Rammel", "rRadio", "rRadio", "", "", function( panel )
        panel:ClearControls()
        panel:Help( "Have an issue? Report it on the Steam Workshop page." )
        local reportBtn = vgui.Create( "DButton", panel )
        reportBtn:Dock( TOP )
        reportBtn:DockMargin( 10, 10, 10, 10 )
        reportBtn:SetText( "Report Issue" )
        function reportBtn:DoClick()
            gui.OpenURL( REPORT_URL )
        end

        createGeneralForm( panel )
        panel:Help( "" )
        createMenuForm( panel )
    end )
end )
