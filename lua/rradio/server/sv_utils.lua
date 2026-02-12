rRadio.sv = rRadio.sv or {}
local utils = {}
rRadio.sv.utils = utils
local sv = rRadio.sv
local config = rRadio.config
local rUtils = rRadio.utils
local function LogDebug( ... )
    rRadio.logger.DebugScope( "sv_utils", ... )
end

function utils.CanControlRadio( entity, player )
    if not IsValid( entity ) or not IsValid( player ) then return false end
    if rUtils.IsBoombox( entity ) then return rUtils.CanInteractWithBoombox( player, entity ) end
    local vehicle = rUtils.GetVehicle( entity )
    if IsValid( vehicle ) and ( not config.DriverPlayOnly or vehicle:GetDriver() == player ) then return true end
    return false
end

function utils.UpdateVehicleStatus( vehicle )
    if not IsValid( vehicle ) then return end
    local veh = rUtils.GetVehicle( vehicle )
    if not veh then return end
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool( "IsSitAnywhereSeat", isSitAnywhere )
    return isSitAnywhere
end

function utils.AssignOwner( player, entity )
    if not IsValid( player ) or not IsValid( entity ) then return end
    if entity.CPPISetOwner then entity:CPPISetOwner( player ) end
    entity:SetNWEntity( "Owner", player )
end

function utils.CountPlayerRadios( player )
    local playerRadioTable = sv.PlayerRadios[player]
    local count = 0
    if playerRadioTable then
        for _ in pairs( playerRadioTable ) do
            count = count + 1
        end
    end
    return count
end

function utils.CountActiveRadios()
    local count = 0
    for _ in pairs( sv.ActiveRadios or {} ) do
        count = count + 1
    end
    return count
end

function utils.BroadcastPlay( entity, stationName, url, volume, target )
    net.Start( "rRadio.PlayStation" )
    net.WriteEntity( entity )
    net.WriteString( stationName )
    net.WriteString( url )
    net.WriteFloat( volume )
    if target then net.Send( target ) else net.Broadcast() end
end

function utils.BroadcastStop( entity )
    net.Start( "rRadio.StopStation" )
    net.WriteEntity( entity )
    net.Broadcast()
end

local function HandleRetryLogic( player, retryFunction )
    if not sv.PlayerRetryAttempts[player] then
        sv.PlayerRetryAttempts[player] = 1
        LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: First attempt for " .. player:Nick() )
    end

    local attempt = sv.PlayerRetryAttempts[player]
    if attempt >= 3 then
        LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Max attempts reached for " .. player:Nick() )
        sv.PlayerRetryAttempts[player] = nil
        return false
    end

    sv.PlayerRetryAttempts[player] = attempt + 1
    timer.Simple( 5, function()
        if IsValid( player ) then
            LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Retrying for " .. player:Nick() )
            retryFunction( player )
        else
            LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Player no longer valid during retry" )
            sv.PlayerRetryAttempts[player] = nil
        end
    end )
    return true
end

function utils.SendActiveRadiosToPlayer( player )
    if not IsValid( player ) then
        LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Invalid player" )
        return
    end

    local activeRadios = sv.ActiveRadios
    if next( activeRadios ) == nil then
        LogDebug(
        "[sv-permanent] SendActiveRadiosToPlayer: No active radios found, attempt "
        .. ( sv.PlayerRetryAttempts[player] or 1 )
    )
        HandleRetryLogic( player, utils.SendActiveRadiosToPlayer )
        return
    end

    LogDebug(
        "[sv-permanent] SendActiveRadiosToPlayer: Sending "
        .. ( utils.CountActiveRadios() or 0 )
        .. " active radios to " .. player:Nick()
    )
    for entityIndex, radioData in pairs( activeRadios ) do
        local entity = Entity( entityIndex )
        LogDebug( "[sv-permanent] Sending radio info for entity " .. entityIndex .. " to " .. player:Nick() )
        LogDebug( "[sv-permanent] Radio station name: " .. radioData.stationName .. " URL: " .. radioData.url )
        utils.BroadcastPlay(
            entity,
            radioData.stationName,
            radioData.url,
            radioData.volume,
            player
        )
    end

    LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Completed for " .. player:Nick() )
    sv.PlayerRetryAttempts[player] = nil
end

function utils.ProcessVolumeUpdate( entity, volume, player )
    if not IsValid( entity ) or not IsValid( player ) then return end
    entity = rUtils.GetVehicle( entity ) or entity
    local entityIndex = entity:EntIndex()
    if not utils.CanControlRadio( entity, player ) then return end
    volume = rUtils.ClampVolume( volume )
    sv.EntityVolumes[entityIndex] = volume
    entity:SetNWFloat( "Volume", volume )
    net.Start( "rRadio.SetRadioVolume" )
    net.WriteEntity( entity )
    net.WriteFloat( volume )
    net.SendPAS( entity:GetPos() )
end

function utils.InitializeEntityVolume( entity )
    if not IsValid( entity ) then return end
    local entityIndex = entity:EntIndex()
    local entityVolumes = sv.EntityVolumes
    if not entityVolumes[entityIndex] then
        local cfg = rUtils.GetEntityConfig( entity )
        entityVolumes[entityIndex] = cfg and cfg.Volume or 0.5
        entity:SetNWFloat( "Volume", entityVolumes[entityIndex] )
    end
