--[[
           /$$$$$$$                  /$$ /$$          
          | $$__  $$                | $$|__/          
  /$$$$$$ | $$  \ $$  /$$$$$$   /$$$$$$$ /$$  /$$$$$$ 
 /$$__  $$| $$$$$$$/ |____  $$ /$$__  $$| $$ /$$__  $$
| $$  \__/| $$__  $$  /$$$$$$$| $$  | $$| $$| $$  \ $$
| $$      | $$  \ $$ /$$__  $$| $$  | $$| $$| $$  | $$
| $$      | $$  | $$|  $$$$$$$|  $$$$$$$| $$|  $$$$$$/
|__/      |__/  |__/ \_______/ \_______/|__/ \______/ 

Discord: crjmx
Steam: https://steamcommunity.com/id/rammel/
]]

hook.Run("rRadio.PostServerLoad")

rRadio.sv = rRadio.sv or {}
rRadio.sv.ActiveRadios = rRadio.sv.ActiveRadios or {}
rRadio.sv.PlayerRetryAttempts = rRadio.sv.PlayerRetryAttempts or {}
rRadio.sv.PlayerCooldowns = rRadio.sv.PlayerCooldowns or {}
rRadio.sv.volumeUpdateQueue = rRadio.sv.volumeUpdateQueue or {}
rRadio.sv.stationUpdateQueue = rRadio.sv.stationUpdateQueue or {}
rRadio.sv.EntityVolumes = rRadio.sv.EntityVolumes or {}
rRadio.sv.BoomboxStatuses = rRadio.sv.BoomboxStatuses or {}
rRadio.sv.CustomStations = rRadio.sv.CustomStations or { data = {}, urlMap = {}, nameMap = {} }
rRadio.sv.ActiveRadiosCount = rRadio.sv.ActiveRadiosCount or 0
rRadio.sv.PlayerRadios = rRadio.sv.PlayerRadios or {}
rRadio.sv.RadioTimers = { "VolumeUpdate_", "StationUpdate_" }
rRadio.sv.RadioDataTables = { volumeUpdateQueue = true }

local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0

timer.Create("rRadio.GlobalUpdateSweep", 0.25, 0, function()
    local now = SysTime()
    for entIdx, data in pairs(rRadio.sv.stationUpdateQueue) do
        if now - data.timestamp >= 2 then
            local ent = Entity(entIdx)
            if IsValid(ent) then
                rRadio.utils.setRadioStatus(ent, "playing", data.station)
                rRadio.sv.utils.BroadcastPlay(ent, data.station, data.url, data.volume)
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
            upd.lastUpdate = now
            upd.pendingVolume = nil
            upd.pendingPlayer = nil
        end
    end
end)

function rRadio.sv.CustomStations:Load()
    local success, contents = pcall(file.Read, "rradio/customstations.json", "DATA")
    if not success or not contents then
        rRadio.FormattedOutput("Failed to load custom stations")
        return
    end
    local tbl = util.JSONToTable(contents) or {}
    self.data = {}
    self.urlMap = {}
    self.nameMap = {}
    for _, v in ipairs(tbl) do
        if type(v) == "table" and v.url and v.name then
            table.insert(self.data, v)
            self.urlMap[v.url] = true
            self.nameMap[v.name] = true
        end
    end
end

function rRadio.sv.CustomStations:Save()
    file.CreateDir("rradio")
    local success, err = pcall(file.Write, "rradio/customstations.json", util.TableToJSON(self.data))
    if not success then
        rRadio.FormattedOutput("Failed to save custom stations: " .. err)
    end
end

function rRadio.sv.CustomStations:Add(name, url, ply)
    if self.urlMap[url] or self.nameMap[name] then
        if IsValid(ply) then ply:ChatPrint("[rRadio] Station name or URL already exists") end
        return false
    end
    if not url:match("^https?://.+%.%a+$") then
        if IsValid(ply) then ply:ChatPrint("[rRadio] Invalid URL format") end
        return false
    end
    if #name > 50 or #url > 200 then
        if IsValid(ply) then ply:ChatPrint("[rRadio] Name or URL too long") end
        return false
    end
    table.insert(self.data, { name = name, url = url })
    self.urlMap[url] = true
    self.nameMap[name] = true
    self:Save()
    return true
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

