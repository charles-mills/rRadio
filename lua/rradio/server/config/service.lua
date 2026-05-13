rRadio = rRadio or {}
rRadio.configManager = rRadio.configManager or {}
rRadio.configManager.service = rRadio.configManager.service or {}

local service = rRadio.configManager.service
local schema = rRadio.configSchema
local protocol = rRadio.net.protocol
local messages = protocol.Messages

local TABLE_NAME = "rradio_config"
local storagePrepared = false
local RADIO_VOLUME_CONFIGS = {
    { id = "Boombox.Volume", section = "Boombox" },
    { id = "GoldenBoombox.Volume", section = "GoldenBoombox" },
    { id = "VehicleRadio.Volume", section = "VehicleRadio" }
}
local RADIO_VOLUME_CONFIG_BY_ID = {}

for _, config in ipairs( RADIO_VOLUME_CONFIGS ) do
    RADIO_VOLUME_CONFIG_BY_ID[config.id] = config.section
end


local function query( sqlText )
    local result = sql.Query( sqlText )
    if result == false then
        rRadio.logger.WarnScope( "config", sql.LastError() or "unknown SQL error" )
    end

    return result
end


local function escape( value )
    return sql.SQLStr( tostring( value or "" ) )
end


local function actorID( actor )
    if not IsValid( actor ) then return "server" end
    if actor.SteamID64 then return actor:SteamID64() end
    if actor.SteamID then return actor:SteamID() end

    return tostring( actor )
end


local function prepareStorage()
    if storagePrepared then return true end

    local created = query( string.format( [[
    CREATE TABLE IF NOT EXISTS %s (
        id TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_by TEXT NOT NULL,
        updated_at INTEGER NOT NULL
    )
    ]], TABLE_NAME ) )

    storagePrepared = created ~= false
    return storagePrepared
end


local function getResultJSON( id )
    local definition = schema.GetDefinition( id )
    if not definition then return "{}" end

    return schema.EncodeJSON( definition, schema.GetValue( definition ) )
end


local function sendResult( player, id, success, message )
    if not IsValid( player ) then return end

    net.Start( messages.ConfigSetResult )
    protocol.WriteVersion()
    protocol.WriteConfigID( id )
    net.WriteBool( success == true )
    net.WriteString( protocol.LimitDisplayName( message or "" ) )
    protocol.WriteConfigValue( getResultJSON( id ) )
    net.Send( player )
end


local function writeValue( definition )
    protocol.WriteConfigID( definition.id )
    protocol.WriteConfigValue( schema.EncodeJSON( definition, schema.GetValue( definition ) ) )
end


