rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.resize = rRadio.client.ui.menu.resize or {}

local resize = rRadio.client.ui.menu.resize
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style

local RESIZE_HANDLE_SIZE = 12
local RESIZE_HANDLE_MIN_SIZE = 10
local RESIZE_SIDE_WIDTH = 4
local RESIZE_SIDE_HEIGHT = 72
local RESIZE_GRIP_ALPHA = 200
local RESIZE_SIDE_ALPHA = 140
local hideResizeGrabbersConVar = GetConVar( "rammel_rradio_hide_resize_grabbers" )


local function shouldHideResizeGrabbers()
    return hideResizeGrabbersConVar:GetBool()
end


local function drawCornerGrip( key, width, height )
    surface.SetDrawColor( ColorAlpha( style.GetResizeGripColor(), RESIZE_GRIP_ALPHA ) )
    draw.NoTexture()
    if key == "br" then
        surface.DrawPoly( {
            { x = width, y = 0 },
            { x = width, y = height },
            { x = 0, y = height }
        } )
    elseif key == "tl" then
        surface.DrawPoly( {
            { x = 0, y = 0 },
            { x = width, y = 0 },
            { x = 0, y = height }
        } )
    elseif key == "tr" then
        surface.DrawPoly( {
            { x = 0, y = 0 },
            { x = width, y = 0 },
            { x = width, y = height }
        } )
    elseif key == "bl" then
        surface.DrawPoly( {
            { x = 0, y = 0 },
            { x = width, y = height },
            { x = 0, y = height }
        } )
    end
end


local function beginResize( frame, key, mode )
    if state.resizeState or state.dragState then return end

    local x, y = frame:GetPos()
    state.resizeState = {
        key = key,
        mode = mode,
        mouseX = gui.MouseX(),
        mouseY = gui.MouseY(),
        x = x,
        y = y,
        width = frame:GetWide(),
        height = frame:GetTall(),
        scale = style.GetMenuScale(),
        widthScale = style.GetMenuWidthScale()
    }
end


local function createResizeHandle( frame, key, cursor, mode )
    local handle = vgui.Create( "DButton", frame )
    handle:SetText( "" )
    handle:SetCursor( cursor )
    handle:SetPaintBackground( false )
    handle.Paint = function( panel, width, height )
        if shouldHideResizeGrabbers() and not ( panel:IsHovered() or state.resizeState ) then return end

        if key == "l" or key == "r" then
            draw.RoundedBox(
                4,
                0,
                0,
                width,
                height,
                ColorAlpha( style.GetResizeGripColor(), RESIZE_SIDE_ALPHA )
            )
            return
        end

        drawCornerGrip( key, width, height )
    end
    handle.OnMousePressed = function( _panel, code )
        if code ~= MOUSE_LEFT then return end

        beginResize( frame, key, mode )
    end

    return handle
end


function resize.CreateHandles( frame )
    state.resizeHandles = {
        tl = createResizeHandle( frame, "tl", "sizenwse", "uniform" ),
        tr = createResizeHandle( frame, "tr", "sizenesw", "uniform" ),
        bl = createResizeHandle( frame, "bl", "sizenesw", "uniform" ),
        br = createResizeHandle( frame, "br", "sizenwse", "uniform" ),
        l = createResizeHandle( frame, "l", "sizewe", "horizontal" ),
        r = createResizeHandle( frame, "r", "sizewe", "horizontal" )
    }
end


function resize.RelayoutHandles( frame )
    if not state.resizeHandles then return end

    local handleSize = math.max( RESIZE_HANDLE_MIN_SIZE, style.ScreenScale( RESIZE_HANDLE_SIZE ) )
    local sideWidth = math.max( RESIZE_SIDE_WIDTH, math.floor( handleSize * 0.45 ) )
    local sideHeight = math.max( handleSize * 3, style.ScreenScale( RESIZE_SIDE_HEIGHT ) )
    local width = frame:GetWide()
    local height = frame:GetTall()
    local sideY = math.floor( ( height - sideHeight ) / 2 )

    state.resizeHandles.tl:SetPos( 0, 0 )
    state.resizeHandles.tl:SetSize( handleSize, handleSize )
    state.resizeHandles.tr:SetPos( width - handleSize, 0 )
    state.resizeHandles.tr:SetSize( handleSize, handleSize )
    state.resizeHandles.bl:SetPos( 0, height - handleSize )
    state.resizeHandles.bl:SetSize( handleSize, handleSize )
    state.resizeHandles.br:SetPos( width - handleSize, height - handleSize )
    state.resizeHandles.br:SetSize( handleSize, handleSize )
    state.resizeHandles.l:SetPos( 0, sideY )
    state.resizeHandles.l:SetSize( sideWidth, sideHeight )
    state.resizeHandles.r:SetPos( width - sideWidth, sideY )
    state.resizeHandles.r:SetSize( sideWidth, sideHeight )
end


function resize.Update( frame, callbacks )
    local resizeState = state.resizeState
    if not resizeState then return end

    if not input.IsMouseDown( MOUSE_LEFT ) then
        style.SetMenuScale( style.GetMenuScale(), true )
        style.SetMenuWidthScale( style.GetMenuWidthScale(), true )
        state.resizeState = nil
        callbacks.rememberPosition( frame, true )
        callbacks.refresh()
        return
    end

    local dx = gui.MouseX() - resizeState.mouseX
    local dy = gui.MouseY() - resizeState.mouseY
    if resizeState.mode == "horizontal" then
        local width = resizeState.key == "l" and resizeState.width - dx or resizeState.width + dx
        local baseWidth = resizeState.width / resizeState.widthScale
        style.SetMenuWidthScale( width / baseWidth, false )
    else
        local movingLeft = string.find( resizeState.key, "l", 1, true )
        local movingTop = string.find( resizeState.key, "t", 1, true )
        local width = resizeState.width + ( movingLeft and -dx or dx )
        local height = resizeState.height + ( movingTop and -dy or dy )
        local baseWidth = resizeState.width / resizeState.scale
        local baseHeight = resizeState.height / resizeState.scale
        style.SetMenuScale( ( width / baseWidth + height / baseHeight ) * 0.5, false )
    end

    callbacks.relayout()

    local newX = resizeState.x
    local newY = resizeState.y
    if string.find( resizeState.key, "l", 1, true ) then
        newX = resizeState.x + resizeState.width - frame:GetWide()
    end
    if string.find( resizeState.key, "t", 1, true ) then
        newY = resizeState.y + resizeState.height - frame:GetTall()
    end

    callbacks.setPosition( frame, newX, newY )
end


return resize
