rRadio = rRadio or {}
rRadio.logger = rRadio.logger or {}

local logger = rRadio.logger

local DEBUG_STORE_DIR = "rradio/debug"
local DEBUG_STORE_RUN_DIR = DEBUG_STORE_DIR .. "/runs"
local DEBUG_STORE_STATE_PATH = DEBUG_STORE_DIR .. "/last_shutdown.txt"
local DEBUG_STORE_PATH_DESCRIPTION = "garrysmod/data/" .. DEBUG_STORE_RUN_DIR
local MAX_DEBUG_STORE_ENTRIES = 5000

logger._debugStore = logger._debugStore or {
    entries = {},
    droppedCount = 0,
    runStartedAt = os.time(),
    runStartedSysTime = SysTime and SysTime() or nil
}

local debugStore = logger._debugStore
debugStore.entryCount = math.min( debugStore.entryCount or #debugStore.entries, MAX_DEBUG_STORE_ENTRIES )
debugStore.nextIndex = debugStore.nextIndex or ( debugStore.entryCount % MAX_DEBUG_STORE_ENTRIES ) + 1
local debugLoggingConVar
local debugStoreConVar

local function isDebugLoggingEnabled()
    if not debugLoggingConVar then debugLoggingConVar = GetConVar( "rammel_rradio_debug_logging" ) end

    return debugLoggingConVar and debugLoggingConVar:GetBool()
end

local function isInfoLoggingEnabled()
    if rRadio.config.EnableLogging == false then return false end

    return true
end

local function isDebugStoreEnabled()
    if not SERVER then return false end

    if not debugStoreConVar then debugStoreConVar = GetConVar( "rammel_rradio_debug_store" ) end

    return debugStoreConVar and debugStoreConVar:GetBool()
end

local function getTimestamp()
    return os.time()
end

local function formatTimestamp( timestamp )
    return os.date( "!%Y-%m-%dT%H:%M:%SZ", timestamp )
end

local function formatFilenameTimestamp( timestamp )
    return os.date( "!%Y%m%d_%H%M%SZ", timestamp )
end

local function getRunElapsedSeconds()
    if debugStore.runStartedSysTime and SysTime then
        return math.max( 0, SysTime() - debugStore.runStartedSysTime )
    end

    return math.max( 0, getTimestamp() - debugStore.runStartedAt )
end

local function formatDuration( seconds )
    seconds = math.max( 0, tonumber( seconds ) or 0 )

    if seconds < 60 then
        return string.format( "%.2fs", seconds )
    end

    local wholeSeconds = math.floor( seconds )
    local days = math.floor( wholeSeconds / 86400 )
    wholeSeconds = wholeSeconds % 86400
    local hours = math.floor( wholeSeconds / 3600 )
    wholeSeconds = wholeSeconds % 3600
    local minutes = math.floor( wholeSeconds / 60 )
    wholeSeconds = wholeSeconds % 60

    if days > 0 then
        return string.format( "%dd %02dh %02dm %02ds", days, hours, minutes, wholeSeconds )
    end

    if hours > 0 then
        return string.format( "%dh %02dm %02ds", hours, minutes, wholeSeconds )
    end

    return string.format( "%dm %02ds", minutes, wholeSeconds )
end

local function stringifyArguments( ... )
    local count = select( "#", ... )
    if count == 0 then return "" end

    local parts = {}

    for index = 1, count do
        parts[index] = tostring( select( index, ... ) )
    end

    return table.concat( parts, " " )
end

local function storeLine( line )
    local entries = debugStore.entries
    local isFull = debugStore.entryCount >= MAX_DEBUG_STORE_ENTRIES

    entries[debugStore.nextIndex] = line
    debugStore.nextIndex = ( debugStore.nextIndex % MAX_DEBUG_STORE_ENTRIES ) + 1

    if isFull then
        debugStore.droppedCount = ( debugStore.droppedCount or 0 ) + 1
    else
        debugStore.entryCount = debugStore.entryCount + 1
    end
end

local function appendStoredDebugLines( lines )
    local count = debugStore.entryCount or 0
    local startIndex = count < MAX_DEBUG_STORE_ENTRIES and 1 or debugStore.nextIndex

    for offset = 0, count - 1 do
        local entryIndex = ( ( startIndex + offset - 1 ) % MAX_DEBUG_STORE_ENTRIES ) + 1
        lines[#lines + 1] = debugStore.entries[entryIndex]
    end
end

local function storeEntry( level, scope, ... )
    if not isDebugStoreEnabled() then return end

    local label = tostring( level or "debug" )
    if scope then
        label = label .. ":" .. tostring( scope )
    end

    local message = stringifyArguments( ... )
    local line = string.format(
        "[%s] +%s [%s] %s",
        formatTimestamp( getTimestamp() ),
        formatDuration( getRunElapsedSeconds() ),
        label,
        message
    )

    storeLine( line )
end

local function readPreviousShutdown()
    local contents = file.Read( DEBUG_STORE_STATE_PATH, "DATA" )
    if not contents then return nil end

    return tonumber( string.match( contents, "^(%d+)" ) )
end

local function ensureDebugStoreDirectory()
    file.CreateDir( "rradio" )
    file.CreateDir( DEBUG_STORE_DIR )
    file.CreateDir( DEBUG_STORE_RUN_DIR )

    return true
end

function logger.IsDebugEnabled()
    return isDebugLoggingEnabled() or isDebugStoreEnabled()
end

function logger.GetDebugStorePath()
    return DEBUG_STORE_PATH_DESCRIPTION
end

function logger.Info( ... )
    storeEntry( "info", nil, ... )
    if not isInfoLoggingEnabled() then return end

    print( "[rRadio]", ... )
end

function logger.Warn( ... )
    storeEntry( "warning", nil, ... )
    print( "[rRadio warning]", ... )
end

function logger.Debug( ... )
    local shouldPrint = isDebugLoggingEnabled()
    local shouldStore = isDebugStoreEnabled()

    if not shouldPrint and not shouldStore then return end

    storeEntry( "debug", nil, ... )
    if shouldPrint then print( "[rRadio debug]", ... ) end
end

function logger.DebugScope( scope, ... )
    local shouldPrint = isDebugLoggingEnabled()
    local shouldStore = isDebugStoreEnabled()

    if not shouldPrint and not shouldStore then return end

    storeEntry( "debug", scope, ... )
    if shouldPrint then print( "[rRadio debug:" .. tostring( scope ) .. "]", ... ) end
end

function logger.WarnScope( scope, ... )
    storeEntry( "warning", scope, ... )
    print( "[rRadio warning:" .. tostring( scope ) .. "]", ... )
end

function logger.FlushDebugStore( reason )
    if not isDebugStoreEnabled() then return false end
    if debugStore.flushed then return false end
    if not ensureDebugStoreDirectory() then return false end

    debugStore.flushed = true

    local shutdownAt = getTimestamp()
    local previousShutdown = readPreviousShutdown()
    local runPath = DEBUG_STORE_RUN_DIR
        .. "/rradio_debug_"
        .. formatFilenameTimestamp( debugStore.runStartedAt )
        .. "_to_"
        .. formatFilenameTimestamp( shutdownAt )
        .. ".log"
    local lines = {
        "==== rRadio debug store ====",
        "reason: " .. tostring( reason or "shutdown" ),
        "run started: " .. formatTimestamp( debugStore.runStartedAt ),
        "shutdown: " .. formatTimestamp( shutdownAt ),
        "run duration: " .. formatDuration( getRunElapsedSeconds() )
    }

    if previousShutdown then
        local betweenRuns = math.max( 0, debugStore.runStartedAt - previousShutdown )
        lines[#lines + 1] = "time since previous stored shutdown: " .. formatDuration( betweenRuns )
        lines[#lines + 1] = "previous stored shutdown: " .. formatTimestamp( previousShutdown )
    else
        lines[#lines + 1] = "time since previous stored shutdown: unavailable"
    end

    if ( debugStore.droppedCount or 0 ) > 0 then
        lines[#lines + 1] = "dropped oldest entries: " .. tostring( debugStore.droppedCount )
    end

    if ( debugStore.entryCount or 0 ) == 0 then
        lines[#lines + 1] = "entries: none captured"
    else
        lines[#lines + 1] = "entries:"
        appendStoredDebugLines( lines )
    end

    lines[#lines + 1] = "==== end rRadio debug store ===="

    file.Write( runPath, table.concat( lines, "\n" ) .. "\n" )
    file.Write( DEBUG_STORE_STATE_PATH, tostring( shutdownAt ) .. "\n" )
    print( "[rRadio]", "Stored debug log:", "garrysmod/data/" .. runPath )

    return true
end

if SERVER then
    hook.Add( "ShutDown", "rRadio_Logger_FlushDebugStore", function()
        logger.FlushDebugStore( "shutdown" )
    end )
end

return logger
