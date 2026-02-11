rRadio = rRadio or {}
rRadio.logger = rRadio.logger or {}
local logger = rRadio.logger
local DEBUG_CONVAR = "rammel_rradio_debug_logging"
local LEVELS = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40
}

local LEVEL_COLOURS = {
    DEBUG = Color( 120, 170, 255 ),
    INFO = Color( 90, 220, 140 ),
    WARN = Color( 255, 210, 90 ),
    ERROR = Color( 255, 120, 120 )
}

local TEXT_COLOUR = Color( 235, 235, 235 )
local function getRealmTag()
    if SERVER then return "SV" end
    return "CL"
end

local function getDebugConVar()
    return GetConVar( DEBUG_CONVAR )
end

function logger.IsDebugEnabled()
    local cv = getDebugConVar()
    return cv and cv:GetBool() or false
end

function logger.ShouldLog( level )
    if level == "DEBUG" or level == "INFO" then return logger.IsDebugEnabled() end
    return LEVELS[level] ~= nil
end

local function stringify( value )
    local t = type( value )
    if t == "string" then return value end
    if t == "table" and util and util.TableToJSON then
        local ok, encoded = pcall( util.TableToJSON, value, false )
        if ok and encoded then return encoded end
    end
    return tostring( value )
end

local function buildMessage( ... )
    local count = select( "#", ... )
    if count == 0 then return "" end
    local parts = {}
    for i = 1, count do
        parts[i] = stringify( select( i, ... ) )
    end
    return table.concat( parts, " " )
end

function logger.Log( level, scope, ... )
    if not logger.ShouldLog( level ) then return end
    local levelTag = LEVELS[level] and level or "INFO"
    local timeTag = os.date( "%H:%M:%S" )
    local prefix = string.format( "[rRadio][%s][%s][%s]", timeTag, getRealmTag(), levelTag )
    if scope and scope ~= "" then prefix = prefix .. "[" .. tostring( scope ) .. "]" end
    local message = buildMessage( ... )
    local levelColour = LEVEL_COLOURS[levelTag] or LEVEL_COLOURS.INFO
    if not MsgC then
        print( prefix .. " " .. message )
        return
    end

    MsgC( levelColour, prefix .. " ", TEXT_COLOUR, message .. "\n" )
end

function logger.Debug( ... )
    logger.Log( "DEBUG", nil, ... )
end

function logger.Info( ... )
    logger.Log( "INFO", nil, ... )
end

function logger.Warn( ... )
    logger.Log( "WARN", nil, ... )
end

function logger.Error( ... )
    logger.Log( "ERROR", nil, ... )
end

function logger.DebugScope( scope, ... )
    logger.Log( "DEBUG", scope, ... )
end

function logger.InfoScope( scope, ... )
    logger.Log( "INFO", scope, ... )
end

function logger.WarnScope( scope, ... )
    logger.Log( "WARN", scope, ... )
end

function logger.ErrorScope( scope, ... )
    logger.Log( "ERROR", scope, ... )
end
