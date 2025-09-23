local Radio = rRadio
local Utils = Radio.utils
local Interface = Radio.interface
local Config = Radio.config

if SERVER then return end

local uiState = Radio.cl.uiState
local timing = Radio.cl.timing
local cvars = Radio.cl.cvars

if not Config.UsePlayerBindHook then
    hook.Add("Think", "rRadio.OpenCarRadioMenu", function()
        local ply = LocalPlayer()
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        
        if input.IsKeyDown(key) and 
           not ply:IsTyping() and 
           now - timing.lastKeyPress > timing.keyPressDelay and 
           not uiState.isSearching then
            timing.lastKeyPress = now
            Radio.cl.toggleCarRadioMenu()
        end
    end)
else
    hook.Add("PlayerButtonDown", "rRadio.OpenCarRadioBind", function(ply, button)
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        
        if button == key and 
           now - timing.lastKeyPress > timing.keyPressDelay and 
           not uiState.isSearching and 
           IsFirstTimePredicted() then
            timing.lastKeyPress = now
            Radio.cl.toggleCarRadioMenu()
        end
    end)
end

hook.Add("EntityRemoved", "rRadio.CleanupRadioStationCount", function(entity)
    if Utils.CanUseRadio(entity) then
        Radio.cl.currentlyPlayingStations[entity] = nil
    end
    if Radio.cl.radioSources[entity] then
        if IsValid(Radio.cl.radioSources[entity]) then
            Radio.cl.radioSources[entity]:Stop()
        end
        Radio.cl.radioSources[entity] = nil
    end
    
    Radio.cl.queuedStations[entity] = nil

    if Radio.cl.stationLastPos[entity] then
        Radio.cl.stationLastPos[entity] = nil
    end

    Radio.cl.playbackNonce[entity] = nil
end)

hook.Add("EntityRemoved", "rRadio.BoomboxCleanup", function(ent)
    if IsValid(ent) and Utils.IsBoombox(ent) then
        Radio.cl.currentlyPlayingStations[ent] = nil
        Radio.cl.boomboxStatuses[ent:EntIndex()] = nil
        Radio.cl.connectedStations[ent] = nil
        Radio.cl.requestedStations[ent] = nil
        Radio.cl.queuedStations[ent] = nil
        Radio.cl.mutedBoomboxes[ent] = nil
    end
end)

hook.Add("VehicleChanged", "rRadio.ClearRadioEntity", function(ply, old, new)
    if ply ~= LocalPlayer() then return end
    if not new then
        ply.currentRadioEntity = nil
    end
end)

hook.Add("EntityRemoved", "rRadio.ClearRadioEntity", function(ent)
    local ply = LocalPlayer()
    if ent == ply.currentRadioEntity then
        Radio.cl.currentlyPlayingStations[ent] = nil
        ply.currentRadioEntity = nil
    end
end)

hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    Radio.addClConVars()
    Interface.loadSavedSettings()
end)

hook.Add("ShutDown", "rRadio.CleanupAllStations", function()
    for ent, station in pairs(Radio.cl.radioSources) do
        if IsValid(station) then
            station:Stop()
        end
    end
    
    Radio.cl.radioSources = {}
    Radio.cl.entityVolumes = {}
    Radio.cl.stationLastPos = {}
    Radio.cl.currentlyPlayingStations = {}
    Radio.cl.performance.activeStationCount = 0
    
    if timer.Exists("ValidateStationCount") then
        timer.Remove("ValidateStationCount")
    end
end)

if not timer.Exists("ValidateStationCount") then
    timer.Create("ValidateStationCount", 30, 0, function()
        local actualCount = 0
        for ent, source in pairs(Radio.cl.radioSources) do
            if IsValid(ent) and IsValid(source) then
                actualCount = actualCount + 1
            else
                Radio.cl.radioSources[ent] = nil
            end
        end
        Radio.cl.performance.activeStationCount = actualCount
    end)
end