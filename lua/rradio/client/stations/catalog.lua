rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.stations = rRadio.client.stations or {}
rRadio.client.stations.catalog = rRadio.client.stations.catalog or {}

local catalog = rRadio.client.stations.catalog
local byID = {}
local byCountry = {}
local allStations = {}
local customIDs = {}
local customOrder = {}
local customCountryKey
local version = 0
local allBuiltinLoaded = false
local loadedChunks = {}


local function markCatalogChanged()
    version = version + 1
end

local function getBuiltinCountryKey( stationID )
    return string.match( tostring( stationID or "" ), "^builtin:([^:]+):" )
end


local function addStationRecord( record )
    byID[record.id] = record

    byCountry[record.countryKey] = byCountry[record.countryKey] or {
        key = record.countryKey,
        name = record.countryName,
        stations = {},
        chunks = {},
        builtinCount = 0,
        loaded = true
    }

    table.insert( byCountry[record.countryKey].stations, record )
    table.insert( allStations, record )
end

local function makeStationRecord( station )
    local countryName = station.countryName or rRadio.util.FormatCountryKey( station.countryKey )
    local searchText = station.search or string.lower( station.name .. " " .. countryName )

    return {
        id = station.id,
        name = station.name,
        url = station.url,
        countryKey = station.countryKey,
        countryName = countryName,
        source = station.source,
        search = searchText
    }
end

local function decodeBuiltinStation( countryKey, countryName, row )
    local stationID = tostring( row[1] or "" )
    if not string.StartWith( stationID, "builtin:" ) then stationID = "builtin:" .. countryKey .. ":" .. stationID end

    local searchText = row[3]
    if not searchText then
        searchText = string.lower( tostring( row[2] or "" ) .. " " .. tostring( countryName or "" ) )
    end

    return {
        id = stationID,
        name = row[2],
        countryKey = countryKey,
        countryName = countryName,
        source = rRadio.constants.Defaults.BuiltinStationSource,
        search = searchText
    }
end


local function sortCountryStations( country )
    if not country or country.stationSorted then return end

    table.sort( country.stations, function( a, b )
        local aName = tostring( a.name or "" )
        local bName = tostring( b.name or "" )
        if aName == bName then return tostring( a.id or "" ) < tostring( b.id or "" ) end

        return aName < bName
    end )

    country.stationSorted = true
end


local function sortAllStations()
    table.SortByMember( allStations, "name", true )
end

local function loadChunk( chunkName )
    if loadedChunks[chunkName] then return end

    local payloadPath = "rradio/client/stations/generated/" .. chunkName
    local record = include( payloadPath )
    local payload = rRadio.generatedPayload.DecodeOrError( record, {
        label = payloadPath,
        kind = "client_station_catalog_chunk",
        maxBytes = 512 * 1024
    } )

    local chunk = payload.countries
    if type( chunk ) ~= "table" then
        error( "[rRadio] " .. payloadPath .. " did not contain a countries table", 2 )
    end

    loadedChunks[chunkName] = true

    for _, countryBlock in ipairs( chunk ) do
        local countryKey = countryBlock[1]
        local countryName = countryBlock[2]
        local country = byCountry[countryKey]
        if country and not ( country.loadedChunks and country.loadedChunks[chunkName] ) then
            for _, row in ipairs( countryBlock[3] or {} ) do
                addStationRecord( decodeBuiltinStation( countryKey, countryName, row ) )
            end

            country.stationSorted = false
            country.loadedChunks = country.loadedChunks or {}
            country.loadedChunks[chunkName] = true
            country.loadedChunkCount = ( country.loadedChunkCount or 0 ) + 1
            country.loaded = country.loadedChunkCount >= #( country.chunks or {} )
            if country.loaded then sortCountryStations( country ) end
        end
    end
end

local function loadCountry( countryKey )
    local country = byCountry[countryKey]
    if not country or country.loaded then return country end

    for _, chunkName in ipairs( country.chunks or {} ) do
        loadChunk( chunkName )
        if country.loaded then
            sortCountryStations( country )
            return country
        end
    end

    country.loaded = true
    sortCountryStations( country )
    return country
