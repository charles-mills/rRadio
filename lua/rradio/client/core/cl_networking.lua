if SERVER then return end
rRadio.cl.networkHandlers = {}
rRadio.cl.networkHandlers["rRadio.SetRadioVolume"] = function()
    local ent = net.ReadEntity()
    local vol = net.ReadFloat()
    if not IsValid( ent ) then return end
    local actual = rRadio.interface.GetVehicleEntity( ent ) or ent
    rRadio.cl.entityVolumes[ent] = vol
    rRadio.cl.entityVolumes[actual] = vol
    local patch = rRadio.cl.radioSources[actual]
    if IsValid( patch ) then patch:SetVolume( rRadio.interface.ClampVolume( vol ) ) end
    rRadio.interface.refreshVolume( actual )
    rRadio.cl.performance.volumeChanged = true
end

rRadio.cl.networkHandlers["rRadio.UpdateRadioStatus"] = function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local isPlaying = net.ReadBool()
    local statusCode = net.ReadUInt( 2 )
    if statusCode == rRadio.status.TUNING and rRadio.cl.connectedStations[entity] then return end
    if statusCode == rRadio.status.PLAYING and IsValid( entity ) then
        local localStatus = rRadio.cl.boomboxStatuses[entity:EntIndex()]
        if localStatus and localStatus.stationStatus == rRadio.status.ERROR then return end
    end

    local status = ( statusCode == rRadio.status.STOPPED or statusCode == rRadio.status.TUNING
        or statusCode == rRadio.status.PLAYING or statusCode == rRadio.status.ERROR )
        and statusCode or rRadio.status.STOPPED
    local displayStatus = status
    if status == rRadio.status.PLAYING and not rRadio.cl.connectedStations[entity] then
        displayStatus = rRadio.status.TUNING
    end
    if status == rRadio.status.STOPPED or status == rRadio.status.ERROR then
        rRadio.cl.connectedStations[entity] = nil
        rRadio.cl.requestedStations[entity] = nil
    end

    if IsValid( entity ) then
        rRadio.cl.boomboxStatuses[entity:EntIndex()] = {
            stationStatus = displayStatus,
            stationName = stationName
        }

        entity:SetNWInt( "Status", statusCode )
        entity:SetNWString( "StationName", stationName )
        entity:SetNWBool( "IsPlaying", isPlaying )
        if displayStatus == rRadio.status.PLAYING then
            local prev = rRadio.cl.currentlyPlayingStations[entity] or {}
            prev.name = stationName
            rRadio.cl.currentlyPlayingStations[entity] = prev
        else
            rRadio.cl.currentlyPlayingStations[entity] = nil
        end
    end
end

rRadio.cl.networkHandlers["rRadio.CustomStationsUpdate"] = function()
    local list = net.ReadTable()
    local cat = rRadio.config.CustomStationCategory or "Custom"
    for url in pairs( rRadio.cl.customUrlSet ) do
        rRadio.cl.allowedUrlSet[url] = nil
    end

    rRadio.cl.customUrlSet = {}
    rRadio.cl.stationData[cat] = {}
    for _, st in ipairs( list ) do
        if type( st ) == "table" and type( st.name ) == "string" and type( st.url ) == "string" then
            table.insert( rRadio.cl.stationData[cat], {
                name = st.name,
                url = st.url,
                country = cat,
                countryKey = cat,
                nameLower = string.lower( st.name ),
                charMap = rRadio.interface.buildCharMap( st.name )
            } )

            rRadio.cl.allowedUrlSet[st.url] = true
            rRadio.cl.customUrlSet[st.url] = true
        end
    end

    rRadio.cl.rebuildNameIndex()
    if rRadio.cl.uiState.radioMenuOpen then rRadio.cl.openRadioMenu() end
end

rRadio.cl.networkHandlers["rRadio.PlayStation"] = function()
    if not rRadio.cl.cvars.enabled:GetBool() then return end
    local entity = net.ReadEntity()
    local actual = rRadio.interface.GetVehicleEntity( entity )
    if rRadio.cl.radioSources[actual] and IsValid( rRadio.cl.radioSources[actual] ) then
        rRadio.cl.radioSources[actual]:Stop()
        rRadio.cl.radioSources[actual] = nil
        rRadio.cl.entityVolumes[actual] = nil
    end

    if IsValid( actual ) and rRadio.utils.IsBoombox( actual ) then rRadio.utils.ClearRadioStatus( actual ) end
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()
    local nonce = ( rRadio.cl.playbackNonce[actual] or 0 ) + 1
    rRadio.cl.playbackNonce[actual] = nonce
    rRadio.utils.SetRadioStatus( actual, rRadio.status.TUNING, stationName )
    if rRadio.config.SecureStationLoad
        and not ( rRadio.cl.isUrlAllowed( url )
            or IsValid( actual ) and actual:GetNWBool( "IsPermanent" ) ) then
        return
    end
    local currentCount = rRadio.interface.updateStationCount()
    if not rRadio.cl.radioSources[actual] and currentCount >= rRadio.config.MaxClientStations then return end
    if rRadio.config.ConditionalStationLoad then
        rRadio.cl.queuedStations[actual] = {
            name = stationName,
            url = url,
            volume = volume,
            nonce = nonce
        }

        local ply = LocalPlayer()
        if IsValid( ply ) then
            local cfg = rRadio.interface.getEntityConfig( actual )
            if cfg and rRadio.cl.isEntityWithinLoadRange( ply:GetPos(), actual:GetPos(), cfg ) then
                rRadio.cl.startStationPlayback( actual, stationName, url, volume, nonce )
                rRadio.cl.queuedStations[actual] = nil
            end
        end
    else
        rRadio.cl.startStationPlayback( actual, stationName, url, volume, nonce )
    end
