if SERVER then return end

local Radio = rRadio
local Utils = Radio.utils
local Interface = Radio.interface
local Status = Radio.status
local Config = Radio.config
local DevPrint = Radio.DevPrint

Radio.cl = Radio.cl or {}

Radio.cl.networkHandlers = {}

Radio.cl.networkHandlers["rRadio.SetRadioVolume"] = function()
    local ent = net.ReadEntity()
    local vol = net.ReadFloat()
    if not IsValid(ent) then return end

    local actual = Interface.GetVehicleEntity(ent) or ent
    Radio.cl.entityVolumes[ent] = vol
    Radio.cl.entityVolumes[actual] = vol

    local patch = Radio.cl.radioSources[actual]
    if IsValid(patch) then
        patch:SetVolume(Interface.ClampVolume(vol))
    end

    Interface.refreshVolume(actual)
    Radio.cl.performance.volumeChanged = true
end

Radio.cl.networkHandlers["rRadio.UpdateRadioStatus"] = function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local isPlaying = net.ReadBool()
    local statusCode = net.ReadUInt(2)

    if statusCode == Status.TUNING and Radio.cl.connectedStations[entity] then
        return
    end

    local status = (statusCode == Status.STOPPED or 
                   statusCode == Status.TUNING or 
                   statusCode == Status.PLAYING) and statusCode or Status.STOPPED

    local displayStatus = status
    if status == Status.PLAYING and not Radio.cl.connectedStations[entity] then
        displayStatus = Status.TUNING
    end

    if status == Status.STOPPED then
        Radio.cl.connectedStations[entity] = nil
        Radio.cl.requestedStations[entity] = nil
    end

    if IsValid(entity) then
        Radio.cl.boomboxStatuses[entity:EntIndex()] = {
            stationStatus = displayStatus,
            stationName = stationName
        }

        entity:SetNWInt("Status", statusCode)
        entity:SetNWString("StationName", stationName)
        entity:SetNWBool("IsPlaying", isPlaying)

        if displayStatus == Status.PLAYING then
            local prev = Radio.cl.currentlyPlayingStations[entity] or {}
            prev.name = stationName
            Radio.cl.currentlyPlayingStations[entity] = prev
        else
            Radio.cl.currentlyPlayingStations[entity] = nil
        end
    end
end

Radio.cl.networkHandlers["rRadio.CustomStationsUpdate"] = function()
    local list = net.ReadTable()
    local cat = Config.CustomStationCategory or "Custom"

    for url in pairs(Radio.cl.customUrlSet) do
        Radio.cl.allowedUrlSet[url] = nil
    end
    Radio.cl.customUrlSet = {}

    Radio.cl.stationData[cat] = {}
    for _, st in ipairs(list) do
        if type(st) == "table" and st.name and st.url then
            table.insert(Radio.cl.stationData[cat], {
                name = st.name,
                url = st.url,
                country = cat
            })
            Radio.cl.allowedUrlSet[st.url] = true
            Radio.cl.customUrlSet[st.url] = true
        end
    end

    Radio.cl.rebuildNameIndex()
    if Radio.cl.uiState.radioMenuOpen then Radio.cl.openRadioMenu() end
end

Radio.cl.networkHandlers["rRadio.PlayStation"] = function()
    if not Radio.cl.cvars.enabled:GetBool() then return end

    local entity = net.ReadEntity()
    local actual = Interface.GetVehicleEntity(entity)

    if Radio.cl.radioSources[actual] and IsValid(Radio.cl.radioSources[actual]) then
        Radio.cl.radioSources[actual]:Stop()
        Radio.cl.radioSources[actual] = nil
        Radio.cl.entityVolumes[actual] = nil
    end

    if IsValid(actual) and Utils.IsBoombox(actual) then
        Utils.ClearRadioStatus(actual)
    end

    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    local nonce = (Radio.cl.playbackNonce[actual] or 0) + 1
    Radio.cl.playbackNonce[actual] = nonce

    Utils.SetRadioStatus(actual, Status.TUNING, stationName)

    if Config.SecureStationLoad then
        if not (Radio.cl.isUrlAllowed(url) or (IsValid(actual) and actual:GetNWBool("IsPermanent"))) then
            return
        end
    end

    local currentCount = Interface.updateStationCount()
    if not Radio.cl.radioSources[actual] and currentCount >= Config.MaxClientStations then
        return
    end

    if Config.ConditionalStationLoad then
        Radio.cl.queuedStations[actual] = {
            name = stationName,
            url = url,
            volume = volume,
            nonce = nonce
        }

        local ply = LocalPlayer()
        if IsValid(ply) then
            local cfg = Interface.getEntityConfig(actual)
            if cfg and Radio.cl.isEntityWithinLoadRange(ply:GetPos(), actual:GetPos(), cfg) then
                Radio.cl.startStationPlayback(actual, stationName, url, volume, nonce)
                Radio.cl.queuedStations[actual] = nil
            end
        end
    else
        Radio.cl.startStationPlayback(actual, stationName, url, volume, nonce)
    end
