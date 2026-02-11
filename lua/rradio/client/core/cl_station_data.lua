if SERVER then return end
rRadio.cl.stationData = {}
rRadio.cl.allowedUrlSet = {}
rRadio.cl.customUrlSet = {}
rRadio.cl.nameIndex = {}
rRadio.cl.globalSearchIndex = {}
rRadio.cl.stationDataLoaded = false
function rRadio.cl.loadStationData()
    if rRadio.cl.stationDataLoaded then return end
    rRadio.cl.stationData = {}
    local files = file.Find( "rradio/client/data/stationpacks/*.lua", "LUA" )
    for _, f in ipairs( files ) do
        local data = include( "rradio/client/data/stationpacks/" .. f )
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
                        nameLower = string.lower( station.n ),
                        charMap = rRadio.interface.buildCharMap( station.n )
                    }

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
    local nameIndex = {}
    local globalSearchIndex = {}
    for country, list in pairs( rRadio.cl.stationData ) do
        for _, station in ipairs( list ) do
            station.countryKey = country
            station.nameLower = station.nameLower or string.lower( station.name or "" )
            station.charMap = station.charMap or rRadio.interface.buildCharMap( station.name or "" )
            table.insert( nameIndex, {
                key = station.nameLower,
                ref = station,
                country = country
            } )

            table.insert( globalSearchIndex, {
                station = station,
                countryKey = country,
                displayKey = station.name,
                searchText = station.name,
                searchTextLower = station.nameLower,
                charMap = station.charMap
            } )
        end
    end

    table.sort( globalSearchIndex, function( a, b ) return ( a.searchTextLower or "" ) < ( b.searchTextLower or "" ) end )
    rRadio.cl.nameIndex = nameIndex
    rRadio.cl.globalSearchIndex = globalSearchIndex
end

function rRadio.cl.isUrlAllowed( url )
    return rRadio.cl.allowedUrlSet[url] == true
end

rRadio.cl.loadStationData()
rRadio.cl.rebuildNameIndex()
