rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.vehicleHint = rRadio.client.ui.vehicleHint or {}

local vehicleHint = rRadio.client.ui.vehicleHint
local style = rRadio.client.ui.style

local PHASE_IN = "in"
local PHASE_HOLD = "hold"
local PHASE_OUT = "out"

local FONT = "rRadio.Inter5"
local TWO_PI = math.pi * 2
local DIVIDER_TOP = 0.30
local DIVIDER_BOTTOM = 0.70
local DIVIDER_ALPHA_PEAK = 50
local OFFSCREEN_GAP = 8

local DEFAULTS = {
    CooldownSeconds = 5,
    ShowSeconds = 2,
    AnimationSeconds = 1.0,
    AnchorY = 0.20,
    Width = 300,
    Height = 70,
    KeyWidth = 40,
    KeyHeight = 30,
    KeyMarginLeft = 20,
    DividerGap = 7,
    MessageGap = 15,
    PanelRadius = 12,
    KeycapRadius = 6,
    PulseHz = 1.5,
    PulseAmplitude = 0.05,
    HoverBrightness = 1.2
}

local activePanel
local lastShownAt = -math.huge
local initialized = false
local enabledConVar = GetConVar( "rammel_rradio_enabled" )
local vehicleAnimationConVar = GetConVar( "rammel_rradio_vehicle_animation" )
local menuKeyConVar = GetConVar( "rammel_rradio_menu_key" )


local function configValue( key )
    local value = tonumber( rRadio.config.VehicleHint[key] )
    if value then return value end

    return DEFAULTS[key]
end


local function getKeyName()
    local keyCode = menuKeyConVar:GetInt()
    local keyName = input.GetKeyName( keyCode )
    if not keyName or keyName == "" then return rRadio.L( "PressAKey", "Press a key..." ) end

    return ( keyName:gsub( "_", " " ):gsub( "(%a)([%w]*)", function( first, rest )
        return first:upper() .. rest:lower()
    end ) )
end


local function measureLayout( message )
    local screenWidth = ScrW()
    local screenHeight = ScrH()
    local panelWidth = math.floor( style.Scale( configValue( "Width" ) ) )
    local panelHeight = math.floor( style.Scale( configValue( "Height" ) ) )
    local keyWidth = math.floor( style.Scale( configValue( "KeyWidth" ) ) )
    local keyHeight = math.floor( style.Scale( configValue( "KeyHeight" ) ) )
    local keyX = math.floor( style.Scale( configValue( "KeyMarginLeft" ) ) )
    local dividerOffset = math.floor( style.Scale( configValue( "DividerGap" ) ) )
    local messageOffset = math.floor( style.Scale( configValue( "MessageGap" ) ) )
    local visibleX = math.max( 0, screenWidth - panelWidth )
    local hiddenX = screenWidth + math.floor( style.Scale( OFFSCREEN_GAP ) )
    local anchorY = math.Clamp( configValue( "AnchorY" ), 0, 1 )
    local panelY = math.floor( screenHeight * anchorY )

    local messageX = keyX + keyWidth + messageOffset
    local rightInset = math.floor( style.Scale( 8 ) )
    local textMaxWidth = math.max( style.Scale( 40 ), panelWidth - messageX - rightInset )
    local displayMessage = style.TruncateText( message, FONT, textMaxWidth )

    return {
        screenWidth = screenWidth,
        screenHeight = screenHeight,
        panelWidth = panelWidth,
        panelHeight = panelHeight,
        panelY = panelY,
        visibleX = visibleX,
        hiddenX = hiddenX,
        keyX = keyX,
        keyY = math.floor( ( panelHeight - keyHeight ) * 0.5 ),
        keyWidth = keyWidth,
        keyHeight = keyHeight,
        dividerX = keyX + keyWidth + dividerOffset,
        messageX = messageX,
        message = displayMessage
    }
end


