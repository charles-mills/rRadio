if SERVER then return end
local IsValid = IsValid
local cl = rRadio.cl
local iface = rRadio.interface
local cfgGlobal = rRadio.config
local utils = rRadio.utils
local UPDATE_INTERVAL = 0.2
local function distSq( a, b )
    return a:DistToSqr( b )
end

local function samePos( ent, p )
    return cl.stationLastPos[ent] == p
end

local function computeRange( cfg, factorField )
    return ( cfg.MaxHearingDistance or 0 ) * ( cfgGlobal[factorField] or 1 )
end

local function isBeyondUnloadRange( plyPos, entPos, cfg )
    local d = computeRange( cfg, "UnloadDistanceFactor" )
    return distSq( plyPos, entPos ) > d * d
end

function cl.isEntityWithinLoadRange( plyPos, entPos, cfg )
    local d = computeRange( cfg, "LoadDistanceFactor" )
    return distSq( plyPos, entPos ) <= d * d
end

function cl.configureStation3D( station, entity )
    local cfg = iface.getEntityConfig( entity )
    if cfg then station:Set3DFadeDistance( cfg.MinVolumeDistance, cfg.MaxHearingDistance ) end
end

function cl.applyInitialVolume( station, volume, entity )
    station:SetVolume( iface.ClampVolume( volume ) )
    local ply = LocalPlayer()
    local inCar = utils.GetVehicle( ply:GetVehicle() ) == entity
    iface.updateRadioVolume( station, distSq( ply:GetPos(), entity:GetPos() ), inCar, entity )
end

function cl.syncStationPosition( station, entity )
    local pos = entity:GetPos()
    if not samePos( entity, pos ) then
        station:SetPos( pos )
        cl.stationLastPos[entity] = pos
    end
end

function cl.markStationActive( station, entity, name, url, volume )
    cl.radioSources[entity] = station
    cl.connectedStations[entity] = true
    utils.SetRadioStatus( entity, rRadio.status.PLAYING, name )
    cl.requestedStations[entity] = nil
    cl.currentlyPlayingStations[entity] = {
        name = name,
        url = url,
        volume = volume
    }
end

function cl.handleStationInactive( entity, failedStationName )
    cl.connectedStations[entity] = nil
    cl.requestedStations[entity] = nil
    cl.currentlyPlayingStations[entity] = nil
    if not IsValid( entity ) then return end
    local entIndex = entity:EntIndex()
    local errorText = cfgGlobal.Lang["StationFailed"] or "Station Failed"
    cl.boomboxStatuses[entIndex] = {
        stationStatus = rRadio.status.ERROR,
        stationName = errorText
    }

    cl.errorTimestamps[entity] = {
        time = CurTime(),
        stationName = failedStationName
    }

    timer.Create( "rRadio.ErrorClear_" .. entIndex, cfgGlobal.ErrorDisplayDuration or 5, 1, function()
        if IsValid( entity ) then utils.ClearRadioStatus( entity ) end
        cl.errorTimestamps[entity] = nil
    end )
end

function cl.startStationPlayback( entity, name, url, volume, nonce )
    if not IsValid( entity ) then return end
    local entIndex = entity:EntIndex()
    timer.Create( "rRadio.TuningTimeout_" .. entIndex, 15, 1, function()
        if not IsValid( entity ) then return end
        if cl.playbackNonce[entity] ~= nonce then return end
        if cl.connectedStations[entity] then return end
        cl.handleStationInactive( entity, name )
    end )

    sound.PlayURL( url, "3d noplay", function( station )
        timer.Remove( "rRadio.TuningTimeout_" .. entIndex )
        if cl.playbackNonce[entity] ~= nonce then
            if IsValid( station ) then station:Stop() end
            return
        end

        if not ( IsValid( station ) and IsValid( entity ) ) then
            cl.handleStationInactive( entity, name )
            return
        end

        timer.Simple( 0, function()
            cl.configureStation3D( station, entity )
            cl.applyInitialVolume( station, volume, entity )
            cl.syncStationPosition( station, entity )
            station:Play()
            cl.markStationActive( station, entity, name, url, volume )
        end )
    end )
