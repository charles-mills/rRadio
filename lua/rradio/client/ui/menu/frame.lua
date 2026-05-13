rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.frame = rRadio.client.ui.menu.frame or {}

local frameModule = rRadio.client.ui.menu.frame
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local keyboard = rRadio.client.ui.menu.keyboard
local list = rRadio.client.ui.menu.list
local viewModel = rRadio.client.ui.menu.viewModel

local HEADER_HEIGHT = 40
local HEADER_TITLE_RIGHT_PADDING = 86
local POSITION_COOKIE_X = "rradio_menu_position_x"
local POSITION_COOKIE_Y = "rradio_menu_position_y"
local CURSOR_PLACEMENT_HOOK = "rRadio_Menu_PlaceInitialCursor"
local moveCursorConVar = GetConVar( "rammel_rradio_menu_move_cursor" )


function frameModule.SetSearchVisible( visible )
    if IsValid( state.searchShell ) then state.searchShell:SetVisible( visible ) end
    if IsValid( state.searchBox ) then state.searchBox:SetVisible( visible ) end
    if IsValid( state.globalButton ) then state.globalButton:SetVisible( visible ) end
end


function frameModule.SetListVisible( visible )
    if IsValid( state.stationListContainer ) then state.stationListContainer:SetVisible( visible ) end
    if IsValid( state.stationListPanel ) then state.stationListPanel:SetVisible( visible ) end
end


function frameModule.SetFooterVisible( visible )
    if IsValid( state.stopButton ) then state.stopButton:SetVisible( visible ) end
    if IsValid( state.volumePanel ) then state.volumePanel:SetVisible( visible ) end
end


function frameModule.RefreshSettingsToggleButton()
    if not IsValid( state.settingsButton ) then return end

    state.settingsButton:SetIcon( style.Materials.settings )
end


function frameModule.RefreshBackButton()
    if not IsValid( state.backButton ) then return end

    local enabled = viewModel.CanNavigateBack()
    state.backButton:SetVisible( enabled )
    state.backButton:SetEnabled( enabled )
end


local function normalizeCoordinate( value )
    value = tonumber( value )
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end

    if value < 0 then return math.ceil( value - 0.5 ) end

    return math.floor( value + 0.5 )
end


local function clearPersistedPosition()
    cookie.Delete( POSITION_COOKIE_X )
    cookie.Delete( POSITION_COOKIE_Y )
end


local function persistPosition( position )
    cookie.Set( POSITION_COOKIE_X, tostring( position.x ) )
    cookie.Set( POSITION_COOKIE_Y, tostring( position.y ) )
end


local function readCookieCoordinate( cookieName )
    local value = cookie.GetString( cookieName, "" )
    if value == "" then return nil, false end

    return normalizeCoordinate( value ), true
end


local function loadPersistedPosition()
    local x, hasX = readCookieCoordinate( POSITION_COOKIE_X )
    local y, hasY = readCookieCoordinate( POSITION_COOKIE_Y )
    if not hasX and not hasY then return nil end

    if not x or not y then
        clearPersistedPosition()
        return nil
    end

    return {
        x = x,
        y = y
    }
end


local function getMemoryPosition()
    local position = state.menuPosition
    if type( position ) ~= "table" then return nil end

    local x = normalizeCoordinate( position.x )
    local y = normalizeCoordinate( position.y )
    if not x or not y then
        state.menuPosition = nil
        return nil
    end

    return {
        x = x,
        y = y
    }
end


local function rememberCoordinates( x, y, persist )
    x = normalizeCoordinate( x )
    y = normalizeCoordinate( y )
    if not x or not y then return false end

    state.menuPosition = {
        x = x,
        y = y
    }

    if persist then persistPosition( state.menuPosition ) end

    return true
end


