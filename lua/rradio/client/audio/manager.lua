rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.audio = rRadio.client.audio or {}
rRadio.client.audio.manager = rRadio.client.audio.manager or {}

local manager = rRadio.client.audio.manager
local sources = {}
local queued = {}
local volumes = {}
local activeAssignments = {}
local playbackNonce = {}
local muted = {}
local occlusionStates = {}
local presentationStates = {}
local setPresentationPhase
local updatePresentationFromChannel
local occlusionTraceBudget = 0
local channelScratch = {}

manager.Phases = manager.Phases or {
    IDLE = "idle",
    PENDING = "pending",
    QUEUED = "queued",
    CONNECTING = "connecting",
    PLAYING = "playing",
    SILENT_READY = "silent_ready",
    ERROR = "error"
}

local phases = manager.Phases
local UPDATE_INTERVAL = 0.2
local DEFAULT_ENVELOPE_INTERVAL = 0.05
local MIN_ENVELOPE_INTERVAL = 0.02
local MAX_FADE_MS = 6000
local AUDIBLE_GAIN_THRESHOLD = 0.01
local CROSSFADE_FOREGROUND_ENVELOPE_GAIN = 0.35
local CONNECT_TIMEOUT_SECONDS = 15
local CONNECT_TIMER_PREFIX = "rRadio.ClientAudioConnect."
local PI_OVER_2 = math.pi * 0.5
local DEFAULT_FULL_VOLUME_DISTANCE = 120
local DEFAULT_MAX_HEARING_DISTANCE = 900
local DEFAULT_FALLOFF_EXPONENT = 1.35
local DEFAULT_OCCLUSION_TRACE_INTERVAL = 0.2
local DEFAULT_OCCLUSION_TRACE_BUDGET = 4
local DEFAULT_OCCLUSION_BLOCKED_GAIN = 0.35
local DEFAULT_OCCLUSION_SMOOTHING_SPEED = 8
local enabledConVar = GetConVar( "rammel_rradio_enabled" )
local muteGameMenuConVar = GetConVar( "rammel_rradio_mute_game_menu" )
local crossfadeConVar = GetConVar( "rammel_rradio_crossfade_ms" )
local maxVolumeConVar = GetConVar( "rammel_rradio_max_volume" )

local function getEntityConfig( entity )
    return rRadio.util.GetEntityConfig( entity ) or rRadio.config.Boombox
end

local function shouldMuteForGameMenu()
    if not muteGameMenuConVar:GetBool() then return false end

    return gui.IsGameUIVisible()
end

local function requestStateRefresh( reason )
    timer.Simple( 0, function()
        local netHandlers = rRadio.client and rRadio.client.net and rRadio.client.net.handlers
        if not netHandlers or not netHandlers.RequestStateSnapshot then return end

        netHandlers.RequestStateSnapshot( reason or "audio" )
    end )
end

local function isEntityMuted( entity )
    if muted[entity] == true then return true end

    return rRadio.client.radio.mutes.IsEntityMuted( entity )
end

local function getStationChangeDuration()
    return math.Clamp( crossfadeConVar:GetInt(), 0, MAX_FADE_MS )
end

local function getConfiguredFadeDuration( key, fallback )
    if getStationChangeDuration() <= 0 then return 0 end

    local duration = rRadio.config.Crossfade[key]
    if duration == nil then duration = fallback end

    return math.Clamp( tonumber( duration ) or 0, 0, MAX_FADE_MS )
end

local function getInitialFadeInDuration()
    return getConfiguredFadeDuration( "InitialFadeInMs", 200 )
end

local function getStopFadeOutDuration()
    return getConfiguredFadeDuration( "StopFadeOutMs", 250 )
end

local function getEnvelopeInterval()
    local interval = tonumber( rRadio.config.Crossfade.TickInterval ) or DEFAULT_ENVELOPE_INTERVAL
    return math.max( interval, MIN_ENVELOPE_INTERVAL )
end

local function getMaxOutgoing()
    return math.max( tonumber( rRadio.config.Crossfade.MaxOutgoing ) or 3, 0 )
end

local function getBucket( entity )
    sources[entity] = sources[entity] or {
        current = nil,
        currentAssignment = nil,
        incoming = nil,
        incomingAssignment = nil,
        pendingAssignment = nil,
        pendingNonce = nil,
        outgoing = {},
        outgoingAssignments = {},
        envelopes = {},
        channelGains = {},
        channel3DEnabled = {}
    }

    return sources[entity]
end

local function removeOutgoing( bucket, channel )
    for index = #bucket.outgoing, 1, -1 do
        if bucket.outgoing[index] == channel then table.remove( bucket.outgoing, index ) end
    end
end

local function hasOutgoing( bucket, channel )
    for _, outgoing in ipairs( bucket.outgoing ) do
        if outgoing == channel then return true end
    end

    return false
end

local function hasValidOutgoing( bucket )
    for _, channel in ipairs( bucket.outgoing ) do
        if IsValid( channel ) then return true end
    end

    return false
end

local function isBucketEmpty( bucket )
    if not bucket then return true end
    if IsValid( bucket.current ) or IsValid( bucket.incoming ) then return false end
    if bucket.pendingAssignment then return false end
    if hasValidOutgoing( bucket ) then return false end

    return next( bucket.envelopes ) == nil
