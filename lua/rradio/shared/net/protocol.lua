rRadio = rRadio or {}
rRadio.net = rRadio.net or {}
rRadio.net.protocol = rRadio.net.protocol or {}

local protocol = rRadio.net.protocol

protocol.Version = 2

protocol.Messages = {
    SelectStationRequest = "rRadio.RequestSelectStation",
    StopRequest = "rRadio.RequestStopRadio",
    VolumeRequest = "rRadio.RequestRadioVolume",
    OpenMenu = "rRadio.MenuOpen",
    StateSnapshotRequest = "rRadio.RequestRadioAssignments",
    StateSnapshot = "rRadio.RadioAssignments",
    AssignmentBroadcast = "rRadio.RadioAssignment",
    ClearBroadcast = "rRadio.RadioCleared",
    VolumeBroadcast = "rRadio.RadioVolume",
    SettingsBroadcast = "rRadio.RadioSettings",
    CustomStations = "rRadio.CustomStations",
    CustomStationResult = "rRadio.CustomStationResult",
    AddCustomStationRequest = "rRadio.RequestAddCustomStation",
    EditCustomStationRequest = "rRadio.RequestEditCustomStation",
    RemoveCustomStationRequest = "rRadio.RequestRemoveCustomStation",
    PublicAccessRequest = "rRadio.RequestBoomboxPublic",
    PublicAccessResult = "rRadio.BoomboxPublicResult",
    PersistenceRequest = "rRadio.RequestPersistence",
    PersistenceResult = "rRadio.PersistenceResult",
    VehicleAnimation = "rRadio.VehicleAnimation",
    ConfigSnapshot = "rRadio.ConfigSnapshot",
    ConfigSetRequest = "rRadio.RequestConfigSet",
    ConfigResetRequest = "rRadio.RequestConfigReset",
    ConfigSetResult = "rRadio.ConfigSetResult"
}

protocol.Limits = {
    StationID = 128,
    PermanentID = 96,
    StationName = 96,
    ConfigID = 128,
    ConfigValue = 8192,
    ConfigCount = 512,
    CustomStationKey = 256,
    URL = 512,
    CustomStationCount = 4096,
    StateRequestCount = 4096,
    ActiveStateCount = 4096
}

function protocol.RegisterServerMessages()
    if not SERVER then return end

    for _, messageName in pairs( protocol.Messages ) do
        util.AddNetworkString( messageName )
    end
end

local function readVersion()
    local version = net.ReadUInt( 8 )
    return version == protocol.Version
end

function protocol.WriteVersion()
    net.WriteUInt( protocol.Version, 8 )
end

function protocol.ReadClientVersion()
    return readVersion()
end

function protocol.LimitString( value, limit )
    local text = tostring( value or "" )
    limit = tonumber( limit ) or #text
    if #text <= limit then return text end

    return string.sub( text, 1, limit )
end

function protocol.LimitDisplayName( value, limit )
    local text = tostring( value or "" )
    limit = math.floor( tonumber( limit ) or protocol.Limits.StationName )
    if limit <= 0 then return "" end
    if #text <= limit then return text end

    local firstOverflowByte = limit + 1
    local startByteIndex = limit
    while startByteIndex > 0 do
        local byte = string.byte( text, startByteIndex )
        if not byte or byte < 128 or byte >= 192 then break end

        startByteIndex = startByteIndex - 1
    end

    if startByteIndex <= 0 then return "" end

    local startByte = string.byte( text, startByteIndex ) or 0
    local characterBytes = 1
    if startByte >= 240 and startByte <= 244 then
        characterBytes = 4
    elseif startByte >= 224 then
        characterBytes = 3
    elseif startByte >= 194 then
        characterBytes = 2
    end

    if startByteIndex + characterBytes > firstOverflowByte then
        return string.sub( text, 1, startByteIndex - 1 )
    end

    return string.sub( text, 1, limit )
end

