rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.radio = rRadio.client.radio or {}
rRadio.client.radio.mutes = rRadio.client.radio.mutes or {}

local mutes = rRadio.client.radio.mutes

local FILE_PATH = "rradio/muted_permanent_boomboxes.json"
local STORAGE_VERSION = 1
local mutedByServer = {}
local loaded = false

local function getServerKey()
    local address = string.Trim( game.GetIPAddress() )
    if address ~= "" then return "address:" .. address end

    return "address:unknown"
end

local function normalizePermanentID( permanentID )
    if permanentID == nil then return nil end

    permanentID = string.Trim( tostring( permanentID ) )
    if permanentID == "" then return nil end

    return permanentID
end

local function storeLoadedMute( serverKey, mapName, permanentID )
    serverKey = tostring( serverKey or "" )
    mapName = tostring( mapName or "" )
    permanentID = normalizePermanentID( permanentID )
    if serverKey == "" or mapName == "" or not permanentID then return false end

    local serverMutes = mutedByServer[serverKey]
    if not serverMutes then
        serverMutes = {}
        mutedByServer[serverKey] = serverMutes
    end

    local mapMutes = serverMutes[mapName]
    if not mapMutes then
        mapMutes = {}
        serverMutes[mapName] = mapMutes
    end

    mapMutes[permanentID] = true
    return true
end

local function loadStoredMap( serverKey, mapName, mapRows )
    if type( mapRows ) ~= "table" then return false end

    local loadedAny = false
    for permanentID, value in pairs( mapRows ) do
        if value == true then loadedAny = storeLoadedMute( serverKey, mapName, permanentID ) or loadedAny end
    end

    return loadedAny
end

local function loadStoredServer( serverKey, serverRows )
    if type( serverRows ) ~= "table" then return false end

    local loadedAny = false
    for mapName, mapRows in pairs( serverRows ) do
        loadedAny = loadStoredMap( serverKey, mapName, mapRows ) or loadedAny
    end

    return loadedAny
end

local function loadLegacyKey( key, value )
    if value ~= true then return false end

    local serverKey, mapName, permanentID = string.match( tostring( key ), "^([^\n]+)\n([^\n]+)\n(.+)$" )
    return storeLoadedMute( serverKey, mapName, permanentID )
end

local function ensureLoaded()
    if loaded then return end

    mutedByServer = {}
    loaded = true

    if not file.Exists( FILE_PATH, "DATA" ) then return end

    local decoded = util.JSONToTable( file.Read( FILE_PATH, "DATA" ) )
    if type( decoded ) ~= "table" then return end
    if type( decoded.muted ) ~= "table" then return end

    for serverKey, serverRows in pairs( decoded.muted ) do
        if not loadStoredServer( serverKey, serverRows ) then
            loadLegacyKey( serverKey, serverRows )
        end
    end
end

local function save()
    ensureLoaded()
    file.CreateDir( "rradio" )
    file.Write( FILE_PATH, util.TableToJSON( {
        version = STORAGE_VERSION,
        muted = mutedByServer
    }, true ) )
end

local function getEntityPermanentID( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    local settings = rRadio.client.radio.state.GetSettings( entity )
    if not settings or settings.permanent ~= true then return nil end

    return normalizePermanentID( settings.permanentID )
end

local function getMapMutes( create )
    ensureLoaded()

    local serverKey = getServerKey()
    local serverMutes = mutedByServer[serverKey]
    if not serverMutes and create then
        serverMutes = {}
        mutedByServer[serverKey] = serverMutes
    end
    if not serverMutes then return nil end

    local mapName = game.GetMap()
    local mapMutes = serverMutes[mapName]
    if not mapMutes and create then
        mapMutes = {}
        serverMutes[mapName] = mapMutes
    end

    return mapMutes, serverMutes, serverKey, mapName
end

local function removeEmptyContainers( serverMutes, serverKey, mapName )
    local mapMutes = serverMutes and serverMutes[mapName]
    if mapMutes and next( mapMutes ) == nil then serverMutes[mapName] = nil end
    if serverMutes and next( serverMutes ) == nil then mutedByServer[serverKey] = nil end
end

function mutes.IsEntityMuted( entity )
    local permanentID = getEntityPermanentID( entity )
    if not permanentID then return false end

    local mapMutes = getMapMutes( false )
    return mapMutes ~= nil and mapMutes[permanentID] == true
end

function mutes.SetEntityMuted( entity, muted )
    local permanentID = getEntityPermanentID( entity )
    if not permanentID then return false end

    local shouldMute = muted == true
    local mapMutes, serverMutes, serverKey, mapName = getMapMutes( shouldMute )
    if not mapMutes then return true end

    local wasMuted = mapMutes[permanentID] == true
    if wasMuted == shouldMute then return true end

    if shouldMute then
        mapMutes[permanentID] = true
    else
        mapMutes[permanentID] = nil
        removeEmptyContainers( serverMutes, serverKey, mapName )
    end

    save()

    return true
end

function mutes.Init()
    ensureLoaded()
end

return mutes
