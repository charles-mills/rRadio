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
    
    if countriesData then
        rRadio.Favorites.Countries = json(countriesData) or {}
    end
    
    if stationsData then
        rRadio.Favorites.Stations = json(stationsData) or {}
    end
end

local function SaveFavorites()
    if saveFavoritesTimer then
        timer.Remove(saveFavoritesTimer)
    end
    
    saveFavoritesTimer = "rRadio_SaveFavorites_" .. CurTime()
    timer.Create(saveFavoritesTimer, 1, 1, function()
        if not file.Exists("rradio/favorites", "DATA") then
            file.CreateDir("rradio/favorites")
        end
        
        file.Write("rradio/favorites/countries.json", toJson(rRadio.Favorites.Countries))
        file.Write("rradio/favorites/stations.json", toJson(rRadio.Favorites.Stations))
    end)
end

function rRadio.ToggleFavoriteCountry(country)
    rRadio.Favorites.Countries = rRadio.Favorites.Countries or {}
    if rRadio.Favorites.Countries[country] then
        rRadio.Favorites.Countries[country] = nil
    else
        rRadio.Favorites.Countries[country] = true
    end
    SaveFavorites()
end

function rRadio.ToggleFavoriteStation(country, stationIndex)
    rRadio.Favorites.Stations = rRadio.Favorites.Stations or {}
    local key = country .. "_" .. stationIndex
    if rRadio.Favorites.Stations[key] then
        rRadio.Favorites.Stations[key] = nil
    else
        rRadio.Favorites.Stations[key] = true
    end
    SaveFavorites()
end

function rRadio.IsCountryFavorite(country)
    return (rRadio.Favorites.Countries or {})[country] or false
end

function rRadio.IsStationFavorite(country, stationIndex)
    rRadio.Favorites.Stations = rRadio.Favorites.Stations or {}
    local key = country .. "_" .. stationIndex
    return rRadio.Favorites.Stations[key] or false
end

-- Load favorites when the file is included
LoadFavorites()

-- Expose functions to other files
rRadio.LoadFavorites = LoadFavorites
rRadio.SaveFavorites = SaveFavorites
