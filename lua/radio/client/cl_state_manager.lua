--[[
    Radio Addon Client-Side State Management
    Author: Charles Mills
    Description: This file manages the state of the Radio Addon on the client side.
                 It handles state changes, event emissions, and the loading of user favorites.
    Date: October 31, 2024
]]--

local StateManagerFunctions = {}

function StateManagerFunctions:GetState(key)
    return self[key]
end

function StateManagerFunctions:SetState(key, value)
    if self[key] ~= value then
        self[key] = value
        self:Emit(self.Events.STATE_CHANGED, key, value)
    end
end

function StateManagerFunctions:On(event, callback)
    if not event then return end
    self._eventListeners[event] = self._eventListeners[event] or {}
    table.insert(self._eventListeners[event], callback)
end

function StateManagerFunctions:Emit(event, ...)
    if not event then return end
    if self._eventListeners[event] then
        for _, callback in ipairs(self._eventListeners[event]) do
            callback(...)
        end
    end
end

function StateManagerFunctions:Initialize()
    if self.initialized then return end
    
    if not file.IsDir(self.dataDir, "DATA") then
        file.CreateDir(self.dataDir)
    end

    self.initialized = true
    self:LoadFavorites()
    self:Emit(self.Events.STATE_INITIALIZED)
    
    return true
end

