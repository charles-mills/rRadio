hook.Run("rRadio.PostServerLoad")

local Radio = rRadio
Radio.sv = Radio.sv or {}
local Server = Radio.sv
local Config = Radio.config
local Utils = Radio.utils
local Status = Radio.status
local DevPrint = Radio.DevPrint
local ServerUtils = Server.utils
local Permanent = Server.permanent

Server.ActiveRadios        = Server.ActiveRadios or {}
Server.PlayerRetryAttempts = Server.PlayerRetryAttempts or {}
Server.PlayerCooldowns     = Server.PlayerCooldowns or {}
Server.volumeUpdateQueue   = Server.volumeUpdateQueue or {}
Server.stationUpdateQueue  = Server.stationUpdateQueue or {}
Server.EntityVolumes       = Server.EntityVolumes or {}
Server.BoomboxStatuses     = Server.BoomboxStatuses or {}
Server.CustomStations      = Server.CustomStations or { data = {}, urlMap = {}, nameMap = {} }
Server.ActiveRadiosCount   = Server.ActiveRadiosCount or 0
Server.PlayerRadios        = Server.PlayerRadios or {}
Server.RadioTimers = {
    "VolumeUpdate_",
    "StationUpdate_",
}

Server.RadioDataTables = {
    volumeUpdateQueue   = true,
}

local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0

timer.Create("rRadio.GlobalUpdateSweep", 0.25, 0, function()
    local now = SysTime()

    for entIdx, data in pairs(Server.stationUpdateQueue) do
        if now - data.timestamp >= 2 then
            local ent = Entity(entIdx)
            if IsValid(ent) then
                Utils.SetRadioStatus(ent, Status.PLAYING, data.station)
            end
            Server.stationUpdateQueue[entIdx] = nil
        end
    end

    for entIdx, upd in pairs(Server.volumeUpdateQueue) do
        if upd.pendingVolume and now - (upd.lastUpdate or 0) >= Config.VolumeUpdateDebounce then
            local ent = Entity(entIdx)
            if IsValid(ent) and IsValid(upd.pendingPlayer) then
                ServerUtils.ProcessVolumeUpdate(ent, upd.pendingVolume, upd.pendingPlayer)
            end
            upd.lastUpdate     = now
            upd.pendingVolume  = nil
            upd.pendingPlayer  = nil
        end
    end
end)

function Server.CustomStations:Load()
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

function Server.CustomStations:Save()
    file.CreateDir("rradio")
    file.Write("rradio/customstations.json", util.TableToJSON(self.data))
end

function Server.CustomStations:Add(name, url)
    if self.urlMap[url] or self.nameMap[name] then return end
    table.insert(self.data, { name = name, url = url })
    self.urlMap[url] = true
    self.nameMap[name] = true
    self:Save()
end

function Server.CustomStations:GetAll()
    return self.data
end

function Server.CustomStations:Remove(key)
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

Server.CustomStations:Load()

