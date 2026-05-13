rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.net = rRadio.client.net or {}
rRadio.client.net.handlers = rRadio.client.net.handlers or {}

local handlers = rRadio.client.net.handlers
local protocol = rRadio.net.protocol
local messages = protocol.Messages
local enabledConVar = GetConVar( "rammel_rradio_enabled" )
local SNAPSHOT_INITIAL_HOOK = "rRadio_Net_RequestInitialStateSnapshot"
local SNAPSHOT_RELOAD_HOOK = "rRadio_Net_RequestReloadStateSnapshot"
local SNAPSHOT_RETRY_TIMER = "rRadio_Net_RetryStateSnapshot"
local SNAPSHOT_RETRY_DELAYS = { 0.5, 1, 2, 4, 8 }
local ENTITY_SYNC_TIMER = "rRadio_Net_RequestEntityStateSnapshot"
local ENTITY_SYNC_CREATED_HOOK = "rRadio_Net_RequestCreatedEntityState"
local ENTITY_SYNC_TRANSMIT_HOOK = "rRadio_Net_RequestTransmitEntityState"
local ENTITY_SYNC_DELAY = 0.05
local ENTITY_SYNC_INTERVAL = 1
local snapshotRetryAttempts = 0
local queuedEntitySync = setmetatable( {}, { __mode = "k" } )
local entitySyncTimes = setmetatable( {}, { __mode = "k" } )

local function resetSnapshotRetries()
    snapshotRetryAttempts = 0
    timer.Remove( SNAPSHOT_RETRY_TIMER )
end

local function scheduleSnapshotRetry( reason )
    if timer.Exists( SNAPSHOT_RETRY_TIMER ) then return end

    if snapshotRetryAttempts >= #SNAPSHOT_RETRY_DELAYS then
        rRadio.logger.DebugScope( "net", "State snapshot retry limit reached", tostring( reason or "unknown" ) )
        return
    end

    snapshotRetryAttempts = snapshotRetryAttempts + 1
    local delay = SNAPSHOT_RETRY_DELAYS[snapshotRetryAttempts]
    rRadio.logger.DebugScope(
        "net",
        "Scheduling state snapshot retry",
        snapshotRetryAttempts,
        delay,
        tostring( reason or "unknown" )
    )

    timer.Create( SNAPSHOT_RETRY_TIMER, delay, 1, function()
        handlers.RequestStateSnapshot( reason or "retry" )
    end )
end

function handlers.RequestPlay( entity, stationID, volume )
    if not IsValid( entity ) then return false end

    local requestedVolume = volume or rRadio.client.radio.state.GetVolume( entity )
    net.Start( messages.SelectStationRequest )
    protocol.WriteVersion()
    net.WriteEntity( entity )
    protocol.WriteStationID( stationID )
    net.WriteFloat( rRadio.util.ClampVolume( requestedVolume ) )
    net.SendToServer()

    return true
end

function handlers.RequestStop( entity )
    if not IsValid( entity ) then return false end

    net.Start( messages.StopRequest )
    protocol.WriteVersion()
    net.WriteEntity( entity )
    net.SendToServer()

    return true
end

function handlers.RequestVolume( entity, volume )
    if not IsValid( entity ) then return false end

    net.Start( messages.VolumeRequest )
    protocol.WriteVersion()
    net.WriteEntity( entity )
    net.WriteFloat( rRadio.util.ClampVolume( volume ) )
    net.SendToServer()

    return true
end

function handlers.RequestPersistence( entity, permanent )
    if not IsValid( entity ) then return false end

    net.Start( messages.PersistenceRequest )
    protocol.WriteVersion()
    net.WriteEntity( entity )
    net.WriteBool( permanent )
    net.SendToServer()

    return true
end

function handlers.RequestPublicAccess( entity, public )
    if not IsValid( entity ) then return false end

    net.Start( messages.PublicAccessRequest )
    protocol.WriteVersion()
    net.WriteEntity( entity )
    net.WriteBool( public == true )
    net.SendToServer()

    return true