local function evaluateAnimation( panel, now )
    local layout = panel.layout
    local animDuration = math.max( 0.01, configValue( "AnimationSeconds" ) )
    local showDuration = math.max( 0, configValue( "ShowSeconds" ) )

    -- Advance the state machine first so the rendering math below has a single phase to dispatch on.
    if panel.phase ~= PHASE_OUT then
        local elapsed = now - panel.startedAt
        if elapsed < animDuration then
            panel.phase = PHASE_IN
        elseif elapsed < animDuration + showDuration then
            panel.phase = PHASE_HOLD
        else
            panel.phase = PHASE_OUT
            panel.outStartedAt = now
            panel.outFromX = layout.visibleX
            panel.outFromAlpha = 1
        end
    end

    if panel.phase == PHASE_IN then
        local progress = math.Clamp( ( now - panel.startedAt ) / animDuration, 0, 1 )
        panel.currentProgress = progress
        panel.currentX = Lerp( math.ease.OutQuint( progress ), layout.hiddenX, layout.visibleX )
        panel.currentAlpha = math.ease.InOutQuad( progress )
    elseif panel.phase == PHASE_HOLD then
        panel.currentProgress = 1
        panel.currentX = layout.visibleX
        panel.currentAlpha = 1
    else
        local progress = math.Clamp( ( now - panel.outStartedAt ) / animDuration, 0, 1 )
        panel.currentProgress = progress
        panel.currentX = Lerp( math.ease.InOutQuint( progress ), panel.outFromX, layout.hiddenX )
        panel.currentAlpha = panel.outFromAlpha * ( 1 - math.ease.InOutQuad( progress ) )
    end
end


local function startOutPhase( panel, now )
    if panel.phase == PHASE_OUT then return end

    panel.phase = PHASE_OUT
    panel.outStartedAt = now
    panel.outFromX = panel.currentX or panel.layout.visibleX
    panel.outFromAlpha = panel.currentAlpha or 1
end


local function buildBackgroundColor( baseColor, hoverActive, alphaByte )
    local brightness = hoverActive and configValue( "HoverBrightness" ) or 1
    return Color(
        math.min( math.floor( baseColor.r * brightness ), 255 ),
        math.min( math.floor( baseColor.g * brightness ), 255 ),
        math.min( math.floor( baseColor.b * brightness ), 255 ),
        alphaByte
    )
end


local function openMenuForEntity( entity )
    if not IsValid( entity ) then return end

    local state = rRadio.client.ui.state
    state.currentEntity = entity
    rRadio.client.ui.menu.controller.Open()
end


local function configurePanel( panel, entity, isDriver )
    panel.entity = entity
    panel.isDriver = isDriver == true
    panel.keyName = getKeyName()
    panel.layout = measureLayout( rRadio.L( "ToOpenRadio", "to open the radio menu" ) )
    panel:SetSize( panel.layout.panelWidth, panel.layout.panelHeight )
    panel:SetPos( panel.layout.hiddenX, panel.layout.panelY )

    if not panel.currentX then panel.currentX = panel.layout.hiddenX end
end


