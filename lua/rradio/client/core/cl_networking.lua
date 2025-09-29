if SERVER then return end

local Radio, Utils, Interface, Status, Config, DevPrint, Net = rRadio:Import(
    "Radio",
    "utils",
    "!interface",
    "status",
    "config",
    "DevPrint",
    "net"
)

local Handlers = {}
Radio.cl.networkHandlers = Handlers
local function canStartPlayback(actual, slotInfo)
    if Radio.cl.radioSources[actual] then
        return true
    end

    local maxStations = Config.MaxClientStations or 0
    if maxStations <= 0 then
        return true
    end

    if slotInfo then
        return slotInfo.count < maxStations
    end

    return Interface.updateStationCount() < maxStations
end

local function processPlayStationPayload(entity, stationName, url, volume, slotInfo)
    local actual = Interface.GetVehicleEntity(entity)

    if Radio.cl.radioSources[actual] and IsValid(Radio.cl.radioSources[actual]) then
        Radio.cl.radioSources[actual]:Stop()
        Radio.cl.radioSources[actual] = nil
        Radio.cl.entityVolumes[actual] = nil
    end

    if IsValid(actual) and Utils.IsBoombox(actual) then
        Utils.ClearRadioStatus(actual)
    end

    stationName = stationName or ""
    url = url or ""
    volume = volume or 1

    local nonce = (Radio.cl.playbackNonce[actual] or 0) + 1
    Radio.cl.playbackNonce[actual] = nonce

    Utils.SetRadioStatus(actual, Status.TUNING, stationName)

    if Config.SecureStationLoad and not (Radio.cl.isUrlAllowed(url) or (IsValid(actual) and actual:GetNWBool("IsPermanent"))) then
        return
    end

    if not canStartPlayback(actual, slotInfo) then
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

Handlers[Net.SetRadioVolume] = function()
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

Handlers[Net.UpdateRadioStatus] = function()
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

Handlers[Net.CustomStationsUpdate] = function()
    local count = net.ReadUInt(12)
    local cat = Config.CustomStationCategory or "Custom"

    for url in pairs(Radio.cl.customUrlSet) do
        Radio.cl.allowedUrlSet[url] = nil
    end
    Radio.cl.customUrlSet = {}

    Radio.cl.stationData[cat] = {}
    for i = 1, count do
        local name = net.ReadString()
        local url = net.ReadString()
        if name ~= "" and url ~= "" then
            table.insert(Radio.cl.stationData[cat], {
                name = name,
                url = url,
                country = cat
            })
            Radio.cl.allowedUrlSet[url] = true
            Radio.cl.customUrlSet[url] = true
        end
    end

    Radio.cl.rebuildNameIndex()
    if Radio.cl.uiState.radioMenuOpen then Radio.cl.openRadioMenu() end
end

Handlers[Net.PlayStation] = function()
    if not Radio.cl.cvars.enabled:GetBool() then return end

    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()

    processPlayStationPayload(entity, stationName, url, volume)
end


Handlers[Net.ActiveRadios] = function()
    local count = net.ReadUInt(12)
    if count == 0 then return end

    local slotInfo = { count = Interface.updateStationCount() }
    local enabled = Radio.cl.cvars.enabled:GetBool()

    for i = 1, count do
        local entity = net.ReadEntity()
        local stationName = net.ReadString()
        local url = net.ReadString()
        local volume = net.ReadFloat()

        if enabled then
            processPlayStationPayload(entity, stationName, url, volume, slotInfo)
        end
    end
end

Handlers[Net.StopStation] = function()
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

Handlers[Net.OpenMenu] = function()
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

Handlers[Net.ListCustomStations] = function()
    local count = net.ReadUInt(16)
    if count == 0 then
        MsgC(Color(255,255,255), "[rRadio] No custom stations found.\n")
        return
    end

    MsgC(Color(255,0,0), "[rRadio] Custom stations:\n")
    for i = 1, count do
        local name = net.ReadString()
        local url = net.ReadString()
        MsgC(Color(255,0,0), "[" .. i .. "] ", Color(255,255,255), name .. ": " .. url .. "\n")
    end

    MsgC(Color(255,0,0), "\n!! ", Color(255,255,255),
        "Remove a Station: !" .. Config.CommandRemoveStation .. " <Name> or <URL>\n")
    MsgC(Color(255,0,0), "!! ", Color(255,255,255),
        "Add a Station: !" .. Config.CommandAddStation .. " <Name> <URL>\n")
end

Handlers[Net.PlayVehicleAnimation] = function()
    DevPrint("Received car radio message")
    local veh = net.ReadEntity()
    local isDriver = net.ReadBool()
    timer.Simple(0, function()
        Interface.DisplayVehicleEnterAnimation(veh, isDriver)
    end)
end

Handlers[Net.SetConfigUpdate] = function()
    for entity, source in pairs(Radio.cl.radioSources) do
        if IsValid(entity) and IsValid(source) then
            local fallback = Radio.cl.entityVolumes[entity] or 0.5
            local cfg = Interface.getEntityConfig(entity)
            local volume = Interface.ClampVolume((cfg and cfg.Volume) or fallback)
            source:SetVolume(volume)
        end
    end
end

Handlers[Net.SendPersistentConfirm] = function()
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

for message, handler in pairs(Handlers) do
    net.Receive(message, handler)
end





