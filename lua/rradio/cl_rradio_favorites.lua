-- Client-side favorites system for rRadio

rRadio = rRadio or {}
rRadio.Favorites = rRadio.Favorites or {
    Countries = {},
    Stations = {}
}

local json = util.JSONToTable
local toJson = util.TableToJSON

-- Debounce timer
local saveFavoritesTimer = nil

local function LoadFavorites()
    local countriesData = file.Read("rradio/favorites/countries.json", "DATA")
    local stationsData = file.Read("rradio/favorites/stations.json", "DATA")
    
    rRadio.Favorites.Countries = json(countriesData) or {}
    rRadio.Favorites.Stations = json(stationsData) or {}

    -- Print out all favorite countries
    print("Favorite Countries:")
    for country, _ in pairs(rRadio.Favorites.Countries) do
        print("- " .. country)
    end
end

local function SaveFavorites()
    if saveFavoritesTimer then
        timer.Remove(saveFavoritesTimer)
    end
    
    -- Create a unique identifier for the timer
    saveFavoritesTimer = "rRadio_SaveFavorites_" .. os.time()
    
    timer.Create(saveFavoritesTimer, 1, 1, function()
        if not file.Exists("rradio/favorites", "DATA") then
            file.CreateDir("rradio/favorites")
        end
        
        file.Write("rradio/favorites/countries.json", toJson(rRadio.Favorites.Countries))
        file.Write("rradio/favorites/stations.json", toJson(rRadio.Favorites.Stations))
    end)
end

function rRadio.ToggleFavoriteCountry(country)
    if rRadio.Favorites.Countries[country] then
        rRadio.Favorites.Countries[country] = nil
    else
        rRadio.Favorites.Countries[country] = true
    end
    SaveFavorites()
end

function rRadio.ToggleFavoriteStation(country, stationName)
    rRadio.Favorites.Stations[country] = rRadio.Favorites.Stations[country] or {}
    if rRadio.Favorites.Stations[country][stationName] then
        rRadio.Favorites.Stations[country][stationName] = nil
        -- If no more favorite stations in this country, remove the country entry
        if table.IsEmpty(rRadio.Favorites.Stations[country]) then
            rRadio.Favorites.Stations[country] = nil
        end
    else
        rRadio.Favorites.Stations[country][stationName] = true
    end
    SaveFavorites()
end

function rRadio.IsCountryFavorite(country)
    return rRadio.Favorites.Countries[country] or false
end

function rRadio.IsStationFavorite(country, stationName)
    return rRadio.Favorites.Stations[country] and rRadio.Favorites.Stations[country][stationName] or false
end

function rRadio.GetFavoriteStations(country)
    return rRadio.Favorites.Stations[country] or {}
end

function rRadio.GetAllFavoriteStations()
    local allFavorites = {}
    for country, stations in pairs(rRadio.Favorites.Stations) do
        for stationName, _ in pairs(stations) do
            table.insert(allFavorites, {country = country, name = stationName})
        end
    end
    return allFavorites
end

-- Load favorites when the file is included
LoadFavorites()

-- Expose functions to other files
rRadio.LoadFavorites = LoadFavorites
rRadio.SaveFavorites = SaveFavorites