end

local function maybeRemoveBucket( entity, bucket )
    if isBucketEmpty( bucket ) then
        sources[entity] = nil
        occlusionStates[entity] = nil
    end
end

local function getConnectTimerName( entity )
    if not IsValid( entity ) then return nil end

    return CONNECT_TIMER_PREFIX .. entity:EntIndex()
end

local function removeConnectTimeout( entity )
    local timerName = getConnectTimerName( entity )
    if timerName then timer.Remove( timerName ) end
end

local function bumpNonce( entity )
    removeConnectTimeout( entity )
    playbackNonce[entity] = ( playbackNonce[entity] or 0 ) + 1

    return playbackNonce[entity]
end

local function assignmentUsesSameSource( left, right )
    if not left or not right then return false end
    if not left.url or left.url == "" then return false end
    if not right.url or right.url == "" then return false end

    return left.url == right.url
end

local function stopChannel( channel )
    if IsValid( channel ) then channel:Stop() end
end

local function hardStopBucket( entity, clearMute )
    local bucket = sources[entity]
    if bucket then
        stopChannel( bucket.current )
        stopChannel( bucket.incoming )

        for _, channel in ipairs( bucket.outgoing ) do
            stopChannel( channel )
        end
    end

    sources[entity] = nil
    occlusionStates[entity] = nil
    if clearMute then
        muted[entity] = nil
    end
end

local function clearPlaybackState( entity, clearMute )
    bumpNonce( entity )
    hardStopBucket( entity, clearMute )

    queued[entity] = nil
    volumes[entity] = nil
    activeAssignments[entity] = nil
    presentationStates[entity] = nil
end

local function countActivePlayback( ignoredEntity )
    local count = 0
    for entity, bucket in pairs( sources ) do
        if entity ~= ignoredEntity and IsValid( entity ) then
            if IsValid( bucket.current ) then count = count + 1 end
            if IsValid( bucket.incoming ) then count = count + 1 end
        end
    end

    return count
end

local function getSourcePosition( entity, config )
    config = config or getEntityConfig( entity )

    local sourceOffset = config and config.SourceOffset
    if isvector( sourceOffset ) and entity.LocalToWorld then return entity:LocalToWorld( sourceOffset ) end
    if entity.WorldSpaceCenter then return entity:WorldSpaceCenter() end

    return entity:GetPos()
end

local function getDistanceSquared( player, sourcePos )
    return player:GetPos():DistToSqr( sourcePos )
end

local function clampLocalVolume( volume )
    return math.Clamp( tonumber( volume ) or 0, 0, maxVolumeConVar:GetFloat() )
end

local function getMaxHearingDistance( config )
    return math.max( tonumber( config.MaxHearingDistance ) or DEFAULT_MAX_HEARING_DISTANCE, 1 )
end

local function getFullVolumeDistance( config, maxDistance )
    local fullDistance = tonumber( config.FullVolumeDistance ) or DEFAULT_FULL_VOLUME_DISTANCE
    return math.Clamp( fullDistance, 1, maxDistance )
end

local function computeDistanceGain( distance, fullDistance, maxDistance, exponent )
    if distance >= maxDistance then return 0 end
    if distance <= fullDistance then return 1 end
    if fullDistance >= maxDistance then return 1 end

    exponent = math.max( tonumber( exponent ) or DEFAULT_FALLOFF_EXPONENT, 0.01 )

    local raw = ( fullDistance / math.max( distance, 1 ) ) ^ exponent
    local floor = ( fullDistance / maxDistance ) ^ exponent
    local denominator = 1 - floor
    if denominator <= 0 then return 0 end

    return math.Clamp( ( raw - floor ) / denominator, 0, 1 )
end

local function getOcclusionState( entity )
    local state = occlusionStates[entity]
    if state then return state end

    state = {
        current = 1,
        target = 1,
        lastTraceTime = 0,
        lastUpdateTime = CurTime()
    }
    occlusionStates[entity] = state

    return state
end

local function smoothOcclusionState( state, now, config )
    local elapsed = math.max( now - ( state.lastUpdateTime or now ), 0 )
    state.lastUpdateTime = now

    local smoothingSpeed = math.max(
        tonumber( config.SmoothingSpeed ) or DEFAULT_OCCLUSION_SMOOTHING_SPEED,
        0
    )

    if smoothingSpeed <= 0 then
        state.current = state.target or 1
    else
        local alpha = 1 - math.exp( -elapsed * smoothingSpeed )
        state.current = Lerp( alpha, state.current or 1, state.target or 1 )
    end

    return math.Clamp( state.current or 1, 0, 1 )
end

local function traceOcclusion( player, entity, sourcePos )
    if occlusionTraceBudget <= 0 then return nil end

    occlusionTraceBudget = occlusionTraceBudget - 1

    local trace = util.TraceLine( {
        start = player:EyePos(),
        endpos = sourcePos,
        mask = MASK_SOLID,
        filter = { player, entity }
    } )

    if not trace or trace.StartSolid then return nil end

    return trace.Hit == true
end

