util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")
util.AddNetworkString("MakeBoomboxPermanent")
util.AddNetworkString("RemoveBoomboxPermanent")
util.AddNetworkString("BoomboxPermanentConfirmation")
util.AddNetworkString("RadioConfigUpdate")

hook.Run("rRadio.PostServerLoad")

rRadio.sv = rRadio.sv or {}

rRadio.sv.ActiveRadios        = rRadio.sv.ActiveRadios or {}
rRadio.sv.PlayerRetryAttempts = rRadio.sv.PlayerRetryAttempts or {}
rRadio.sv.PlayerCooldowns     = rRadio.sv.PlayerCooldowns or {}
rRadio.sv.volumeUpdateQueue   = rRadio.sv.volumeUpdateQueue or {}
rRadio.sv.EntityVolumes       = rRadio.sv.EntityVolumes or {}
rRadio.sv.BoomboxStatuses     = rRadio.sv.BoomboxStatuses or {}

local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0

rRadio.sv.RadioTimers = {
    "VolumeUpdate_",
    "StationUpdate_",
}

rRadio.sv.RadioDataTables = {
    volumeUpdateQueue   = true,
}

net.Receive("PlayCarRadioStation", function(len, ply)
    rRadio.DevPrint("[rRADIO] Server got PlayCarRadioStation from: " .. ply:Nick())
    for entIdx, data in pairs(rRadio.sv.ActiveRadios) do
        local ent = data.entity or Entity(entIdx)
        if not IsValid(ent) then
            rRadio.DevPrint("[rRADIO] Purging invalid ActiveRadio entry idx="..entIdx)
            rRadio.sv.ActiveRadios[entIdx] = nil
        end
    end

    local now = SysTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("The radio system is busy. Please try again in a moment.")
        return
    end
    lastGlobalAction = now

    local ent       = rRadio.sv.utils.GetVehicleEntity(net.ReadEntity())
    local station   = net.ReadString()
    local stationURL= net.ReadString()
    local volume    = net.ReadFloat()

    if not IsValid(ent) then return end

    if hook.Run("rRadio.PrePlayStation", ply, ent, station, stationURL, volume) == false then return end

    if not rRadio.utils.canUseRadio(ent) then
        ply:ChatPrint("[rRADIO] This seat cannot use the radio.")
        return
    end

    if now - (rRadio.sv.PlayerCooldowns[ply] or 0) < 0.25 then
        ply:ChatPrint("You are changing stations too quickly.")
        return
    end
    rRadio.sv.PlayerCooldowns[ply] = now

    if table.Count(rRadio.sv.ActiveRadios) >= 100 then
        rRadio.sv.utils.ClearOldestActiveRadio()
    end

    if rRadio.sv.utils.CountPlayerRadios(ply) >= 5 then
        ply:ChatPrint("You have reached your maximum number of active radios.")
        return
    end

    local idx = ent:EntIndex()

    if not rRadio.sv.utils.CanControlRadio(ent, ply) then
        ply:ChatPrint("You do not have permission to control this radio.")
        return
    end

    if rRadio.utils.IsBoombox(ent) then
        rRadio.utils.setRadioStatus(ent, "tuning", station)
        rRadio.sv.BoomboxStatuses[idx] = rRadio.sv.BoomboxStatuses[idx] or {}
        rRadio.sv.BoomboxStatuses[idx].stationName = station
        rRadio.sv.BoomboxStatuses[idx].url = stationURL
    end

    if rRadio.sv.ActiveRadios[idx] then
        rRadio.sv.utils.BroadcastStop(ent)
        rRadio.sv.utils.RemoveActiveRadio(ent)
    end

    rRadio.sv.utils.AddActiveRadio(ent, station, stationURL, volume)
    rRadio.DevPrint("[rRADIO] ActiveRadios now contains:")

    rRadio.sv.utils.BroadcastPlay(ent, station, stationURL, volume)

    if ent.IsPermanent then
        rRadio.sv.permanent.SavePermanentBoombox(ent)
    end

    timer.Create("StationUpdate_" .. idx, 2, 1, function()
        if IsValid(ent) then
            rRadio.utils.setRadioStatus(ent, "playing", station)
        end
    end)

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end

    if not rRadio.sv.utils.CanControlRadio(entity, ply) then
        ply:ChatPrint("You do not have permission to control this radio.")
        return
    end

    rRadio.utils.setRadioStatus(entity, "stopped")
    rRadio.sv.utils.RemoveActiveRadio(entity)
    rRadio.sv.utils.BroadcastStop(entity)
    net.Start("UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteString("stopped")
    net.Broadcast()
    local entIndex = entity:EntIndex()
    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end
    timer.Create("StationUpdate_" .. entIndex, rRadio.config.StationUpdateDebounce(), 1, function()
        if IsValid(entity) and entity.IsPermanent then
            rRadio.sv.permanent.SavePermanentBoombox(entity)
        end
    end)

    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local entIndex = IsValid(entity) and entity:EntIndex() or nil
    if not entIndex then return end
    if not rRadio.sv.volumeUpdateQueue[entIndex] then
        rRadio.sv.volumeUpdateQueue[entIndex] = {
            lastUpdate = 0,
            pendingVolume = nil,
            pendingPlayer = nil
        }
    end
    local updateData = rRadio.sv.volumeUpdateQueue[entIndex]
    local currentTime = SysTime()

    if currentTime - updateData.lastUpdate >= rRadio.config.VolumeUpdateDebounce() then
        rRadio.sv.utils.ProcessVolumeUpdate(entity, volume, ply)
        updateData.lastUpdate = currentTime
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        if not timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Create("VolumeUpdate_" .. entIndex, rRadio.config.VolumeUpdateDebounce(), 1, function()
                if updateData.pendingVolume and IsValid(updateData.pendingPlayer) then
                    rRadio.sv.utils.ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
                    updateData.lastUpdate = SysTime()
                    updateData.pendingVolume = nil
                    updateData.pendingPlayer = nil
                end
            end)
        end
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            rRadio.sv.utils.SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    rRadio.DevPrint("Player entered a vehicle")

    if not ply:GetInfoNum("rammel_rradio_enabled", 1) == 1 then return end

    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh then return end
    rRadio.DevPrint("Vehicle is valid")
    if rRadio.utils.isSitAnywhereSeat(vehicle) then return end
    rRadio.DevPrint("Vehicle is not a sit anywhere seat")

    if rRadio.config.DriverPlayOnly and veh:GetDriver() ~= ply then
        rRadio.DevPrint("Skipping CarRadioMessage: not driver")
        return
    end

    net.Start("CarRadioMessage")
    net.WriteEntity(vehicle)
    net.WriteBool(vehicle:GetDriver() == ply)
    net.Send(ply)

    rRadio.DevPrint("Queued car radio animation")
end)

hook.Add("CanTool", "rRadio.AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        return rRadio.utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "rRadio.AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        return rRadio.utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("InitPostEntity", "rRadio.initalizePostEntity", function()
    timer.Simple(1, function()
        if rRadio.sv.utils.IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
                    rRadio.sv.utils.AssignOwner(ply, ent)
                end
            end)
        end
    end)

    timer.Simple(0.5, function()
        rRadio.sv.permanent.LoadPermanentBoomboxes()
    end)
end)

timer.Create("CleanupInactiveRadios", rRadio.config.CleanupInterval(), 0, rRadio.sv.utils.CleanupInactiveRadios)

hook.Add("OnEntityCreated", "rRadio.InitializeRadio", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) and (rRadio.utils.IsBoombox(entity) or rRadio.utils.GetVehicle(entity)) then
            rRadio.sv.utils.InitializeEntityVolume(entity)
        end
    end)

    timer.Simple(0, function()
        if IsValid(entity) and rRadio.utils.GetVehicle(entity) then
            rRadio.sv.utils.UpdateVehicleStatus(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "rRadio.CleanupEntityRemoved", function(entity)
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end

    rRadio.sv.volumeUpdateQueue[entIndex] = nil

    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end

    if IsValid(entity) then
        rRadio.sv.utils.CleanupEntityData(entity:EntIndex())
    end

    local mainEntity = entity:GetParent() or entity
    if rRadio.sv.ActiveRadios[mainEntity:EntIndex()] then
        rRadio.sv.utils.RemoveActiveRadio(mainEntity)
    end
end)

hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    rRadio.sv.PlayerRetryAttempts[ply] = nil
    rRadio.sv.PlayerCooldowns[ply] = nil

    for entIndex, updateData in pairs(rRadio.sv.volumeUpdateQueue) do
        if updateData.pendingPlayer == ply then
            rRadio.sv.utils.CleanupEntityData(entIndex)
        end
    end

    rRadio.DevPrint("Volume update queue cleared for player: " .. ply:Nick())

    for tableName in pairs(rRadio.sv.RadioDataTables) do
        if _G[tableName] then
            for entIndex, data in pairs(_G[tableName]) do
                if data.ply == ply or data.pendingPlayer == ply then
                    rRadio.sv.utils.CleanupEntityData(entIndex)
                end
            end
        end
    end

    rRadio.DevPrint("Entity data cleaned up for player: " .. ply:Nick())
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    game.ReloadConVars()
    if IsValid(ply) then
        ply:ChatPrint("[rRADIO] Configuration reloaded!")
    else
        print("[rRADIO] Configuration reloaded!")
    end
end)