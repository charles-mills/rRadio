-- Shared station loading for rRadio

rRadio = rRadio or {}
rRadio.Stations = rRadio.Stations or {}

function rRadio.LoadStationData()
    local files, _ = file.Find("lua/rradio/stations/*.lua", "GAME")
    for _, f in ipairs(files) do
        local success, stationData = pcall(include, "rradio/stations/" .. f)
        if success and type(stationData) == "table" then
            table.Merge(rRadio.Stations, stationData)
        else
            rRadio.LogError("Failed to load station data from " .. f .. ": " .. tostring(stationData))
        end
    end
    
    -- Log the number of loaded stations
    local stationCount = table.Count(rRadio.Stations)
    print("[rRadio] Loaded " .. stationCount .. " station categories")

    hook.Run("rRadio_StationsLoaded")
end

hook.Add("Initialize", "rRadio_LoadStations", rRadio.LoadStationData)