function frameModule.ClampPosition( frame, x, y )
    x = tonumber( x ) or 0
    y = tonumber( y ) or 0

    local maxX = math.max( 0, ScrW() - frame:GetWide() )
    local maxY = math.max( 0, ScrH() - frame:GetTall() )

    return math.Clamp( x, 0, maxX ), math.Clamp( y, 0, maxY )
end


function frameModule.RememberPosition( frame, persist )
    if not IsValid( frame ) then return end

    local x, y = frame:GetPos()
    rememberCoordinates( x, y, persist )
end


function frameModule.SetPosition( frame, x, y, persist )
    if not IsValid( frame ) then return nil, nil end

    x, y = frameModule.ClampPosition( frame, x, y )
    frame:SetPos( x, y )

    rememberCoordinates( x, y, persist )

    return x, y
end


function frameModule.ApplyInitialPosition( frame )
    if not IsValid( frame ) then return end

    local position = getMemoryPosition() or loadPersistedPosition()
    if position then
        local x, y = frameModule.SetPosition( frame, position.x, position.y, false )
        if x ~= position.x or y ~= position.y then persistPosition( state.menuPosition ) end

        return
    end

    frame:Center()
    frameModule.SetPosition( frame, frame:GetPos(), true )
end


local function shouldWaitForUseRelease()
    local currentEntity = state.currentEntity
    if not IsValid( currentEntity ) then return false end
    if not rRadio.util.IsBoomboxClass( currentEntity:GetClass() ) then return false end

    local player = LocalPlayer()
    if not IsValid( player ) or not player.KeyDown then return false end

    return player:KeyDown( IN_USE )
end


local function getFrameCenter( frame )
    if not IsValid( frame ) then return nil, nil end

    local frameX, frameY = frame:GetPos()
    local width = frame:GetWide()
    local height = frame:GetTall()
    if width <= 0 or height <= 0 then return nil, nil end

    return frameX + math.floor( width * 0.5 ), frameY + math.floor( height * 0.5 )
end


local function getPanelCenter( frame, panel )
    if not IsValid( panel ) or not panel:IsVisible() then return nil, nil end

    local width = panel:GetWide()
    local height = panel:GetTall()
    if width <= 0 or height <= 0 then return nil, nil end

    local frameX, frameY = frame:GetPos()
    local panelX, panelY = panel:GetPos()
    local x = frameX + panelX + math.floor( width * 0.5 )
    local y = frameY + panelY + math.floor( height * 0.5 )

    return x, y
end


local function shouldMoveCursorOnOpen()
    return moveCursorConVar:GetBool()
end


function frameModule.PlaceInitialCursor( frame )
    if not IsValid( frame ) then return end
    if not shouldMoveCursorOnOpen() then return end

    local x, y = getPanelCenter( frame, state.searchShell )
    if not x or not y then x, y = getFrameCenter( frame ) end
    if not x or not y then return end

    input.SetCursorPos( math.floor( x + 0.5 ), math.floor( y + 0.5 ) )
end


function frameModule.QueueInitialCursorPlacement( frame )
    if not IsValid( frame ) then return end

    hook.Remove( "HUDPaint", CURSOR_PLACEMENT_HOOK )
    if not shouldMoveCursorOnOpen() then return end

    hook.Add( "HUDPaint", CURSOR_PLACEMENT_HOOK, function()
        if not IsValid( frame ) then
            hook.Remove( "HUDPaint", CURSOR_PLACEMENT_HOOK )
            return
        end
        if state.frame ~= frame then
            hook.Remove( "HUDPaint", CURSOR_PLACEMENT_HOOK )
            return
        end

        if shouldWaitForUseRelease() then return end

        frameModule.PlaceInitialCursor( frame )
        hook.Remove( "HUDPaint", CURSOR_PLACEMENT_HOOK )
    end )
end


local function beginHeaderDrag( frame, dragPanel )
    if state.dragState or state.resizeState then return end

    local x, y = frame:GetPos()
    state.dragState = {
        frame = frame,
        panel = dragPanel,
        mouseX = gui.MouseX(),
        mouseY = gui.MouseY(),
        x = x,
        y = y
    }

    dragPanel:MouseCapture( true )
