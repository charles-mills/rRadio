rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.customStations = rRadio.radio.customStations or {}

local customStations = rRadio.radio.customStations
local registry = rRadio.stations.registry
local stateStore = rRadio.radio.stateStore
local permissions = rRadio.radio.permissions
local snapshots = rRadio.radio.snapshots

local function refreshActiveAssignments( station )
    local displayName = rRadio.net.protocol.LimitDisplayName( station.name )
    local affectedStates = {}

    stateStore.ForEach( function( state )
        if state.stationID == station.id and IsValid( state.entity ) then
            affectedStates[#affectedStates + 1] = state
        end
    end )

    for _, state in ipairs( affectedStates ) do
        if state.stationID == station.id and IsValid( state.entity ) then
            local stored = stateStore.SetAssignment( state.entity, {
                stationID = station.id,
                stationName = displayName,
                url = station.url,
                volume = state.volume,
                owner = state.owner
            } )
            snapshots.BroadcastAssignment( stored )
        end
    end
end

function customStations.Add( player, name, url )
    if IsValid( player ) and not permissions.CanManageCustomStations( player ) then
        return false, "You do not have permission to manage custom stations."
    end

    local ok, result = registry.AddCustom( name, url, player )
    if ok then snapshots.BroadcastCustomStations() end

    return ok, ok and "Custom station added." or tostring( result )
end

function customStations.Edit( player, stationID, name, url )
    if IsValid( player ) and not permissions.CanManageCustomStations( player ) then
        return false, "You do not have permission to manage custom stations."
    end

    local ok, result = registry.EditCustom( stationID, name, url, player )
    if ok then
        refreshActiveAssignments( result )
        snapshots.BroadcastCustomStations()
    end

    return ok, ok and "Custom station updated." or tostring( result )
end


function customStations.Remove( player, key )
    if IsValid( player ) and not permissions.CanManageCustomStations( player ) then
        return false, "You do not have permission to manage custom stations."
    end

    local ok, result = registry.RemoveCustom( key or "" )
    if ok then
        local service = rRadio.radio.service
        local affectedStates = {}
        stateStore.ForEach( function( state )
            if state.stationID == result and IsValid( state.entity ) then
                affectedStates[#affectedStates + 1] = state
            end
        end )

        for _, state in ipairs( affectedStates ) do
            if state.stationID == result and IsValid( state.entity ) then
                service.Stop( player, state.entity, "cleanup" )
            end
        end

        snapshots.BroadcastCustomStations()
    end

    return ok, ok and "Custom station removed." or tostring( result )
end


function customStations.List()
    return registry.ListCustom()
end


return customStations
