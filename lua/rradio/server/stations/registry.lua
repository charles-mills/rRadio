rRadio = rRadio or {}
rRadio.stations = rRadio.stations or {}
rRadio.stations.registry = rRadio.stations.registry or {}

local registry = rRadio.stations.registry
local schema = rRadio.stations.schema

local builtinStations = {}
local builtinByURL
local customStations = {}
local customOrder = {}
local customByURL = {}
local customLookupID = {}
local customLookupCount = {}

local CUSTOM_STATIONS_FILE = "rradio/custom_stations.json"
local LEGACY_CUSTOM_STATIONS_FILE = "rradio/customstations.json"
local BUILTIN_NAME_INDEX = 1
local BUILTIN_URL_INDEX = 2
local BUILTIN_COUNTRY_KEY_INDEX = 3
local BUILTIN_SOURCE_INDEX = 4
local writeCustomStations

local function copyStation( station )
    return {
        id = station.id,
        name = station.name,
        url = station.url,
        countryKey = station.countryKey,
        source = station.source
    }
end

local function copyBuiltinStation( stationID, station )
    return {
        id = stationID,
        name = station[BUILTIN_NAME_INDEX],
        url = station[BUILTIN_URL_INDEX],
        countryKey = station[BUILTIN_COUNTRY_KEY_INDEX],
        source = station[BUILTIN_SOURCE_INDEX]
    }
end


local function expandGeneratedBuiltinStations()
    local generated = rRadio.generated
    if not generated then
        error( "Generated builtin station registry is missing; builtin_registry.lua did not load", 2 )
    end

    local flatStations = generated.serverStations
    if flatStations then return flatStations end

    local countries = generated.serverStationCountries
    if not countries then
        error( "Generated builtin station country registry is missing; builtin_registry.lua did not load", 2 )
    end

    local expanded = {}
    local builtinSource = rRadio.constants.Defaults.BuiltinStationSource

    for countryKey, countryStations in pairs( countries ) do
        if type( countryStations ) == "table" then
            for stationSuffix, station in pairs( countryStations ) do
                if type( station ) == "table" then
                    local stationID = stationSuffix
                    if not string.StartWith( stationID, "builtin:" ) then
                        stationID = "builtin:" .. countryKey .. ":" .. stationSuffix
                    end

                    expanded[stationID] = {
                        station[BUILTIN_NAME_INDEX],
                        station[BUILTIN_URL_INDEX],
                        countryKey,
                        builtinSource
                    }
                end
            end
        end
    end

    return expanded
end


local function ensureBuiltinURLIndex()
    if builtinByURL then return builtinByURL end

    builtinByURL = {}
    for stationID, station in pairs( builtinStations ) do
        local url = station[BUILTIN_URL_INDEX]
        if url and not builtinByURL[url] then builtinByURL[url] = stationID end
    end

    return builtinByURL
end

local function registerCustomLookup( station )
    if not customByURL[station.url] then customByURL[station.url] = station.id end

    local nameCount = customLookupCount[station.name] or 0
    customLookupCount[station.name] = nameCount + 1
    if nameCount == 0 then customLookupID[station.name] = station.id end

    if station.url ~= station.name then
        local urlCount = customLookupCount[station.url] or 0
        customLookupCount[station.url] = urlCount + 1
        if urlCount == 0 then customLookupID[station.url] = station.id end
    end
end

local function findRemainingLookupID( key, removedStationID )
    for stationID, station in pairs( customStations ) do
        if stationID ~= removedStationID and ( station.name == key or station.url == key ) then return stationID end
    end

    return nil
end

local function findRemainingURLID( url, removedStationID )
    for stationID, station in pairs( customStations ) do
        if stationID ~= removedStationID and station.url == url then return stationID end
    end

    return nil
end