local function paintPanel( panel, width, height )
    local layout = panel.layout
    if not layout then return end

    local alpha = math.Clamp( panel.currentAlpha or 0, 0, 1 )
    local alphaByte = math.floor( alpha * 255 + 0.5 )
    if alphaByte <= 0 then return end

    local colors = rRadio.config.UI
    local panelRadius = math.max( 0, math.floor( style.Scale( configValue( "PanelRadius" ) ) ) )
    local keycapRadius = math.max( 0, math.floor( style.Scale( configValue( "KeycapRadius" ) ) ) )

    -- Background: top-left + bottom-left rounded only, hover-brightened (matches v1 flush-right look).
    local background = buildBackgroundColor( colors.HeaderColor, panel:IsHovered(), alphaByte )
    draw.RoundedBoxEx( panelRadius, 0, 0, width, height, background, true, false, true, false )

    -- Keycap rectangle pulses around its centre while the glyph stays stationary (matches v1 feel).
    local pulseScale = 1 + math.sin( panel.pulse * TWO_PI ) * configValue( "PulseAmplitude" )
    local pulsedW = layout.keyWidth * pulseScale
    local pulsedH = layout.keyHeight * pulseScale
    local pulsedX = layout.keyX - ( pulsedW - layout.keyWidth ) * 0.5
    local pulsedY = layout.keyY - ( pulsedH - layout.keyHeight ) * 0.5
    draw.RoundedBox(
        keycapRadius,
        pulsedX,
        pulsedY,
        pulsedW,
        pulsedH,
        ColorAlpha( colors.ButtonColor, alphaByte )
    )

    draw.SimpleText(
        panel.keyName,
        FONT,
        layout.keyX + layout.keyWidth * 0.5,
        height * 0.5,
        ColorAlpha( colors.TextColor, alphaByte ),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )

    surface.SetDrawColor( ColorAlpha( colors.TextColor, math.floor( alpha * DIVIDER_ALPHA_PEAK ) ) )
    surface.DrawLine(
        layout.dividerX,
        math.floor( height * DIVIDER_TOP ),
        layout.dividerX,
        math.floor( height * DIVIDER_BOTTOM )
    )

    draw.SimpleText(
        layout.message,
        FONT,
        layout.messageX,
        height * 0.5,
        ColorAlpha( colors.TextColor, alphaByte ),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
end


local function thinkPanel( panel )
    local layout = panel.layout
    if not layout then return end

    if ScrW() ~= layout.screenWidth or ScrH() ~= layout.screenHeight then
        configurePanel( panel, panel.entity, panel.isDriver )
        layout = panel.layout
    end

    panel.pulse = ( panel.pulse + FrameTime() * configValue( "PulseHz" ) ) % 1

    evaluateAnimation( panel, CurTime() )
    panel:SetPos( math.floor( panel.currentX ), layout.panelY )

    if panel.phase == PHASE_OUT and panel.currentProgress >= 1 then panel:Remove() end
end


local function clickPanel( panel )
    if panel.phase == PHASE_OUT then return end

    style.PlaySound( "ButtonPressMain" )
    openMenuForEntity( panel.entity )
    startOutPhase( panel, CurTime() )
end


local function createPanel()
    local panel = vgui.Create( "DButton" )
    panel:SetText( "" )
    panel:SetCursor( "hand" )
    panel:SetMouseInputEnabled( true )
    panel:SetKeyboardInputEnabled( false )
    panel:MoveToFront()

    panel.startedAt = CurTime()
    panel.phase = PHASE_IN
    panel.pulse = 0
    panel.currentAlpha = 0
    panel.currentX = nil

    panel.Think = thinkPanel
    panel.Paint = paintPanel
    panel.DoClick = clickPanel
    panel.OnRemove = function( self )
        if activePanel == self then activePanel = nil end
    end

    return panel
end


local function shouldShow()
    if not enabledConVar:GetBool() then return false end
    if not vehicleAnimationConVar:GetBool() then return false end

    local cooldown = math.max( 0, configValue( "CooldownSeconds" ) )
    return CurTime() - lastShownAt >= cooldown
end


function vehicleHint.Show( entity, isDriver )
    if not IsValid( entity ) then return false end
    if not shouldShow() then return false end

    if IsValid( activePanel ) then activePanel:Remove() end

    style.RefreshFonts()
    activePanel = createPanel()
    configurePanel( activePanel, entity, isDriver )
    lastShownAt = CurTime()

    return true
end


function vehicleHint.Dismiss()
    if not IsValid( activePanel ) then return false end
    if activePanel.phase == PHASE_OUT then return true end

    startOutPhase( activePanel, CurTime() )
    return true
end


function vehicleHint.IsVisible()
    return IsValid( activePanel )
end


function vehicleHint.Init()
    if initialized then return end
    initialized = true

    hook.Add( "rRadio_LanguageChanged", "rRadio_VehicleHint_RefreshLanguage", function()
        if not IsValid( activePanel ) then return end

        configurePanel( activePanel, activePanel.entity, activePanel.isDriver )
    end )

    hook.Add( "rRadio_ThemeChanged", "rRadio_VehicleHint_RefreshTheme", function()
        if IsValid( activePanel ) then activePanel:InvalidateLayout() end
    end )

    cvars.AddChangeCallback( "rammel_rradio_enabled", function( _name, _oldValue, newValue )
        if tonumber( newValue ) == 0 then vehicleHint.Dismiss() end
    end, "rRadio_VehicleHint_DismissWhenDisabled" )

    cvars.AddChangeCallback( "rammel_rradio_vehicle_animation", function( _name, _oldValue, newValue )
        if tonumber( newValue ) == 0 then vehicleHint.Dismiss() end
    end, "rRadio_VehicleHint_DismissWhenAnimationDisabled" )

    cvars.AddChangeCallback( "rammel_rradio_menu_key", function()
        if not IsValid( activePanel ) then return end

        configurePanel( activePanel, activePanel.entity, activePanel.isDriver )
    end, "rRadio_VehicleHint_RefreshKey" )
end


return vehicleHint