-- Enhanced UI for radioadd
local function createRadioAddMenu()
    if SERVER then return end
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(500, 400)
    frame:Center()
    frame:SetTitle("Add Custom Radio Station")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame:SetBackgroundBlur(true)
    
    local panel = vgui.Create("DPanel", frame)
    panel:SetPos(10, 30)
    panel:SetSize(480, 360)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 240))
    end

    local nameLabel = vgui.Create("DLabel", panel)
    nameLabel:SetPos(20, 20)
    nameLabel:SetText("Station Name:")
    nameLabel:SetFont("rRadio.Roboto24")
    nameLabel:SetTextColor(Color(255, 255, 255))

    local nameEntry = vgui.Create("DTextEntry", panel)
    nameEntry:SetPos(20, 50)
    nameEntry:SetSize(440, 30)
    nameEntry:SetPlaceholderText("Enter station name (max 50 chars)")
    nameEntry:SetFont("rRadio.Roboto24")

    local urlLabel = vgui.Create("DLabel", panel)
    urlLabel:SetPos(20, 100)
    urlLabel:SetText("Station URL:")
    urlLabel:SetFont("rRadio.Roboto24")
    urlLabel:SetTextColor(Color(255, 255, 255))

    local urlEntry = vgui.Create("DTextEntry", panel)
    urlEntry:SetPos(20, 130)
    urlEntry:SetSize(440, 30)
    urlEntry:SetPlaceholderText("Enter station URL (https://...)")
    urlEntry:SetFont("rRadio.Roboto24")

    local previewButton = vgui.Create("DButton", panel)
    previewButton:SetPos(20, 180)
    previewButton:SetSize(440, 40)
    previewButton:SetText("Preview Station")
    previewButton:SetFont("rRadio.Roboto24")
    previewButton.DoClick = function()
        local url = urlEntry:GetValue()
        if url:match("^https?://.+%.%a+$") then
            sound.PlayURL(url, "noblock", function(station, err)
                if IsValid(station) then
                    station:Play()
                    timer.Simple(10, function() if IsValid(station) then station:Stop() end end)
                    Derma_Message("Playing preview for 10 seconds", "Preview", "OK")
                else
                    Derma_Message("Failed to load station: " .. (err or "Unknown error"), "Error", "OK")
                end
            end)
        else
            Derma_Message("Invalid URL format", "Error", "OK")
        end
    end

    local addButton = vgui.Create("DButton", panel)
    addButton:SetPos(20, 230)
    addButton:SetSize(440, 40)
    addButton:SetText("Add Station")
    addButton:SetFont("rRadio.Roboto24")
    addButton.DoClick = function()
        local name = nameEntry:GetValue():Trim()
        local url = urlEntry:GetValue():Trim()
        
        if name == "" or url == "" then
            Derma_Message("Please fill in both fields", "Error", "OK")
            return
        end
        
        if #name > 50 or #url > 200 then
            Derma_Message("Name or URL too long", "Error", "OK")
            return
        end
        
        if not url:match("^https?://.+%.%a+$") then
            Derma_Message("Invalid URL format", "Error", "OK")
            return
        end

        net.Start("rRadio.AddCustomStation")
        net.WriteString(name)
        net.WriteString(url)
        net.SendToServer()
        frame:Close()
    end

    local cancelButton = vgui.Create("DButton", panel)
    cancelButton:SetPos(20, 280)
    cancelButton:SetSize(440, 40)
    cancelButton:SetText("Cancel")
    cancelButton:SetFont("rRadio.Roboto24")
    cancelButton.DoClick = function() frame:Close() end
end

