rRadio.sv = rRadio.sv or {}
local utils = {}
rRadio.sv.utils = utils
local sv = rRadio.sv
local config = rRadio.config
local rUtils = rRadio.utils
local function LogDebug( ... )
    rRadio.logger.DebugScope( "sv_utils", ... )
end

function utils.IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

function utils.CanControlRadio( entity, player )
    if not IsValid( entity ) or not IsValid( player ) then return false end
    if rUtils.IsBoombox( entity ) then return rUtils.CanInteractWithBoombox( player, entity ) end
    local vehicle = rUtils.GetVehicle( entity )
    if IsValid( vehicle ) then if not config.DriverPlayOnly or vehicle:GetDriver() == player then return true end end
    return false
end

function utils.GetVehicleEntity( entity )
    if not IsValid( entity ) then return entity end
    if not entity:IsVehicle() then return entity end
    local parent = entity:GetParent()
    return IsValid( parent ) and parent or entity
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
    return sv.ActiveRadiosCount or 0
end

function utils.ClampVolume( volume )
    if type( volume ) ~= "number" then return 0.5 end
    local maxVolume = config.MaxVolume
    return math.Clamp( volume, 0, maxVolume )
end

function utils.GetDefaultVolume( entity )
    if not IsValid( entity ) then return 0.5 end
    local class = entity:GetClass()
    if class == "rammel_boombox_gold" then
        return config.GoldenBoombox.Volume
    elseif class == "rammel_boombox" then
        return config.Boombox.Volume
    else
        return config.VehicleRadio.Volume
    end
end

function utils.BroadcastPlay( entity, stationName, url, volume )
    net.Start( "rRadio.PlayStation" )
    net.WriteEntity( entity )
    net.WriteString( stationName )
    net.WriteString( url )
    net.WriteFloat( volume )
    net.Broadcast()
end

function utils.BroadcastStop( entity )
    net.Start( "rRadio.StopStation" )
    net.WriteEntity( entity )
    net.Broadcast()
end

local function SendRadioToPlayer( player, entityIndex, radioData )
    local entity = Entity( entityIndex )
    LogDebug( "[sv-permanent] Sending radio info for entity " .. entityIndex .. " to " .. player:Nick() )
    LogDebug( "[sv-permanent] Radio station name: " .. radioData.stationName .. " URL: " .. radioData.url )
    net.Start( "rRadio.PlayStation" )
    net.WriteEntity( entity )
    net.WriteString( radioData.stationName )
    net.WriteString( radioData.url )
    net.WriteFloat( radioData.volume )
    net.Send( player )
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
        LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: No active radios found, attempt " .. ( sv.PlayerRetryAttempts[player] or 1 ) )
        HandleRetryLogic( player, utils.SendActiveRadiosToPlayer )
        return
    end

    LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Sending " .. ( utils.CountActiveRadios() or 0 ) .. " active radios to " .. player:Nick() )
    for entityIndex, radioData in pairs( activeRadios ) do
        SendRadioToPlayer( player, entityIndex, radioData )
    end

    LogDebug( "[sv-permanent] SendActiveRadiosToPlayer: Completed for " .. player:Nick() )
    sv.PlayerRetryAttempts[player] = nil
end

function utils.ProcessVolumeUpdate( entity, volume, player )
    if not IsValid( entity ) or not IsValid( player ) then return end
    entity = rUtils.GetVehicle( entity ) or entity
    local entityIndex = entity:EntIndex()
    if not utils.CanControlRadio( entity, player ) then return end
    volume = utils.ClampVolume( volume )
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
        entityVolumes[entityIndex] = utils.GetDefaultVolume( entity )
        entity:SetNWFloat( "Volume", entityVolumes[entityIndex] )
    end
end

function utils.AddActiveRadio( entity, stationName, url, volume, owner )
    if not IsValid( entity ) then return end
    local entityIndex = entity:EntIndex()
    LogDebug( "[sv-permanent] Adding active radio for entity " .. entityIndex .. " owner=" .. ( IsValid( owner ) and owner:Nick() or "nil" ) )
    local entityVolumes = sv.EntityVolumes
    entityVolumes[entityIndex] = entityVolumes[entityIndex] or volume or utils.GetDefaultVolume( entity )
    entity:SetNWString( "StationName", stationName )
    entity:SetNWString( "StationURL", url )
    entity:SetNWFloat( "Volume", entityVolumes[entityIndex] )
    LogDebug( "[sv-permanent] Setting volume for entity " .. entityIndex .. " to " .. tostring( entityVolumes[entityIndex] ) )
    local player = owner or rUtils.GetOwner( entity )
    sv.ActiveRadios[entityIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = entityVolumes[entityIndex],
        owner = player,
        timestamp = SysTime()
    }

    sv.ActiveRadiosCount = ( sv.ActiveRadiosCount or 0 ) + 1
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

function utils.RemoveActiveRadio( entity )
    if not IsValid( entity ) then return end
    local entityIndex = entity:EntIndex()
    local activeRadioData = sv.ActiveRadios[entityIndex]
    if activeRadioData then
        if rRadio.utils.IsBoombox( entity ) then LogDebug( "[sv-permanent] Removing ActiveRadio entry idx=" .. entityIndex ) end
        local player = activeRadioData.owner
        local playerRadios = sv.PlayerRadios
        if player and playerRadios[player] then
            playerRadios[player][entityIndex] = nil
            if not next( playerRadios[player] ) then playerRadios[player] = nil end
        end

        sv.ActiveRadiosCount = math.max( ( sv.ActiveRadiosCount or 1 ) - 1, 0 )
        sv.ActiveRadios[entityIndex] = nil
    end
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
        if not IsValid( entity ) or currentTime - radioData.timestamp > inactiveTimeout then utils.RemoveActiveRadio( entity ) end
    end
end

function utils.ClearOldestActiveRadio()
    local oldestTime, oldestIndex = math.huge, nil
    local activeRadios = sv.ActiveRadios
    for entityIndex, radioData in pairs( activeRadios ) do
        local entity = radioData.entity or Entity( entityIndex )
        if not IsValid( entity ) then
            LogDebug( "[sv-permanent] Purging invalid ActiveRadio entry idx=" .. entityIndex )
            activeRadios[entityIndex] = nil
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
        utils.RemoveActiveRadio( oldEntity )
    end
end