end


local function finishHeaderDrag()
    local dragState = state.dragState
    if not dragState then return end

    if IsValid( dragState.panel ) then dragState.panel:MouseCapture( false ) end
    if IsValid( dragState.frame ) then frameModule.RememberPosition( dragState.frame, true ) end

    state.dragState = nil
end


local function updateHeaderDrag( frame )
    local dragState = state.dragState
    if not dragState or dragState.frame ~= frame then return end

    if not input.IsMouseDown( MOUSE_LEFT ) then
        finishHeaderDrag()
        return
    end

    local x = dragState.x + gui.MouseX() - dragState.mouseX
    local y = dragState.y + gui.MouseY() - dragState.mouseY
    frameModule.SetPosition( frame, x, y )
end


local function createHeaderPanel( frame )
    state.headerPanel = vgui.Create( "DPanel", frame )
    state.headerPanel:SetMouseInputEnabled( true )
    state.headerPanel:SetCursor( "sizeall" )
    state.headerPanel.Paint = function( _panel, width, height )
        draw.RoundedBoxEx(
            8,
            0,
            0,
            width,
            height,
            rRadio.config.UI.HeaderColor,
            true,
            true,
            false,
            false
        )

        local iconSize = style.Scale( 25 )
        local iconX = style.Scale( 10 )
        local iconY = height * 0.5 - iconSize * 0.5
        surface.SetMaterial( viewModel.GetHeaderIcon() )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        surface.DrawTexturedRect( iconX, iconY, iconSize, iconSize )

        local titleX = iconX + iconSize + style.Scale( 5 )
        local titleWidth = math.max( 0, width - titleX - style.Scale( HEADER_TITLE_RIGHT_PADDING ) )
        local title = style.TruncateText( viewModel.GetHeaderText(), "rRadio.Inter8", titleWidth )
        draw.SimpleText(
            title,
            "rRadio.Inter8",
            titleX,
            height * 0.5 + style.Scale( 2 ),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end
    state.headerPanel.OnMousePressed = function( panel, code )
        if code ~= MOUSE_LEFT then return end

        beginHeaderDrag( frame, panel )
    end
    state.headerPanel.OnMouseReleased = function()
        finishHeaderDrag()
    end
end


function frameModule.RelayoutHeader( width )
    if not IsValid( state.headerPanel ) then return end

    state.headerPanel:SetPos( 0, 0 )
    state.headerPanel:SetSize( width, style.Scale( HEADER_HEIGHT ) )
end


local function createSearchControls( frame, callbacks )
    state.searchShell = vgui.Create( "DPanel", frame )
    state.searchShell.Paint = function( _panel, width, height )
        style.DrawSurface( "control", 8, 0, 0, width, height, rRadio.config.UI.SearchBoxColor )
    end

    state.searchBox = vgui.Create( "DTextEntry", state.searchShell )
    state.searchBox:Dock( FILL )
    state.searchBox:DockMargin( style.Scale( 12 ), 0, style.Scale( 6 ), 0 )
    state.searchBox:SetFont( "rRadio.Inter5" )
    state.searchBox:SetPlaceholderText( rRadio.L( "SearchPlaceholder", "Search..." ) )
    state.searchBox:SetPaintBackground( false )
    state.searchBox:SetDrawBorder( false )
    state.searchBox:SetTextColor( rRadio.config.UI.TextColor )
    state.searchBox:SetCursorColor( rRadio.config.UI.TextColor )
    state.searchBox:SetHighlightColor( Color( 120, 120, 120 ) )
    state.searchBox:SetPlaceholderColor( ColorAlpha( rRadio.config.UI.TextColor, 150 ) )
    state.searchBox.OnChange = callbacks.queueSearchRefresh

    state.globalButton = vgui.Create( "DButton", frame )
    state.globalButton:SetText( rRadio.L( "Global", "GLOBAL" ) )
    state.globalButton:SetFont( "rRadio.Inter5" )
    state.globalButton:SetTextColor( rRadio.config.UI.TextColor )
    state.globalButton.lerp = 0
    state.globalButton.lerpColor = Color( 0, 0, 0, 255 )
    state.globalButton.Think = function( panel )
        local target = ( panel:IsHovered() or state.viewMode == viewModel.Views.GLOBAL ) and 1 or 0
        panel.lerp = style.ApproachLerp( panel.lerp, target, 10 )
    end
    state.globalButton.Paint = function( panel, width, height )
        local color = style.LerpColor(
            panel.lerp,
            rRadio.config.UI.ButtonColor,
            rRadio.config.UI.ButtonHoverColor,
            panel.lerpColor
        )
        style.DrawSurface( "button", 8, 0, 0, width, height, color )
    end
    state.globalButton.DoClick = callbacks.toggleGlobal
end


local function createNavigationButtons( frame, callbacks )
    state.closeButton = vgui.Create( "rRadioMenuNavButton", frame )
    state.closeButton:SetIcon( style.Materials.close )
    state.closeButton:SetCallback( callbacks.close )

    state.settingsButton = vgui.Create( "rRadioMenuNavButton", frame )
    state.settingsButton:SetIcon( style.Materials.settings )
    state.settingsButton:SetCallback( callbacks.toggleSettings )

    state.backButton = vgui.Create( "rRadioMenuNavButton", frame )
    state.backButton:SetIcon( style.Materials.returnIcon )
    state.backButton:SetCallback( callbacks.goBack )
end


local function createStationList( frame )
    state.stationListContainer = vgui.Create( "DPanel", frame )
    state.stationListContainer.Paint = function( _panel, width, height )
        style.DrawSurface( "panel", 8, 0, 0, width, height, style.GetSurfaceColor( "panel" ) )
    end

    state.stationListPanel = vgui.Create( "DScrollPanel", state.stationListContainer )
    state.stationListPanel:Dock( FILL )
    state.stationListPanel:DockMargin( style.Scale( 6 ), style.Scale( 6 ), style.Scale( 6 ), style.Scale( 6 ) )
    style.StyleScrollBar( state.stationListPanel:GetVBar() )

    state.stationListPanel.Think = function( panel )
        local virtualState = panel.virtualState
        if not virtualState then return end

        local canvas = panel:GetCanvas()
        local vbar = panel:GetVBar()
        if virtualState.lastScroll == vbar:GetScroll()
            and virtualState.lastTall == panel:GetTall()
            and virtualState.lastWide == canvas:GetWide() then
            return
        end

        list.UpdateVisibleRows( panel )
    end
end


function frameModule.Create( callbacks )
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( style.GetFrameSize() )
    frameModule.ApplyInitialPosition( frame )
    frame:SetTitle( "" )
    frame:ShowCloseButton( false )
    frame:SetDraggable( false )
    frame:MakePopup()
    frame.OnClose = callbacks.onFrameClose
    frame.OnKeyCodePressed = function( _frame, keyCode )
        if keyboard.HandleKeyCode( keyCode, callbacks ) then return true end
    end
    frame.OnKeyCodeReleased = function( _frame, keyCode )
        keyboard.HandleKeyRelease( keyCode )
    end
    frame.Think = function( panel )
        keyboard.UpdateHeldKeys( callbacks )
        updateHeaderDrag( panel )
        callbacks.updateResize( panel )
    end
    frame.Paint = function( _panel, width, height )
        draw.RoundedBox( 8, 0, 0, width, height, style.GetSurfaceColor( "frame" ) )
    end

    createHeaderPanel( frame )
    createSearchControls( frame, callbacks )
    createNavigationButtons( frame, callbacks )
    createStationList( frame )

    return frame
end


return frameModule
