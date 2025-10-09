local Radio, Utils, Interface = rRadio:Import("Radio", "utils", "!interface", "!cl")

if SERVER then return end

concommand.Add("rammel_rradio_list_active", function()
    local idx = 0
    for ent, source in pairs(Radio.cl.radioSources) do
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
    for ent, station in pairs(Radio.cl.radioSources) do
        if IsValid(station) then
            station:Stop()
            count = count + 1
        end
        Utils.ClearRadioStatus(ent)
        Radio.cl.connectedStations[ent] = nil
        Radio.cl.requestedStations[ent] = nil
        Radio.cl.queuedStations[ent] = nil
        Radio.cl.entityVolumes[ent] = nil
        Radio.cl.stationLastPos[ent] = nil
        Radio.cl.currentlyPlayingStations[ent] = nil
        Radio.cl.radioSources[ent] = nil
    end
    Radio.cl.performance.activeStationCount = 0
    MsgC(Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255),
        "Disconnected " .. count .. " station" .. (count == 1 and "" or "s") .. ".\n")
end, nil, "Disconnects all radio streams", FCVAR_CLIENTCMD_CAN_EXECUTE)

Interface.loadFavorites()

Radio.cl.performance.lastEnabled = Radio.cl.cvars.enabled:GetBool()
Radio.cl.performance.lastMaxVolume = Radio.cl.cvars.maxVolume:GetFloat()