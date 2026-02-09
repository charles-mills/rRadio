if SERVER then return end
local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local cvars = rRadio.cl.cvars
if not rRadio.config.UsePlayerBindHook then
    hook.Add("Think", "rRadio.OpenCarRadioMenu", function()
        local ply = LocalPlayer()
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        if input.IsKeyDown(key) and not ply:IsTyping() and now - timing.lastKeyPress > timing.keyPressDelay and not uiState.isSearching then
            timing.lastKeyPress = now
            rRadio.cl.toggleCarRadioMenu()
        end
    end)
else
    hook.Add("PlayerButtonDown", "rRadio.OpenCarRadioBind", function(ply, button)
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        if button == key and now - timing.lastKeyPress > timing.keyPressDelay and not uiState.isSearching and IsFirstTimePredicted() then
            timing.lastKeyPress = now
            rRadio.cl.toggleCarRadioMenu()
        end
    end)
end

hook.Add("EntityRemoved", "rRadio.EntityCleanup", function(ent)
    if rRadio.cl.radioSources[ent] then
        if IsValid(rRadio.cl.radioSources[ent]) then rRadio.cl.radioSources[ent]:Stop() end
        rRadio.cl.radioSources[ent] = nil
    end

    rRadio.cl.currentlyPlayingStations[ent] = nil
    rRadio.cl.queuedStations[ent] = nil
    rRadio.cl.stationLastPos[ent] = nil
    rRadio.cl.playbackNonce[ent] = nil
    rRadio.cl.errorTimestamps[ent] = nil
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        local entIndex = ent:EntIndex()
        rRadio.cl.boomboxStatuses[entIndex] = nil
        rRadio.cl.connectedStations[ent] = nil
        rRadio.cl.requestedStations[ent] = nil
        rRadio.cl.mutedBoomboxes[ent] = nil
        timer.Remove("rRadio.ErrorClear_" .. entIndex)
        timer.Remove("rRadio.TuningTimeout_" .. entIndex)
    end

    local ply = LocalPlayer()
    if ent == ply.currentRadioEntity then ply.currentRadioEntity = nil end
end)

hook.Add("VehicleChanged", "rRadio.ClearRadioEntity", function(ply, old, new)
    if ply ~= LocalPlayer() then return end
    if not new then ply.currentRadioEntity = nil end
end)

hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.addClConVars()
    rRadio.interface.loadSavedSettings()
end)

hook.Add("ShutDown", "rRadio.CleanupAllStations", function()
    for ent, station in pairs(rRadio.cl.radioSources) do
        if IsValid(station) then station:Stop() end
    end

    rRadio.cl.radioSources = {}
    rRadio.cl.entityVolumes = {}
    rRadio.cl.stationLastPos = {}
    rRadio.cl.currentlyPlayingStations = {}
    rRadio.cl.performance.activeStationCount = 0
    if timer.Exists("ValidateStationCount") then timer.Remove("ValidateStationCount") end
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
