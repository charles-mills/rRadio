rRadio = rRadio or {}
rRadio.config = rRadio.config or {}

local config = rRadio.config
local catalog = rRadio.settingsCatalog

local function setPathDefault( setting )
    local path = setting.path
    local value = catalog.GetDefaultValue( setting )
    local cursor = config
    for index = 1, #path - 1 do
        local key = path[index]
        if type( cursor[key] ) ~= "table" then cursor[key] = {} end

        cursor = cursor[key]
    end

    local leaf = path[#path]
    if cursor[leaf] == nil then
        cursor[leaf] = catalog.CopyValue( value )
    elseif setting.type == "bool" and value == true then
        cursor[leaf] = cursor[leaf] ~= false
    end
end

local function applyConfigDefaults()
    for _, setting in ipairs( catalog.GetConfigSettings() ) do
        setPathDefault( setting )
    end
end

local function mergeClientConVars( generated, existing )
    if type( existing ) ~= "table" then return generated end

    local seenIDs = {}
    local seenNames = {}
    for _, definition in ipairs( generated ) do
        seenIDs[definition.id] = true
        seenNames[definition.name] = true
    end

    for _, definition in ipairs( existing ) do
        if type( definition ) == "table" and definition.name
            and not seenIDs[definition.id]
            and not seenNames[definition.name]
        then
            generated[#generated + 1] = definition
        end
    end

    return generated
end

local existingClientConVars = config.ClientConVars
applyConfigDefaults()
config.ClientConVars = mergeClientConVars( catalog.GetClientConVarDefinitions(), existingClientConVars )

local clientConVarsByID

local function rebuildClientConVarIndex()
    clientConVarsByID = {}

    for _, definition in ipairs( config.ClientConVars or {} ) do
        if type( definition ) == "table" and definition.id and definition.name then
            clientConVarsByID[definition.id] = definition
        end
    end
end

function rRadio.GetClientConVarDefinition( id )
    if not clientConVarsByID then rebuildClientConVarIndex() end

    return clientConVarsByID[tostring( id or "" )]
end

function rRadio.GetClientConVarName( id )
    local definition = rRadio.GetClientConVarDefinition( id )
    if not definition then return nil end

    return definition.name
end

if SERVER then
    CreateConVar(
        "rammel_rradio_debug_logging",
        "0",
        FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "Enable debug logging for rRadio on both server and clients."
    )

    CreateConVar(
        "rammel_rradio_debug_store",
        "0",
        FCVAR_ARCHIVE,
        "Write captured rRadio debug logs to garrysmod/data/rradio/debug/runs during server shutdown."
    )

    CreateConVar(
        "rammel_rradio_logging",
        "0",
        FCVAR_ARCHIVE,
        "Enable server-side rRadio integration logging when supported."
    )
end

function rRadio.AddClientConVars()
    if SERVER then return false end

    for _, definition in ipairs( config.ClientConVars or {} ) do
        if type( definition ) == "table" and definition.name then
            CreateClientConVar( definition.name, tostring( definition.default or "" ), true, false )
        end
    end

    return true
end

return config