local function computeOcclusionGain( player, entity, sourcePos, distanceGain )
    local config = rRadio.config.Occlusion
    if config.Enabled == false then return 1 end
    if distanceGain <= 0 then return 1 end

    local state = getOcclusionState( entity )
    local now = CurTime()
    local traceInterval = math.max(
        tonumber( config.TraceInterval ) or DEFAULT_OCCLUSION_TRACE_INTERVAL,
        0
    )

    if now - ( state.lastTraceTime or 0 ) >= traceInterval and occlusionTraceBudget > 0 then
        state.lastTraceTime = now

        local blocked = traceOcclusion( player, entity, sourcePos )
        if blocked ~= nil then
            local blockedGain = tonumber( config.BlockedVolumeMultiplier ) or DEFAULT_OCCLUSION_BLOCKED_GAIN
            state.target = blocked and math.Clamp( blockedGain, 0, 1 ) or 1
        end
    end

    return smoothOcclusionState( state, now, config )
end

local function beginOcclusionTraceBatch()
    local config = rRadio.config.Occlusion
    if config.Enabled == false then
        occlusionTraceBudget = 0
        return
    end

    occlusionTraceBudget = math.max(
        math.floor( tonumber( config.MaxTracesPerTick ) or DEFAULT_OCCLUSION_TRACE_BUDGET ),
        0
    )
end

local function endOcclusionTraceBatch()
    occlusionTraceBudget = 0
end

local function buildEntityPositionContext( entity )
    if not IsValid( entity ) then return nil end

    local config = getEntityConfig( entity )
    return {
        entity = entity,
        config = config,
        sourcePos = getSourcePosition( entity, config )
    }
end

local function buildEntityAudioContext( entity, player, context )
    context = context or buildEntityPositionContext( entity )
    if not context then return nil end

    local config = context.config
    local sourcePos = context.sourcePos

    context.distanceGain = 0
    context.occlusionGain = 1
    context.localVehicleMode = false
    context.channel3DEnabled = nil
    context.canEmit = false

    if not enabledConVar:GetBool() then return context end
    if isEntityMuted( entity ) then return context end
    if shouldMuteForGameMenu() then return context end

    player = player or LocalPlayer()
    if not IsValid( player ) then return context end

    local playerPos = player:GetPos()
    local playerVehicle = rRadio.vehicle.GetPlayerRadioHost( player )
    local localVehicleMode = playerVehicle == rRadio.util.GetRadioEntity( entity )

    context.player = player
    context.playerPos = playerPos
    context.playerVehicle = playerVehicle
    context.localVehicleMode = localVehicleMode
    context.channel3DEnabled = not localVehicleMode
    context.canEmit = true

    if localVehicleMode then
        context.distanceGain = 1
        return context
    end

    local distance = math.sqrt( playerPos:DistToSqr( sourcePos ) )
    local maxDistance = getMaxHearingDistance( config )
    local fullDistance = getFullVolumeDistance( config, maxDistance )
    local distanceGain = computeDistanceGain(
        distance,
        fullDistance,
        maxDistance,
        config.DistanceFalloffExponent
    )

    context.distanceGain = distanceGain
    context.occlusionGain = computeOcclusionGain( player, entity, sourcePos, distanceGain )

    return context
end

local function isWithinLoadRange( player, entity, context )
    context = context or buildEntityPositionContext( entity )
    if not context then return false end

    local config = context.config
    local sourcePos = context.sourcePos
    local range = getMaxHearingDistance( config ) * ( rRadio.config.LoadDistanceFactor or 2 )

    return getDistanceSquared( player, sourcePos ) <= range * range
end

local function isBeyondUnloadRange( player, entity, context )
    context = context or buildEntityPositionContext( entity )
    if not context then return false end

    local config = context.config
    local sourcePos = context.sourcePos
    local range = getMaxHearingDistance( config ) * ( rRadio.config.UnloadDistanceFactor or 2.5 )

    return getDistanceSquared( player, sourcePos ) > range * range
end

local function computeBaseVolume( context, volume )
    if not context or not context.canEmit then return 0 end

    return clampLocalVolume( volume ) * context.distanceGain * context.occlusionGain
end

local function curveProgress( curve, progress )
    if curve == "equalIn" or curve == "normalizedEqualIn" then
        return math.sin( progress * PI_OVER_2 )
    end

    if curve == "equalOut" or curve == "normalizedEqualOut" then
        return 1 - math.cos( progress * PI_OVER_2 )
    end

    return progress
end

local function normalizedEqualGain( curve, progress )
    local incoming = math.sin( progress * PI_OVER_2 )
    local outgoing = math.cos( progress * PI_OVER_2 )
    local total = incoming + outgoing
    if total <= 0 then return curve == "normalizedEqualIn" and 1 or 0 end

    if curve == "normalizedEqualIn" then return incoming / total end

    return outgoing / total
end

local function getEnvelopeProgress( envelope )
    local durationMs = tonumber( envelope.durationMs ) or 0
    if durationMs <= 0 then return 1 end

    local elapsedMs = ( SysTime() - envelope.startTime ) * 1000
    return math.Clamp( elapsedMs / durationMs, 0, 1 )
end

