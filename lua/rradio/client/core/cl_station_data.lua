if SERVER then return end
rRadio.cl.stationData = {}
rRadio.cl.allowedUrlSet = {}
rRadio.cl.customUrlSet = {}
rRadio.cl.globalSearchIndex = {}
rRadio.cl.countrySearchIndex = {}
rRadio.cl.stationDataLoaded = false
function rRadio.cl.loadStationData()
    if rRadio.cl.stationDataLoaded then return end
    rRadio.cl.stationData = {}
    local files = file.Find( "rradio/client/stations/*.lua", "LUA" )
    for _, f in ipairs( files ) do
        local data = include( "rradio/client/stations/" .. f )
        if data then
            for country, stations in pairs( data ) do
                local baseCountry = country:gsub( "_(%d+)$", "" )
                rRadio.cl.stationData[baseCountry] = rRadio.cl.stationData[baseCountry] or {}
                for _, station in ipairs( stations ) do
                    local entry = {
                        name = station.n,
                        url = station.u,
                        country = baseCountry,
                        countryKey = baseCountry,
                    }
                    rRadio.interface.ensureSearchFields( entry )

                    table.insert( rRadio.cl.stationData[baseCountry], entry )
                    rRadio.cl.allowedUrlSet[station.u] = true
                end
            end
        else
            rRadio.logger.ErrorScope( "station_data", "Could not load station file", f )
        end
    end

    rRadio.cl.stationDataLoaded = true
end

function rRadio.cl.rebuildNameIndex()
    local globalSearchIndex = {}
    local countrySearchIndex = {}
    for country, list in pairs( rRadio.cl.stationData ) do
        local countrySearchList = {}
        for _, station in ipairs( list ) do
            station.countryKey = country
            rRadio.interface.ensureSearchFields( station )
            local searchEntry = {
                station = station,
                countryKey = country,
                displayKey = station.name,
                searchText = station.name,
                searchTextLower = station.nameLower,
                charMap = station.charMap
            }
            table.insert( globalSearchIndex, searchEntry )
            table.insert( countrySearchList, searchEntry )
        end

        countrySearchIndex[country] = countrySearchList
    end

    table.sort( globalSearchIndex, function( a, b )
        return ( a.searchTextLower or "" ) < ( b.searchTextLower or "" )
    end )
    rRadio.cl.globalSearchIndex = globalSearchIndex
    rRadio.cl.countrySearchIndex = countrySearchIndex
end

function rRadio.cl.isUrlAllowed( url )
    return rRadio.cl.allowedUrlSet[url] == true
end

rRadio.cl.loadStationData()
rRadio.cl.rebuildNameIndex()
