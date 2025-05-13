hook.Run("rRadio.PostServerLoad")

rRadio.sv = rRadio.sv or {}

rRadio.sv.ActiveRadios        = rRadio.sv.ActiveRadios or {}
rRadio.sv.PlayerRetryAttempts = rRadio.sv.PlayerRetryAttempts or {}
rRadio.sv.PlayerCooldowns     = rRadio.sv.PlayerCooldowns or {}
rRadio.sv.volumeUpdateQueue   = rRadio.sv.volumeUpdateQueue or {}
rRadio.sv.stationUpdateQueue  = rRadio.sv.stationUpdateQueue or {}
rRadio.sv.EntityVolumes       = rRadio.sv.EntityVolumes or {}
rRadio.sv.BoomboxStatuses     = rRadio.sv.BoomboxStatuses or {}
rRadio.sv.CustomStations      = rRadio.sv.CustomStations or { data = {}, urlMap = {}, nameMap = {} }
rRadio.sv.ActiveRadiosCount   = rRadio.sv.ActiveRadiosCount or 0
rRadio.sv.PlayerRadios        = rRadio.sv.PlayerRadios or {}
rRadio.sv.RadioTimers = {
    "VolumeUpdate_",
    "StationUpdate_",
}

rRadio.sv.RadioDataTables = {
    volumeUpdateQueue   = true,
}

local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0

timer.Create("rRadio.GlobalUpdateSweep", 0.25, 0, function()
    local now = SysTime()

    for entIdx, data in pairs(rRadio.sv.stationUpdateQueue) do
        if now - data.timestamp >= 2 then
            local ent = Entity(entIdx)
            if IsValid(ent) then
                rRadio.utils.setRadioStatus(ent, rRadio.status.PLAYING, data.station)
            end
            rRadio.sv.stationUpdateQueue[entIdx] = nil
        end
    end

    for entIdx, upd in pairs(rRadio.sv.volumeUpdateQueue) do
        if upd.pendingVolume and now - (upd.lastUpdate or 0) >= rRadio.config.VolumeUpdateDebounce() then
            local ent = Entity(entIdx)
            if IsValid(ent) and IsValid(upd.pendingPlayer) then
                rRadio.sv.utils.ProcessVolumeUpdate(ent, upd.pendingVolume, upd.pendingPlayer)
            end
            upd.lastUpdate     = now
            upd.pendingVolume  = nil
            upd.pendingPlayer  = nil
        end
    end
end)

function rRadio.sv.CustomStations:Load()
    local contents = file.Read("rradio/customstations.json", "DATA")
    local tbl = contents and util.JSONToTable(contents) or {}
    self.data = {}
    self.urlMap = {}
    self.nameMap = {}

    for _, v in ipairs(tbl) do
        if type(v) == "string" then
            table.insert(self.data, { name = v, url = v })
        elseif type(v) == "table" and v.url then
            table.insert(self.data, v)
        end
        self.urlMap[v.url] = true
        self.nameMap[v.name] = true
    end
end

function rRadio.sv.CustomStations:Save()
    file.CreateDir("rradio")
    file.Write("rradio/customstations.json", util.TableToJSON(self.data))
end

function rRadio.sv.CustomStations:Add(name, url)
    if self.urlMap[url] or self.nameMap[name] then return end
    table.insert(self.data, { name = name, url = url })
    self.urlMap[url] = true
    self.nameMap[name] = true
    self:Save()
end

function rRadio.sv.CustomStations:GetAll()
    return self.data
end

function rRadio.sv.CustomStations:Remove(key)
    local removed = false
    for i = #self.data, 1, -1 do
        local st = self.data[i]
        if st.url == key or st.name == key then
            table.remove(self.data, i)
            removed = true
        end
    end
    if removed then
        self.urlMap = {}
        self.nameMap = {}
        for _, st in ipairs(self.data) do
            self.urlMap[st.url] = true
            self.nameMap[st.name] = true
        end
        self:Save()
    end
    return removed
end

rRadio.sv.CustomStations:Load()