function service.WriteSnapshotPayload( targetPlayer )
    local definitions = schema.GetDefinitions()
    net.WriteBool( rRadio.radio.permissions.CanManageConfig( targetPlayer ) )
    local count = math.min( #definitions, protocol.Limits.ConfigCount )
    net.WriteUInt( count, 16 )
    for index = 1, count do
        writeValue( definitions[index] )
    end
end


function service.SendSnapshot( targetPlayer )
    if not IsValid( targetPlayer ) then return end

    net.Start( messages.ConfigSnapshot )
    protocol.WriteVersion()
    service.WriteSnapshotPayload( targetPlayer )
    net.Send( targetPlayer )
end


function service.BroadcastSnapshot( target )
    if IsValid( target ) then
        service.SendSnapshot( target )
        return
    end

    for _, targetPlayer in player.Iterator() do
        service.SendSnapshot( targetPlayer )
    end
end


local function entityConfigKey( entity )
    if not IsValid( entity ) then return nil end
    if rRadio.util.IsBoomboxClass( entity:GetClass() ) then return entity.ConfigKey end
    if rRadio.vehicle.IsRadioHost( entity ) then return "VehicleRadio" end

    return nil
end


local function applyVolumeDefault( entity, configKey )
    local config = rRadio.config[configKey]
    if not config then return end
    if rRadio.radio.stateStore.Get( entity ) then return end

    local volume = rRadio.util.ClampVolume( config.Volume or 1 )
    local state = rRadio.radio.stateStore.SetDefaultVolume( entity, volume )
    rRadio.radio.snapshots.BroadcastSettings( state )
end


local function applyRadioDefaultVolumes( configKey )
    for _, entity in ents.Iterator() do
        if entityConfigKey( entity ) == configKey then applyVolumeDefault( entity, configKey ) end
    end
end


local function clampExistingVolumes()
    local snapshots = rRadio.radio.snapshots
    rRadio.radio.stateStore.ForEach( function( state )
        if not IsValid( state.entity ) then return end

        local volume = rRadio.util.ClampVolume( state.volume )
        if volume == state.volume then return end

        snapshots.BroadcastVolume( rRadio.radio.stateStore.SetVolume( state.entity, volume ) )
    end )

    for _, entity in ents.Iterator() do
        if entityConfigKey( entity ) and not rRadio.radio.stateStore.Get( entity ) then
            local current = rRadio.radio.stateStore.GetDefaultVolume( entity )
            local volume = rRadio.util.ClampVolume( current )
            if volume ~= current then
                snapshots.BroadcastSettings( rRadio.radio.stateStore.SetDefaultVolume( entity, volume ) )
            end
        end
    end
end


local function containsID( ids, id )
    for _, changedID in ipairs( ids ) do
        if changedID == id then return true end
    end

    return false
end


local function applyRuntimeEffects( id )
    hook.Run( "rRadio_ConfigChanged", id )

    if RADIO_VOLUME_CONFIG_BY_ID[id] then applyRadioDefaultVolumes( RADIO_VOLUME_CONFIG_BY_ID[id] ) end
    if id == "MaxVolume" then clampExistingVolumes() end
end


local function applyRuntimeEffectsBatch( ids )
    for _, id in ipairs( ids ) do
        applyRuntimeEffects( id )
    end

    service.BroadcastSnapshot()

    if containsID( ids, "CustomStationCategory" ) then
        rRadio.radio.snapshots.BroadcastCustomStations()
    end
end


local function persistOverride( actor, definition, value )
    local json = schema.EncodeJSON( definition, value )

    return query( string.format(
        "REPLACE INTO %s (id, value, updated_by, updated_at) VALUES (%s, %s, %s, %d)",
        TABLE_NAME,
        escape( definition.id ),
        escape( json ),
        escape( actorID( actor ) ),
        os.time()
    ) ) ~= false
end


local function removeOverride( definition )
    return query( string.format(
        "DELETE FROM %s WHERE id = %s",
        TABLE_NAME,
        escape( definition.id )
    ) ) ~= false
end


local function isDefaultValue( definition, value )
    return schema.EncodeJSON( definition, value ) == schema.EncodeJSON( definition, schema.GetDefault( definition ) )
end


function service.SetOverride( actor, id, value )
    if not prepareStorage() then return false, "Could not prepare config storage." end

    local definition = schema.GetDefinition( id )
    if not definition then return false, "Unknown config setting." end

    local previous = schema.GetValue( definition )
    local ok, normalized = schema.SetValue( definition, value )
    if not ok then return false, tostring( normalized or "Invalid value." ) end

    local saved = isDefaultValue( definition, normalized ) and removeOverride( definition )
        or persistOverride( actor, definition, normalized )

    if not saved then
        schema.SetValue( definition, previous )
        return false, "Could not save config override."
    end

    applyRuntimeEffectsBatch( { definition.id } )
    return true, "Config updated."
end


function service.ResetOverride( actor, id )
    if not prepareStorage() then return false, "Could not prepare config storage." end

    local definition = schema.GetDefinition( id )
    if not definition then return false, "Unknown config setting." end

    local previous = schema.GetValue( definition )
    local ok, value = schema.ResetValue( definition )
    if not ok then return false, tostring( value or "Could not reset config setting." ) end

    if not removeOverride( definition ) then
        schema.SetValue( definition, previous )
        return false, "Could not remove config override."
    end

    applyRuntimeEffectsBatch( { definition.id } )
    rRadio.logger.Info( "Config reset by", actorID( actor ), definition.id )
    return true, "Config reset."
end


function service.ResetAll( actor )
    if not prepareStorage() then return false, "Could not prepare config storage." end
    if query( "DELETE FROM " .. TABLE_NAME ) == false then return false, "Could not clear config overrides." end

    local changedIDs = {}
    for _, definition in ipairs( schema.GetDefinitions() ) do
        schema.ResetValue( definition )
        changedIDs[#changedIDs + 1] = definition.id
    end

    applyRuntimeEffectsBatch( changedIDs )
    rRadio.logger.WarnScope( "config", "All config overrides reset by", actorID( actor ) )
    return true, "All config overrides reset."
end


local function loadOverrides()
    if not prepareStorage() then return false end

    local rows = query( "SELECT id, value FROM " .. TABLE_NAME )
    if not rows then return true end

    for _, row in ipairs( rows ) do
        local definition = schema.GetDefinition( row.id )
        if definition then
            local value = schema.DecodeJSON( definition, row.value )
            if value ~= nil then
                schema.SetValue( definition, value )
            else
                rRadio.logger.WarnScope( "config", "Ignoring invalid override for", row.id )
            end
        end
    end

    return true
end


local function receiveSetRequest( _length, actor )
    if not protocol.ReadClientVersion() then return end

    local id = protocol.ReadConfigID()
    local json = protocol.ReadConfigValue()
    if not rRadio.radio.permissions.CanManageConfig( actor ) then
        sendResult( actor, id, false, "You do not have permission to manage rRadio config." )
        return
    end

    local definition = schema.GetDefinition( id )
    local value, reason = schema.DecodeJSON( definition, json )
    if value == nil then
        sendResult( actor, id, false, reason or "Invalid config value." )
        return
    end

    local ok, message = service.SetOverride( actor, id, value )
    sendResult( actor, id, ok, message )
end


local function receiveResetRequest( _length, actor )
    if not protocol.ReadClientVersion() then return end

    local id = protocol.ReadConfigID()
    if not rRadio.radio.permissions.CanManageConfig( actor ) then
        sendResult( actor, id, false, "You do not have permission to manage rRadio config." )
        return
    end

    local ok, message
    if id == "*" then
        ok, message = service.ResetAll( actor )
    else
        ok, message = service.ResetOverride( actor, id )
    end

    sendResult( actor, id, ok, message )
end


function service.RegisterReceivers()
    net.Receive( messages.ConfigSetRequest, receiveSetRequest )
    net.Receive( messages.ConfigResetRequest, receiveResetRequest )
end


function service.Init()
    loadOverrides()
end


return service
