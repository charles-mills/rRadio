rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.stations = rRadio.client.stations or {}
rRadio.client.stations.favourites = rRadio.client.stations.favourites or {}

local favourites = rRadio.client.stations.favourites
local stationIDs = {}
local countryKeys = {}
local version = 0
local WRITE_DELAY = 0.5
local STATIONS_FILE = "rradio/favorite_stations.json"
local COUNTRIES_FILE = "rradio/favorite_countries.json"


local function markFavouritesChanged()
    version = version + 1
end

local function readSet( path )
    local contents = file.Read( path, "DATA" )
    local decoded = contents and util.JSONToTable( contents ) or {}
    local result = {}

    if type( decoded ) == "table" then
        for _, key in ipairs( decoded ) do
            if type( key ) == "string" then result[key] = true end
        end
    end

    return result
end

local function readStationSet()
    local contents = file.Read( STATIONS_FILE, "DATA" )
    local decoded = contents and util.JSONToTable( contents ) or {}
    local result = {}

    if type( decoded ) ~= "table" then return result end

    for _, stationID in ipairs( decoded ) do
        if type( stationID ) == "string" and rRadio.client.stations.catalog.Get( stationID ) then
            result[stationID] = true
        end
    end

    if next( result ) ~= nil then return result end

    for countryKey, stations in pairs( decoded ) do
        if type( countryKey ) == "string" and type( stations ) == "table" then
            for stationName, favourite in pairs( stations ) do
                if type( stationName ) == "string" and favourite == true then
                    local legacyStationIDs = rRadio.client.stations.catalog.FindByLegacyName( countryKey, stationName )
                    for _, stationID in ipairs( legacyStationIDs ) do
                        result[stationID] = true
                    end
                end
            end
        end
    end

    return result
end

local function writeSet( path, set )
    local rows = {}
    for key in pairs( set ) do
        rows[#rows + 1] = key
    end

    table.sort( rows )
    file.CreateDir( "rradio" )
    file.Write( path, util.TableToJSON( rows, true ) )
end

local function queueWrite()
    timer.Create( "rRadio_Favourites_Write", WRITE_DELAY, 1, function()
        writeSet( STATIONS_FILE, stationIDs )
        writeSet( COUNTRIES_FILE, countryKeys )
    end )
end

function favourites.Init()
    stationIDs = readStationSet()
    countryKeys = readSet( COUNTRIES_FILE )
    markFavouritesChanged()

    if next( stationIDs ) ~= nil then queueWrite() end
end

function favourites.GetVersion()
    return version
end

function favourites.IsStationFavourite( stationID )
    return stationIDs[stationID] == true
end

function favourites.HasStationFavourites()
    return next( stationIDs ) ~= nil
end

function favourites.ListStationIDs()
    local rows = {}
    for stationID in pairs( stationIDs ) do
        rows[#rows + 1] = stationID
    end

    table.sort( rows )
    return rows
end

function favourites.SetStationFavourite( stationID, favourite )
    local shouldFavourite = favourite == true
    if favourites.IsStationFavourite( stationID ) == shouldFavourite then return end

    if shouldFavourite then
        stationIDs[stationID] = true
    else
        stationIDs[stationID] = nil
    end

    markFavouritesChanged()
    queueWrite()
end

function favourites.IsCountryFavourite( countryKey )
    return countryKeys[countryKey] == true
end

function favourites.SetCountryFavourite( countryKey, favourite )
    local shouldFavourite = favourite == true
    if favourites.IsCountryFavourite( countryKey ) == shouldFavourite then return end

    if shouldFavourite then
        countryKeys[countryKey] = true
    else
        countryKeys[countryKey] = nil
    end

    markFavouritesChanged()
    queueWrite()
end

return favourites
