rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.dialogs = rRadio.client.ui.dialogs or {}

local dialogs = rRadio.client.ui.dialogs
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style

local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 190
local BUTTON_WIDTH = 118
local BUTTON_HEIGHT = 34

local function noop()
end

local function getOptionText( options, key, fallback )
    local value = options and options[key]
    if value and value ~= "" then return value end

    return fallback or ""
end

local function setActiveDialog( panel )
    state.dialog = panel

    panel.OnRemove = function( removed )
        if state.dialog == removed then state.dialog = nil end
    end
end

local function closeWithCancel( panel, onCancel )
    panel:Remove()
    style.PlaySound( "ButtonPressSecondary" )
    onCancel()
end

local function createButton( parent, text, danger, callback )
    local button = vgui.Create( "rRadioMenuAnimatedButton", parent )
    button:SetText( text )
    button:SetColors(
        rRadio.config.UI.TextColor,
        danger and ( rRadio.config.UI.CloseButtonColor or rRadio.config.UI.ButtonColor )
            or ( style.GetSurfaceColor( "control" ) or rRadio.config.UI.ButtonColor ),
        danger and ( rRadio.config.UI.CloseButtonHoverColor or rRadio.config.UI.ButtonHoverColor )
            or ( style.GetSurfaceColor( "controlHover" ) or rRadio.config.UI.ButtonHoverColor )
    )
    button.DoClick = callback

    return button
end

local function createDialogPanel( parent, root, options )
    options = options or {}
    local onConfirm = options.onConfirm or noop
    local onCancel = options.onCancel or noop

    local dialog = vgui.Create( "DPanel", parent )
    dialog.Paint = function( _panel, width, height )
        style.DrawSurface(
            "panel",
            8,
            0, 0,
            width,
            height,
            style.GetSurfaceColor( "panel" ),
            style.GetBorderColor()
        )
    end

    local title = vgui.Create( "DLabel", dialog )
    title:SetFont( "rRadio.Inter8" )
    title:SetTextColor( rRadio.config.UI.TextColor )
    title:SetText( getOptionText( options, "title", "" ) )

    local message = vgui.Create( "DLabel", dialog )
    message:SetFont( "rRadio.Inter5" )
    message:SetTextColor( ColorAlpha( rRadio.config.UI.TextColor, 175 ) )
    message:SetWrap( true )
    message:SetContentAlignment( 7 )
    message:SetText( getOptionText( options, "message", "" ) )

    local cancelButton = createButton(
        dialog,
        getOptionText( options, "cancelText", rRadio.L( "Cancel", "Cancel" ) ),
        false,
        function()
            closeWithCancel( root, onCancel )
        end
    )
    local confirmButton = createButton(
        dialog,
        getOptionText( options, "confirmText", rRadio.L( "Confirm", "Confirm" ) ),
        options.danger == true,
        function()
            root:Remove()
            onConfirm()
        end
    )

    dialog.PerformLayout = function( _panel, width, height )
        local margin = style.Scale( 18 )
        local gap = style.Scale( 8 )
        local buttonWidth = math.min(
            style.Scale( BUTTON_WIDTH ),
            ( width - margin * 2 - gap ) * 0.5
        )
        local buttonHeight = style.Scale( BUTTON_HEIGHT )

        title:SetPos( margin, margin )
        title:SetSize( width - margin * 2, style.Scale( 34 ) )

        message:SetPos( margin, margin + style.Scale( 44 ) )
        local messageHeight = height - margin * 3 - buttonHeight - style.Scale( 44 )
        message:SetSize( width - margin * 2, messageHeight )

        local buttonY = height - margin - buttonHeight
        cancelButton:SetPos( width - margin - buttonWidth * 2 - gap, buttonY )
        cancelButton:SetSize( buttonWidth, buttonHeight )
        cancelButton:SetFont( style.GetButtonFillFont( cancelButton:GetText(), buttonWidth, buttonHeight ) )

        confirmButton:SetPos( width - margin - buttonWidth, buttonY )
        confirmButton:SetSize( buttonWidth, buttonHeight )
        confirmButton:SetFont( style.GetButtonFillFont( confirmButton:GetText(), buttonWidth, buttonHeight ) )
    end

    root.OnKeyCodePressed = function( panel, keyCode )
        if keyCode ~= KEY_ESCAPE then return end

        closeWithCancel( panel, onCancel )
    end

    return dialog
end

function dialogs.Close()
    if state.dialog then state.dialog:Remove() end
    state.dialog = nil
end

function dialogs.Show( parent, options )
    if not parent then return nil end

    dialogs.Close()
    style.RefreshFonts()

    local overlay = vgui.Create( "DPanel", parent )
    overlay:SetPos( 0, 0 )
    overlay:SetSize( parent:GetSize() )
    overlay:SetMouseInputEnabled( true )
    overlay:SetKeyboardInputEnabled( true )
    overlay:MoveToFront()
    overlay:RequestFocus()
    overlay.Paint = function( _panel, width, height )
        draw.RoundedBox( 8, 0, 0, width, height, Color( 0, 0, 0, 145 ) )
    end

    local dialog = createDialogPanel( overlay, overlay, options )
    overlay.PerformLayout = function( _panel, width, height )
        local margin = style.Scale( 18 )
        local dialogWidth = math.min( style.Scale( DEFAULT_WIDTH ), width - margin * 2 )
        local dialogHeight = math.min( style.Scale( DEFAULT_HEIGHT ), height - margin * 2 )

        dialog:SetSize( dialogWidth, dialogHeight )
        dialog:SetPos( ( width - dialogWidth ) * 0.5, ( height - dialogHeight ) * 0.5 )
    end

    setActiveDialog( overlay )
    overlay:InvalidateLayout( true )
    return overlay
end

function dialogs.ShowFrame( options )
    dialogs.Close()
    style.SyncScaleFromConVars()
    style.RefreshFonts()

    local width = style.Scale( DEFAULT_WIDTH )
    local height = style.Scale( DEFAULT_HEIGHT )
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( width, height )
    frame:SetTitle( "" )
    frame:ShowCloseButton( false )
    frame:SetDraggable( false )
    frame:Center()
    frame:MakePopup()
    frame.Paint = noop

    local dialog = createDialogPanel( frame, frame, options )
    frame.PerformLayout = function( _panel, panelWidth, panelHeight )
        dialog:SetPos( 0, 0 )
        dialog:SetSize( panelWidth, panelHeight )
    end

    setActiveDialog( frame )
    frame:InvalidateLayout( true )
    return frame
end

return dialogs
