rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.stateStore = rRadio.radio.stateStore or {}

local stateStore = rRadio.radio.stateStore
local activeByEntity = {}
local activeCount = 0
local playerCounts = setmetatable( {}, { __mode = "k" } )
local RELOAD_REBUILD_HOOK = "rRadio_StateStore_RebuildAfterReload"

local function getEntityIndex( entity )
    if not entity or not entity.EntIndex then return nil end
    if not IsValid( entity ) then
        local ok, entityIndex = pcall( entity.EntIndex, entity )
        if ok and isnumber( entityIndex ) and entityIndex > 0 then return entityIndex end

        return nil
    end

    return entity:EntIndex()
end

local function isRadioEntity( entity )
    if not IsValid( entity ) then return false end
    if rRadio.util.IsBoomboxClass( entity:GetClass() ) then return true end

    return rRadio.vehicle.IsRadioHost( entity )
end

local function getDefaultVolume( entity )
    local config = rRadio.util.GetEntityConfig( entity )
    return rRadio.util.ClampVolume( config and config.Volume or 1 )
end

local function copySettings( settings )
    settings = settings or {}
    local defaultVolume = settings.defaultVolume
    if defaultVolume == nil then defaultVolume = 1 end

    return {
        permanent = settings.permanent == true,
        permanentID = tostring( settings.permanentID or "" ),
        public = settings.public == true,
        defaultVolume = rRadio.util.ClampVolume( defaultVolume )
    }
end

local function copyAssignment( assignment )
    if not assignment or assignment.active ~= true then return nil end

    return {
        active = true,
        stationID = tostring( assignment.stationID or "" ),
        stationName = rRadio.net.protocol.LimitDisplayName( assignment.stationName ),
        url = tostring( assignment.url or "" ),
        volume = rRadio.util.ClampVolume( assignment.volume ),
        owner = assignment.owner,
        updatedAt = assignment.updatedAt or CurTime()
    }
end

function stateStore.Ensure( entity )
    if not IsValid( entity ) then return nil end

    local runtime = entity.rRadioState
    if type( runtime ) ~= "table" then
        runtime = {}
        entity.rRadioState = runtime
    end

    runtime.revision = tonumber( runtime.revision ) or 0
    runtime.settings = runtime.settings or {}
    runtime.settings.permanent = runtime.settings.permanent == true
    runtime.settings.permanentID = tostring( runtime.settings.permanentID or "" )
    runtime.settings.public = runtime.settings.public == true
    runtime.settings.defaultVolume = rRadio.util.ClampVolume(
        runtime.settings.defaultVolume or getDefaultVolume( entity )
    )

    if runtime.assignment then
        runtime.assignment = copyAssignment( runtime.assignment )
    end

    return runtime
end

local function decrementPlayer( player )
    if not IsValid( player ) then return end

    local current = playerCounts[player] or 0
    if current <= 1 then
        playerCounts[player] = nil
    else
        playerCounts[player] = current - 1
    end
end

local function incrementPlayer( player )
    if not IsValid( player ) then return end

    playerCounts[player] = ( playerCounts[player] or 0 ) + 1
end

local function unindexEntityIndex( entityIndex )
    if not entityIndex then return nil end

    local oldState = activeByEntity[entityIndex]
    if not oldState then return nil end

    decrementPlayer( oldState.owner )
    activeByEntity[entityIndex] = nil
    activeCount = math.max( activeCount - 1, 0 )

    return oldState
end

local function indexEntity( entity, runtime )
    local entityIndex = getEntityIndex( entity )
    if not entityIndex then return false end

    local assignment = runtime and runtime.assignment
    if not assignment or assignment.active ~= true then
        unindexEntityIndex( entityIndex )
        return true
    end

    local oldState = activeByEntity[entityIndex]
    if oldState and oldState.owner ~= assignment.owner then decrementPlayer( oldState.owner ) end
    if not oldState or oldState.owner ~= assignment.owner then incrementPlayer( assignment.owner ) end
    if not oldState then activeCount = activeCount + 1 end

    activeByEntity[entityIndex] = {
        entity = entity,
        entityIndex = entityIndex,
        revision = runtime.revision or 0,
        stationID = assignment.stationID,
        stationName = assignment.stationName,
        url = assignment.url,
        volume = assignment.volume,
        owner = assignment.owner,
        updatedAt = assignment.updatedAt or CurTime()
    }

    return true