local function unregisterCustomLookup( station )
    if customByURL[station.url] == station.id then
        customByURL[station.url] = findRemainingURLID( station.url, station.id )
    end

    local nameCount = customLookupCount[station.name] or 0
    if nameCount <= 1 then
        customLookupCount[station.name] = nil
        customLookupID[station.name] = nil
    else
        customLookupCount[station.name] = nameCount - 1
        if nameCount == 2 then customLookupID[station.name] = findRemainingLookupID( station.name, station.id ) end
    end

    if station.url == station.name then return end

    local urlCount = customLookupCount[station.url] or 0
    if urlCount <= 1 then
        customLookupCount[station.url] = nil
        customLookupID[station.url] = nil
    else
        customLookupCount[station.url] = urlCount - 1
        if urlCount == 2 then customLookupID[station.url] = findRemainingLookupID( station.url, station.id ) end
    end
end

local function resolveCustomStationID( key, ambiguousMessage )
    key = string.Trim( tostring( key or "" ) )
    if customStations[key] then return key end

    local matchCount = customLookupCount[key] or 0
    if matchCount > 1 then return nil, ambiguousMessage end

    local stationID = customLookupID[key]
    if customStations[stationID] then return stationID end

    return nil, "Custom station not found"
end

local function registerCustomStation( station )
    local valid, reason = schema.ValidateStation( station )
    if not valid then return false, reason end
    if customStations[station.id] then return false, "Duplicate station ID" end

    customStations[station.id] = copyStation( station )
    registerCustomLookup( customStations[station.id] )
    return true
end

