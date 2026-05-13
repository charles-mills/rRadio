rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.state = rRadio.client.hud.state or {}

local stateModule = rRadio.client.hud.state
local phases = rRadio.client.audio.manager.Phases

local HUD_OFFSET_FORWARD = 4.6
local HUD_OFFSET_UP = 14.5
local HUD_LOCAL_OFFSET = Vector( HUD_OFFSET_FORWARD, 0, HUD_OFFSET_UP )
local TEXT_SLIDE_OFFSET = 4 * ( rRadio.client.hud.DETAIL_SCALE or 2 )
local HUD_ANG_OFFSET = Angle( 0, 0, 0 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Up(), -90 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Forward(), 90 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Right(), 180 )

local MAX_FRAME_TIME = 0.1
local TUNING_SPEED = 1.5
local PHASE_TRANSITION_SPEED = 4
local EQUALIZER_RESPONSE = 10
local EQ_MIN_HEIGHT = 0.12
local EQ_MAX_HEIGHT = 0.88
local EQ_BARS = 5
local TEXT_ALPHA = 255
local ACCENT_ALPHA = 205
local DIM_ACCENT_ALPHA = 70
local EQ_FREQUENCIES = { 0.9, 1.1, 1.3, 1.5, 1.7 }
local EQ_OFFSETS = { 0, 0.2, 0.4, 0.6, 0.8 }
local DOTS = { "", ".", "..", "..." }
local SIN_SAMPLES = 1024
local DEFAULT_SHADOW = Color( 0, 0, 0, 190 )
local DEFAULT_TEXT_BORDER = Color( 0, 0, 0, 220 )

local staticTexts
local sinLookup = {}

for index = 0, SIN_SAMPLES - 1 do
    sinLookup[index] = math.sin( index * math.pi * 2 / SIN_SAMPLES )
end


local function fastSin( value )
    return sinLookup[math.floor( value * SIN_SAMPLES ) % SIN_SAMPLES]
end


local function resetStaticTexts()
    staticTexts = {
        interact = rRadio.L( "Interact", "Press E to Interact" ),
        tuning = rRadio.L( "TuningIn", "Tuning in" ),
        queued = rRadio.L( "WaitingForSignal", "Waiting for signal" ),
        error = rRadio.L( "StationFailed", "Station Failed" ),
        radio = rRadio.L( "Radio", "Radio" )
    }
end


local function getNormalizedMode( mode )
    if mode == "basic" or mode == "compact" then return "basic" end

    return "full"
end


local function readPresentation( hudState )
    local entity = hudState.entity
    local manager = rRadio.client.audio.manager
    local presentation = manager.GetPresentationState( entity )
    if presentation then
        return presentation.phase or phases.IDLE,
            rRadio.net.protocol.LimitDisplayName( presentation.stationName ),
            tostring( presentation.stationID or "" )
    end

    local assignment = rRadio.client.radio.state.GetAssignment( entity )
    if assignment then
        return phases.PLAYING,
            rRadio.net.protocol.LimitDisplayName( assignment.stationName ),
            assignment.stationID or ""
    end

    return phases.IDLE, "", ""
end


local function getVolume( hudState, maxVolume )
    local manager = rRadio.client.audio.manager
    if manager.IsMuted( hudState.entity ) then return 0 end

    return math.Clamp(
        rRadio.client.radio.state.GetVolume( hudState.entity ) * ( tonumber( maxVolume ) or 1 ),
        0,
        1
    )
end


local function getRawText( hudState, now )
    if not staticTexts then resetStaticTexts() end

    if hudState.phase == phases.IDLE then return staticTexts.interact, 0 end
    if hudState.phase == phases.ERROR then return staticTexts.error, 0 end
    if hudState.phase == phases.QUEUED then return staticTexts.queued, 0 end
    if hudState.phase == phases.CONNECTING or hudState.phase == phases.PENDING then
        if hudState.mode == "basic" then return staticTexts.tuning, 0 end

        local dotIndex = math.floor( now * 2 ) % 4 + 1
        return staticTexts.tuning .. DOTS[dotIndex], dotIndex
    end

    if hudState.stationName ~= "" then return hudState.stationName, 0 end

    return staticTexts.radio, 0
