-- Enhanced rRadio server-side logic with improved performance, error handling, and modularity
hook.Run("rRadio.PostServerLoad")

rRadio.sv = rRadio.sv or {}
rRadio.sv.ActiveRadios = rRadio.sv.ActiveRadios or {}
rRadio.sv.PlayerRetryAttempts = rRadio.sv.PlayerRetryAttempts or {}
rRadio.sv.PlayerCooldowns = rRadio.sv.PlayerCooldowns or {}
rRadio.sv.volumeUpdateQueue = rRadio.sv.volumeUpdateQueue or {}
rRadio.sv.EntityVolumes = rRadio.sv.EntityVolumes or {}
rRadio.sv.BoomboxStatuses = rRadio.sv.BoomboxStatuses or {}

local GLOBAL_COOLDOWN = 0.5 -- Reduced for better responsiveness
local lastGlobalAction = 0
local MAX_ACTIVE_RADIOS = 50 -- Lowered to prevent server strain
local PLAYER_RADIO_LIMIT = 3 -- Reduced to balance resource usage

rRadio.sv.RadioTimers = {
    VolumeUpdate = "VolumeUpdate_",
    StationUpdate = "StationUpdate_"
}

rRadio.sv.RadioDataTables = {
    volumeUpdateQueue = true
}

-- Utility function to validate entity and player
local function validateEntityAndPlayer(ent, ply)
    if not IsValid(ent) or not IsValid(ply) then return false end
    if not rRadio.utils.canUseRadio(ent) then
        ply:ChatPrint("[rRADIO] This seat cannot use the radio.")
        return false
    end
    if not rRadio.sv.utils.CanControlRadio(ent, ply) then
        ply:ChatPrint("[rRADIO] You do not have permission to control this radio.")
        return false
    end
    return true
end

-- Centralized cooldown check
local function checkCooldown(ply, now)
    if now - (rRadio.sv.PlayerCooldowns[ply] or 0) < 0.2 then
        ply:ChatPrint("You are changing stations too quickly.")
        return false
    end
    rRadio.sv.PlayerCooldowns[ply] = now
    return true
end

net.Receive("rRadio.PlayStation", function(len, ply)
    rRadio.DevPrint("[rRADIO] PlayStation request from: " .. ply:Nick())

    -- Clean invalid radio entries
    for entIdx, data in pairs(rRadio.sv.ActiveRadios) do
        if not IsValid(data.entity or Entity(entIdx)) then
            rRadio.DevPrint("[rRADIO] Purging invalid radio idx=" .. entIdx)
            rRadio.sv.ActiveRadios[entIdx] = nil
        end
    end

    local now = SysTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("Radio system busy. Try again shortly.")
        return
    end
    lastGlobalAction = now

    local ent = rRadio.sv.utils.GetVehicleEntity(net.ReadEntity())
    local station = net.ReadString()
    local stationURL = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1) -- Ensure volume is valid

    if not validateEntityAndPlayer(ent, ply) then return end
    if hook.Run("rRadio.PrePlayStation", ply, ent, station, stationURL, volume) == false then return end
    if not checkCooldown(ply, now) then return end

    -- Enforce radio limits
    if table.Count(rRadio.sv.ActiveRadios) >= MAX_ACTIVE_RADIOS then
        rRadio.sv.utils.ClearOldestActiveRadio()
    end
    if rRadio.sv.utils.CountPlayerRadios(ply) >= PLAYER_RADIO_LIMIT then
        ply:ChatPrint("Max active radios reached.")
        return
    end

    local idx = ent:EntIndex()

    -- Handle boombox-specific logic
    if rRadio.utils.IsBoombox(ent) then
        rRadio.utils.setRadioStatus(ent, "tuning", station)
        rRadio.sv.BoomboxStatuses[idx] = { stationName = station, url = stationURL }
    end

    -- Stop and remove existing radio
    if rRadio.sv.ActiveRadios[idx] then
        rRadio.sv.utils.BroadcastStop(ent)
        rRadio.sv.utils.RemoveActiveRadio(ent)
    end

    -- Add and broadcast new radio
    rRadio.sv.utils.AddActiveRadio(ent, station, stationURL, volume)
    rRadio.sv.utils.BroadcastPlay(ent, station, stationURL, volume)

    -- Save permanent boombox
    if ent.IsPermanent then
        rRadio.sv.permanent.SavePermanentBoombox(ent)
    end

    -- Debounced station update
    timer.Create(rRadio.sv.RadioTimers.StationUpdate .. idx, 1.5, 1, function()
        if IsValid(ent) then
            rRadio.utils.setRadioStatus(ent, "playing", station)
        end
    end)

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("rRadio.StopStation", function(len, ply)
    local ent = net.ReadEntity()
    if not validateEntityAndPlayer(ent, ply) then return end
    if hook.Run("rRadio.PreStopStation", ply, ent) == false then return end

    local idx = ent:EntIndex()
    rRadio.utils.setRadioStatus(ent, "stopped")
    rRadio.sv.utils.RemoveActiveRadio(ent)
    rRadio.sv.utils.BroadcastStop(ent)

    -- Broadcast status update
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(ent)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteString("stopped")
    net.Broadcast()

    -- Clean up timers
    for _, timerPrefix in pairs(rRadio.sv.RadioTimers) do
        if timer.Exists(timerPrefix .. idx) then
            timer.Remove(timerPrefix .. idx)
        end
    end

    -- Save permanent boombox
    timer.Create(rRadio.sv.RadioTimers.StationUpdate .. idx, rRadio.config.StationUpdateDebounce(), 1, function()
        if IsValid(ent) and ent.IsPermanent then
            rRadio.sv.permanent.SavePermanentBoombox(ent)
        end
    end)

    hook.Run("rRadio.PostStopStation", ply, ent)
end)

