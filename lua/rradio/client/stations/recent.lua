rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.stations = rRadio.client.stations or {}
rRadio.client.stations.recent = rRadio.client.stations.recent or {}

local recent = rRadio.client.stations.recent
local stationIDs = {}
local pendingStations = {}
local version = 0
local PENDING_TIMEOUT = 10
local WRITE_DELAY = 0.5
local STATIONS_FILE = "rradio/recent_stations.json"


local function getLimit()
    return math.max( 0, math.floor( tonumber( rRadio.config.RecentStationLimit ) or 25 ) )
end


local function markRecentChanged()
    version = version + 1
end


local function stationIDIsValid( stationID )
    return rRadio.stations.schema.IsValidStationID( stationID )
end


local function trimToLimit()
    local limit = getLimit()

    while #stationIDs > limit do
        stationIDs[#stationIDs] = nil
    end
end


local function readStationQueue()
    local contents = file.Read( STATIONS_FILE, "DATA" )
    local decoded = contents and util.JSONToTable( contents ) or {}
    local result = {}
    local seen = {}
    local changed = false
    local limit = getLimit()

    if type( decoded ) ~= "table" then return result, contents ~= nil end

    for _, stationID in ipairs( decoded ) do
        if type( stationID ) == "string" and stationIDIsValid( stationID ) and not seen[stationID] then
            if #result < limit then
                result[#result + 1] = stationID
                seen[stationID] = true
            else
                changed = true
            end
        else
            changed = true
        end
    end

    return result, changed
end


local function writeStationQueue()
    file.CreateDir( "rradio" )
    file.Write( STATIONS_FILE, util.TableToJSON( stationIDs, true ) )
end


local function queueWrite()
    timer.Create( "rRadio_RecentStations_Write", WRITE_DELAY, 1, writeStationQueue )
end


local function clearExpiredPendingStations()
    local now = CurTime()
    for entity, pending in pairs( pendingStations ) do
        if not IsValid( entity ) or pending.expiresAt <= now then pendingStations[entity] = nil end
    end
end


function recent.Init()
    local changed
    pendingStations = {}
    stationIDs, changed = readStationQueue()
    markRecentChanged()

    if changed then queueWrite() end
end


function recent.GetVersion()
    return version
end


function recent.ListStationIDs()
    local rows = {}
    for index, stationID in ipairs( stationIDs ) do
        rows[index] = stationID
    end

    return rows
end


function recent.MarkPendingStation( entity, stationID )
    if not IsValid( entity ) then return false end
    if not stationIDIsValid( stationID ) then return false end
    if getLimit() <= 0 then return false end

    clearExpiredPendingStations()
    pendingStations[entity] = {
        stationID = stationID,
        expiresAt = CurTime() + PENDING_TIMEOUT
    }

    return true
end


function recent.RecordStation( stationID )
    if not stationIDIsValid( stationID ) then return false end
    if getLimit() <= 0 then return false end
    if stationIDs[1] == stationID then return false end

    for index = #stationIDs, 1, -1 do
        if stationIDs[index] == stationID then table.remove( stationIDs, index ) end
    end

    table.insert( stationIDs, 1, stationID )
    trimToLimit()
    markRecentChanged()
    queueWrite()

    return true
end


function recent.RecordAcceptedStation( entity, stationID )
    if not IsValid( entity ) then return false end

    local pending = pendingStations[entity]
    if not pending then return false end

    pendingStations[entity] = nil
    if pending.expiresAt <= CurTime() then return false end
    if pending.stationID ~= stationID then return false end

    return recent.RecordStation( stationID )
end


return recent