end

function handlers.RequestAddCustomStation( name, url )
    net.Start( messages.AddCustomStationRequest )
    protocol.WriteVersion()
    net.WriteString( protocol.LimitDisplayName( name ) )
    net.WriteString( protocol.LimitString( url, protocol.Limits.URL ) )
    net.SendToServer()
end

function handlers.RequestEditCustomStation( stationID, name, url )
    net.Start( messages.EditCustomStationRequest )
    protocol.WriteVersion()
    protocol.WriteStationID( stationID )
    net.WriteString( protocol.LimitDisplayName( name ) )
    net.WriteString( protocol.LimitString( url, protocol.Limits.URL ) )
    net.SendToServer()
end

function handlers.RequestRemoveCustomStation( key )
    net.Start( messages.RemoveCustomStationRequest )
    protocol.WriteVersion()
    net.WriteString( protocol.LimitString( key, protocol.Limits.CustomStationKey ) )
    net.SendToServer()
end

function handlers.RequestConfigSet( id, json )
    net.Start( messages.ConfigSetRequest )
    protocol.WriteVersion()
    protocol.WriteConfigID( id )
    protocol.WriteConfigValue( json or "{}" )
    net.SendToServer()
end

function handlers.RequestConfigReset( id )
    net.Start( messages.ConfigResetRequest )
    protocol.WriteVersion()
    protocol.WriteConfigID( id )
    net.SendToServer()
end

local function resolveRadioEntity( entity )
    entity = rRadio.util.GetRadioEntity( entity, LocalPlayer() )
    if not IsValid( entity ) then return nil end

    return entity
end