local function readCustomStations()
    local contents = file.Read( CUSTOM_STATIONS_FILE, "DATA" )
    local usedLegacyFile = false
    if not contents then
        contents = file.Read( LEGACY_CUSTOM_STATIONS_FILE, "DATA" )
        usedLegacyFile = contents ~= nil
    end

    if not contents then return {} end

    local decoded = util.JSONToTable( contents )
    if type( decoded ) ~= "table" then return {} end

    local stations = {}
    for _, row in ipairs( decoded ) do
        if type( row ) == "table" then
            if schema.ValidateStation( row ) and schema.IsCustomID( row.id ) then
                stations[#stations + 1] = row
            elseif type( row.name ) == "string" and type( row.url ) == "string" then
                stations[#stations + 1] = {
                    id = schema.MakeCustomID( util.CRC( row.name .. "\n" .. row.url ) ),
                    name = row.name,
                    url = row.url,
                    countryKey = rRadio.config.CustomStationCategory or "Custom",
                    source = rRadio.constants.Defaults.CustomStationSource
                }
            end
        elseif type( row ) == "string" then
            stations[#stations + 1] = {
                id = schema.MakeCustomID( util.CRC( row ) ),
                name = row,
                url = row,
                countryKey = rRadio.config.CustomStationCategory or "Custom",
                source = rRadio.constants.Defaults.CustomStationSource
            }
        end
    end

    if usedLegacyFile and #stations > 0 then
        timer.Simple( 0, writeCustomStations )
    end

    return stations
end

function writeCustomStations()
    file.CreateDir( "rradio" )

    local rows = {}
    for _, stationID in ipairs( customOrder ) do
        local station = customStations[stationID]
        if station then rows[#rows + 1] = copyStation( station ) end
    end

    file.Write( CUSTOM_STATIONS_FILE, util.TableToJSON( rows, true ) )
end

function registry.Init()
    builtinStations = expandGeneratedBuiltinStations()
    builtinByURL = nil
    customStations = {}
    customOrder = {}
    customByURL = {}
    customLookupID = {}
    customLookupCount = {}

    for _, station in ipairs( readCustomStations() ) do
        if schema.ValidateStation( station ) and schema.IsCustomID( station.id ) then
            local valid = registerCustomStation( station )
            if valid then customOrder[#customOrder + 1] = station.id end
        end
    end
end

function registry.Get( stationID )
    local station = customStations[stationID]
    if station then return copyStation( station ) end

    station = builtinStations[stationID]
    if not station then return nil end

    return copyBuiltinStation( stationID, station )
end

function registry.FindByURL( url )
    local stationID = ensureBuiltinURLIndex()[url]
    if stationID then return copyBuiltinStation( stationID, builtinStations[stationID] ) end

    stationID = customByURL[url]
    if stationID then return copyStation( customStations[stationID] ) end

    return nil
end

function registry.Exists( stationID )
    return builtinStations[stationID] ~= nil or customStations[stationID] ~= nil
end

function registry.ListBuiltin()
    local rows = {}
    for stationID, station in pairs( builtinStations ) do
        rows[#rows + 1] = copyBuiltinStation( stationID, station )
    end

    table.SortByMember( rows, "name", true )
    return rows
end

function registry.ListCustom()
    local rows = {}
    for _, stationID in ipairs( customOrder ) do
        local station = customStations[stationID]
        if station then rows[#rows + 1] = copyStation( station ) end
    end

    return rows
end

function registry.CountCustom()
    return #customOrder
end

function registry.ForEachCustom( callback )
    for _, stationID in ipairs( customOrder ) do
        local station = customStations[stationID]
        if station then callback( station ) end
    end
end

function registry.AddCustom( name, url, _actor )
    name = string.Trim( tostring( name or "" ) )
    url = string.Trim( tostring( url or "" ) )

    if not schema.IsValidURL( url ) then return false, "Invalid station URL" end
    if name == "" then return false, "Invalid station name" end

    if customByURL[url] then return false, "Custom station URL already exists" end

    local stationID = schema.MakeCustomID( util.CRC( name .. "\n" .. url ) )
    if customStations[stationID] then return false, "Custom station already exists" end

    local station = {
        id = stationID,
        name = string.sub( name, 1, rRadio.config.MaxNameChars or 40 ),
        url = url,
        countryKey = rRadio.config.CustomStationCategory or "Custom",
        source = rRadio.constants.Defaults.CustomStationSource
    }

    local valid, reason = registerCustomStation( station )
    if not valid then return false, reason end

    customOrder[#customOrder + 1] = stationID
    writeCustomStations()

    return true, copyStation( station )
end

function registry.EditCustom( stationID, name, url, _actor )
    stationID = string.Trim( tostring( stationID or "" ) )
    local current = customStations[stationID]
    if not current then return false, "Custom station not found" end

    name = string.Trim( tostring( name or "" ) )
    url = string.Trim( tostring( url or "" ) )

    if not schema.IsValidURL( url ) then return false, "Invalid station URL" end
    if name == "" then return false, "Invalid station name" end

    local existingURLStationID = customByURL[url]
    if existingURLStationID and existingURLStationID ~= stationID then
        return false, "Custom station URL already exists"
    end

    local station = {
        id = stationID,
        name = string.sub( name, 1, rRadio.config.MaxNameChars or 40 ),
        url = url,
        countryKey = rRadio.config.CustomStationCategory or "Custom",
        source = rRadio.constants.Defaults.CustomStationSource
    }

    local valid, reason = schema.ValidateStation( station )
    if not valid then return false, reason end

    unregisterCustomLookup( current )
    customStations[stationID] = copyStation( station )
    registerCustomLookup( customStations[stationID] )
    writeCustomStations()

    return true, copyStation( customStations[stationID] )
end

function registry.RemoveCustom( key )
    local stationID, reason = resolveCustomStationID(
        key,
        "Custom station name is ambiguous; remove by station ID or URL."
    )
    if not stationID then return false, reason end

    local removedStationID = stationID
    unregisterCustomLookup( customStations[stationID] )
    customStations[stationID] = nil
    for index = #customOrder, 1, -1 do
        if customOrder[index] == stationID then table.remove( customOrder, index ) end
    end

    writeCustomStations()
    return true, removedStationID
end

return registry
