rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.actions = rRadio.client.ui.actions or {}

local actions = rRadio.client.ui.actions
local favourites = rRadio.client.stations.favourites
local recent = rRadio.client.stations.recent
local pendingVolumeEntity
local pendingVolume

local function sendPendingVolume()
    if not IsValid( pendingVolumeEntity ) then return end

    rRadio.client.net.handlers.RequestVolume( pendingVolumeEntity, pendingVolume )
end

local function resolveActionEntity( entity )
    if IsValid( entity ) then return rRadio.util.GetRadioEntity( entity, LocalPlayer() ) end

    return rRadio.client.ui.state.currentEntity
end

function actions.PlayStation( stationID, entity )
    entity = resolveActionEntity( entity )
    if not IsValid( entity ) then return false end

    local state = rRadio.client.ui.state
    local currentEntity = rRadio.util.GetRadioEntity( state.currentEntity, LocalPlayer() )
    local updatesOpenMenu = currentEntity == entity
    if updatesOpenMenu then
        state.pendingStationID = stationID
        timer.Create( "rRadio_Actions_ClearPendingStation", 3, 1, function()
            if state.pendingStationID == stationID then
                state.pendingStationID = nil
            end
        end )
    end

    local volume = rRadio.client.radio.state.GetVolume( entity )
    local sent = rRadio.client.net.handlers.RequestPlay( entity, stationID, volume )
    if sent then
        recent.MarkPendingStation( entity, stationID )
    elseif updatesOpenMenu then
        state.pendingStationID = nil
    end

    return sent
end

function actions.Stop()
    local entity = rRadio.client.ui.state.currentEntity
    if not IsValid( entity ) then return false end

    rRadio.client.ui.state.pendingStationID = nil
    return rRadio.client.net.handlers.RequestStop( entity )
end

function actions.SetVolume( volume )
    local entity = rRadio.client.ui.state.currentEntity
    if not IsValid( entity ) then return false end

    pendingVolumeEntity = entity
    pendingVolume = volume

    local delay = rRadio.config.VolumeUpdateDebounce or 0.1
    timer.Create( "rRadio_Actions_RequestVolumeDebounced", delay, 1, sendPendingVolume )
    return true
end

function actions.ToggleFavouriteStation( stationID )
    if not stationID or stationID == "" then return false end

    favourites.SetStationFavourite( stationID, not favourites.IsStationFavourite( stationID ) )
    return true
end

function actions.SetFavouriteStation( stationID, favourite )
    if not stationID or stationID == "" then return false end

    favourites.SetStationFavourite( stationID, favourite == true )
    return true
end

function actions.SetPermanent( permanent, entity )
    entity = resolveActionEntity( entity )
    if not IsValid( entity ) then return false end

    return rRadio.client.net.handlers.RequestPersistence( entity, permanent )
end

function actions.SetPublic( public, entity )
    entity = resolveActionEntity( entity )
    if not IsValid( entity ) then return false end

    return rRadio.client.net.handlers.RequestPublicAccess( entity, public )
end

function actions.SyncEntityState( entity, reason, options )
    return rRadio.client.net.handlers.QueueEntityStateSync( entity, reason, options )
end

function actions.AddCustomStation( name, url )
    name = string.Trim( tostring( name or "" ) )
    url = string.Trim( tostring( url or "" ) )
    if name == "" or url == "" then return false end

    rRadio.client.net.handlers.RequestAddCustomStation( name, url )
    return true
end

function actions.EditCustomStation( stationID, name, url )
    stationID = string.Trim( tostring( stationID or "" ) )
    name = string.Trim( tostring( name or "" ) )
    url = string.Trim( tostring( url or "" ) )
    if stationID == "" or name == "" or url == "" then return false end

    rRadio.client.net.handlers.RequestEditCustomStation( stationID, name, url )
    return true
end

function actions.RemoveCustomStation( key )
    key = string.Trim( tostring( key or "" ) )
    if key == "" then return false end

    rRadio.client.net.handlers.RequestRemoveCustomStation( key )
    return true
end

function actions.SetServerConfig( setting, value )
    local definition = rRadio.configSchema.GetDefinition( setting )
    if not definition then definition = setting end
    if not definition then return false end

    local normalized = rRadio.configSchema.NormalizeValue( definition, value )
    if normalized == nil then return false end

    local json = rRadio.configSchema.EncodeJSON( definition, normalized )
    rRadio.client.net.handlers.RequestConfigSet( definition.id, json )
    return true
end

function actions.ResetServerConfig( setting )
    local id = setting == "*" and "*" or nil
    if not id then
        local definition = rRadio.configSchema.GetDefinition( setting )
        if not definition then definition = setting end
        if not definition then return false end

        id = definition.id
    end

    rRadio.client.net.handlers.RequestConfigReset( id )
    return true
end

return actions
