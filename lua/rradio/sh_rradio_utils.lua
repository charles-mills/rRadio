-- Shared utilities for rRadio

rRadio = rRadio or {}

function rRadio.SafeString(str)
    return string.gsub(str, "[^%w%s]", "")
end

function rRadio.FormatStationName(name)
    return string.sub(rRadio.SafeString(name), 1, rRadio.Config.MaxStationNameLength)
end

function rRadio.LogError(message)
    if rRadio.Config.LogErrors then
        ErrorNoHalt("[rRadio] " .. message .. "\n")
    end
end

rRadio.Cache = rRadio.Cache or {}

function rRadio.CacheGet(key)
    local cachedData = rRadio.Cache[key]
    if cachedData and os.time() - cachedData.timestamp < rRadio.Config.CacheTimeout then
        return cachedData.value
    end
    return nil
end

function rRadio.CacheSet(key, value)
    rRadio.Cache[key] = {value = value, timestamp = os.time()}
end

rRadio.StationIndex = rRadio.StationIndex or {}

function rRadio.BuildStationIndex()
    for country, stations in pairs(rRadio.Stations) do
        for i, station in ipairs(stations) do
            local key = string.lower(station.n)
            rRadio.StationIndex[key] = rRadio.StationIndex[key] or {}
            table.insert(rRadio.StationIndex[key], {country = country, index = i})
        end
    end
end

function rRadio.SearchStations(query)
    local results = {}
    local lowerQuery = string.lower(query)
    for key, stations in pairs(rRadio.StationIndex) do
        if string.find(key, lowerQuery) then
            for _, stationInfo in ipairs(stations) do
                table.insert(results, stationInfo)
            end
        end
    end
    return results
end

if CLIENT then
    rRadio.Favorites = rRadio.Favorites or {}
    rRadio.RecentStations = rRadio.RecentStations or {}

    function rRadio.IsFavorite(country, index)
        for _, fav in ipairs(rRadio.Favorites) do
            if fav.country == country and fav.index == index then
                return true
            end
        end
        return false
    end

    function rRadio.ToggleFavorite(country, index)
        if rRadio.IsFavorite(country, index) then
            for i, fav in ipairs(rRadio.Favorites) do
                if fav.country == country and fav.index == index then
                    table.remove(rRadio.Favorites, i)
                    break
                end
            end
        else
            if #rRadio.Favorites < rRadio.Config.MaxFavorites then
                table.insert(rRadio.Favorites, {country = country, index = index})
            else
                LocalPlayer():ChatPrint("You've reached the maximum number of favorites.")
            end
        end
        
        file.Write("rradio_favorites.txt", util.TableToJSON(rRadio.Favorites))
        hook.Run("rRadio_FavoritesChanged")
        
        net.Start("rRadio_ToggleFavorite")
        net.WriteString(country)
        net.WriteUInt(index, 16)
        net.SendToServer()
    end

    function rRadio.AddRecentStation(country, index)
        local newRecent = {country = country, index = index}
        
        -- Remove if already in the list
        for i, recent in ipairs(rRadio.RecentStations) do
            if recent.country == country and recent.index == index then
                table.remove(rRadio.RecentStations, i)
                break
            end
        end
        
        -- Add to the beginning of the list
        table.insert(rRadio.RecentStations, 1, newRecent)
        
        -- Trim the list if it's too long
        while #rRadio.RecentStations > rRadio.Config.MaxRecentStations do
            table.remove(rRadio.RecentStations)
        end
        
        file.Write("rradio_recent.txt", util.TableToJSON(rRadio.RecentStations))
    end
end