end

function stateStore.Touch( entity )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    runtime.revision = ( tonumber( runtime.revision ) or 0 ) + 1
    return runtime.revision
end

function stateStore.InitializeEntity( entity, settings )
    local existed = IsValid( entity ) and type( entity.rRadioState ) == "table"
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    settings = settings or {}
    local changed = false
    if settings.defaultVolume ~= nil then
        local volume = rRadio.util.ClampVolume( settings.defaultVolume )
        changed = changed or runtime.settings.defaultVolume ~= volume
        runtime.settings.defaultVolume = volume
    end
    if settings.permanent ~= nil then
        local permanent = settings.permanent == true
        changed = changed or runtime.settings.permanent ~= permanent
        runtime.settings.permanent = permanent
    end
    if settings.public ~= nil then
        local public = settings.public == true
        changed = changed or runtime.settings.public ~= public
        runtime.settings.public = public
    end
    if settings.permanentID ~= nil then
        local permanentID = tostring( settings.permanentID or "" )
        changed = changed or runtime.settings.permanentID ~= permanentID
        runtime.settings.permanentID = permanentID
    end

    if existed and changed then stateStore.Touch( entity ) end
    indexEntity( entity, runtime )
    return runtime
end

function stateStore.SetOwner( entity, owner )
    if not IsValid( entity ) then return false end

    local hasOwner = IsValid( owner )
    entity.rRadioOwner = hasOwner and owner or nil
    if entity.Setowning_ent and hasOwner then entity:Setowning_ent( owner ) end
    if hasOwner and owner.SID ~= nil then entity.SID = owner.SID end
    if entity.CPPISetOwner and hasOwner then
        local ok, assigned = pcall( entity.CPPISetOwner, entity, owner )
        if not ok then
            rRadio.logger.WarnScope( "radio", "CPPI owner assignment failed:", assigned )
        elseif assigned == false then
            rRadio.logger.DebugScope( "radio", "CPPI owner assignment declined", entity, owner )
        end
    end
    return true
end

function stateStore.GetOwner( entity )
    if not IsValid( entity ) then return nil end
    if entity.Getowning_ent then
        local owner = entity:Getowning_ent()
        if IsValid( owner ) then return owner end
    end
    if IsValid( entity.rRadioOwner ) then return entity.rRadioOwner end
    if entity.CPPIGetOwner then
        local owner = entity:CPPIGetOwner()
        if IsValid( owner ) then return owner end
    end

    return nil
end

function stateStore.SetAssignment( entity, assignment )
    local runtime = stateStore.Ensure( entity )
    local entityIndex = getEntityIndex( entity )
    if not runtime or not entityIndex then return nil end

    runtime.assignment = copyAssignment( {
        active = true,
        stationID = assignment.stationID,
        stationName = assignment.stationName,
        url = assignment.url,
        volume = assignment.volume,
        owner = assignment.owner,
        updatedAt = CurTime()
    } )
    stateStore.Touch( entity )
    indexEntity( entity, runtime )

    return stateStore.GetEntityState( entity )
end

function stateStore.ClearAssignment( entityOrIndex )
    local entityIndex = isnumber( entityOrIndex ) and entityOrIndex or getEntityIndex( entityOrIndex )
    local oldState = unindexEntityIndex( entityIndex )

    if IsValid( entityOrIndex ) then
        local runtime = stateStore.Ensure( entityOrIndex )
        if runtime then
            runtime.assignment = nil
            stateStore.Touch( entityOrIndex )
        end
    elseif oldState and IsValid( oldState.entity ) then
        local runtime = stateStore.Ensure( oldState.entity )
        if runtime then
            runtime.assignment = nil
            stateStore.Touch( oldState.entity )
        end
    end

    return oldState
end

function stateStore.Get( entityOrIndex )
    local entityIndex = isnumber( entityOrIndex ) and entityOrIndex or getEntityIndex( entityOrIndex )
    if not entityIndex then return nil end

    return activeByEntity[entityIndex]
end

function stateStore.GetEntityState( entity )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    return {
        entity = entity,
        entityIndex = getEntityIndex( entity ) or 0,
        revision = runtime.revision or 0,
        assignment = copyAssignment( runtime.assignment ),
        settings = copySettings( runtime.settings )
    }