local function addRadioEntity( entities, seen, entity )
    entity = resolveRadioEntity( entity )
    if not IsValid( entity ) or seen[entity] then return end

    seen[entity] = true
    entities[#entities + 1] = entity
end

local function collectRadioEntities()
    local entities = {}
    local seen = {}
    for _, entity in ipairs( ents.GetAll() ) do
        addRadioEntity( entities, seen, entity )
    end

    return entities
end

local function sendStateSnapshotRequest( entities, reason, options )
    if type( options ) ~= "table" then options = {} end
    entities = entities or {}

    local seen = {}
    local requested = {}
    local limit = protocol.Limits.StateRequestCount
    for _, entity in ipairs( entities ) do
        addRadioEntity( requested, seen, entity )
        if #requested >= limit then break end
    end

    net.Start( messages.StateSnapshotRequest )
    protocol.WriteVersion()
    net.WriteBool( options.includeMetadata == true )
    net.WriteUInt( #requested, 16 )
    for _, entity in ipairs( requested ) do
        net.WriteEntity( entity )
        entitySyncTimes[entity] = SysTime()
    end
    net.SendToServer()

    rRadio.logger.DebugScope(
        "net",
        "Requested state snapshot",
        tostring( reason or "client" ),
        #requested
    )
    return true
end

local function flushQueuedEntitySync()
    local entities = {}
    for entity in pairs( queuedEntitySync ) do
        queuedEntitySync[entity] = nil
        if IsValid( entity ) then entities[#entities + 1] = entity end
    end

    if #entities == 0 then return end
    sendStateSnapshotRequest( entities, "entity_available" )
end

function handlers.QueueEntityStateSync( entity, reason, options )
    entity = resolveRadioEntity( entity )
    if not IsValid( entity ) then return false end

    if type( options ) ~= "table" then options = {} end
    local now = SysTime()
    if options.force ~= true and now - ( entitySyncTimes[entity] or 0 ) < ENTITY_SYNC_INTERVAL then return false end

    if options.immediate == true then
        queuedEntitySync[entity] = nil
        return sendStateSnapshotRequest( { entity }, reason or "entity", options )
    end

    queuedEntitySync[entity] = true
    timer.Create( ENTITY_SYNC_TIMER, ENTITY_SYNC_DELAY, 1, flushQueuedEntitySync )
    return true
end

function handlers.RequestStateSnapshot( reason, options )
    return sendStateSnapshotRequest( collectRadioEntities(), reason, options )
end

local function getAssignmentForAudio( state )
    if not state or not IsValid( state.entity ) or not state.assignment then return nil end

    return {
        entity = state.entity,
        revision = state.revision,
        stationID = state.assignment.stationID,
        stationName = state.assignment.stationName,
        url = state.assignment.url,
        volume = state.assignment.volume
    }
end

local function updateUIForAssignment( assignment, options )
    local recordedRecent = false
    if not options or options.recordRecent ~= false then
        recordedRecent = rRadio.client.stations.recent.RecordAcceptedStation(
            assignment.entity,
            assignment.stationID
        )
    end

    local state = rRadio.client.ui.state
    if rRadio.util.GetRadioEntity( state.currentEntity ) == assignment.entity then
        state.selectedStationID = assignment.stationID
        if state.pendingStationID == assignment.stationID then state.pendingStationID = nil end
    end
    if recordedRecent
        and IsValid( state.frame )
        and state.viewMode == rRadio.client.ui.menu.viewModel.Views.RECENTS then
        rRadio.client.ui.menu.controller.Refresh()
    end
end

local function applyRadioState( state, invalidReason, options )
    if not state or not IsValid( state.entity ) then
        scheduleSnapshotRetry( invalidReason )
        return
    end

    if not rRadio.client.radio.state.ApplyState( state ) then return end

    local assignment = getAssignmentForAudio( state )
    if assignment then
        rRadio.client.audio.manager.ApplyAssignment( assignment )
        if not options or options.updateStationSelection ~= false then
            updateUIForAssignment( assignment, options )
        end
        return
    end

    rRadio.client.audio.manager.ClearAssignment( state.entity )

    local uiState = rRadio.client.ui.state
    if rRadio.util.GetRadioEntity( uiState.currentEntity ) == state.entity then
        uiState.selectedStationID = nil
        uiState.pendingStationID = nil
    end
end

local function receiveAssignment()
    if not protocol.ReadClientVersion() then return end

    applyRadioState( protocol.ReadRadioState(), "invalid_assignment_entity" )
end

local function receiveClear()
    if not protocol.ReadClientVersion() then return end

    applyRadioState( protocol.ReadRadioState(), "invalid_clear_entity" )
end

local function receiveVolume()
    if not protocol.ReadClientVersion() then return end

    applyRadioState( protocol.ReadRadioState(), "invalid_volume_entity", {
        updateStationSelection = false
    } )
end

local function receiveSettings()
    if not protocol.ReadClientVersion() then return end

    applyRadioState( protocol.ReadRadioState(), "invalid_settings_entity", {
        updateStationSelection = false
    } )
end

local function receiveSnapshot()
    if not protocol.ReadClientVersion() then return end

    local count = math.min( net.ReadUInt( 16 ), protocol.Limits.ActiveStateCount )
    local invalidCount = 0
    for _ = 1, count do
        local state = protocol.ReadRadioState()
        if IsValid( state.entity ) then
            applyRadioState( state, "invalid_snapshot_entity", {
                recordRecent = false
            } )
        else
            invalidCount = invalidCount + 1
        end
    end

    if invalidCount > 0 then
        rRadio.logger.DebugScope( "net", "State snapshot had unresolved entities", invalidCount, count )
        scheduleSnapshotRetry( "invalid_snapshot_entities" )
    else
        resetSnapshotRetries()
    end
end

local function receiveCustomStations()
    if not protocol.ReadClientVersion() then return end

    local canManage = net.ReadBool()
    local count = math.min( net.ReadUInt( 16 ), protocol.Limits.CustomStationCount )
    local stations = {}
    for _ = 1, count do
        stations[#stations + 1] = protocol.ReadCustomStationMetadata( canManage )
    end

    rRadio.client.stations.catalog.ApplyCustomStations( stations )

    local state = rRadio.client.ui.state
    state.canManageCustomStations = canManage

    if IsValid( state.frame ) then
        timer.Simple( 0, function()
            rRadio.client.ui.menu.controller.Refresh()
        end )
    end
end

local function receiveCustomStationResult()
    if not protocol.ReadClientVersion() then return end

    local action = net.ReadString()
    local success = net.ReadBool()
    local message = net.ReadString()
    local state = rRadio.client.ui.state
    state.customStationNotice = {
        action = action,
        success = success,
        message = message,
        expiresAt = CurTime() + 5
    }

    local color = success and Color( 0, 220, 120 ) or Color( 248, 81, 73 )
    chat.AddText( Color( 58, 114, 255 ), "[rRadio] ", color, message )

    timer.Simple( 0, function()
        rRadio.client.ui.menu.controller.Refresh()
    end )
end

local function receiveConfigSnapshot()
    if not protocol.ReadClientVersion() then return end

    local options = handlers.ApplyConfigSnapshotPayload()
    hook.Run( "rRadio_ConfigChanged", nil, options )
end

function handlers.ApplyConfigSnapshotPayload()
    local state = rRadio.client.ui.state
    local canManageConfig = net.ReadBool()
    local permissionsChanged = state.canManageConfig ~= canManageConfig
    state.canManageConfig = canManageConfig

    local count = math.min( net.ReadUInt( 16 ), protocol.Limits.ConfigCount )
    for _ = 1, count do
        local id = protocol.ReadConfigID()
        local json = protocol.ReadConfigValue()
        local definition = rRadio.configSchema.GetDefinition( id )
        local value = rRadio.configSchema.DecodeJSON( definition, json )
        if value ~= nil then rRadio.configSchema.SetValue( definition, value ) end
    end

    return {
        permissionsChanged = permissionsChanged
    }
end

local function receiveConfigSetResult()
    if not protocol.ReadClientVersion() then return end

    local id = protocol.ReadConfigID()
    local success = net.ReadBool()
    local message = net.ReadString()
    local json = protocol.ReadConfigValue()
    local definition = rRadio.configSchema.GetDefinition( id )
    local value = rRadio.configSchema.DecodeJSON( definition, json )
    if value ~= nil then
        rRadio.configSchema.SetValue( definition, value )
        hook.Run( "rRadio_ConfigChanged", id )
    end

    if success then return end

    chat.AddText( Color( 58, 114, 255 ), "[rRadio] ", Color( 248, 81, 73 ), message )
end

local function showEnablePrompt( entity, canSetPublic )
    if not rRadio.util.IsBoomboxClass( entity:GetClass() ) then return end

    rRadio.client.ui.dialogs.ShowFrame( {
        title = rRadio.L( "EnableRRadioPromptTitle", "Enable rRadio?" ),
        message = rRadio.L(
            "EnableRRadioPromptMessage",
            "rRadio is disabled. Enable it to open this boombox radio menu."
        ),
        confirmText = rRadio.L( "EnableRRadioPromptAction", "Enable" ),
        onConfirm = function()
            RunConsoleCommand( "rammel_rradio_enabled", "1" )

            timer.Simple( 0, function()
                if not IsValid( entity ) then return end

                local state = rRadio.client.ui.state
                state.currentEntity = entity
                state.canSetBoomboxPublic = canSetPublic == true
                rRadio.client.ui.menu.controller.Open()
            end )
        end
    } )
end

local function receiveOpenMenu()
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    if not IsValid( entity ) then return end

    local canSetPublic = net.ReadBool()
    handlers.ApplyConfigSnapshotPayload()

    if not enabledConVar:GetBool() then
        showEnablePrompt( entity, canSetPublic )
        return
    end

    rRadio.client.ui.state.currentEntity = entity
    rRadio.client.ui.state.canSetBoomboxPublic = canSetPublic
    rRadio.client.ui.menu.controller.Open()
end

local function receiveVehicleAnimation()
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local isDriver = net.ReadBool()
    if not IsValid( entity ) then return end

    rRadio.client.ui.vehicleHint.Show( entity, isDriver )
end

local function receivePersistenceResult()
    if not protocol.ReadClientVersion() then return end

    local success = net.ReadBool()
    net.ReadBool()
    local message = net.ReadString()
    local entity = net.ReadEntity()
    local color = success and Color( 0, 220, 120 ) or Color( 248, 81, 73 )
    chat.AddText( Color( 58, 114, 255 ), "[rRadio] ", color, message )

    local state = rRadio.client.ui.state
    if rRadio.util.GetRadioEntity( state.currentEntity ) == entity then
        timer.Simple( 0, function()
            rRadio.client.ui.menu.controller.Refresh()
        end )
    end
end

local function receivePublicAccessResult()
    if not protocol.ReadClientVersion() then return end

    local success = net.ReadBool()
    net.ReadBool()
    local message = net.ReadString()
    local entity = net.ReadEntity()
    local color = success and Color( 0, 220, 120 ) or Color( 248, 81, 73 )
    chat.AddText( Color( 58, 114, 255 ), "[rRadio] ", color, message )

    local state = rRadio.client.ui.state
    if rRadio.util.GetRadioEntity( state.currentEntity ) == entity then
        timer.Simple( 0, function()
            rRadio.client.ui.menu.controller.Refresh()
        end )
    end
end

local function requestInitialSnapshot()
    resetSnapshotRetries()
    handlers.RequestStateSnapshot( "init_post_entity", {
        includeMetadata = true
    } )
end

local function requestReloadSnapshot()
    resetSnapshotRetries()
    timer.Simple( 0, function()
        handlers.RequestStateSnapshot( "client_reload", {
            includeMetadata = true
        } )
    end )
end

local function queueCreatedEntitySync( entity )
    timer.Simple( 0, function()
        handlers.QueueEntityStateSync( entity, "entity_created" )
    end )
end

local function queueTransmitEntitySync( entity, shouldTransmit )
    if shouldTransmit then handlers.QueueEntityStateSync( entity, "entity_transmit" ) end
end

function handlers.Init()
    net.Receive( messages.AssignmentBroadcast, receiveAssignment )
    net.Receive( messages.ClearBroadcast, receiveClear )
    net.Receive( messages.VolumeBroadcast, receiveVolume )
    net.Receive( messages.SettingsBroadcast, receiveSettings )
    net.Receive( messages.StateSnapshot, receiveSnapshot )
    net.Receive( messages.CustomStations, receiveCustomStations )
    net.Receive( messages.CustomStationResult, receiveCustomStationResult )
    net.Receive( messages.OpenMenu, receiveOpenMenu )
    net.Receive( messages.VehicleAnimation, receiveVehicleAnimation )
    net.Receive( messages.PublicAccessResult, receivePublicAccessResult )
    net.Receive( messages.PersistenceResult, receivePersistenceResult )
    net.Receive( messages.ConfigSnapshot, receiveConfigSnapshot )
    net.Receive( messages.ConfigSetResult, receiveConfigSetResult )

    hook.Add( "InitPostEntity", SNAPSHOT_INITIAL_HOOK, requestInitialSnapshot )
    hook.Add( "OnReloaded", SNAPSHOT_RELOAD_HOOK, requestReloadSnapshot )
    hook.Add( "OnEntityCreated", ENTITY_SYNC_CREATED_HOOK, queueCreatedEntitySync )
    hook.Add( "NotifyShouldTransmit", ENTITY_SYNC_TRANSMIT_HOOK, queueTransmitEntitySync )

    concommand.Remove( "rammel_rradio_request_snapshot" )
    concommand.Add( "rammel_rradio_request_snapshot", function()
        resetSnapshotRetries()
        handlers.RequestStateSnapshot( "manual_command", {
            includeMetadata = true
        } )
    end, nil, "Request rRadio state for currently resolved radios.", FCVAR_CLIENTCMD_CAN_EXECUTE )

end

return handlers