function StateManagerFunctions:StopEntityStation(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    if self.activeStations[entIndex] then
        local currentStation = self.activeStations[entIndex]
        if IsValid(currentStation.source) then
            currentStation.source:Stop()
        end
        
        if currentStation.hookName then
            hook.Remove("Think", currentStation.hookName)
        end
        
        self.currentRadioSources[entity] = nil
        self.currentlyPlayingStations[entity] = nil
        self.activeStations[entIndex] = nil
        
        self:UpdateStationCount()
        self:Emit(self.Events.RADIO_STOPPED, entity)
        return true
    end
    return false
end

function StateManagerFunctions:StartEntityStation(entity, stationData, source)
    if not IsValid(entity) then return false end
    local entIndex = entity:EntIndex()
    
    self:StopEntityStation(entity)
    
    self.activeStations[entIndex] = {
        entity = entity,
        source = source,
        stationData = stationData,
        hookName = "UpdateRadioPosition_" .. entIndex,
        startTime = CurTime()
    }
    
    self.currentRadioSources[entity] = source
    self.currentlyPlayingStations[entity] = stationData
    
    self:UpdateStationCount()
    self:Emit(self.Events.STATION_CHANGED, entity, stationData)
    return true
end

function StateManagerFunctions:GetEntityStation(entity)
    if not IsValid(entity) then return nil end
    return self.activeStations[entity:EntIndex()]
end

function StateManagerFunctions:UpdateStationCount()
    local count = 0
    for ent, source in pairs(self.currentRadioSources) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            if IsValid(source) then
                source:Stop()
            end
            self.currentRadioSources[ent] = nil
        end
    end
    self.activeStationCount = count
    return count
end

function StateManagerFunctions:GetFavoritesList(lang, filterText)
    local cacheKey = lang .. "_" .. (filterText or "")
    
    -- Check if cache is valid
    if self._cache.favoritesList and 
       self._cache.favoritesList.key == cacheKey and 
       self._cache.favoritesList.timestamp > self._lastStateUpdate then
        return self._cache.favoritesList.data
    end

    local favoritesList = {}
    
    -- Ensure StationData is available
    if not StationData then return favoritesList end
    
    -- Iterate through favorite stations
    for country, stations in pairs(self.favoriteStations) do
        if StationData[country] then
            -- Find matching stations in StationData
            for _, stationData in ipairs(StationData[country]) do
                if stations[stationData.name] and 
                   (not filterText or stationData.name:lower():find(filterText:lower(), 1, true)) then
                    local translatedName = self:GetTranslatedCountryName(country, lang)
                    
                    table.insert(favoritesList, {
                        station = stationData, -- Use full station data including URL
                        country = country,
                        countryName = translatedName
                    })
                end
            end
        end
    end

    -- Sort the list
    table.sort(favoritesList, function(a, b)
        if a.countryName == b.countryName then
            return a.station.name < b.station.name
        end
        return a.countryName < b.countryName
    end)

    -- Cache the result
    self._cache.favoritesList = {
        key = cacheKey,
        data = favoritesList,
        timestamp = CurTime()
    }

    return favoritesList
end

function StateManagerFunctions:GetTranslatedCountryName(country, lang)
    if not LanguageManager then
        print("[Radio] Warning: LanguageManager not available")
        return country
    end

    local cacheKey = country .. "_" .. lang
    
    if self._cache.countryTranslations[cacheKey] then
        return self._cache.countryTranslations[cacheKey]
    end

    local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    
    local translatedName = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry
    self._cache.countryTranslations[cacheKey] = translatedName
    
    return translatedName
end

function StateManagerFunctions:SaveFavorites()
    if not self.initialized then return false end

    local function createBackup(filename)
        if file.Exists(filename, "DATA") then
            file.Write(filename .. ".bak", file.Read(filename, "DATA"))
        end
    end

    -- Save countries
    local favCountriesList = {}
    for country, _ in pairs(self.favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    
    local countriesJson = util.TableToJSON(favCountriesList, true)
    if countriesJson then
        createBackup(self.favoriteCountriesFile)
        file.Write(self.favoriteCountriesFile, countriesJson)
    end

    -- Save stations
    local favStationsTable = {}
    for country, stations in pairs(self.favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and type(isFavorite) == "boolean" then
                    favStationsTable[country][stationName] = isFavorite
                end
            end
        end
    end
    
    local stationsJson = util.TableToJSON(favStationsTable, true)
    if stationsJson then
        createBackup(self.favoriteStationsFile)
        file.Write(self.favoriteStationsFile, stationsJson)
    end

    self:Emit(self.Events.FAVORITES_SAVED)
    return true
end

function StateManagerFunctions:LoadFavorites()
    if not self.initialized then return end

    local function loadFromBackup(filename)
        if file.Exists(filename .. ".bak", "DATA") then
            return util.JSONToTable(file.Read(filename .. ".bak", "DATA"))
        end
        return nil
    end

    -- Load countries
    if file.Exists(self.favoriteCountriesFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(self.favoriteCountriesFile, "DATA"))
        end)
        
        if not success or not data then
            data = loadFromBackup(self.favoriteCountriesFile)
        end

        if data then
            self.favoriteCountries = {}
            for _, country in ipairs(data) do
                if type(country) == "string" then
                    self.favoriteCountries[country] = true
                end
            end
        end
    end

    -- Load stations
    if file.Exists(self.favoriteStationsFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(self.favoriteStationsFile, "DATA"))
        end)
        
        if not success or not data then
            data = loadFromBackup(self.favoriteStationsFile)
        end

        if data then
            self.favoriteStations = {}
            for country, stations in pairs(data) do
                if type(country) == "string" and type(stations) == "table" then
                    self.favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if type(stationName) == "string" and type(isFavorite) == "boolean" then
                            self.favoriteStations[country][stationName] = isFavorite
                        end
                    end
                end
            end
        end
    end

    self:Emit(self.Events.FAVORITES_LOADED, {
        countries = self.favoriteCountries,
        stations = self.favoriteStations
    })
end

local StateManager = {
    Events = {
        STATE_CHANGED = "RadioStateChanged",
        STATE_INITIALIZED = "RadioStateInitialized",
        VOLUME_CHANGED = "RadioVolumeChanged",
        STATION_CHANGED = "RadioStationChanged",
        FAVORITES_CHANGED = "RadioFavoritesChanged",
        RADIO_STATUS_CHANGED = "RadioStatusChanged",
        RADIO_STOPPED = "RadioStopped",
        ENTITY_REMOVED = "RadioEntityRemoved",
        SETTINGS_CHANGED = "RadioSettingsChanged",
        THEME_CHANGED = "RadioThemeChanged",
        LANGUAGE_CHANGED = "RadioLanguageChanged",
        FAVORITES_LOADED = "RadioFavoritesLoaded",
        FAVORITES_SAVED = "RadioFavoritesSaved"
    },

    -- Initialize data directory
    dataDir = "rradio",
    favoriteCountriesFile = "rradio/favorite_countries.json",
    favoriteStationsFile = "rradio/favorite_stations.json",

    -- State storage
    initialized = false,
    _eventListeners = {},
    _cache = {
        favoritesList = nil,
        countryTranslations = {},
        lastUpdate = 0
    },
    _lastStateUpdate = 0,
    
    -- Core state
    radioMenuOpen = false,
    settingsMenuOpen = false,
    favoritesMenuOpen = false,
    selectedCountry = nil,
    isSearching = false,
    
    -- Audio state
    currentRadioSources = {},
    activeStations = {},
    activeStationCount = 0,
    entityVolumes = {},
    currentlyPlayingStations = {},
    
    -- UI state
    currentFrame = nil,
    BoomboxStatuses = {},
    
    -- Favorites state
    favoriteCountries = {},
    favoriteStations = {},
    
    -- Cache
    formattedCountryNames = {},
    
    -- Timing
    lastKeyPress = 0,
    lastStationSelectTime = 0,
    lastPermissionMessage = 0,
    lastMessageTime = -math.huge
}

-- Apply all functions to StateManager
for name, func in pairs(StateManagerFunctions) do
    StateManager[name] = func
end

return StateManager 