end

rRadio.cl.networkHandlers["rRadio.StopStation"] = function()
    local entity = net.ReadEntity()
    if not IsValid( entity ) then return end
    entity = rRadio.interface.GetVehicleEntity( entity )
    if rRadio.cl.radioSources[entity] and IsValid( rRadio.cl.radioSources[entity] ) then
        rRadio.cl.radioSources[entity]:Stop()
        rRadio.cl.radioSources[entity] = nil
        rRadio.cl.entityVolumes[entity] = nil
    end

    rRadio.cl.queuedStations[entity] = nil
    rRadio.cl.connectedStations[entity] = nil
    rRadio.cl.currentlyPlayingStations[entity] = nil
    rRadio.cl.stationLastPos[entity] = nil
    rRadio.cl.playbackNonce[entity] = nil
    if IsValid( entity ) and rRadio.utils.IsBoombox( entity ) then rRadio.utils.ClearRadioStatus( entity ) end
end

rRadio.cl.networkHandlers["rRadio.OpenMenu"] = function()
    local ent = net.ReadEntity()
    if not IsValid( ent ) then return end
    local ply = LocalPlayer()
    if rRadio.utils.IsBoombox( ent ) then
        ply.currentRadioEntity = ent
        if not rRadio.cl.uiState.radioMenuOpen then rRadio.cl.openRadioMenu() end
    end
end

rRadio.cl.networkHandlers["rRadio.ListCustomStations"] = function()
    local count = net.ReadUInt( 16 )
    if count == 0 then
        MsgC( Color( 255, 255, 255 ), "[rRadio] No custom stations found.\n" )
        return
    end

    MsgC( Color( 255, 0, 0 ), "[rRadio] Custom stations:\n" )
    for i = 1, count do
        local name = net.ReadString()
        local url = net.ReadString()
        MsgC( Color( 255, 0, 0 ), "[" .. i .. "] ", Color( 255, 255, 255 ), name .. ": " .. url .. "\n" )
    end

    MsgC(
        Color( 255, 0, 0 ), "\n!! ", Color( 255, 255, 255 ),
        "Remove a Station: !" .. rRadio.config.CommandRemoveStation .. " <Name> or <URL>\n"
    )
    MsgC(
        Color( 255, 0, 0 ), "!! ", Color( 255, 255, 255 ),
        "Add a Station: !" .. rRadio.config.CommandAddStation .. " <Name> <URL>\n"
    )
end

rRadio.cl.networkHandlers["rRadio.PlayVehicleAnimation"] = function()
    rRadio.logger.DebugScope( "cl_networking", "Received car radio message" )
    local veh = net.ReadEntity()
    local isDriver = net.ReadBool()
    timer.Simple( 0, function() rRadio.interface.DisplayVehicleEnterAnimation( veh, isDriver ) end )
end

rRadio.cl.networkHandlers["rRadio.SetConfigUpdate"] = function()
    for entity, source in pairs( rRadio.cl.radioSources ) do
        if IsValid( entity ) and IsValid( source ) then
            local fallback = rRadio.cl.entityVolumes[entity] or 0.5
            local cfg = rRadio.interface.getEntityConfig( entity )
            local volume = rRadio.interface.ClampVolume( cfg and cfg.Volume or fallback )
            source:SetVolume( volume )
        end
    end
end

rRadio.cl.networkHandlers["rRadio.SendPersistentConfirmation"] = function()
    local message = net.ReadString()
    chat.AddText( Color( 0, 255, 0 ), "[rRadio] ", Color( 255, 255, 255 ), message )
    if IsValid( rRadio.cl.uiState.permanentCheckboxRef ) then
        if string.find( message, "marked as permanent" ) then
            rRadio.cl.uiState.permanentCheckboxRef:SetChecked( true )
        elseif string.find( message, "permanence has been removed" ) then
            rRadio.cl.uiState.permanentCheckboxRef:SetChecked( false )
        end
    end
end

for name, handler in pairs( rRadio.cl.networkHandlers ) do
    net.Receive( name, handler )
end