net.Receive("rRadio.PlayStation", function(len, ply)
    DevPrint("[rRADIO] Server got rRadio.PlayStation from: " .. ply:Nick())
    local now = SysTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("The radio system is busy. Please try again in a moment.")
        return
    end
    lastGlobalAction = now

    local ent       = ServerUtils.GetVehicleEntity(net.ReadEntity())
    local station   = net.ReadString()
    local stationURL= net.ReadString()
    local volume    = net.ReadFloat()

    if not IsValid(ent) then return end

    if hook.Run("rRadio.PrePlayStation", ply, ent, station, stationURL, volume) == false then return end

    if not Utils.CanUseRadio(ent) then
        ply:ChatPrint("[rRADIO] This seat cannot use the radio.")
        return
    end

    if now - (Server.PlayerCooldowns[ply] or 0) < 0.25 then
        ply:ChatPrint("You are changing stations too quickly.")
        return
    end
    Server.PlayerCooldowns[ply] = now

    if ServerUtils.CountActiveRadios() >= Config.MaxActiveRadios then
        ServerUtils.ClearOldestActiveRadio()
    end

    if ServerUtils.CountPlayerRadios(ply) >= Config.MaxPlayerRadios then
        ply:ChatPrint("You have reached your maximum number of active radios.")
        return
    end

    local idx = ent:EntIndex()

    if not ServerUtils.CanControlRadio(ent, ply) then
        ply:ChatPrint("You do not have permission to control this radio.")
        return
    end

    Utils.SetRadioStatus(ent, Status.TUNING, station)

    if Server.ActiveRadios[idx] then
        ServerUtils.BroadcastStop(ent)
        ServerUtils.RemoveActiveRadio(ent)
    end

    ServerUtils.AddActiveRadio(ent, station, stationURL, volume, ply)

    DevPrint("[sv_core] ActiveRadios now contains:")

    if Radio.DEV then
        for k, v in pairs(Server.ActiveRadios) do
            print("[sv_core] ActiveRadio " .. k .. ": " .. v.entity:EntIndex())
            print("\tStation: " .. v.stationName)
            print("\tURL: " .. v.url)
            print("\tVolume: " .. v.volume)
        end
    end



    ServerUtils.BroadcastPlay(ent, station, stationURL, volume)

    if ent.IsPermanent then
        Permanent.SavePermanentBoombox(ent)
    end

    Server.stationUpdateQueue[idx] = {
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

    if not ServerUtils.CanControlRadio(entity, ply) then
        ply:ChatPrint("You do not have permission to control this radio.")
        return
    end

    Utils.SetRadioStatus(entity, Status.STOPPED)
    ServerUtils.RemoveActiveRadio(entity)
    ServerUtils.BroadcastStop(entity)
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteInt(Status.STOPPED, 2)
    net.Broadcast()
    local entIndex = entity:EntIndex()
    Server.stationUpdateQueue[entIndex] = nil
    timer.Create("StationUpdate_" .. entIndex, Config.StationUpdateDebounce, 1, function()
        if IsValid(entity) and entity.IsPermanent then
            Permanent.ClearSavedStation(entity)
        end
    end)

    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("rRadio.SetRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local entIndex = IsValid(entity) and entity:EntIndex() or nil
    if not entIndex then return end

    local upd = Server.volumeUpdateQueue[entIndex]
    if not upd then
        upd = { lastUpdate = 0, pendingVolume = volume, pendingPlayer = ply }
        Server.volumeUpdateQueue[entIndex] = upd
    else
        upd.pendingVolume = volume
        upd.pendingPlayer = ply
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            ServerUtils.SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendCustomStations", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            net.Start("rRadio.CustomStationsUpdate")
                net.WriteTable(Server.CustomStations:GetAll())
            net.Send(ply)
        end
    end)
end)

local function AddCustomStation(ply, name, url)
    if not name or not url then
        local usage = "!" .. Config.CommandAddStation .. ' "name" "url"'
        if IsValid(ply) then
            ply:ChatPrint("[rRadio] Invalid command format. Usage: " .. usage)
        else
            print("[rRadio] Invalid command format. Usage: " .. usage)
        end
        return
    end
    if IsValid(ply) and not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] You don't have permission.")
        return
    end
    if not url:match("^https?://") then
        if IsValid(ply) then
            ply:ChatPrint("[rRadio] Invalid URL.")
        else
            print("[rRadio] Invalid URL.")
        end
        return
    end

    Server.CustomStations:Add(name, url)
    local msg = string.format("[rRadio] Added custom station '%s'.", name)
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
    net.Start("rRadio.CustomStationsUpdate")
        net.WriteTable(Server.CustomStations:GetAll())
    net.Broadcast()
end

local function RemoveCustomStation(ply, key)
    if not key then
        local usage = "!" .. Config.CommandRemoveStation .. ' "key"'
        if IsValid(ply) then
            ply:ChatPrint("[rRadio] Invalid command format. Usage: " .. usage)
        else
            print("[rRadio] Invalid command format. Usage: " .. usage)
        end
        return
    end
    if IsValid(ply) and not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] You don't have permission.")
        return
    end
    local removed = Server.CustomStations:Remove(key)
    if removed then
        local msg = string.format("[rRadio] Removed custom station '%s'.", key)
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
        net.Start("rRadio.CustomStationsUpdate")
            net.WriteTable(Server.CustomStations:GetAll())
        net.Broadcast()
    else
        if IsValid(ply) then
            ply:ChatPrint("[rRadio] No matching station found for " .. key)
        else
            print("[rRadio] No matching station found for " .. tostring(key))
        end
    end
end

local function HandleAddStation(ply, text)
    local prefix = "!" .. Config.CommandAddStation
    local name, url = text:match('^' .. prefix .. '%s+"([^"]+)"%s+"([^"]+)"')
    AddCustomStation(ply, name, url)
end

local function HandleRemoveStation(ply, text)
    local prefix = "!" .. Config.CommandRemoveStation
    local key = text:match('^' .. prefix .. '%s+"([^"]+)"')
    RemoveCustomStation(ply, key)
end