net.Receive("rRadio.PlayStation", function(len, ply)
    rRadio.DevPrint("[rRADIO] Server got rRadio.PlayStation from: " .. ply:Nick())
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

    if rRadio.sv.utils.CountActiveRadios() >= 100 then
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

    -- Server: broadcast tuning status for all radio entities
    rRadio.utils.setRadioStatus(ent, rRadio.status.TUNING, station)

    if rRadio.sv.ActiveRadios[idx] then
        rRadio.sv.utils.BroadcastStop(ent)
        rRadio.sv.utils.RemoveActiveRadio(ent)
    end

    rRadio.sv.utils.AddActiveRadio(ent, station, stationURL, volume)

    rRadio.DevPrint("[rRADIO] ActiveRadios now contains:")

    for k, v in pairs(rRadio.sv.ActiveRadios) do
        rRadio.DevPrint("[rRADIO] ActiveRadio " .. k .. ": " .. v.entity:EntIndex())
        rRadio.DevPrint("[rRADIO] ActiveRadio " .. k .. ": " .. v.stationName)
        rRadio.DevPrint("[rRADIO] ActiveRadio " .. k .. ": " .. v.url)
        rRadio.DevPrint("[rRADIO] ActiveRadio " .. k .. ": " .. v.volume)
    end

    rRadio.sv.utils.BroadcastPlay(ent, station, stationURL, volume)

    if ent.IsPermanent then
        rRadio.sv.permanent.SavePermanentBoombox(ent)
    end

    rRadio.sv.stationUpdateQueue[idx] = {
        station   = station,
        url       = stationURL,
        volume    = volume,
        timestamp = SysTime()
    }

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("rRadio.StopStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end

    if not rRadio.sv.utils.CanControlRadio(entity, ply) then
        ply:ChatPrint("You do not have permission to control this radio.")
        return
    end

    rRadio.utils.setRadioStatus(entity, rRadio.status.STOPPED)
    rRadio.sv.utils.RemoveActiveRadio(entity)
    rRadio.sv.utils.BroadcastStop(entity)
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteInt(rRadio.status.STOPPED, 2)
    net.Broadcast()
    local entIndex = entity:EntIndex()
    rRadio.sv.stationUpdateQueue[entIndex] = nil
    timer.Create("StationUpdate_" .. entIndex, rRadio.config.StationUpdateDebounce(), 1, function()
        if IsValid(entity) and entity.IsPermanent then
            rRadio.sv.permanent.SavePermanentBoombox(entity)
        end
    end)

    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("rRadio.SetRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local entIndex = IsValid(entity) and entity:EntIndex() or nil
    if not entIndex then return end

    local upd = rRadio.sv.volumeUpdateQueue[entIndex]
    if not upd then
        upd = { lastUpdate = 0, pendingVolume = volume, pendingPlayer = ply }
        rRadio.sv.volumeUpdateQueue[entIndex] = upd
    else
        upd.pendingVolume = volume
        upd.pendingPlayer = ply
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            rRadio.sv.utils.SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendCustomStations", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            net.Start("rRadio.CustomStationsUpdate")
                net.WriteTable(rRadio.sv.CustomStations:GetAll())
            net.Send(ply)
        end
    end)
end)

local function HandleAddStation(ply, text)
    local name, url = text:match('^' .. rRadio.config.CommandAddStation .. '%s+"([^"]+)"%s+"([^"]+)"')
    if not name or not url then
        ply:ChatPrint("[rRadio] Invalid command format. Usage: " .. rRadio.config.CommandAddStation .. ' "name" "url"')
        return
    end
    if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] You don't have permission.")
        return
    end
    if not url:match("^https?://") then
        ply:ChatPrint("[rRadio] Invalid URL.")
        return
    end
    rRadio.sv.CustomStations:Add(name, url)
    ply:ChatPrint(string.format("[rRadio] Added custom station '%s'.", name))
    net.Start("rRadio.CustomStationsUpdate")
        net.WriteTable(rRadio.sv.CustomStations:GetAll())
    net.Broadcast()
end

local function HandleRemoveStation(ply, text)
    local key = text:match('^' .. rRadio.config.CommandRemoveStation .. '%s+"([^"]+)"')
    if not key then
        ply:ChatPrint("[rRadio] Invalid command format. Usage: " .. rRadio.config.CommandRemoveStation .. ' "key"')
        return
    end
    if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] You don't have permission.")
        return
    end
    local removed = rRadio.sv.CustomStations:Remove(key)
    if removed then
        ply:ChatPrint(string.format("[rRadio] Removed custom station '%s'.", key))
        net.Start("rRadio.CustomStationsUpdate")
            net.WriteTable(rRadio.sv.CustomStations:GetAll())
        net.Broadcast()
    else
        ply:ChatPrint("[rRadio] No matching station found for " .. key)
    end
end

hook.Add("PlayerSay", "rRadio.HandleCommands", function(ply, text, teamChat)
    if text:sub(1, #rRadio.config.CommandAddStation) == rRadio.config.CommandAddStation then
        HandleAddStation(ply, text)
        return ""
    elseif text:sub(1, #rRadio.config.CommandRemoveStation) == rRadio.config.CommandRemoveStation then
        HandleRemoveStation(ply, text)
        return ""
    end
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

    net.Start("rRadio.PlayVehicleAnimation")
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
    rRadio.sv.volumeUpdateQueue[entIndex] = nil
    rRadio.sv.stationUpdateQueue[entIndex] = nil

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
    rRadio.sv.PlayerRadios[ply] = nil

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


concommand.Add(
    "rammel_rradio_list_custom",
    function(ply, cmd, args)
      if not IsValid(ply)
        or not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil)
      then
        ply:ChatPrint("You do not have permission to use this command.")
        return
      end

      local stations = rRadio.sv.CustomStations:GetAll()
      net.Start("rRadio.ListCustomStations")
        net.WriteUInt(#stations, 16)
        for _, st in ipairs(stations) do
          net.WriteString(st.name)
          net.WriteString(st.url)
        end
      net.Send(ply)
    end,
    nil,
    "Lists all custom radio stations",
    FCVAR_CLIENTCMD_CAN_EXECUTE
)