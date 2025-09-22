if SERVER then return end

local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local cvars = rRadio.cl.cvars

if not rRadio.config.UsePlayerBindHook then
    hook.Add("Think", "rRadio.OpenCarRadioMenu", function()
        local ply = LocalPlayer()
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        
        if input.IsKeyDown(key) and 
           not ply:IsTyping() and 
           now - timing.lastKeyPress > timing.keyPressDelay and 
           not uiState.isSearching then
            timing.lastKeyPress = now
            rRadio.cl.toggleCarRadioMenu()
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
            rRadio.cl.toggleCarRadioMenu()
        end
    end)
end

hook.Add("EntityRemoved", "rRadio.CleanupRadioStationCount", function(entity)
    if rRadio.utils.CanUseRadio(entity) then
        rRadio.cl.currentlyPlayingStations[entity] = nil
    end
    if rRadio.cl.radioSources[entity] then
        if IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:Stop()
        end
        rRadio.cl.radioSources[entity] = nil
    end
    
    rRadio.cl.queuedStations[entity] = nil

    if rRadio.cl.stationLastPos[entity] then
        rRadio.cl.stationLastPos[entity] = nil
    end

    rRadio.cl.playbackNonce[entity] = nil
end)

hook.Add("EntityRemoved", "rRadio.BoomboxCleanup", function(ent)
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        rRadio.cl.currentlyPlayingStations[ent] = nil
        rRadio.cl.boomboxStatuses[ent:EntIndex()] = nil
        rRadio.cl.connectedStations[ent] = nil
        rRadio.cl.requestedStations[ent] = nil
        rRadio.cl.queuedStations[ent] = nil
        rRadio.cl.mutedBoomboxes[ent] = nil
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
        rRadio.cl.currentlyPlayingStations[ent] = nil
        ply.currentRadioEntity = nil
    end
end)

hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.addClConVars()
    rRadio.interface.loadSavedSettings()
end)

hook.Add("ShutDown", "rRadio.CleanupAllStations", function()
    for ent, station in pairs(rRadio.cl.radioSources) do
        if IsValid(station) then
            station:Stop()
        end
    end
    
    rRadio.cl.radioSources = {}
    rRadio.cl.entityVolumes = {}
    rRadio.cl.stationLastPos = {}
    rRadio.cl.currentlyPlayingStations = {}
    rRadio.cl.performance.activeStationCount = 0
    
    if timer.Exists("ValidateStationCount") then
        timer.Remove("ValidateStationCount")
    end
end)

if not timer.Exists("ValidateStationCount") then
    timer.Create("ValidateStationCount", 30, 0, function()
        local actualCount = 0
        for ent, source in pairs(rRadio.cl.radioSources) do
            if IsValid(ent) and IsValid(source) then
                actualCount = actualCount + 1
            else
                rRadio.cl.radioSources[ent] = nil
            end
        end
        rRadio.cl.performance.activeStationCount = actualCount
    end)
end
