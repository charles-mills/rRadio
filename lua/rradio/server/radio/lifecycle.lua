rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.lifecycle = rRadio.radio.lifecycle or {}

local lifecycle = rRadio.radio.lifecycle
local protocol = rRadio.net.protocol
local messages = protocol.Messages
local permissions = rRadio.radio.permissions
local cooldowns = rRadio.radio.cooldowns
local stateStore = rRadio.radio.stateStore

local function isRadioEntity( entity )
    if not IsValid( entity ) then return false end
    if rRadio.util.IsBoomboxClass( entity:GetClass() ) then return true end

    return rRadio.vehicle.IsRadioHost( entity )
end

local function createCleanupTimer()
    timer.Create( "rRadio_Radio_CleanupInvalid", rRadio.config.CleanupInterval or 300, 0, function()
        rRadio.radio.service.CleanupInvalid()
        rRadio.radio.service.CleanupInactive()
    end )
end


local function assignOwner( entity, player )
    if not IsValid( entity ) or not IsValid( player ) then return end
    if not rRadio.util.IsBoomboxClass( entity:GetClass() ) then return end

    stateStore.SetOwner( entity, player )
end


local function sendVehicleHint( player, vehicle )
    local radioEntity = rRadio.vehicle.ResolveRadioHost( vehicle, player )
    if not IsValid( radioEntity ) then return end
    if not permissions.CanControl( player, radioEntity ) then return end

    net.Start( messages.VehicleAnimation )
    protocol.WriteVersion()
    net.WriteEntity( radioEntity )
    net.WriteBool( rRadio.vehicle.GetDriver( radioEntity ) == player )
    net.Send( player )
end


local function initializeCreatedRadioEntity( entity )
    timer.Simple( 0, function()
        if not isRadioEntity( entity ) then return end

        stateStore.InitializeEntity( entity )
        rRadio.radio.snapshots.BroadcastSettings( entity )
    end )
end


function lifecycle.Register()
    hook.Add( "OnEntityCreated", "rRadio_Radio_InitializeCreatedEntity", initializeCreatedRadioEntity )

    hook.Add( "EntityRemoved", "rRadio_Radio_CleanupRemovedEntity", function( entity )
        rRadio.radio.service.CleanupEntity( entity, "removed" )
    end )

    hook.Add( "PlayerDisconnected", "rRadio_Radio_ClearPlayerCooldown", function( player )
        rRadio.radio.service.CleanupPlayer( player )
        cooldowns.ClearPlayer( player )
    end )

    hook.Add( "PlayerEnteredVehicle", "rRadio_VehicleHint_ShowForDriver", sendVehicleHint )

    hook.Add( "playerBoughtCustomEntity", "rRadio_Radio_AssignDarkRPOwner", function( player, _entityTable, entity )
        assignOwner( entity, player )
    end )

    createCleanupTimer()

    hook.Add( "rRadio_ConfigChanged", "rRadio_Radio_RefreshCleanupTimerConfig", function( id )
        if id == "CleanupInterval" then createCleanupTimer() end
    end )
end


return lifecycle
