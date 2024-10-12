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
    rRadio.StationIndex = {}  -- Clear the existing index
    for country, stations in pairs(rRadio.Stations) do
        for i, station in ipairs(stations) do
            local key = string.lower(station.n)
            rRadio.StationIndex[key] = rRadio.StationIndex[key] or {}
            -- Check if the station already exists in the index
            local exists = false
            for _, indexedStation in ipairs(rRadio.StationIndex[key]) do
                if indexedStation.country == country and indexedStation.index == i then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(rRadio.StationIndex[key], {country = country, index = i})
            end
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

function rRadio.FormatCountryName(name)
    return name:gsub("_", " "):gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

-- New functions moved from cl_rradio_menu.lua

function rRadio.SafeColor(color)
    return IsColor(color) and color or Color(255, 255, 255)
end

function rRadio.SortIgnoringThe(a, b)
    local function stripThe(str)
        return str:gsub("^The%s+", ""):lower()
    end
    return stripThe(a) < stripThe(b)
end

function rRadio.GetScaledFontSize(baseSize)
    local scaleFactor = math.min(ScrW() / 1920, ScrH() / 1080) * 1.5
    return math.Round(baseSize * scaleFactor)
end

function rRadio.IsDarkMode()
    if CLIENT then
        return GetConVar("rradio_dark_mode"):GetBool()
    end
    return false -- Default to light mode on the server or in shared context
end

function rRadio.ToggleDarkMode()
    if CLIENT then
        local darkModeConVar = GetConVar("rradio_dark_mode")
        darkModeConVar:SetBool(not darkModeConVar:GetBool())
        hook.Run("rRadio_ColorSchemeChanged")
    end
end

function rRadio.GetColors()
    local isDarkMode = rRadio.IsDarkMode()
    return {
        bg = isDarkMode and Color(18, 18, 18) or Color(255, 255, 255),
        text = isDarkMode and Color(255, 255, 255) or Color(0, 0, 0),
        button = isDarkMode and Color(30, 30, 30) or Color(240, 240, 240),
        buttonHover = isDarkMode and Color(40, 40, 40) or Color(230, 230, 230),
        accent = Color(0, 122, 255),
        text_placeholder = isDarkMode and Color(150, 150, 150) or Color(100, 100, 100),
        scrollBg = isDarkMode and Color(25, 25, 25) or Color(245, 245, 245),
        divider = isDarkMode and Color(50, 50, 50) or Color(200, 200, 200),
    }
end