hook.Add("PlayerSay", "rRadio.HandleCommands", function(ply, text, teamChat)
    local addCmd = "!" .. Config.CommandAddStation
    local remCmd = "!" .. Config.CommandRemoveStation
    if text:sub(1, #addCmd) == addCmd then
        HandleAddStation(ply, text)
        return ""
    elseif text:sub(1, #remCmd) == remCmd then
        HandleRemoveStation(ply, text)
        return ""
    end
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    DevPrint("Player entered a vehicle")

    if not ply:GetInfoNum("rammel_rradio_enabled", 1) == 1 then return end

    local veh = Utils.GetVehicle(vehicle)
    if not veh then return end
    DevPrint("Vehicle is valid")
    if Utils.IsSitAnywhereSeat(vehicle) then return end
    DevPrint("Vehicle is not a sit anywhere seat")

    if Config.DriverPlayOnly and veh:GetDriver() ~= ply then
        DevPrint("Skipping CarRadioMessage: not driver")
        return
    end

    net.Start("rRadio.PlayVehicleAnimation")
    net.WriteEntity(vehicle)
    net.WriteBool(vehicle:GetDriver() == ply)
    net.Send(ply)

    DevPrint("Queued car radio animation")
end)

hook.Add("CanTool", "rRadio.AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and Utils.IsBoombox(ent) then
        return Utils.CanInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "rRadio.AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and Utils.IsBoombox(ent) then
        return Utils.CanInteractWithBoombox(ply, ent)
    end
end)

hook.Add("InitPostEntity", "rRadio.initalizePostEntity", function()
    timer.Simple(1, function()
        if ServerUtils.IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and Utils.IsBoombox(ent) then
                    ServerUtils.AssignOwner(ply, ent)
                end
            end)
        end
    end)

    timer.Simple(0.5, function()
        Permanent.LoadPermanentBoomboxes()
    end)
end)

timer.Create("CleanupInactiveRadios", Config.CleanupInterval, 0, ServerUtils.CleanupInactiveRadios)

hook.Add("OnEntityCreated", "rRadio.InitializeRadio", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) and (Utils.IsBoombox(entity) or Utils.GetVehicle(entity)) then
            ServerUtils.InitializeEntityVolume(entity)
        end
    end)

    timer.Simple(0, function()
        if IsValid(entity) and Utils.GetVehicle(entity) then
            ServerUtils.UpdateVehicleStatus(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "rRadio.CleanupEntityRemoved", function(entity)
    local entIndex = entity:EntIndex()
    Server.volumeUpdateQueue[entIndex] = nil
    Server.stationUpdateQueue[entIndex] = nil

    if IsValid(entity) then
        ServerUtils.RemoveActiveRadio(entity)
        ServerUtils.CleanupEntityData(entity:EntIndex())
    end

    local mainEntity = entity:GetParent() or entity
    if Server.ActiveRadios[mainEntity:EntIndex()] then
        ServerUtils.RemoveActiveRadio(mainEntity)
    end
end)

hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    Server.PlayerRetryAttempts[ply] = nil
    Server.PlayerCooldowns[ply] = nil
    Server.PlayerRadios[ply] = nil

    for entIndex, updateData in pairs(Server.volumeUpdateQueue) do
        if updateData.pendingPlayer == ply then
            ServerUtils.CleanupEntityData(entIndex)
        end
    end

    DevPrint("Volume update queue cleared for player: " .. ply:Nick())

    for tableName in pairs(Server.RadioDataTables) do
        if _G[tableName] then
            for entIndex, data in pairs(_G[tableName]) do
                if data.ply == ply or data.pendingPlayer == ply then
                    ServerUtils.CleanupEntityData(entIndex)
                end
            end
        end
    end

    DevPrint("Entity data cleaned up for player: " .. ply:Nick())
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

      local stations = Server.CustomStations:GetAll()
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

concommand.Add(Config.CommandAddStation, function(ply, cmd, args, argStr)
    AddCustomStation(ply, args[1], args[2])
end, nil, "Add a custom radio station")

concommand.Add(Config.CommandRemoveStation, function(ply, cmd, args, argStr)
    RemoveCustomStation(ply, args[1])
end, nil, "Remove a custom radio station")

if Radio.DEV then
    concommand.Add("rradio_fake_volume", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            ply:ChatPrint("[rRadio] You do not have permission to use this command.")
            return
        end

        local entID = tonumber(args[1] or "")
        local vol   = tonumber(args[2] or "")
        if not entID or not vol then
            print("[rRadio] Usage: rradio_fake_volume <entity id> <volume 0-1>")
            return
        end

        local ent = Entity(entID)
        if not IsValid(ent) then
            print("[rRadio] Invalid entity ID:", entID)
            return
        end
        vol = math.Clamp(vol, 0, 1)

        Server.EntityVolumes[entID] = vol
        ent:SetNWFloat("Volume", vol)
        net.Start("rRadio.SetRadioVolume")
            net.WriteEntity(ent)
            net.WriteFloat(vol)
        net.Broadcast()

        print(string.format("[rRadio] Sent fake volume %.2f to entity %d", vol, entID))
    end, nil,
    "[rRadio] Simulate a server volume change")
end
