rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.playback = rRadio.radio.playback or {}

local playback = rRadio.radio.playback
local registry = rRadio.stations.registry
local stationSchema = rRadio.stations.schema
local stateStore = rRadio.radio.stateStore
local permissions = rRadio.radio.permissions
local cooldowns = rRadio.radio.cooldowns
local snapshots = rRadio.radio.snapshots


local function resolveStation( stationID )
    local station = registry.Get( stationID )
    if station or rRadio.config.SecureStationLoad ~= false then return station end

    local url = tostring( stationID or "" )
    if not stationSchema.IsValidURL( url ) then return nil end

    return {
        id = stationSchema.MakeCustomID( util.CRC( url ) ),
        name = url,
        url = url,
        countryKey = rRadio.config.CustomStationCategory or "Custom",
        source = rRadio.constants.Defaults.CustomStationSource
    }
end


local function savePermanentIfNeeded( entity )
    if stateStore.IsPermanent( entity ) then
        rRadio.persistence.service.SavePermanentBoombox( entity )
    end
end


local function queuePermanentSaveIfNeeded( entity )
    if stateStore.IsPermanent( entity ) then
        rRadio.persistence.service.QueuePermanentBoomboxSave( entity )
    end
end


local function flushPermanentSaveIfNeeded( entity )
    if stateStore.IsPermanent( entity ) then
        rRadio.persistence.service.FlushPermanentBoomboxSave( entity )
    end
end


local function clearOldestIfNeeded()
    local service = rRadio.radio.service
    service.CleanupInvalid()
    if stateStore.CountActive() < ( rRadio.config.MaxActiveRadios or 100 ) then return end

    local oldest = stateStore.GetOldest()
    if not oldest then return end

    service.Stop( oldest.owner, oldest.entity, "capacity" )
end


function playback.Play( actor, entity, stationID, requestedVolume )
    entity = rRadio.util.GetRadioEntity( entity, actor )
    if not IsValid( entity ) then return false, "Invalid radio" end
    if not rRadio.util.CanUseRadio( entity, actor ) then return false, "This entity cannot use a radio." end
    if not cooldowns.CanUseControl( actor ) then return false, "You are changing stations too quickly." end

    local allowed, reason = permissions.CanControl( actor, entity )
    if not allowed then return false, reason end

    local replacingExisting = stateStore.Get( entity ) ~= nil

    if stateStore.CountPlayer( actor ) >= ( rRadio.config.MaxPlayerRadios or 15 ) and not replacingExisting then
        return false, "You have reached your maximum number of active radios."
    end

    local station = resolveStation( stationID )
    if not station then return false, "Unknown station." end

    if hook.Run( "rRadio_PrePlayStation", actor, entity, stationID, station ) == false then return false end

    if not replacingExisting then clearOldestIfNeeded() end

    local displayName = rRadio.net.protocol.LimitDisplayName( station.name )
    local state = {
        entity = entity,
        stationID = station.id,
        stationName = displayName,
        url = station.url,
        volume = rRadio.util.ClampVolume( requestedVolume ),
        owner = actor
    }

    local stored = stateStore.SetAssignment( entity, state )
    if not stored then return false, "Could not store radio assignment." end

    snapshots.BroadcastAssignment( stored )

    savePermanentIfNeeded( entity )
    hook.Run( "rRadio_PostPlayStation", actor, entity, stationID, station )

    return true
end


function playback.Stop( actor, entity, reason )
    entity = rRadio.util.GetRadioEntity( entity, actor )
    if not IsValid( entity ) then return false, "Invalid radio" end

    local allowed, failure = permissions.CanControl( actor, entity )
    local forcedStop = reason == "cleanup" or reason == "capacity"
    if not allowed and not forcedStop then return false, failure end
    if not forcedStop and hook.Run( "rRadio_PreStopStation", actor, entity ) == false then return false end

    stateStore.ClearAssignment( entity )
    snapshots.BroadcastClear( entity )

    savePermanentIfNeeded( entity )
    hook.Run( "rRadio_PostStopStation", actor, entity )

    return true
end


function playback.SetVolume( actor, entity, volume )
    entity = rRadio.util.GetRadioEntity( entity, actor )
    if not IsValid( entity ) then return false, "Invalid radio" end

    local allowed, reason = permissions.CanControl( actor, entity )
    if not allowed then return false, reason end
    if not cooldowns.CanUseVolume( actor, entity ) then return false end

    local clampedVolume = rRadio.util.ClampVolume( volume )
    local state = stateStore.GetEntityState( entity )
    local currentVolume = state and state.assignment and state.assignment.volume
        or state and state.settings and state.settings.defaultVolume
        or clampedVolume
    if currentVolume == clampedVolume then return true end

    local stored = stateStore.SetVolume( entity, clampedVolume )
    snapshots.BroadcastVolume( stored )
    queuePermanentSaveIfNeeded( entity )

    return true