end

local function loadAllBuiltins()
    if allBuiltinLoaded then return end

    for countryKey in pairs( byCountry ) do
        loadCountry( countryKey )
    end

    allBuiltinLoaded = true
    sortAllStations()
end

local function removeStationFromList( rows, station )
    for index = #rows, 1, -1 do
        if rows[index] == station then table.remove( rows, index ) end
    end
end

local function removeCustomStations()
    for stationID in pairs( customIDs ) do
        local station = byID[stationID]
        if station and byCountry[station.countryKey] then
            removeStationFromList( byCountry[station.countryKey].stations, station )
        end

        if station then removeStationFromList( allStations, station ) end
        byID[stationID] = nil
    end

    customIDs = {}
    customOrder = {}
end

function catalog.Init()
    byID = {}
    byCountry = {}
    allStations = {}
    customIDs = {}
    customOrder = {}
    customCountryKey = rRadio.config.CustomStationCategory or "Custom"
    allBuiltinLoaded = false
    loadedChunks = {}

    local generatedCatalog = rRadio.generated.clientCatalog or {}
    for _, countryRow in ipairs( generatedCatalog.countries or {} ) do
        local countryKey = countryRow[1]
        byCountry[countryKey] = {
            key = countryKey,
            name = countryRow[2],
            stations = {},
            chunks = countryRow[4] or {},
            builtinCount = tonumber( countryRow[3] ) or 0,
            loadedChunks = {},
            loadedChunkCount = 0,
            loaded = false
        }
    end

    markCatalogChanged()
end

function catalog.ApplyCustomStations( stations )
    local nextCustomCountryKey = rRadio.config.CustomStationCategory or "Custom"
    removeCustomStations()
    customCountryKey = nextCustomCountryKey

    for _, station in ipairs( stations or {} ) do
        station.countryName = customCountryKey
        local record = makeStationRecord( station )
        addStationRecord( record )
        customIDs[record.id] = true
        customOrder[#customOrder + 1] = record.id
    end

    sortAllStations()
    markCatalogChanged()
end

function catalog.GetVersion()
    return version
end

function catalog.Get( stationID )
    local station = byID[stationID]
    if station then return station end

    local countryKey = getBuiltinCountryKey( stationID )
    if countryKey then
        loadCountry( countryKey )
        return byID[stationID]
    end

    return nil
end

function catalog.FindByLegacyName( countryKey, stationName )
    local country = loadCountry( countryKey )
    if not country then return {} end

    local stationIDs = {}
    for _, station in ipairs( country.stations ) do
        if station.name == stationName then stationIDs[#stationIDs + 1] = station.id end
    end

    return stationIDs
end

function catalog.ListCountries()
    local countries = {}
    for _, country in pairs( byCountry ) do
        if ( country.builtinCount or 0 ) > 0 or #country.stations > 0 then countries[#countries + 1] = country end
    end

    table.SortByMember( countries, "name", true )
    return countries
end

function catalog.ListStationsForCountry( countryKey )
    local country = loadCountry( countryKey )
    if not country then return {} end

    return country.stations
end

function catalog.ListCustomStations()
    local stations = {}
    for _, stationID in ipairs( customOrder ) do
        local station = byID[stationID]
        if station then stations[#stations + 1] = station end
    end

    return stations
end

function catalog.ListStations()
    loadAllBuiltins()
    return allStations
end

function catalog.ListFavouriteStations( favouriteIDs )
    local stations = {}
    for _, stationID in ipairs( favouriteIDs or {} ) do
        local station = catalog.Get( stationID )
        if station then stations[#stations + 1] = station end
    end

    table.SortByMember( stations, "name", true )
    return stations
end

function catalog.Search( query )
    loadAllBuiltins()

    local normalized = string.lower( tostring( query or "" ) )
    if normalized == "" then return allStations end

    local results = {}
    for _, station in ipairs( allStations ) do
        if string.find( station.search, normalized, 1, true ) then results[#results + 1] = station end
    end

    return results
end

return catalog
