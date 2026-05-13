rRadio = rRadio or {}
rRadio.configSchema = rRadio.configSchema or {}

local schema = rRadio.configSchema
local catalog = rRadio.settingsCatalog
local definitions = {}
local definitionsByID = {}
local sections = {}
local sectionsByID = {}

local function copyValue( value )
    return catalog.CopyValue( value )
end

local function getPathValue( path )
    local cursor = rRadio.config
    for _, key in ipairs( path ) do
        if type( cursor ) ~= "table" then return nil end

        cursor = cursor[key]
    end

    return cursor
end

local function setPathValue( path, value )
    local cursor = rRadio.config
    for index = 1, #path - 1 do
        local key = path[index]
        if type( cursor[key] ) ~= "table" then cursor[key] = {} end

        cursor = cursor[key]
    end

    cursor[path[#path]] = value
end

local function addSection( section )
    local record = {
        id = section.id,
        labelKey = section.labelKey,
        labelFallback = section.labelFallback,
        rows = {}
    }

    sections[#sections + 1] = record
    sectionsByID[record.id] = record
end

local function addDefinition( setting )
    local definition = {
        id = setting.id,
        path = copyValue( setting.path ),
        scope = setting.scope,
        type = setting.type,
        control = setting.control,
        section = setting.section,
        labelKey = setting.labelKey,
        labelFallback = setting.labelFallback,
        helpKey = setting.helpKey,
        helpFallback = setting.helpFallback,
        minimum = setting.minimum,
        maximum = setting.maximum,
        decimals = setting.decimals,
        maxLength = setting.maxLength,
        required = setting.required,
        maxItems = setting.maxItems,
        itemMaxLength = setting.itemMaxLength,
        default = copyValue( getPathValue( setting.path ) )
    }

    definitions[#definitions + 1] = definition
    definitionsByID[definition.id] = definition

    local section = sectionsByID[definition.section]
    if section then section.rows[#section.rows + 1] = definition.id end
end

for _, section in ipairs( catalog.GetServerSections() ) do
    addSection( section )
end

for _, setting in ipairs( catalog.GetServerSettings() ) do
    addDefinition( setting )
end

local function clampNumber( value, minimum, maximum )
    if minimum ~= nil then value = math.max( value, minimum ) end
    if maximum ~= nil then value = math.min( value, maximum ) end

    return value
end

local function normalizeString( definition, value )
    local text = string.Trim( tostring( value or "" ) )
    local maxLength = tonumber( definition.maxLength )
    if maxLength and maxLength > 0 then text = string.sub( text, 1, maxLength ) end
    if definition.required and text == "" then return nil, "Value cannot be empty." end

    return text
end

local function normalizeList( definition, value )
    local rows = value
    if type( rows ) == "string" then rows = string.Explode( ",", rows ) end
    if type( rows ) ~= "table" then rows = {} end

    local result = {}
    local maxItems = tonumber( definition.maxItems ) or 64
    local maxLength = tonumber( definition.itemMaxLength ) or 64
    for _, item in ipairs( rows ) do
        if #result >= maxItems then break end

        local text = string.Trim( tostring( item or "" ) )
        if text ~= "" then result[#result + 1] = string.sub( text, 1, maxLength ) end
    end

    return result
end

local function normalizeVector( value )
    if isvector and isvector( value ) then return Vector( value.x, value.y, value.z ) end
    if type( value ) ~= "table" then return Vector( 0, 0, 0 ) end

    return Vector(
        tonumber( value.x or value[1] ) or 0,
        tonumber( value.y or value[2] ) or 0,
        tonumber( value.z or value[3] ) or 0
    )
end

function schema.GetDefinitions()
    return definitions
end

function schema.GetDefinition( id )
    return definitionsByID[tostring( id or "" )]
end

function schema.GetSections()
    return sections
end

function schema.GetValue( definition )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return nil end

    return getPathValue( definition.path )
end

function schema.GetDefault( definition )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return nil end

    return copyValue( definition.default )
end

function schema.NormalizeValue( definition, value )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return nil, "Unknown config setting." end

    if definition.type == "bool" then return value == true or value == 1 or value == "1" end
    if definition.type == "string" then return normalizeString( definition, value ) end
    if definition.type == "stringList" then return normalizeList( definition, value ) end
    if definition.type == "vector" then return normalizeVector( value ) end

    local numeric = tonumber( value )
    if not numeric then return nil, "Expected a number." end

    numeric = clampNumber( numeric, definition.minimum, definition.maximum )
    if definition.type == "integer" then return math.floor( numeric + 0.5 ) end

    local decimals = math.max( tonumber( definition.decimals ) or 0, 0 )
    if decimals <= 0 then return numeric end

    local multiplier = 10 ^ decimals
    return math.floor( numeric * multiplier + 0.5 ) / multiplier
end

function schema.SetValue( definition, value )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return false, "Unknown config setting." end

    local normalized, reason = schema.NormalizeValue( definition, value )
    if normalized == nil then return false, reason end

    setPathValue( definition.path, normalized )
    return true, normalized
end

function schema.ResetValue( definition )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return false, "Unknown config setting." end

    setPathValue( definition.path, schema.GetDefault( definition ) )
    return true, schema.GetValue( definition )
end

function schema.EncodeValue( definition, value )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return nil end

    if definition.type == "vector" then
        value = normalizeVector( value )
        return {
            x = value.x,
            y = value.y,
            z = value.z
        }
    end

    if definition.type == "stringList" then return normalizeList( definition, value ) end

    return value
end

function schema.EncodeJSON( definition, value )
    local encoded = schema.EncodeValue( definition, value )
    return util.TableToJSON( { value = encoded }, false ) or "{}"
end

function schema.DecodeJSON( definition, json )
    if type( definition ) == "string" then definition = schema.GetDefinition( definition ) end
    if not definition then return nil, "Unknown config setting." end

    local decoded = util.JSONToTable( tostring( json or "" ) )
    if type( decoded ) ~= "table" then return nil, "Invalid config payload." end

    return schema.NormalizeValue( definition, decoded.value )
end

return schema
