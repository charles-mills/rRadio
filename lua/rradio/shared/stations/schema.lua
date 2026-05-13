rRadio = rRadio or {}
rRadio.stations = rRadio.stations or {}
rRadio.stations.schema = rRadio.stations.schema or {}

local schema = rRadio.stations.schema

schema.ID_PATTERN = "^[A-Za-z0-9_%-:%.]+$"
schema.BUILTIN_PREFIX = "builtin:"
schema.CUSTOM_PREFIX = "custom:"

local function isNonEmptyString( value )
    return type( value ) == "string" and value ~= ""
end

function schema.IsValidStationID( stationID )
    if not isNonEmptyString( stationID ) then return false end
    if #stationID > rRadio.net.protocol.Limits.StationID then return false end

    return string.match( stationID, schema.ID_PATTERN ) ~= nil
end

function schema.IsValidURL( url )
    if not isNonEmptyString( url ) then return false end
    if #url > rRadio.net.protocol.Limits.URL then return false end

    local lowerURL = string.lower( url )
    if string.StartWith( lowerURL, "http://" ) then return true end
    if string.StartWith( lowerURL, "https://" ) then return true end

    return string.StartWith( lowerURL, "mms://" )
end

function schema.ValidateStation( station )
    if type( station ) ~= "table" then return false, "Station must be a table" end
    if not schema.IsValidStationID( station.id ) then return false, "Invalid station ID" end
    if not isNonEmptyString( station.name ) then return false, "Invalid station name" end
    if not schema.IsValidURL( station.url ) then return false, "Invalid station URL" end
    if not isNonEmptyString( station.countryKey ) then return false, "Invalid country key" end
    if not isNonEmptyString( station.source ) then return false, "Invalid station source" end

    return true
end

local function slugify( value )
    local slug = string.lower( tostring( value or "" ) )
    slug = string.gsub( slug, "[^a-z0-9]+", "_" )
    slug = string.gsub( slug, "^_+", "" )
    slug = string.gsub( slug, "_+$", "" )

    if slug == "" then return "station" end

    return slug
end

function schema.MakeBuiltinID( countryKey, name, ordinal )
    return string.format(
        "%s%s:%s:%03d",
        schema.BUILTIN_PREFIX,
        slugify( countryKey ),
        slugify( name ),
        tonumber( ordinal ) or 1
    )
end

function schema.MakeCustomID( key )
    return schema.CUSTOM_PREFIX .. slugify( key )
end

function schema.IsCustomID( stationID )
    return type( stationID ) == "string" and string.StartWith( stationID, schema.CUSTOM_PREFIX )
end

return schema