net.Receive("rRadio.PlayStation", function(len, ply)
    local now = SysTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("Radio system busy. Try again.")
        return
    end
    lastGlobalAction = now

    local ent = rRadio.sv.utils.GetVehicleEntity(net.ReadEntity())
    local station = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(ent) then return end
    if hook.Run("rRadio.PrePlayStation", ply, ent, station, stationURL, volume) == false then return end
    if not rRadio.utils.canUseRadio(ent) then
        ply:ChatPrint("[rRadio] This seat cannot use radio")
        return
    end
    if now - (rRadio.sv.PlayerCooldowns[ply] or 0) < 0.25 then
        ply:ChatPrint("Changing stations too quickly")
        return
    end
    rRadio.sv.PlayerCooldowns[ply] = now

    if rRadio.sv.utils.CountActiveRadios() >= 100 then
        rRadio.sv.utils.ClearOldestActiveRadio()
    end
    if rRadio.sv.utils.CountPlayerRadios(ply) >= 5 then
        ply:ChatPrint("Maximum active radios reached")
        return
    end

    local idx = ent:EntIndex()
    if not rRadio.sv.utils.CanControlRadio(ent, ply) then
        ply:ChatPrint("No permission to control radio")
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
    rRadio.sv.utils.BroadcastPlay(ent, station, stationURL, volume)

    if ent.IsPermanent then
        rRadio.sv.permanent.SavePermanentBoombox(ent)
    end

    rRadio.sv.stationUpdateQueue[idx] = {
        station = station,
        url = stationURL,
        volume = volume,
        timestamp = SysTime()
    }

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("rRadio.StopStation", function(len, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end
    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end
    if not rRadio.sv.utils.CanControlRadio(entity, ply) then
        ply:ChatPrint("No permission to control radio")
        return
    end

    rRadio.utils.setRadioStatus(entity, "stopped")
    rRadio.sv.utils.RemoveActiveRadio(entity)
    rRadio.sv.utils.BroadcastStop(entity)
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteString("stopped")
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

net.Receive("rRadio.AddCustomStation", function(len, ply)
    if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] No permission")
        return
    end

    local name = net.ReadString()
    local url = net.ReadString()
    
    if rRadio.sv.CustomStations:Add(name, url, ply) then
        ply:ChatPrint(string.format("[rRadio] Added station '%s'", name))
        net.Start("rRadio.CustomStationsUpdate")
        net.WriteTable(rRadio.sv.CustomStations:GetAll())
        net.Broadcast()
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

hook.Add("PlayerSay", "rRadio.HandleAddStation", function(ply, text, teamChat)
    local name, url = text:match('^' .. rRadio.config.CommandAddStation .. '%s+"([^"]+)"%s+"([^"]+)"')
    if not name or not url then
        ply:ChatPrint("[rRadio] Usage: " .. rRadio.config.CommandAddStation .. ' "name" "url"')
        return ""
    end
    if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] No permission")
        return ""
    end
    if rRadio.sv.CustomStations:Add(name, url, ply) then
        ply:ChatPrint(string.format("[rRadio] Added station '%s'", name))
        net.Start("rRadio.CustomStationsUpdate")
        net.WriteTable(rRadio.sv.CustomStations:GetAll())
        net.Broadcast()
    end
    return ""
end)

hook.Add("PlayerSay", "rRadio.HandleRemoveStation", function(ply, text, teamChat)
    local key = text:match('^' .. rRadio.config.CommandRemoveStation .. '%s+"([^"]+)"')
    if not key then
        ply:ChatPrint("[rRadio] Usage: " .. rRadio.config.CommandRemoveStation .. ' "key"')
        return ""
    end
    if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] No permission")
        return ""
    end
    local removed = rRadio.sv.CustomStations:Remove(key)
    if removed then
        ply:ChatPrint(string.format("[rRadio] Removed station '%s'", key))
        net.Start("rRadio.CustomStationsUpdate")
        net.WriteTable(rRadio.sv.CustomStations:GetAll())
        net.Broadcast()
    else
        ply:ChatPrint("[rRadio] No matching station")
    end
    return ""
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    if not ply:GetInfoNum("rammel_rradio_enabled", 1) == 1 then return end
    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh or rRadio.utils.isSitAnywhereSeat(vehicle) then return end
    if rRadio.config.DriverPlayOnly and veh:GetDriver() ~= ply then return end

    net.Start("rRadio.PlayVehicleAnimation")
    net.WriteEntity(vehicle)
    net.WriteBool(vehicle:GetDriver() == ply)
    net.Send(ply)
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
        rRadio.sv.utils.CleanupEntityData(entIndex)
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
    for tableName in pairs(rRadio.sv.RadioDataTables) do
        if _G[tableName] then
            for entIndex, data in pairs(_G[tableName]) do
                if data.ply == ply or data.pendingPlayer == ply then
                    rRadio.sv.utils.CleanupEntityData(entIndex)
                end
            end
        end
    end
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    game.ReloadConVars()
    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Configuration reloaded")
    else
        print("[rRadio] Configuration reloaded")
    end
end)

concommand.Add("rammel_rradio_list_custom", function(ply)
    if not IsValid(ply) or not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
        ply:ChatPrint("[rRadio] No permission")
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
end)

concommand.Add("radioadd", createRadioAddMenu, nil, "Opens menu to add custom radio station")
