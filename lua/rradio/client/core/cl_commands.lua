if SERVER then return end

concommand.Add("rammel_rradio_list_active", function()
    local idx = 0
    for ent, source in pairs(rRadio.cl.radioSources) do
        if IsValid(ent) and IsValid(source) then
            if idx == 0 then
                MsgC(Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255), "Active stations:\n")
            end
            idx = idx + 1
            local name = ent:GetNWString("StationName", "Unknown")
            MsgC(Color(0, 255, 0), "[" .. idx .. "] ", Color(255, 255, 255), name .. "\n")
        end
    end
    if idx == 0 then
        MsgC(Color(255, 255, 255), "[rRadio] No active stations.\n")
    end
end, nil, "Lists all active stations", FCVAR_CLIENTCMD_CAN_EXECUTE)

concommand.Add("rammel_rradio_disconnect_all", function()
    local count = 0
    for ent, station in pairs(rRadio.cl.radioSources) do
        if IsValid(station) then
            station:Stop()
            count = count + 1
        end
        rRadio.utils.ClearRadioStatus(ent)
        rRadio.cl.connectedStations[ent] = nil
        rRadio.cl.requestedStations[ent] = nil
        rRadio.cl.queuedStations[ent] = nil
        rRadio.cl.entityVolumes[ent] = nil
        rRadio.cl.stationLastPos[ent] = nil
        rRadio.cl.currentlyPlayingStations[ent] = nil
        rRadio.cl.radioSources[ent] = nil
    end
    rRadio.cl.performance.activeStationCount = 0
    MsgC(Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255), 
        "Disconnected " .. count .. " station" .. (count == 1 and "" or "s") .. ".\n")
end, nil, "Disconnects all radio streams", FCVAR_CLIENTCMD_CAN_EXECUTE)

rRadio.interface.loadFavorites()

rRadio.cl.performance.lastEnabled = rRadio.cl.cvars.enabled:GetBool()
rRadio.cl.performance.lastMaxVolume = rRadio.cl.cvars.maxVolume:GetFloat()