local function getEnvelopeGain( bucket, channel )
    local envelope = bucket.envelopes[channel]
    if not envelope then return 1 end

    local rawProgress = getEnvelopeProgress( envelope )
    if envelope.curve == "normalizedEqualIn" or envelope.curve == "normalizedEqualOut" then
        return normalizedEqualGain( envelope.curve, rawProgress )
    end

    local progress = curveProgress( envelope.curve, rawProgress )
    local gain = envelope.startGain + ( envelope.targetGain - envelope.startGain ) * progress

    return math.Clamp( gain, 0, 1 )
end

local function getChannelAssignment( bucket, channel )
    if bucket.current == channel then return bucket.currentAssignment end
    if bucket.incoming == channel then return bucket.incomingAssignment end

    return bucket.outgoingAssignments[channel]
end

local function getMaxCompetingGain( bucket, channel )
    local maxGain = 0
    for otherChannel, gain in pairs( bucket.channelGains ) do
        if otherChannel ~= channel and IsValid( otherChannel ) then
            maxGain = math.max( maxGain, tonumber( gain ) or 0 )
        end
    end

    return maxGain
end

setPresentationPhase = function( entity, phase, stationName, stationID, errorMessage )
    if not IsValid( entity ) then return end

    presentationStates[entity] = {
        phase = phase or phases.IDLE,
        stationName = stationName or "",
        stationID = stationID or "",
        error = errorMessage,
        updatedAt = CurTime()
    }
end

updatePresentationFromChannel = function( entity, bucket, channel, baseVolume, effectiveVolume )
    local assignment = getChannelAssignment( bucket, channel )
    if not assignment then return end

    local presentation = presentationStates[entity]
    if presentation and presentation.phase == phases.ERROR then return end
    if presentation and presentation.stationID ~= assignment.stationID then return end

    local phase = phases.CONNECTING
    if baseVolume <= AUDIBLE_GAIN_THRESHOLD then
        phase = phases.SILENT_READY
    elseif channel == bucket.incoming and effectiveVolume > AUDIBLE_GAIN_THRESHOLD then
        local envelopeGain = getEnvelopeGain( bucket, channel )
        local competingGain = getMaxCompetingGain( bucket, channel )
        local isForeground = competingGain <= AUDIBLE_GAIN_THRESHOLD
            or effectiveVolume >= competingGain
            or envelopeGain >= CROSSFADE_FOREGROUND_ENVELOPE_GAIN

        if isForeground then phase = phases.PLAYING end
    elseif effectiveVolume > AUDIBLE_GAIN_THRESHOLD then
        phase = phases.PLAYING
    end

    setPresentationPhase( entity, phase, assignment.stationName, assignment.stationID )
end

local function setChannel3DEnabled( bucket, channel, enabled )
    bucket.channel3DEnabled = bucket.channel3DEnabled or {}
    if bucket.channel3DEnabled[channel] == enabled then return end

    channel:Set3DEnabled( enabled )
    bucket.channel3DEnabled[channel] = enabled
end

local function applyChannelVolume( bucket, channel, entity, volume, context )
    if not IsValid( channel ) then return end

    context = context or buildEntityAudioContext( entity )
    if context and context.channel3DEnabled ~= nil then
        setChannel3DEnabled( bucket, channel, context.channel3DEnabled )
    end

    local baseVolume = computeBaseVolume( context, volume )
    local envelopeGain = getEnvelopeGain( bucket, channel )
    local effectiveVolume = baseVolume * envelopeGain
    bucket.channelGains[channel] = effectiveVolume

    channel:SetVolume( effectiveVolume )
    updatePresentationFromChannel( entity, bucket, channel, baseVolume, effectiveVolume )
end

