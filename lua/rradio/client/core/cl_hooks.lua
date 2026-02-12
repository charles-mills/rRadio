if SERVER then return end
local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local cvars = rRadio.cl.cvars
if not rRadio.config.UsePlayerBindHook then
    hook.Add( "Think", "rRadio.OpenCarRadioMenu", function()
        local ply = LocalPlayer()
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        if input.IsKeyDown( key ) and not ply:IsTyping()
            and now - timing.lastKeyPress > timing.keyPressDelay
            and not uiState.isSearching then
            timing.lastKeyPress = now
            rRadio.cl.toggleCarRadioMenu()
        end
    end )
else
    hook.Add( "PlayerButtonDown", "rRadio.OpenCarRadioBind", function( _ply, button )
        local key = cvars.menuKey:GetInt()
        local now = CurTime()
        if button == key and now - timing.lastKeyPress > timing.keyPressDelay
            and not uiState.isSearching and IsFirstTimePredicted() then
            timing.lastKeyPress = now
            rRadio.cl.toggleCarRadioMenu()
        end
    end )
end

hook.Add( "EntityRemoved", "rRadio.EntityCleanup", function( ent )
    rRadio.cl.cleanupEntity( ent )
    local ply = LocalPlayer()
    if ent == ply.currentRadioEntity then ply.currentRadioEntity = nil end
end )

hook.Add( "VehicleChanged", "rRadio.ClearRadioEntity", function( ply, _old, new )
    if ply ~= LocalPlayer() then return end
    if not new then ply.currentRadioEntity = nil end
end )

hook.Add( "InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.interface.loadSavedSettings()
end )

hook.Add( "ShutDown", "rRadio.CleanupAllStations", function()
    for _ent, station in pairs( rRadio.cl.radioSources ) do
        if IsValid( station ) then station:Stop() end
    end

    rRadio.cl.radioSources = {}
    rRadio.cl.entityVolumes = {}
    rRadio.cl.stationLastPos = {}
    rRadio.cl.currentlyPlayingStations = {}
    rRadio.cl.performance.activeStationCount = 0
    if timer.Exists( "ValidateStationCount" ) then timer.Remove( "ValidateStationCount" ) end
end )

if not timer.Exists( "ValidateStationCount" ) then
    timer.Create( "ValidateStationCount", 30, 0, function()
        local actualCount = 0
        for ent, source in pairs( rRadio.cl.radioSources ) do
            if IsValid( ent ) and IsValid( source ) then
                actualCount = actualCount + 1
            else
                rRadio.cl.radioSources[ent] = nil
            end
        end

        rRadio.cl.performance.activeStationCount = actualCount
    end )
end