end

function utils.AddActiveRadio( entity, stationName, url, volume, owner )
    if not IsValid( entity ) then return end
    local entityIndex = entity:EntIndex()
    LogDebug(
        "[sv-permanent] Adding active radio for entity " .. entityIndex
        .. " owner=" .. ( IsValid( owner ) and owner:Nick() or "nil" )
    )
    local entityVolumes = sv.EntityVolumes
    local cfg = rUtils.GetEntityConfig( entity )
    entityVolumes[entityIndex] = entityVolumes[entityIndex]
        or volume
        or ( cfg and cfg.Volume or 0.5 )
    entity:SetNWString( "StationName", stationName )
    entity:SetNWString( "StationURL", url )
    entity:SetNWFloat( "Volume", entityVolumes[entityIndex] )
    LogDebug(
        "[sv-permanent] Setting volume for entity " .. entityIndex
        .. " to " .. tostring( entityVolumes[entityIndex] )
    )
    local player = owner or rUtils.GetOwner( entity )
    sv.ActiveRadios[entityIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = entityVolumes[entityIndex],
        owner = player,
        timestamp = SysTime()
    }

    if player then
        sv.PlayerRadios[player] = sv.PlayerRadios[player] or {}
        sv.PlayerRadios[player][entityIndex] = true
    end

    if rUtils.IsBoombox( entity ) then
        LogDebug( "[sv-permanent] Entity " .. entityIndex .. " is a boombox, updating status" )
        sv.BoomboxStatuses[entityIndex] = {
            stationStatus = rRadio.status.PLAYING,
            stationName = stationName,
            url = url
        }
    end

    LogDebug( "[sv-permanent] Successfully added entity " .. entityIndex .. " to active radios" )
end

local function resolveEntityIndex( entityOrIndex )
    if type( entityOrIndex ) == "number" then
        return entityOrIndex > 0 and entityOrIndex or nil
    end
    if IsValid( entityOrIndex ) then return entityOrIndex:EntIndex() end
    return nil
end

function utils.RemoveActiveRadio( entityOrIndex )
    local entityIndex = resolveEntityIndex( entityOrIndex )
    if not entityIndex then return end
    local activeRadioData = sv.ActiveRadios[entityIndex]
    if not activeRadioData then return end
    local entity = IsValid( entityOrIndex ) and entityOrIndex or activeRadioData.entity
    if IsValid( entity ) and rRadio.utils.IsBoombox( entity ) then
        LogDebug( "[sv-permanent] Removing ActiveRadio entry idx=" .. entityIndex )
    end
    local player = activeRadioData.owner
    local playerRadios = sv.PlayerRadios
    if player and playerRadios[player] then
        playerRadios[player][entityIndex] = nil
        if not next( playerRadios[player] ) then playerRadios[player] = nil end
    end

    sv.ActiveRadios[entityIndex] = nil
end

function utils.CleanupEntityData( entityIndex )
    local radioTimers = sv.RadioTimers
    for _, timerPrefix in ipairs( radioTimers ) do
        local timerName = timerPrefix .. entityIndex
        if timer.Exists( timerName ) then timer.Remove( timerName ) end
    end

    local radioDataTables = sv.RadioDataTables
    for _, tableName in ipairs( radioDataTables ) do
        local dataTable = sv[tableName]
        if dataTable and dataTable[entityIndex] then dataTable[entityIndex] = nil end
    end

    sv.EntityVolumes[entityIndex] = nil
end

function utils.CleanupInactiveRadios()
    local currentTime = SysTime()
    local activeRadios = sv.ActiveRadios
    local inactiveTimeout = config.InactiveTimeout
    for entityIndex, radioData in pairs( activeRadios ) do
        local entity = radioData.entity
        if not IsValid( entity )
            or currentTime - radioData.timestamp > inactiveTimeout then
            utils.RemoveActiveRadio( entityIndex )
        end
    end
end

function utils.ClearOldestActiveRadio()
    local oldestTime, oldestIndex = math.huge, nil
    local activeRadios = sv.ActiveRadios
    for entityIndex, radioData in pairs( activeRadios ) do
        local entity = radioData.entity or Entity( entityIndex )
        if not IsValid( entity ) then
            LogDebug( "[sv-permanent] Purging invalid ActiveRadio entry idx=" .. entityIndex )
            utils.RemoveActiveRadio( entityIndex )
        elseif radioData.timestamp then
            if radioData.timestamp < oldestTime then oldestTime, oldestIndex = radioData.timestamp, entityIndex end
        else
            LogDebug( "[sv-permanent] Entry idx=" .. entityIndex .. " missing timestamp, treating as oldest" )
            oldestTime, oldestIndex = 0, entityIndex
        end
    end

    if oldestIndex then
        LogDebug( "[sv-permanent] Clearing oldest ActiveRadio idx=" .. oldestIndex .. " timestamp=" .. oldestTime )
        local oldEntity = Entity( oldestIndex )
        if IsValid( oldEntity ) then utils.BroadcastStop( oldEntity ) end
        utils.RemoveActiveRadio( oldestIndex )
    end
end
