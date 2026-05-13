rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.service = rRadio.radio.service or {}

local service = rRadio.radio.service
local playback = rRadio.radio.playback
local snapshots = rRadio.radio.snapshots
local network = rRadio.radio.network
local commands = rRadio.radio.commands
local lifecycle = rRadio.radio.lifecycle
local protocol = rRadio.net.protocol

service.Play = playback.Play
service.Stop = playback.Stop
service.SetVolume = playback.SetVolume
service.SetPublic = playback.SetPublic
service.Restore = playback.Restore
service.CleanupEntity = playback.CleanupEntity
service.CleanupPlayer = playback.CleanupPlayer
service.CleanupInactive = playback.CleanupInactive
service.CleanupInvalid = playback.CleanupInvalid
service.GetAssignment = playback.GetAssignment
service.SyncToPlayer = snapshots.SyncToPlayer
service.BroadcastCustomStations = snapshots.BroadcastCustomStations
service.SetPermanent = function( ... )
    return rRadio.persistence.service.SetPermanent( ... )
end


function service.Init()
    protocol.RegisterServerMessages()
    rRadio.radio.stateStore.RebuildFromEntities()
    network.RegisterReceivers()
    rRadio.configManager.service.RegisterReceivers()
    lifecycle.Register()
    commands.Register()
end


return service