end


local function colorWithAlpha( output, source, alpha )
    alpha = math.Clamp( alpha, 0, 255 )
    output.r = source.r or 255
    output.g = source.g or 255
    output.b = source.b or 255
    output.a = math.floor( ( source.a or 255 ) * alpha / 255 + 0.5 )
end


local function createEqualizer()
    local equalizer = {}
    for index = 1, EQ_BARS do
        equalizer[index] = 0
    end

    return equalizer
end


local function isPlayingPhase( phase )
    return phase == phases.PLAYING or phase == phases.SILENT_READY
end


local function isConnectingPhase( phase )
    return phase == phases.CONNECTING or phase == phases.PENDING
end


function stateModule.Create( entity )
    return {
        entity = entity,
        isGolden = entity:GetClass() == rRadio.constants.EntityClasses.GOLDEN_BOOMBOX,
        mode = "full",
        phase = phases.IDLE,
        stationID = "",
        stationName = "",
        rawText = "",
        lastTransitionText = "",
        volume = 0,
        alpha = 0,
        distanceSqr = 0,
        layoutDirty = true,
        lastTime = CurTime(),
        phaseTransition = 1,
        textSlide = 0,
        tuningOffset = 0,
        tuningPulse = 0,
        isPlayingPhase = false,
        isConnectingPhase = false,
        equalizer = createEqualizer(),
        equalizerActive = false,
        lastColorAlpha = nil,
        lastTextAlpha = nil,
        lastColorPhase = nil,
        lastColorPulse = nil,
        lastScheme = nil,
        layout = {},
        colors = {
            background = Color( 0, 0, 0, 0 ),
            text = Color( 255, 255, 255, 0 ),
            textBorder = Color( 0, 0, 0, 0 ),
            accent = Color( 255, 255, 255, 0 ),
            dimAccent = Color( 255, 255, 255, 0 ),
            phase = Color( 255, 255, 255, 0 ),
            shadow = Color( 0, 0, 0, 0 )
        },
        position = Vector( 0, 0, 0 ),
        angles = Angle( 0, 0, 0 )
    }
end


function stateModule.RefreshPresentation( hudState, now, mode, maxVolume )
    mode = getNormalizedMode( mode )

    local phase, stationName, stationID = readPresentation( hudState )
    local modeChanged = hudState.mode ~= mode
    local phaseChanged = hudState.phase ~= phase
    local identityChanged = hudState.stationID ~= stationID or hudState.stationName ~= stationName

    hudState.mode = mode
    hudState.phase = phase
    hudState.stationName = stationName
    hudState.stationID = stationID
    hudState.isPlayingPhase = isPlayingPhase( phase )
    hudState.isConnectingPhase = isConnectingPhase( phase )

    if mode ~= "basic" and hudState.isPlayingPhase then
        hudState.volume = getVolume( hudState, maxVolume )
    else
        hudState.volume = 0
    end

    local rawText, dotIndex = getRawText( hudState, now )
    if hudState.rawText ~= rawText or modeChanged then hudState.layoutDirty = true end

    local transitionText = dotIndex == 0 and rawText or staticTexts.tuning
    if phaseChanged or identityChanged or hudState.lastTransitionText ~= transitionText then
        hudState.phaseTransition = 0
        hudState.lastTransitionText = transitionText
    end

    hudState.rawText = rawText
end


function stateModule.UpdateTransform( hudState )
    local entity = hudState.entity
    hudState.position = entity:LocalToWorld( HUD_LOCAL_OFFSET )
    hudState.angles = entity:LocalToWorldAngles( HUD_ANG_OFFSET )
end