local function addBucketChannel( channels, channel )
    if not IsValid( channel ) then return end

    for _, existing in ipairs( channels ) do
        if existing == channel then return end
    end

    channels[#channels + 1] = channel
end

local function collectBucketChannels( bucket, channels )
    channels = channels or {}
    table.Empty( channels )

    addBucketChannel( channels, bucket.current )
    addBucketChannel( channels, bucket.incoming )

    for _, channel in ipairs( bucket.outgoing ) do
        addBucketChannel( channels, channel )
    end

    return channels
end

local function applyBucketVolumes( entity, context )
    local bucket = sources[entity]
    if not bucket or not IsValid( entity ) then return end

    local volume = volumes[entity] or rRadio.client.radio.state.GetVolume( entity )
    context = context or buildEntityAudioContext( entity )
    for _, channel in ipairs( collectBucketChannels( bucket, channelScratch ) ) do
        applyChannelVolume( bucket, channel, entity, volume, context )
    end
end

local function beginEnvelope( bucket, channel, envelope )
    if not IsValid( channel ) then return end

    envelope.startTime = SysTime()
    envelope.durationMs = math.max( tonumber( envelope.durationMs ) or 0, 0 )
    bucket.envelopes[channel] = envelope

    if envelope.durationMs > 0 then return end

    bucket.envelopes[channel] = nil
    if envelope.onComplete then envelope.onComplete() end
end

local function stopOutgoingChannel( entity, bucket, channel )
    bucket.envelopes[channel] = nil
    bucket.channelGains[channel] = nil
    if bucket.channel3DEnabled then bucket.channel3DEnabled[channel] = nil end
    bucket.outgoingAssignments[channel] = nil
    removeOutgoing( bucket, channel )
    stopChannel( channel )
    maybeRemoveBucket( entity, bucket )
end

local function fadeChannelOut( entity, bucket, channel, durationMs, curve )
    if not IsValid( channel ) then return end
    local startGain = getEnvelopeGain( bucket, channel )
    local assignment = getChannelAssignment( bucket, channel )

    if bucket.current == channel then
        bucket.current = nil
        bucket.currentAssignment = nil
    end

    if bucket.incoming == channel then
        bucket.incoming = nil
        bucket.incomingAssignment = nil
    end

    if not hasOutgoing( bucket, channel ) then
        bucket.outgoing[#bucket.outgoing + 1] = channel
    end
    if assignment then bucket.outgoingAssignments[channel] = assignment end

    beginEnvelope( bucket, channel, {
        direction = "out",
        curve = curve or "linear",
        durationMs = durationMs,
        startGain = startGain,
        targetGain = 0,
        onComplete = function()
            stopOutgoingChannel( entity, bucket, channel )
        end
    } )
end

local function promoteIncoming( entity, bucket, channel )
    if sources[entity] ~= bucket then return end
    if bucket.incoming ~= channel then return end
    if not IsValid( channel ) then return end

    bucket.current = channel
    bucket.currentAssignment = bucket.incomingAssignment
    bucket.incoming = nil
    bucket.incomingAssignment = nil

    if not bucket.pendingAssignment and bucket.currentAssignment then
        local current = presentationStates[entity]
        setPresentationPhase(
            entity,
            current and current.phase or phases.CONNECTING,
            bucket.currentAssignment.stationName,
            bucket.currentAssignment.stationID
        )
    end

    applyBucketVolumes( entity )
    return true
end

local function capOutgoing( entity, bucket )
    local maxOutgoing = getMaxOutgoing()
    while #bucket.outgoing > maxOutgoing do
        local channel = table.remove( bucket.outgoing, 1 )
        bucket.envelopes[channel] = nil
        bucket.channelGains[channel] = nil
        if bucket.channel3DEnabled then bucket.channel3DEnabled[channel] = nil end
        bucket.outgoingAssignments[channel] = nil
        stopChannel( channel )
    end

    maybeRemoveBucket( entity, bucket )
end

local function fadeAudibleChannelsOut( entity, bucket, durationMs, curve )
    local channels = collectBucketChannels( bucket, channelScratch )
    for _, channel in ipairs( channels ) do
        fadeChannelOut( entity, bucket, channel, durationMs, curve )
    end

    capOutgoing( entity, bucket )
end

local function markPlaybackError( entity, assignment )
    assignment = assignment or {}
    bumpNonce( entity )

    local bucket = sources[entity]
    if bucket then
        bucket.pendingAssignment = nil
        bucket.pendingNonce = nil
    end

    volumes[entity] = nil
    activeAssignments[entity] = nil
    queued[entity] = nil
    setPresentationPhase( entity, phases.ERROR, assignment.stationName, assignment.stationID, assignment.error )
    if bucket then
        fadeAudibleChannelsOut( entity, bucket, getStopFadeOutDuration(), "linear" )
        maybeRemoveBucket( entity, bucket )
    end
end

local function retryPlayback( assignment, entity, nonce )
    if playbackNonce[entity] ~= nonce then return end

    local config = getEntityConfig( entity )
    local attempt = tonumber( assignment.retryAttempt ) or 0
    local maxAttempts = tonumber( config.RetryAttempts ) or 0
    if attempt >= maxAttempts then
        markPlaybackError( entity, assignment )
        return
    end

    local retryNonce = bumpNonce( entity )
    local delay = tonumber( config.RetryDelay ) or 2
    local retryAssignment = table.Copy( assignment )
    retryAssignment.retryAttempt = attempt + 1
    timer.Simple( delay, function()
        if IsValid( entity ) and playbackNonce[entity] == retryNonce then
            manager.ApplyAssignment( retryAssignment )
        end
    end )
end

local function clearPendingPlayback( entity, bucket )
    if not bucket.pendingAssignment then return end

    bumpNonce( entity )
    bucket.pendingAssignment = nil
    bucket.pendingNonce = nil
end

local function updateMatchingAssignment( entity, bucket, assignment )
    local matchesCurrent = assignmentUsesSameSource( bucket.currentAssignment, assignment )
    local matchesIncoming = assignmentUsesSameSource( bucket.incomingAssignment, assignment )
    local matchesPending = assignmentUsesSameSource( bucket.pendingAssignment, assignment )
    local matchesQueued = queued[entity] and assignmentUsesSameSource( queued[entity].assignment, assignment )

    if not matchesCurrent and not matchesIncoming and not matchesPending and not matchesQueued then
        return false
    end

    volumes[entity] = assignment.volume
    activeAssignments[entity] = assignment

    if matchesCurrent then
        bucket.currentAssignment = assignment
        clearPendingPlayback( entity, bucket )
        queued[entity] = nil

        if IsValid( bucket.incoming ) then
            fadeChannelOut( entity, bucket, bucket.incoming, getStopFadeOutDuration(), "linear" )
        end

        local current = presentationStates[entity]
        setPresentationPhase(
            entity,
            current and current.phase or phases.CONNECTING,
            assignment.stationName,
            assignment.stationID
        )
    elseif matchesIncoming then
        bucket.incomingAssignment = assignment
        clearPendingPlayback( entity, bucket )
        queued[entity] = nil
        setPresentationPhase( entity, phases.CONNECTING, assignment.stationName, assignment.stationID )
    elseif matchesPending then
        bucket.pendingAssignment = assignment
        setPresentationPhase( entity, phases.CONNECTING, assignment.stationName, assignment.stationID )
    elseif matchesQueued then
        queued[entity].assignment = assignment
        setPresentationPhase( entity, phases.QUEUED, assignment.stationName, assignment.stationID )
    end

    capOutgoing( entity, bucket )
    applyBucketVolumes( entity )

    return true
end

local function beginIncomingFade( entity, bucket, channel, assignment, hadAudiblePlayback )
    local durationMs = hadAudiblePlayback and getStationChangeDuration() or getInitialFadeInDuration()
    local curve = hadAudiblePlayback and "normalizedEqualIn" or "linear"

    bucket.incoming = channel
    bucket.incomingAssignment = assignment

    beginEnvelope( bucket, channel, {
        direction = "in",
        curve = curve,
        durationMs = durationMs,
        startGain = 0,
        targetGain = 1,
        onComplete = function()
            promoteIncoming( entity, bucket, channel )
        end
    } )
end

local function startConnectTimeout( assignment, entity, nonce )
    local timerName = getConnectTimerName( entity )
    if not timerName then return end

    timer.Create( timerName, CONNECT_TIMEOUT_SECONDS, 1, function()
        if not IsValid( entity ) or playbackNonce[entity] ~= nonce then return end

        local bucket = sources[entity]
        if bucket then
            bucket.pendingAssignment = nil
            bucket.pendingNonce = nil
        end

        retryPlayback( assignment, entity, nonce )
    end )
end

function manager.ApplyAssignment( assignment )
    local entity = rRadio.util.GetRadioEntity( assignment.entity )
    if not IsValid( entity ) or assignment.url == "" then return end
    if not enabledConVar:GetBool() then
        clearPlaybackState( entity, true )
        return
    end

    assignment.entity = entity
    local bucket = getBucket( entity )

    if updateMatchingAssignment( entity, bucket, assignment ) then return end

    volumes[entity] = assignment.volume
    activeAssignments[entity] = assignment
    queued[entity] = nil
    setPresentationPhase( entity, phases.CONNECTING, assignment.stationName, assignment.stationID )

    local player = LocalPlayer()
    if rRadio.config.ConditionalStationLoad and IsValid( player ) and not isWithinLoadRange( player, entity ) then
        bumpNonce( entity )
        hardStopBucket( entity )
        queued[entity] = {
            assignment = assignment
        }
        setPresentationPhase( entity, phases.QUEUED, assignment.stationName, assignment.stationID )
        return
    end

    local maxClientStations = tonumber( rRadio.config.MaxClientStations ) or 10
    if maxClientStations > 0 and countActivePlayback( entity ) >= maxClientStations then
        markPlaybackError( entity, assignment )
        return
    end

    local nonce = bumpNonce( entity )
    bucket = getBucket( entity )
    bucket.pendingAssignment = assignment
    bucket.pendingNonce = nonce

    startConnectTimeout( assignment, entity, nonce )
    sound.PlayURL( assignment.url, "3d noplay", function( source )
        if playbackNonce[entity] ~= nonce then
            stopChannel( source )
            return
        end

        removeConnectTimeout( entity )
        if not IsValid( source ) or not IsValid( entity ) then
            if IsValid( entity ) then
                bucket.pendingAssignment = nil
                bucket.pendingNonce = nil
                fadeAudibleChannelsOut( entity, bucket, getStopFadeOutDuration(), "linear" )
                retryPlayback( assignment, entity, nonce )
            end
            return
        end

        bucket.pendingAssignment = nil
        bucket.pendingNonce = nil

        local previousCurrent = bucket.current
        local previousIncoming = bucket.incoming
        local hadAudiblePlayback = IsValid( previousCurrent )
            or IsValid( previousIncoming )
            or hasValidOutgoing( bucket )

        source:Set3DFadeDistance( 1000000, 10000000 )
        source:SetPos( getSourcePosition( entity, getEntityConfig( entity ) ) )
        source:SetVolume( 0 )
        source:Play()

        bucket.incoming = source
        bucket.incomingAssignment = assignment

        if IsValid( previousCurrent ) then
            fadeChannelOut( entity, bucket, previousCurrent, getStationChangeDuration(), "normalizedEqualOut" )
        end

        if IsValid( previousIncoming ) then
            fadeChannelOut( entity, bucket, previousIncoming, getStationChangeDuration(), "normalizedEqualOut" )
        end

        beginIncomingFade( entity, bucket, source, assignment, hadAudiblePlayback )
        capOutgoing( entity, bucket )
        applyBucketVolumes( entity )
    end )
end

function manager.ClearAssignment( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return end

    bumpNonce( entity )

    local bucket = sources[entity]
    if bucket then
        bucket.pendingAssignment = nil
        bucket.pendingNonce = nil
    end

    queued[entity] = nil
    volumes[entity] = nil
    activeAssignments[entity] = nil
    presentationStates[entity] = nil

    if not bucket then return end

    fadeAudibleChannelsOut( entity, bucket, getStopFadeOutDuration(), "linear" )
    maybeRemoveBucket( entity, bucket )
end

manager.Stop = manager.ClearAssignment

function manager.SetVolume( entity, volume )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return end

    volumes[entity] = volume
    if activeAssignments[entity] then activeAssignments[entity].volume = volume end
    applyBucketVolumes( entity )
end

function manager.SetMuted( entity, isMuted )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return end

    if rRadio.client.radio.mutes.SetEntityMuted( entity, isMuted ) then
        muted[entity] = nil
    else
        muted[entity] = isMuted and true or nil
    end

    applyBucketVolumes( entity )
end

function manager.IsMuted( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    return IsValid( entity ) and isEntityMuted( entity )
end

function manager.GetPresentationState( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    return presentationStates[entity]
end

function manager.GetStationPresentationState( entity, stationID )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    stationID = tostring( stationID or "" )
    local presentation = presentationStates[entity]
    if presentation and presentation.stationID == stationID then return presentation end

    return nil
end

function manager.GetActiveStationID( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    local assignment = activeAssignments[entity]
    if assignment then return assignment.stationID end

    local queuedAssignment = queued[entity] and queued[entity].assignment
    return queuedAssignment and queuedAssignment.stationID or nil
end

function manager.GetActiveStationURL( entity )
    entity = rRadio.util.GetRadioEntity( entity )
    if not IsValid( entity ) then return nil end

    local assignment = activeAssignments[entity]
    if assignment and assignment.url and assignment.url ~= "" then return assignment.url end

    local queuedAssignment = queued[entity] and queued[entity].assignment
    if queuedAssignment and queuedAssignment.url and queuedAssignment.url ~= "" then return queuedAssignment.url end

    return nil
end

function manager.StopAll()
    local entities = {}
    for entity in pairs( sources ) do
        entities[entity] = true
    end

    for entity in pairs( queued ) do
        entities[entity] = true
    end

    for entity in pairs( activeAssignments ) do
        entities[entity] = true
    end

    for entity in pairs( entities ) do
        clearPlaybackState( entity, true )
    end
end

function manager.ListKnownAssignments()
    local rows = {}
    for entity, assignment in pairs( activeAssignments ) do
        if IsValid( entity ) then
            local presentation = presentationStates[entity]
            rows[#rows + 1] = {
                entity = entity,
                stationID = assignment.stationID,
                stationName = assignment.stationName,
                url = assignment.url,
                volume = volumes[entity] or assignment.volume,
                queued = queued[entity] ~= nil,
                phase = presentation and presentation.phase or phases.IDLE
            }
        end
    end

    return rows
end

local function appendConnectedRow( rows, entity, bucket, channel, role )
    if not IsValid( channel ) then return end

    local assignment = getChannelAssignment( bucket, channel )
    local volume = volumes[entity]
    if volume == nil and assignment then volume = assignment.volume end

    rows[#rows + 1] = {
        entity = entity,
        role = role,
        stationID = assignment and assignment.stationID or "",
        stationName = assignment and assignment.stationName or "",
        url = assignment and assignment.url or "",
        volume = volume or 0,
        gain = bucket.channelGains[channel] or 0
    }
end

function manager.ListConnectedStreams()
    local rows = {}
    for entity, bucket in pairs( sources ) do
        if IsValid( entity ) then
            appendConnectedRow( rows, entity, bucket, bucket.current, "current" )
            appendConnectedRow( rows, entity, bucket, bucket.incoming, "incoming" )
            for _, channel in ipairs( bucket.outgoing ) do
                appendConnectedRow( rows, entity, bucket, channel, "outgoing" )
            end
        end
    end

    return rows
end

local function refreshSourceVolumes()
    for entity in pairs( sources ) do
        if IsValid( entity ) then applyBucketVolumes( entity ) end
    end
end

local function muteSourceVolumes()
    for _, bucket in pairs( sources ) do
        for _, channel in ipairs( collectBucketChannels( bucket, channelScratch ) ) do
            channel:SetVolume( 0 )
        end
    end
end

local function updateQueued( player )
    for entity, data in pairs( queued ) do
        if not IsValid( entity ) then
            queued[entity] = nil
            muted[entity] = nil
            occlusionStates[entity] = nil
            activeAssignments[entity] = nil
            presentationStates[entity] = nil
        elseif isWithinLoadRange( player, entity ) then
            queued[entity] = nil
            manager.ApplyAssignment( data.assignment )
        end
    end
end

local function updateSources( player )
    beginOcclusionTraceBatch()

    for entity, bucket in pairs( sources ) do
        if not IsValid( entity ) then
            clearPlaybackState( entity, true )
        else
            local context = buildEntityPositionContext( entity )
            if rRadio.config.ConditionalStationUnload and isBeyondUnloadRange( player, entity, context ) then
                local assignment = activeAssignments[entity]
                bumpNonce( entity )
                hardStopBucket( entity )
                if assignment then
                    queued[entity] = {
                        assignment = assignment
                    }
                    setPresentationPhase( entity, phases.QUEUED, assignment.stationName, assignment.stationID )
                end
            else
                context = buildEntityAudioContext( entity, player, context )
                local sourcePos = context and context.sourcePos
                for _, channel in ipairs( collectBucketChannels( bucket, channelScratch ) ) do
                    if sourcePos then channel:SetPos( sourcePos ) end
                end

                applyBucketVolumes( entity, context )
            end
        end
    end

    endOcclusionTraceBatch()
end

local function updateEnvelope( entity, bucket, channel, envelope, context, volume )
    if not IsValid( channel ) then
        bucket.envelopes[channel] = nil
        bucket.channelGains[channel] = nil
        if bucket.channel3DEnabled then bucket.channel3DEnabled[channel] = nil end
        bucket.outgoingAssignments[channel] = nil
        removeOutgoing( bucket, channel )
        return
    end

    applyChannelVolume( bucket, channel, entity, volume, context )

    if getEnvelopeProgress( envelope ) < 1 then return end

    bucket.envelopes[channel] = nil
    if envelope.onComplete then envelope.onComplete() end
end

local function updateEnvelopes()
    for entity, bucket in pairs( sources ) do
        if not IsValid( entity ) then
            clearPlaybackState( entity, true )
        else
            if next( bucket.envelopes ) ~= nil then
                local context = buildEntityAudioContext( entity )
                local volume = volumes[entity] or rRadio.client.radio.state.GetVolume( entity )
                for channel, envelope in pairs( bucket.envelopes ) do
                    updateEnvelope( entity, bucket, channel, envelope, context, volume )
                end
            end

            maybeRemoveBucket( entity, bucket )
        end
    end
end

local function addDebugCommands()
    concommand.Remove( "rammel_rradio_disconnect_all" )
    concommand.Add( "rammel_rradio_disconnect_all", function()
        manager.StopAll()
        print( "[rRadio]", rRadio.L( "CommandDisconnectedAllStreams", "Disconnected all local radio streams." ) )
    end, nil,
        rRadio.L( "CommandDisconnectAllHelp", "Disconnect all local rRadio streams." ),
        FCVAR_CLIENTCMD_CAN_EXECUTE
    )

    concommand.Remove( "rammel_rradio_list_active" )
    concommand.Add( "rammel_rradio_list_active", function()
        local known = manager.ListKnownAssignments()
        print( "[rRadio] Known radio assignments:" )
        if #known == 0 then
            print( "[rRadio]", "  none" )
        else
            for _, row in ipairs( known ) do
                print(
                    "[rRadio]",
                    " ",
                    row.entity,
                    row.queued and "queued" or tostring( row.phase ),
                    row.stationID,
                    row.stationName,
                    row.volume
                )
            end
        end

        local connected = manager.ListConnectedStreams()
        print( "[rRadio] Connected local streams:" )
        if #connected == 0 then
            print( "[rRadio]", "  none" )
            return
        end

        for _, row in ipairs( connected ) do
            print(
                "[rRadio]",
                " ",
                row.entity,
                row.role,
                row.stationID,
                row.stationName,
                row.volume,
                row.url
            )
        end
    end, nil,
        rRadio.L( "CommandListActiveHelp", "List known and connected local rRadio streams." ),
        FCVAR_CLIENTCMD_CAN_EXECUTE
    )
end

function manager.Init()
    timer.Create( "rRadio_ClientAudio_Update", UPDATE_INTERVAL, 0, function()
        local player = LocalPlayer()
        if not IsValid( player ) then return end

        updateQueued( player )
        updateSources( player )
    end )

    timer.Create( "rRadio_ClientAudio_EnvelopeUpdate", getEnvelopeInterval(), 0, updateEnvelopes )

    addDebugCommands()

    hook.Add( "EntityRemoved", "rRadio_Audio_CleanupRemoved", function( entity )
        clearPlaybackState( entity, true )
    end )

    hook.Add( "rRadio_ClientRadioStateChanged", "rRadio_Audio_PromotePermanentMute", function( entity )
        if muted[entity] ~= true then return end

        if rRadio.client.radio.mutes.SetEntityMuted( entity, true ) then
            muted[entity] = nil
        end
    end )

    hook.Add( "ShutDown", "rRadio_Audio_StopAll", function()
        manager.StopAll()
    end )

    hook.Add( "OnPauseMenuShow", "rRadio_Audio_RefreshGameMenuMute", function()
        if muteGameMenuConVar:GetBool() then muteSourceVolumes() end
    end )

    cvars.AddChangeCallback( "rammel_rradio_mute_game_menu", function()
        refreshSourceVolumes()
    end, "rRadio_Audio_RefreshGameMenuMute" )

    cvars.AddChangeCallback( "rammel_rradio_enabled", function( _name, _oldValue, newValue )
        if tonumber( newValue ) == 0 then
            manager.StopAll()
            return
        end

        requestStateRefresh( "audio_enabled" )
    end, "rRadio_Audio_StopWhenDisabled" )
end

return manager
