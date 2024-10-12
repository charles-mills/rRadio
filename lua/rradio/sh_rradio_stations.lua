-- Shared station loading for rRadio

rRadio = rRadio or {}
rRadio.Stations = rRadio.Stations or {}

function rRadio.LoadStationData()
    rRadio.Stations = {}  -- Clear existing stations to prevent duplicates from previous loads
    local files, _ = file.Find("lua/rradio/stations/*.lua", "GAME")
    for _, f in ipairs(files) do
        local success, stationData = pcall(include, "rradio/stations/" .. f)
        if success and type(stationData) == "table" then
            for country, stations in pairs(stationData) do
                rRadio.Stations[country] = rRadio.Stations[country] or {}
                local existingStations = {}
                for _, station in ipairs(rRadio.Stations[country]) do
                    existingStations[station.n] = true
                end
                for _, station in ipairs(stations) do
                    if not existingStations[station.n] then
                        table.insert(rRadio.Stations[country], station)
                        existingStations[station.n] = true
                    else
                        print("Skipping duplicate station:", country, station.n)
                    end
                end
            end
        else
            rRadio.LogError("Failed to load station data from " .. f .. ": " .. tostring(stationData))
        end
    end
    
    hook.Run("rRadio_StationsLoaded")
end

hook.Add("Initialize", "rRadio_LoadStations", rRadio.LoadStationData)
