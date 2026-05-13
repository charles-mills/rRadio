rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.layout = rRadio.client.hud.layout or {}

local layout = rRadio.client.hud.layout
local textModule = rRadio.client.hud.text

local DETAIL_SCALE = rRadio.client.hud.DETAIL_SCALE or 2
rRadio.client.hud.DETAIL_SCALE = DETAIL_SCALE

layout.HUD_SCALE = 0.06 / DETAIL_SCALE

local MAX_WIDTH = 380 * DETAIL_SCALE
local HEIGHT = 42 * DETAIL_SCALE
local PAD = 11 * DETAIL_SCALE
local TEXT_GAP = 11 * DETAIL_SCALE
local RIGHT_PAD = PAD * 2
local EQ_BARS = 5
local EQ_BAR_WIDTH = 3 * DETAIL_SCALE
local EQ_GAP = 2 * DETAIL_SCALE
local EQ_WIDTH = EQ_BARS * EQ_BAR_WIDTH + ( EQ_BARS - 1 ) * EQ_GAP
local STATUS_MARKER_WIDTH = 4 * DETAIL_SCALE
local DECORATION_WIDTH = math.max( EQ_WIDTH, STATUS_MARKER_WIDTH )
local STRIP_HEIGHT = 3 * DETAIL_SCALE


local function getTextBounds( mode, left, width )
    if mode == "basic" then return left + RIGHT_PAD, left + width - RIGHT_PAD end

    return left + PAD + DECORATION_WIDTH + TEXT_GAP, left + width - RIGHT_PAD
end


function layout.Rebuild( hudState )
    local mode = hudState.mode == "basic" and "basic" or "full"
    local result = hudState.layout or {}
    local font = textModule.GetFont()
    local width = MAX_WIDTH
    local halfWidth = width * 0.5
    local halfHeight = HEIGHT * 0.5
    local left = -halfWidth
    local top = -halfHeight
    local textLeft, textRight = getTextBounds( mode, left, width )
    local fittedText = textModule.Fit( hudState.rawText, font, textRight - textLeft )
    local _, textHeight = textModule.Measure( fittedText, font )

    result.mode = mode
    result.font = font
    result.width = width
    result.height = HEIGHT
    result.halfWidth = halfWidth
    result.halfHeight = halfHeight
    result.left = left
    result.top = top
    result.text = fittedText
    result.textDrawX = textLeft
    result.textY = math.floor( -textHeight * 0.5 + 0.5 )
    result.statusX = left + PAD
    result.statusY = -HEIGHT * 0.16
    result.statusWidth = STATUS_MARKER_WIDTH
    result.statusHeight = HEIGHT * 0.32
    result.stripY = halfHeight - STRIP_HEIGHT
    result.stripHeight = STRIP_HEIGHT
    result.equalizerX = left + PAD
    result.equalizerY = 0
    result.equalizerBarWidth = EQ_BAR_WIDTH
    result.equalizerGap = EQ_GAP
    result.equalizerMaxHeight = 18 * DETAIL_SCALE

    hudState.layout = result
    hudState.layoutDirty = false

    return result
end


return layout