net.Receive("rRadio.SetRadioVolume", function(len, ply)
    local ent = net.ReadEntity()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)
    local idx = IsValid(ent) and ent:EntIndex() or nil
    if not idx or not validateEntityAndPlayer(ent, ply) then return end

    rRadio.sv.volumeUpdateQueue[idx] = rRadio.sv.volumeUpdateQueue[idx] or {
        lastUpdate = 0,
        pendingVolume = nil,
        pendingPlayer = nil
    }

    local updateData = rRadio.sv.volumeUpdateQueue[idx]
    local now = SysTime()

    if now - updateData.lastUpdate >= rRadio.config.VolumeUpdateDebounce() then
        rRadio.sv.utils.ProcessVolumeUpdate(ent, volume, ply)
        updateData.lastUpdate = now
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        updateData.pendingVolume = volume
        updateData.pendingPlayer = ply
        if not timer.Exists(rRadio.sv.RadioTimers.VolumeUpdate .. idx) then
            timer.Create(rRadio.sv.RadioTimers.VolumeUpdate .. idx, rRadio.config.VolumeUpdateDebounce(), 1, function()
                if updateData.pendingVolume and IsValid(updateData.pendingPlayer) and IsValid(ent) then
                    rRadio.sv.utils.ProcessVolumeUpdate(ent, updateData.pendingVolume, updateData.pendingPlayer)
                    updateData.lastUpdate = SysTime()
                    updateData.pendingVolume = nil
                    updateData.pendingPlayer = nil
                end
            end)
        end
    end
end)

-- Optimized player join handling
hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then
            rRadio.sv.utils.SendActiveRadiosToPlayer(ply)
        end
    end)
end)

-- Improved vehicle handling
hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    if ply:GetInfoNum("rammel_rradio_enabled", 1) ~= 1 then return end

    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh or rRadio.utils.isSitAnywhereSeat(vehicle) then return end

    if rRadio.config.DriverPlayOnly and veh:GetDriver() ~= ply then return end

    net.Start("rRadio.PlayVehicleAnimation")
    net.WriteEntity(vehicle)
    net.WriteBool(veh:GetDriver() == ply)
    net.Send(ply)
end)

-- Toolgun and physgun permissions
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

-- Initialize post-entity
hook.Add("InitPostEntity", "rRadio.InitializePostEntity", function()
    timer.Simple(0.5, function()
        if rRadio.sv.utils.IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
                    rRadio.sv.utils.AssignOwner(ply, ent)
                end
            end)
        end
        rRadio.sv.permanent.LoadPermanentBoomboxes()
    end)
end)

-- Periodic cleanup
timer.Create("CleanupInactiveRadios", rRadio.config.CleanupInterval(), 0, rRadio.sv.utils.CleanupInactiveRadios)

-- Entity creation handling
hook.Add("OnEntityCreated", "rRadio.InitializeRadio", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if rRadio.utils.IsBoombox(ent) or rRadio.utils.GetVehicle(ent) then
            rRadio.sv.utils.InitializeEntityVolume(ent)
        end
        if rRadio.utils.GetVehicle(ent) then
            rRadio.sv.utils.UpdateVehicleStatus(ent)
        end
    end)
end)

-- Entity removal cleanup
hook.Add("EntityRemoved", "rRadio.CleanupEntityRemoved", function(ent)
    local idx = ent:EntIndex()
    for _, timerPrefix in pairs(rRadio.sv.RadioTimers) do
        if timer.Exists(timerPrefix .. idx) then
            timer.Remove(timerPrefix .. idx)
        end
    end
    rRadio.sv.volumeUpdateQueue[idx] = nil
    rRadio.sv.utils.CleanupEntityData(idx)
    local mainEntity = ent:GetParent() or ent
    if rRadio.sv.ActiveRadios[mainEntity:EntIndex()] then
        rRadio.sv.utils.RemoveActiveRadio(mainEntity)
    end
end)

-- Player disconnect cleanup
hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    rRadio.sv.PlayerRetryAttempts[ply] = nil
    rRadio.sv.PlayerCooldowns[ply] = nil

    for idx, data in pairs(rRadio.sv.volumeUpdateQueue) do
        if data.pendingPlayer == ply then
            rRadio.sv.utils.CleanupEntityData(idx)
        end
    end

    for tableName in pairs(rRadio.sv.RadioDataTables) do
        if _G[tableName] then
            for idx, data in pairs(_G[tableName]) do
                if data.ply == ply or data.pendingPlayer == ply then
                    rRadio.sv.utils.CleanupEntityData(idx)
                end
            end
        end
    end
end)

-- Admin config reload
concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    game.ReloadConVars()
    local msg = "[rRADIO] Configuration reloaded!"
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
end)
