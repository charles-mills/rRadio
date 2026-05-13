rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.radio = rRadio.client.radio or {}
rRadio.client.radio.state = rRadio.client.radio.state or {}

local radioState = rRadio.client.radio.state
local byEntity = {}

local function normalizeSettings( settings )
    settings = settings or {}
    return {
        permanent = settings.permanent == true,
        permanentID = tostring( settings.permanentID or "" ),
        public = settings.public == true,
        defaultVolume = rRadio.util.ClampVolume( settings.defaultVolume or 1 )
    }
end

local function normalizeAssignment( assignment )
    if not assignment or assignment.active ~= true then return nil end

    return {
        active = true,
        stationID = tostring( assignment.stationID or "" ),
        stationName = rRadio.net.protocol.LimitDisplayName( assignment.stationName ),
        url = tostring( assignment.url or "" ),
        volume = rRadio.util.ClampVolume( assignment.volume )
    }
end

function radioState.ApplyState( state )
    if not state or not IsValid( state.entity ) then return false end

    local entity = rRadio.util.GetRadioEntity( state.entity )
    if not IsValid( entity ) then return false end

    local revision = tonumber( state.revision ) or 0
    local current = byEntity[entity]
    if current and revision < ( current.revision or 0 ) then return false end

    byEntity[entity] = {
        entity = entity,
        revision = revision,
        assignment = normalizeAssignment( state.assignment ),
        settings = normalizeSettings( state.settings )
    }

    hook.Run( "rRadio_ClientRadioStateChanged", entity, byEntity[entity] )
    return true
end

function radioState.ClearEntity( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return false end

    byEntity[entity] = nil
    hook.Run( "rRadio_ClientRadioStateChanged", entity, nil )
    return true
end

function radioState.Get( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    return byEntity[entity]
end

function radioState.GetAssignment( entity )
    local state = radioState.Get( entity )
    return state and state.assignment or nil
end

function radioState.GetSettings( entity )
    local state = radioState.Get( entity )
    return state and state.settings or nil
end

function radioState.GetVolume( entity )
    local state = radioState.Get( entity )
    if state and state.assignment then return state.assignment.volume end
    if state and state.settings then return state.settings.defaultVolume end

    return 1
end

function radioState.GetStationID( entity )
    local assignment = radioState.GetAssignment( entity )
    return assignment and assignment.stationID or nil
end

function radioState.GetStationURL( entity )
    local assignment = radioState.GetAssignment( entity )
    return assignment and assignment.url or nil
end

function radioState.IsPermanent( entity )
    local settings = radioState.GetSettings( entity )
    return settings ~= nil and settings.permanent == true
end

function radioState.IsPublic( entity )
    local settings = radioState.GetSettings( entity )
    return settings ~= nil and settings.public == true
end

function radioState.ListActiveAssignments()
    local rows = {}
    for entity, state in pairs( byEntity ) do
        if IsValid( entity ) and state.assignment then
            rows[#rows + 1] = {
                entity = entity,
                revision = state.revision,
                stationID = state.assignment.stationID,
                stationName = state.assignment.stationName,
                url = state.assignment.url,
                volume = state.assignment.volume
            }
        end
    end

    return rows
end

function radioState.Init()
    byEntity = {}

    hook.Add( "EntityRemoved", "rRadio_ClientRadio_ClearRemovedState", function( entity )
        if not byEntity[entity] then return end

        byEntity[entity] = nil
        hook.Run( "rRadio_ClientRadioStateChanged", entity, nil )
    end )
end

return radioState
