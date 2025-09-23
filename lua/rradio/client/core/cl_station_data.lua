if SERVER then return end

local Radio = rRadio
local Interface = Radio.interface

Radio.cl = Radio.cl or {}

Radio.cl.stationData = {}
Radio.cl.allowedUrlSet = {}
Radio.cl.customUrlSet = {}
Radio.cl.nameIndex = {}
Radio.cl.stationDataLoaded = false

function Radio.cl.loadStationData()
    if Radio.cl.stationDataLoaded then return end
    
    Radio.cl.stationData = {}
    local files = file.Find("rradio/client/data/stationpacks/*.lua", "LUA")
    
    for _, f in ipairs(files) do
        local data = include("rradio/client/data/stationpacks/" .. f)
        if data then
            for country, stations in pairs(data) do
                local baseCountry = country:gsub("_(%d+)$", "")
                Radio.cl.stationData[baseCountry] = Radio.cl.stationData[baseCountry] or {}
                
                for _, station in ipairs(stations) do
                    local entry = {
                        name = station.n,
                        url = station.u,
                        country = baseCountry,
                        charMap = Interface.buildCharMap(station.n)
                    }
                    table.insert(Radio.cl.stationData[baseCountry], entry)
                    Radio.cl.allowedUrlSet[station.u] = true
                end
            end
        else
            print("[rRADIO] Error: Could not load station file " .. f)
        end
    end
    
    Radio.cl.stationDataLoaded = true
end

function Radio.cl.rebuildNameIndex()
    Radio.cl.nameIndex = {}
    for country, list in pairs(Radio.cl.stationData) do
        for _, station in ipairs(list) do
            table.insert(Radio.cl.nameIndex, {
                key = station.name:lower(),
                ref = station,
                country = country
            })
        end
    end
end

function Radio.cl.isUrlAllowed(url)
    return Radio.cl.allowedUrlSet[url] == true
end

Radio.cl.loadStationData()
Radio.cl.rebuildNameIndex()