end

Radio.cl.networkHandlers["rRadio.StopStation"] = function()
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end
    
    entity = Interface.GetVehicleEntity(entity)

    if Radio.cl.radioSources[entity] and IsValid(Radio.cl.radioSources[entity]) then
        Radio.cl.radioSources[entity]:Stop()
        Radio.cl.radioSources[entity] = nil
        Radio.cl.entityVolumes[entity] = nil
    end

    Radio.cl.queuedStations[entity] = nil
    Radio.cl.connectedStations[entity] = nil
    Radio.cl.currentlyPlayingStations[entity] = nil
    Radio.cl.stationLastPos[entity] = nil
    Radio.cl.playbackNonce[entity] = nil

    if IsValid(entity) and Utils.IsBoombox(entity) then
        Utils.ClearRadioStatus(entity)
    end
end

Radio.cl.networkHandlers["rRadio.OpenMenu"] = function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    
    local ply = LocalPlayer()
    if Utils.IsBoombox(ent) then
        ply.currentRadioEntity = ent
        if not Radio.cl.uiState.radioMenuOpen then
            Radio.cl.openRadioMenu()
        end
    end
end

Radio.cl.networkHandlers["rRadio.ListCustomStations"] = function()
    local count = net.ReadUInt(16)
    if count == 0 then
        MsgC(Color(255,255,255), "[rRadio] No custom stations found.\n")
        return
    end
    
    MsgC(Color(255,0,0), "[rRadio] Custom stations:\n")
    for i = 1, count do
        local name = net.ReadString()
        local url = net.ReadString()
        MsgC(Color(255,0,0), "["..i.."] ", Color(255,255,255), name..": "..url.."\n")
    end
    
    MsgC(Color(255,0,0), "\n!! ", Color(255,255,255), 
        "Remove a Station: !"..Config.CommandRemoveStation.." <Name> or <URL>\n")
    MsgC(Color(255,0,0), "!! ", Color(255,255,255), 
        "Add a Station: !"..Config.CommandAddStation.." <Name> <URL>\n")
end

Radio.cl.networkHandlers["rRadio.PlayVehicleAnimation"] = function()
    DevPrint("Received car radio message")
    local veh = net.ReadEntity()
    local isDriver = net.ReadBool()
    timer.Simple(0, function()
        Interface.DisplayVehicleEnterAnimation(veh, isDriver)
    end)
end

Radio.cl.networkHandlers["rRadio.SetConfigUpdate"] = function()
    for entity, source in pairs(Radio.cl.radioSources) do
        if IsValid(entity) and IsValid(source) then
            local fallback = Radio.cl.entityVolumes[entity] or 0.5
            local cfg = Interface.getEntityConfig(entity)
            local volume = Interface.ClampVolume((cfg and cfg.Volume) or fallback)
            source:SetVolume(volume)
        end
    end
end

Radio.cl.networkHandlers["rRadio.SendPersistentConfirmation"] = function()
    local message = net.ReadString()
    chat.AddText(Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255), message)
    
    if Radio.cl.uiState.permanentCheckboxRef then
        if string.find(message, "marked as permanent") then
            Radio.cl.uiState.permanentCheckboxRef:SetChecked(true)
        elseif string.find(message, "permanence has been removed") then
            Radio.cl.uiState.permanentCheckboxRef:SetChecked(false)
        end
    end
end

for name, handler in pairs(Radio.cl.networkHandlers) do
    net.Receive(name, handler)
end