end


function playback.SetPublic( actor, entity, public )
    entity = rRadio.util.GetRadioEntity( entity, actor )
    if not rRadio.util.IsBoombox( entity ) then
        return false, "Invalid boombox.", false
    end
    if not cooldowns.CanUseControl( actor ) then
        return false, "You are changing boombox settings too quickly.", stateStore.IsPublic( entity )
    end

    local allowed, reason = permissions.CanSetBoomboxPublic( actor, entity )
    if not allowed then return false, reason or "You do not have permission.", stateStore.IsPublic( entity ) end

    public = public == true
    local previousPublic = stateStore.IsPublic( entity )
    if previousPublic == public then
        return true, "Boombox public access unchanged.", public
    end

    stateStore.SetPublic( entity, public )
    snapshots.BroadcastSettings( entity )

    if stateStore.IsPermanent( entity ) and not rRadio.persistence.service.SavePermanentBoombox( entity ) then
        stateStore.SetPublic( entity, previousPublic )
        snapshots.BroadcastSettings( entity )
        return false, "Could not save boombox public access.", previousPublic
    end

    return true, "Boombox public access updated.", public
end


function playback.Restore( entity, stationID, volume )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return false, "Invalid radio" end

    local station = resolveStation( stationID )
    if not station then return false, "Unknown station." end

    local displayName = rRadio.net.protocol.LimitDisplayName( station.name )
    local state = {
        entity = entity,
        stationID = station.id,
        stationName = displayName,
        url = station.url,
        volume = rRadio.util.ClampVolume( volume ),
        owner = nil
    }

    local stored = stateStore.SetAssignment( entity, state )
    if not stored then return false, "Could not store radio assignment." end

    snapshots.BroadcastAssignment( stored )

    return true
end


function playback.CleanupEntity( entityOrIndex, reason )
    local state = stateStore.Get( entityOrIndex )

    if state and IsValid( state.entity ) then
        flushPermanentSaveIfNeeded( state.entity )
    elseif IsValid( entityOrIndex ) and stateStore.IsPermanent( entityOrIndex ) then
        rRadio.logger.DebugScope( "persistence", "Skipping permanent cleanup save", tostring( reason or "unknown" ) )
    end

    state = stateStore.ClearAssignment( entityOrIndex )
    if not state then return end

    if IsValid( state.entity ) then snapshots.BroadcastClear( state.entity ) end

    rRadio.logger.DebugScope( "radio", "Cleaned radio state", tostring( reason or "unknown" ) )
end


function playback.CleanupPlayer( player )
    local service = rRadio.radio.service
    local playerStates = {}
    stateStore.ForEach( function( state )
        if state.owner == player and IsValid( state.entity ) then playerStates[#playerStates + 1] = state end
    end )

    for _, state in ipairs( playerStates ) do
        if state.owner == player and IsValid( state.entity ) then
            if stateStore.IsPermanent( state.entity ) then
                rRadio.persistence.service.SavePermanentBoombox( state.entity )
            else
                service.Stop( player, state.entity, "cleanup" )
            end
        end
    end

    stateStore.ReleaseOwner( player )
end


function playback.CleanupInactive()
    local timeout = rRadio.config.InactiveTimeout or 3600
    if timeout <= 0 then return end

    local service = rRadio.radio.service
    local now = CurTime()
    local inactiveStates = {}
    stateStore.ForEach( function( state )
        if now - ( state.updatedAt or now ) >= timeout and IsValid( state.entity ) then
            inactiveStates[#inactiveStates + 1] = state
        end
    end )

    for _, state in ipairs( inactiveStates ) do
        if now - ( state.updatedAt or now ) >= timeout and IsValid( state.entity ) then
            service.Stop( state.owner, state.entity, "cleanup" )
        end
    end
end


function playback.CleanupInvalid()
    local service = rRadio.radio.service
    for _, entityIndex in ipairs( stateStore.ListInvalidIndices() ) do
        service.CleanupEntity( entityIndex, "invalid" )
    end
end


function playback.GetAssignment( entity )
    return snapshots.FromState( stateStore.GetEntityState( entity ) )
end


return playback