end

function stateStore.CountActive()
    return activeCount
end

function stateStore.CountPlayer( player )
    if not IsValid( player ) then return 0 end

    return playerCounts[player] or 0
end

function stateStore.ReleaseOwner( player )
    if not IsValid( player ) then return end

    for _, state in pairs( activeByEntity ) do
        if state.owner == player then state.owner = nil end
    end

    for _, entity in ents.Iterator() do
        local runtime = entity.rRadioState
        if runtime and runtime.assignment and runtime.assignment.owner == player then
            runtime.assignment.owner = nil
        end
        if entity.rRadioOwner == player then entity.rRadioOwner = nil end
    end

    playerCounts[player] = nil
end

function stateStore.GetOldest()
    local oldest
    for _, state in pairs( activeByEntity ) do
        if not oldest or state.updatedAt < oldest.updatedAt then oldest = state end
    end

    return oldest
end

function stateStore.ForEach( callback )
    for _, state in pairs( activeByEntity ) do
        callback( state )
    end
end

function stateStore.List()
    local rows = {}
    stateStore.ForEach( function( state )
        rows[#rows + 1] = state
    end )

    return rows
end

function stateStore.ListInvalidIndices()
    local indices = {}
    for entityIndex, state in pairs( activeByEntity ) do
        if not IsValid( state.entity ) then
            indices[#indices + 1] = entityIndex
        end
    end

    return indices
end

function stateStore.CleanupInvalid()
    for _, entityIndex in ipairs( stateStore.ListInvalidIndices() ) do
        stateStore.ClearAssignment( entityIndex )
    end
end

function stateStore.RebuildFromEntities()
    activeByEntity = {}
    activeCount = 0
    playerCounts = setmetatable( {}, { __mode = "k" } )

    for _, entity in ents.Iterator() do
        if isRadioEntity( entity ) then
            local runtime = stateStore.Ensure( entity )
            if runtime then indexEntity( entity, runtime ) end
        end
    end

    rRadio.logger.DebugScope( "radio", "Rebuilt radio state indexes", activeCount )
end

hook.Add( "OnReloaded", RELOAD_REBUILD_HOOK, stateStore.RebuildFromEntities )

function stateStore.GetSettings( entity )
    local runtime = stateStore.Ensure( entity )
    return runtime and runtime.settings or nil
end

function stateStore.IsPermanent( entity )
    local settings = stateStore.GetSettings( entity )
    return settings ~= nil and settings.permanent == true
end

function stateStore.IsPublic( entity )
    local settings = stateStore.GetSettings( entity )
    return settings ~= nil and settings.public == true
end

function stateStore.SetPermanent( entity, permanent )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    runtime.settings.permanent = permanent == true
    stateStore.Touch( entity )
    return stateStore.GetEntityState( entity )
end

function stateStore.SetPublic( entity, public )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    runtime.settings.public = public == true
    stateStore.Touch( entity )
    return stateStore.GetEntityState( entity )
end

function stateStore.SetPermanentID( entity, permanentID )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    runtime.settings.permanentID = tostring( permanentID or "" )
    stateStore.Touch( entity )
    return stateStore.GetEntityState( entity )
end

function stateStore.GetPermanentID( entity )
    local settings = stateStore.GetSettings( entity )
    return settings and settings.permanentID or ""
end

function stateStore.GetDefaultVolume( entity )
    local settings = stateStore.GetSettings( entity )
    return settings and settings.defaultVolume or getDefaultVolume( entity )
end

function stateStore.SetDefaultVolume( entity, volume )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    runtime.settings.defaultVolume = rRadio.util.ClampVolume( volume )
    stateStore.Touch( entity )
    return stateStore.GetEntityState( entity )
end

function stateStore.SetVolume( entity, volume )
    local runtime = stateStore.Ensure( entity )
    if not runtime then return nil end

    local clamped = rRadio.util.ClampVolume( volume )
    if runtime.assignment then
        runtime.assignment.volume = clamped
        runtime.assignment.updatedAt = CurTime()
    else
        runtime.settings.defaultVolume = clamped
    end

    stateStore.Touch( entity )
    indexEntity( entity, runtime )
    return stateStore.GetEntityState( entity )
end

return stateStore
