rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.snapshots = rRadio.radio.snapshots or {}

local snapshots = rRadio.radio.snapshots
local protocol = rRadio.net.protocol
local messages = protocol.Messages
local registry = rRadio.stations.registry
local stateStore = rRadio.radio.stateStore
local permissions = rRadio.radio.permissions


local function resolveEntityState( entityOrState )
    if not entityOrState then return nil end
    if entityOrState.settings then return entityOrState end
    if entityOrState.entity then return stateStore.GetEntityState( entityOrState.entity ) end

    return stateStore.GetEntityState( entityOrState )
end


function snapshots.FromState( state )
    if not state or not state.assignment then return nil end

    return {
        entity = state.entity,
        revision = state.revision,
        stationID = state.assignment.stationID,
        stationName = state.assignment.stationName,
        url = state.assignment.url,
        volume = state.assignment.volume
    }
end


local function sendState( messageName, state, targetPlayer )
    if not state then return end

    net.Start( messageName )
    protocol.WriteVersion()
    protocol.WriteRadioState( state )
    if IsValid( targetPlayer ) then
        net.Send( targetPlayer )
    else
        net.Broadcast()
    end
end


local function broadcastState( messageName, state )
    sendState( messageName, state )
end


function snapshots.BroadcastAssignment( state )
    broadcastState( messages.AssignmentBroadcast, resolveEntityState( state ) )
end


function snapshots.BroadcastClear( entity )
    broadcastState( messages.ClearBroadcast, resolveEntityState( entity ) )
end


function snapshots.BroadcastVolume( entityOrState )
    broadcastState( messages.VolumeBroadcast, resolveEntityState( entityOrState ) )
end


function snapshots.BroadcastSettings( entityOrState )
    broadcastState( messages.SettingsBroadcast, resolveEntityState( entityOrState ) )
end


local function sendCustomStations( targetPlayer )
    if not IsValid( targetPlayer ) then return end

    local count = math.min( registry.CountCustom(), protocol.Limits.CustomStationCount )
    local written = 0
    local canManage = permissions.CanManageCustomStations( targetPlayer )

    net.Start( messages.CustomStations )
    protocol.WriteVersion()
    net.WriteBool( canManage )
    net.WriteUInt( count, 16 )
    registry.ForEachCustom( function( station )
        if written >= count then return end

        written = written + 1
        protocol.WriteCustomStationMetadata( station, canManage )
    end )
    net.Send( targetPlayer )
end


function snapshots.BroadcastCustomStations( target )
    if IsValid( target ) then
        sendCustomStations( target )
        return
    end

    for _, targetPlayer in player.Iterator() do
        sendCustomStations( targetPlayer )
    end
end


function snapshots.SendStateSnapshot( targetPlayer, entities )
    if not IsValid( targetPlayer ) then return end

    local states = {}
    local seen = {}
    local limit = protocol.Limits.ActiveStateCount
    for _, entity in ipairs( entities or {} ) do
        if IsValid( entity ) and not seen[entity] then
            local state = stateStore.GetEntityState( entity )
            if state then
                seen[entity] = true
                states[#states + 1] = state
            end
        end

        if #states >= limit then break end
    end

    net.Start( messages.StateSnapshot )
    protocol.WriteVersion()
    net.WriteUInt( #states, 16 )
    for _, state in ipairs( states ) do
        protocol.WriteRadioState( state )
    end
    net.Send( targetPlayer )
end


function snapshots.SyncToPlayer( targetPlayer, entities, options )
    if not IsValid( targetPlayer ) then return end
    if type( options ) ~= "table" then options = {} end

    if options.includeMetadata == true then
        rRadio.configManager.service.SendSnapshot( targetPlayer )
        snapshots.BroadcastCustomStations( targetPlayer )
    end

    snapshots.SendStateSnapshot( targetPlayer, entities )
end


return snapshots