function stateModule.UpdateAnimation( hudState, now )
    local dt = math.Clamp( now - ( hudState.lastTime or now ), 0, MAX_FRAME_TIME )
    hudState.lastTime = now

    hudState.phaseTransition = math.min( 1, hudState.phaseTransition + dt * PHASE_TRANSITION_SPEED )
    hudState.textSlide = ( 1 - hudState.phaseTransition ) * TEXT_SLIDE_OFFSET

    local fullMode = hudState.mode ~= "basic"

    if fullMode and hudState.isConnectingPhase then
        hudState.tuningOffset = fastSin( now * TUNING_SPEED ) * 0.5 + 0.5
        hudState.tuningPulse = hudState.tuningOffset
    else
        hudState.tuningOffset = 0
        hudState.tuningPulse = 0
    end

    if not fullMode or not hudState.isPlayingPhase or hudState.volume <= 0 then
        if hudState.equalizerActive then
            local response = math.Clamp( dt * EQUALIZER_RESPONSE, 0, 1 )
            local active = false

            for index = 1, EQ_BARS do
                hudState.equalizer[index] = Lerp( response, hudState.equalizer[index], 0 )
                active = active or hudState.equalizer[index] > 0.001
            end

            hudState.equalizerActive = active
        end

        return
    end

    hudState.equalizerActive = true

    local equalizerResponse = math.Clamp( dt * EQUALIZER_RESPONSE, 0, 1 )
    for index = 1, EQ_BARS do
        local frequency = EQ_FREQUENCIES[index]
        local base = ( now + EQ_OFFSETS[index] ) * frequency
        local wave = ( fastSin( base ) + fastSin( base * 1.5 ) ) * 0.5
        local target = EQ_MIN_HEIGHT + math.abs( wave ) * EQ_MAX_HEIGHT * hudState.volume
        hudState.equalizer[index] = Lerp( equalizerResponse, hudState.equalizer[index], target )
    end
end


function stateModule.UpdateColors( hudState, scheme )
    local textAlpha = hudState.alpha * hudState.phaseTransition
    local pulse = hudState.isConnectingPhase and ( hudState.tuningPulse or 0 ) or 0

    if hudState.lastColorAlpha == hudState.alpha
        and hudState.lastTextAlpha == textAlpha
        and hudState.lastColorPhase == hudState.phase
        and hudState.lastColorPulse == pulse
        and hudState.lastScheme == scheme then
        return
    end

    hudState.lastColorAlpha = hudState.alpha
    hudState.lastTextAlpha = textAlpha
    hudState.lastColorPhase = hudState.phase
    hudState.lastColorPulse = pulse
    hudState.lastScheme = scheme

    colorWithAlpha( hudState.colors.background, scheme.background, hudState.alpha )
    colorWithAlpha( hudState.colors.text, scheme.text, textAlpha * TEXT_ALPHA / 255 )
    colorWithAlpha( hudState.colors.textBorder, DEFAULT_TEXT_BORDER, textAlpha )
    colorWithAlpha( hudState.colors.accent, scheme.accent, hudState.alpha * ACCENT_ALPHA / 255 )
    colorWithAlpha( hudState.colors.dimAccent, scheme.accent, hudState.alpha * DIM_ACCENT_ALPHA / 255 )
    colorWithAlpha( hudState.colors.shadow, scheme.shadow or DEFAULT_SHADOW, hudState.alpha )

    local phaseColor = hudState.colors.phase
    if hudState.isConnectingPhase then
        phaseColor.r = math.floor( Lerp( pulse, scheme.inactive.r, scheme.accent.r ) )
        phaseColor.g = math.floor( Lerp( pulse, scheme.inactive.g, scheme.accent.g ) )
        phaseColor.b = math.floor( Lerp( pulse, scheme.inactive.b, scheme.accent.b ) )
        phaseColor.a = math.floor( hudState.alpha + 0.5 )
    elseif hudState.phase == phases.ERROR then
        colorWithAlpha( phaseColor, scheme.error, hudState.alpha )
    elseif hudState.isPlayingPhase then
        colorWithAlpha( phaseColor, scheme.accent, hudState.alpha )
    else
        colorWithAlpha( phaseColor, scheme.inactive, hudState.alpha )
    end
end


function stateModule.MarkLayoutDirty( hudState )
    hudState.layoutDirty = true
end


function stateModule.ClearStaticTexts()
    staticTexts = nil
end


return stateModule
