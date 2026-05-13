rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.text = rRadio.client.hud.text or {}

local textModule = rRadio.client.hud.text
local fonts = rRadio.client.fonts

local FONT = "rRadio.BoomboxHUD.Text"
local DETAIL_SCALE = rRadio.client.hud.DETAIL_SCALE or 2
rRadio.client.hud.DETAIL_SCALE = DETAIL_SCALE
local FONT_SIZE = 24 * DETAIL_SCALE
local FONT_WEIGHT = 500
local ELLIPSIS = "..."
local MAX_MEASURE_CACHE = 512
local MAX_FIT_CACHE = 256

local measureCache = {}
local measureCacheKeys = {}
local measureCacheNextIndex = 1
local measureCacheCount = 0
local fitCache = {}
local fitCacheKeys = {}
local fitCacheNextIndex = 1
local fitCacheCount = 0


local function cacheValue( cache, keys, nextIndex, count, maxItems, key, value )
    local oldKey = keys[nextIndex]
    if oldKey and oldKey ~= key then cache[oldKey] = nil end

    cache[key] = value
    keys[nextIndex] = key

    nextIndex = ( nextIndex % maxItems ) + 1
    count = math.min( count + 1, maxItems )

    return value, nextIndex, count
end


local function cacheMeasure( key, value )
    value, measureCacheNextIndex, measureCacheCount = cacheValue(
        measureCache,
        measureCacheKeys,
        measureCacheNextIndex,
        measureCacheCount,
        MAX_MEASURE_CACHE,
        key,
        value
    )

    return value
end


local function cacheFit( key, value )
    value, fitCacheNextIndex, fitCacheCount = cacheValue(
        fitCache,
        fitCacheKeys,
        fitCacheNextIndex,
        fitCacheCount,
        MAX_FIT_CACHE,
        key,
        value
    )

    return value
end


local function trimText( text, length )
    if utf8 and utf8.sub then return utf8.sub( text, 1, length ) end

    return string.sub( text, 1, length )
end


local function getTextLength( text )
    if utf8 and utf8.len then return utf8.len( text ) or #text end

    return #text
end


function textModule.Init()
    surface.CreateFont( FONT, {
        font = fonts.GetFace( FONT_WEIGHT ),
        size = fonts.ScaleSize( FONT_SIZE ),
        weight = FONT_WEIGHT,
        antialias = true,
        extended = true
    } )
end


function textModule.GetFont()
    return FONT
end


function textModule.Measure( text, font )
    text = tostring( text or "" )
    font = font or FONT

    local key = font .. "\1" .. text
    local cached = measureCache[key]
    if cached then return cached.width, cached.height end

    surface.SetFont( font )
    local width, height = surface.GetTextSize( text )
    local result = {
        width = width,
        height = height
    }

    cacheMeasure( key, result )

    return width, height
end


function textModule.Fit( rawText, font, maxWidth )
    rawText = tostring( rawText or "" )
    font = font or FONT
    maxWidth = math.floor( maxWidth )
    if maxWidth <= 0 then return "" end

    local key = font .. "\1" .. maxWidth .. "\1" .. rawText
    local cached = fitCache[key]
    if cached then return cached end

    local width = textModule.Measure( rawText, font )
    if width <= maxWidth then
        return cacheFit( key, rawText )
    end

    local suffixWidth = textModule.Measure( ELLIPSIS, font )
    local low = 0
    local high = getTextLength( rawText )
    while low < high do
        local mid = math.ceil( ( low + high ) / 2 )
        local candidate = trimText( rawText, mid )
        local candidateWidth = textModule.Measure( candidate, font )
        if candidateWidth + suffixWidth <= maxWidth then
            low = mid
        else
            high = mid - 1
        end
    end

    local fitted = trimText( rawText, low ) .. ELLIPSIS
    return cacheFit( key, fitted )
end


function textModule.ClearCaches()
    table.Empty( measureCache )
    table.Empty( measureCacheKeys )
    table.Empty( fitCache )
    table.Empty( fitCacheKeys )
    measureCacheNextIndex = 1
    measureCacheCount = 0
    fitCacheNextIndex = 1
    fitCacheCount = 0
end


function textModule.GetStats()
    return {
        measuredTexts = measureCacheCount,
        fittedTexts = fitCacheCount
    }
end


return textModule