end

function cl.processPendingStations( _, plyPos )
    for seatEnt, data in pairs( cl.queuedStations ) do
        local entity = utils.GetVehicleEntity( seatEnt )
        if not IsValid( entity ) then
            rRadio.logger.DebugScope( "cl_playback", "Removing invalid entity from queue:", tostring( seatEnt ) )
            cl.queuedStations[seatEnt] = nil
        else
            local cfg = iface.getEntityConfig( entity )
            if cfg and cl.isEntityWithinLoadRange( plyPos, entity:GetPos(), cfg ) then
                rRadio.logger.DebugScope( "cl_playback", "Starting playback for queued station:", data.name )
                cl.startStationPlayback( entity, data.name, data.url, data.volume, data.nonce )
                cl.queuedStations[seatEnt] = nil
            end
        end
    end
end

function cl.unloadDistantStations( plyPos )
    local removed = false
    local radioSources = cl.radioSources
    local connectedStations = cl.connectedStations
    local entityVolumes = cl.entityVolumes
    local stationLastPos = cl.stationLastPos
    local playingStations = cl.currentlyPlayingStations
    local playbackNonceTbl = cl.playbackNonce
    local queuedStationsTbl = cl.queuedStations
    for seatEnt, station in pairs( radioSources ) do
        local entity = utils.GetVehicleEntity( seatEnt )
        if IsValid( entity ) and IsValid( station ) then
            local cfg = iface.getEntityConfig( entity )
            if cfg and isBeyondUnloadRange( plyPos, entity:GetPos(), cfg ) then
                local vol = cl.getEntityVolume( entity )
                station:Stop()
                radioSources[seatEnt] = nil
                connectedStations[entity] = nil
                entityVolumes[entity] = nil
                stationLastPos[entity] = nil
                local data = playingStations[entity]
                if data and data.url then
                    local newNonce = ( playbackNonceTbl[entity] or 0 ) + 1
                    playbackNonceTbl[entity] = newNonce
                    queuedStationsTbl[seatEnt] = {
                        name = data.name,
                        url = data.url,
                        volume = vol,
                        nonce = newNonce
                    }
                end

                playingStations[entity] = nil
                rRadio.logger.DebugScope( "cl_playback", "Unloaded a station", entity )
                removed = true
            end
        end
    end

    if removed then iface.updateStationCount() end
end

function cl.refreshStation( ent, station )
    local entity = utils.GetVehicleEntity( ent )
    cl.syncStationPosition( station, entity )
    iface.refreshVolume( entity )
end

function cl.cleanAndRefreshSources()
    for ent, station in pairs( cl.radioSources ) do
        if not ( IsValid( ent ) and IsValid( station ) ) then
            cl.radioSources[ent] = nil
        else
            cl.refreshStation( ent, station )
        end
    end
end

local perf = cl.performance
function cl.maybeLoadUnload( ply, plyPos )
    if cfgGlobal.ConditionalStationLoad then cl.processPendingStations( ply, plyPos ) end
    if cfgGlobal.ConditionalStationUnload then cl.unloadDistantStations( plyPos ) end
end

function cl.updateAllStations()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end
    perf.playerVehicle = utils.GetVehicle( ply:GetVehicle() )
    local plyPos = ply:GetPos()
    cl.maybeLoadUnload( ply, plyPos )
    local stationCt = perf.volumeChanged and iface.updateStationCount() or perf.lastStationCount
    local enabled = cl.cvars.enabled:GetBool()
    local maxVol = cl.cvars.maxVolume:GetFloat()
    if stationCt == perf.lastStationCount and enabled == perf.lastEnabled
        and maxVol == perf.lastMaxVolume and not perf.volumeChanged
        and distSq( plyPos, perf.lastPlayerPos ) < 1 then return end
    perf.lastPlayerPos = plyPos
    perf.lastStationCount = stationCt
    perf.lastEnabled = enabled
    perf.lastMaxVolume = maxVol
    perf.volumeChanged = false
    cl.cleanAndRefreshSources()
end

timer.Create( "rRadio.UpdateStationsTimer", UPDATE_INTERVAL, 0, cl.updateAllStations )