function protocol.WriteStationID( stationID )
    net.WriteString( protocol.LimitString( stationID, protocol.Limits.StationID ) )
end

function protocol.ReadStationID()
    local stationID = net.ReadString()
    if #stationID > protocol.Limits.StationID then return nil end

    return stationID
end

function protocol.WriteConfigID( id )
    net.WriteString( protocol.LimitString( id, protocol.Limits.ConfigID ) )
end

function protocol.ReadConfigID()
    local id = net.ReadString()
    if #id > protocol.Limits.ConfigID then return nil end

    return id
end

function protocol.WriteConfigValue( value )
    net.WriteString( protocol.LimitString( value, protocol.Limits.ConfigValue ) )
end

function protocol.ReadConfigValue()
    local value = net.ReadString()
    if #value > protocol.Limits.ConfigValue then return "" end

    return value
end

function protocol.WriteRadioState( state )
    state = state or {}
    local assignment = state.assignment
    local settings = state.settings or {}

    net.WriteEntity( state.entity )
    net.WriteUInt( math.max( math.floor( tonumber( state.revision ) or 0 ), 0 ), 32 )
    net.WriteBool( assignment ~= nil and assignment.active == true )
    if assignment ~= nil and assignment.active == true then
        net.WriteString( protocol.LimitString( assignment.stationID, protocol.Limits.StationID ) )
        net.WriteString( protocol.LimitDisplayName( assignment.stationName ) )
        net.WriteString( protocol.LimitString( assignment.url, protocol.Limits.URL ) )
        net.WriteFloat( assignment.volume or 0 )
    end

    net.WriteBool( settings.permanent == true )
    net.WriteString( protocol.LimitString( settings.permanentID, protocol.Limits.PermanentID ) )
    net.WriteBool( settings.public == true )
    net.WriteFloat( settings.defaultVolume or 1 )
end

function protocol.ReadRadioState()
    local state = {
        entity = net.ReadEntity(),
        revision = net.ReadUInt( 32 ),
        assignment = nil,
        settings = nil
    }

    if net.ReadBool() then
        state.assignment = {
            active = true,
            stationID = net.ReadString(),
            stationName = net.ReadString(),
            url = net.ReadString(),
            volume = net.ReadFloat()
        }

        if #state.assignment.stationID > protocol.Limits.StationID then state.assignment.stationID = "" end
        if #state.assignment.stationName > protocol.Limits.StationName then
            state.assignment.stationName = protocol.LimitDisplayName( state.assignment.stationName )
        end
        if #state.assignment.url > protocol.Limits.URL then state.assignment.url = "" end
    end

    state.settings = {
        permanent = net.ReadBool(),
        permanentID = net.ReadString(),
        public = net.ReadBool(),
        defaultVolume = net.ReadFloat()
    }
    if #state.settings.permanentID > protocol.Limits.PermanentID then state.settings.permanentID = "" end

    return state
end

function protocol.WriteCustomStationMetadata( station, includeURL )
    net.WriteString( protocol.LimitString( station.id, protocol.Limits.StationID ) )
    net.WriteString( protocol.LimitDisplayName( station.name ) )
    local countryKey = station.countryKey
    if station.source == rRadio.constants.Defaults.CustomStationSource then
        countryKey = rRadio.config.CustomStationCategory or countryKey
    end

    net.WriteString( protocol.LimitDisplayName( countryKey ) )
    if includeURL then net.WriteString( protocol.LimitString( station.url, protocol.Limits.URL ) ) end
end

function protocol.ReadCustomStationMetadata( includeURL )
    return {
        id = protocol.LimitString( net.ReadString(), protocol.Limits.StationID ),
        name = protocol.LimitDisplayName( net.ReadString() ),
        countryKey = protocol.LimitDisplayName( net.ReadString() ),
        url = includeURL and protocol.LimitString( net.ReadString(), protocol.Limits.URL ) or nil,
        source = rRadio.constants.Defaults.CustomStationSource
    }
end

return protocol
