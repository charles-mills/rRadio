rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.network = rRadio.radio.network or {}

local network = rRadio.radio.network
local protocol = rRadio.net.protocol
local messages = protocol.Messages
local customStations = rRadio.radio.customStations


local function sendChat( player, message )
    if IsValid( player ) then player:ChatPrint( "[rRadio] " .. message ) end
end

local function sendCustomStationResult( player, action, success, message )
    if not IsValid( player ) then return end

    net.Start( messages.CustomStationResult )
    protocol.WriteVersion()
    net.WriteString( protocol.LimitDisplayName( action or "" ) )
    net.WriteBool( success == true )
    net.WriteString( protocol.LimitDisplayName( message or "" ) )
    net.Send( player )
end

local function sendPublicAccessResult( player, success, public, message, entity )
    if not IsValid( player ) then return end

    net.Start( messages.PublicAccessResult )
    protocol.WriteVersion()
    net.WriteBool( success == true )
    net.WriteBool( public == true )
    net.WriteString( protocol.LimitDisplayName( message or "" ) )
    net.WriteEntity( entity )
    net.Send( player )
end

local function readRequestedRadioEntities( player )
    local count = math.min( net.ReadUInt( 16 ), protocol.Limits.StateRequestCount )
    local entities = {}
    local seen = {}
    for _ = 1, count do
        local entity = rRadio.util.GetRadioEntity( net.ReadEntity(), player )
        if IsValid( entity ) and not seen[entity] then
            seen[entity] = true
            entities[#entities + 1] = entity
        end
    end

    return entities
end

local function receiveStateSnapshotRequest( _length, player )
    if not protocol.ReadClientVersion() then return end
    if not IsValid( player ) then return end

    local includeMetadata = net.ReadBool()
    local entities = readRequestedRadioEntities( player )

    rRadio.logger.DebugScope( "radio", "Sending requested state snapshot", player, #entities )
    rRadio.radio.service.SyncToPlayer( player, entities, {
        includeMetadata = includeMetadata
    } )
end


local function receivePlayRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local stationID = protocol.ReadStationID()
    local volume = net.ReadFloat()
    local ok, reason = rRadio.radio.service.Play( player, entity, stationID, volume )
    if not ok then sendChat( player, reason or "Could not play station." ) end
end


local function receiveStopRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local ok, reason = rRadio.radio.service.Stop( player, entity )
    if not ok then sendChat( player, reason or "Could not stop radio." ) end
end


local function receiveVolumeRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local ok, reason = rRadio.radio.service.SetVolume( player, entity, volume )
    if not ok and reason then sendChat( player, reason ) end
end


local function receiveAddCustomStationRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local name = protocol.LimitDisplayName( net.ReadString() )
    local url = protocol.LimitString( net.ReadString(), protocol.Limits.URL )
    local ok, message = customStations.Add( player, name, url )
    sendCustomStationResult( player, "add", ok, message )
end


local function receiveEditCustomStationRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local stationID = protocol.ReadStationID()
    local name = protocol.LimitDisplayName( net.ReadString() )
    local url = protocol.LimitString( net.ReadString(), protocol.Limits.URL )
    local ok, message = customStations.Edit( player, stationID, name, url )
    sendCustomStationResult( player, "edit", ok, message )
end


local function receiveRemoveCustomStationRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local key = protocol.LimitString( net.ReadString(), protocol.Limits.CustomStationKey )
    local ok, message = customStations.Remove( player, key )
    sendCustomStationResult( player, "remove", ok, message )
end

local function receivePublicAccessRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local public = net.ReadBool()

    local ok, message, effectivePublic = rRadio.radio.service.SetPublic( player, entity, public )
    if effectivePublic == nil then effectivePublic = public end

    sendPublicAccessResult( player, ok, effectivePublic, message, entity )
end


function network.RegisterReceivers()
    net.Receive( messages.StateSnapshotRequest, receiveStateSnapshotRequest )
    net.Receive( messages.SelectStationRequest, receivePlayRequest )
    net.Receive( messages.StopRequest, receiveStopRequest )
    net.Receive( messages.VolumeRequest, receiveVolumeRequest )
    net.Receive( messages.AddCustomStationRequest, receiveAddCustomStationRequest )
    net.Receive( messages.EditCustomStationRequest, receiveEditCustomStationRequest )
    net.Receive( messages.RemoveCustomStationRequest, receiveRemoveCustomStationRequest )
    net.Receive( messages.PublicAccessRequest, receivePublicAccessRequest )
end


return network
