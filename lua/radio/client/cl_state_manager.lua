--[[
    Radio Addon Client-Side State Management
    Author: Charles Mills
    Description: This file manages the state of the Radio Addon on the client side.
                 It handles state changes, event emissions, and the loading of user favorites.
    Date: October 31, 2024
]]--

local utils = include("radio/shared/sh_utils.lua")
local Debug = RadioDebug
local Events = include("radio/shared/sh_events.lua")
local Misc = include("radio/client/cl_misc.lua")

local StateManager = {
    -- Core state
    initialized = false,
    _state = {},
    _eventListeners = {},
    _cache = {
        favoritesList = nil,
        countryTranslations = {},
        lastUpdate = 0
    },
    _lastStateUpdate = 0,
    
    -- Configuration
    Config = {
        dataDir = "rradio",
        favoriteCountriesFile = "rradio/favorite_countries.json",
        favoriteStationsFile = "rradio/favorite_stations.json",
        maxHistorySize = 100,
        saveInterval = 0.5
    },
    
    -- Event definitions
    Events = Events.STATE
}

function StateManager:Initialize()
    if self.initialized then
        Debug:Warning("StateManager already initialized")
        return self
    end
    
    Debug:Log("Initializing StateManager")
    
    -- Create data directory if it doesn't exist
    if not file.IsDir(self.Config.dataDir, "DATA") then
        file.CreateDir(self.Config.dataDir)
    end
    
    -- Initialize state storage
    self._state = {
        favoriteCountries = {},
        favoriteStations = {},
        entityVolumes = {},
        currentlyPlayingStations = {},
        streamsEnabled = true,
        stationDataLoaded = false,
        currentRadioEntity = nil,
        radioMenuOpen = false,
        settingsMenuOpen = false,
        favoritesMenuOpen = false,
        selectedCountry = nil,
        activeStationCount = 0,
        lastKeyPress = 0,
        lastStationSelectTime = 0,
        lastPermissionMessage = 0,
        lastMessageTime = -math.huge
    }
    
    self.initialized = true -- Mark as initialized before loading favorites
    Debug:Log("StateManager initialized successfully")
    
    -- Load saved data after initialization
    self:LoadFavorites()
    
    self:Emit(self.Events.INITIALIZED)
    
    return self
end

function StateManager:GetState(key)
    if not self.initialized then
        Debug:Error("Attempted to get state before initialization")
        return nil
    end
    return self._state[key]
end

function StateManager:SetState(key, value)
    if not self.initialized then
        Debug:Error("Attempted to set state before initialization")
        return false
    end
    
    if self._state[key] ~= value then
        self._state[key] = value
        self._lastStateUpdate = CurTime()
        self:Emit(self.Events.CHANGED, key, value)
    end
    return true
end

function StateManager:On(event, callback)
    if not event then return end
    self._eventListeners[event] = self._eventListeners[event] or {}
    table.insert(self._eventListeners[event], callback)
end

function StateManager:Emit(event, ...)
    if not event then return end
    if self._eventListeners[event] then
        for _, callback in ipairs(self._eventListeners[event]) do
            local success, err = pcall(callback, ...)
            if not success then
                Debug:Error("Error in event handler for", event, ":", err)
            end
        end
    end
end

function StateManager:SaveFavorites()
    if not self.initialized then return false end

    Debug:Log("Saving favorites...")

    -- Create backup function
    local function createBackup(filename)
        if file.Exists(filename, "DATA") then
            local content = file.Read(filename, "DATA")
            if content then
                file.Write(filename .. ".bak", content)
                Debug:Log("Created backup for", filename)
            end
        end
    end

    -- Save countries
    local favCountriesList = {}
    for country, _ in pairs(self._state.favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    
    local countriesJson = util.TableToJSON(favCountriesList, true)
    if countriesJson then
        createBackup(self.Config.favoriteCountriesFile)
        file.Write(self.Config.favoriteCountriesFile, countriesJson)
        Debug:Log("Saved favorite countries:", #favCountriesList)
    else
        Debug:Error("Failed to serialize favorite countries")
        return false
    end

    -- Save stations
    local favStationsTable = {}
    for country, stations in pairs(self._state.favoriteStations) do
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
        createBackup(self.Config.favoriteStationsFile)
        file.Write(self.Config.favoriteStationsFile, stationsJson)
        Debug:Log("Saved favorite stations:", table.Count(favStationsTable))
    else
        Debug:Error("Failed to serialize favorite stations")
        return false
    end

    self:Emit(self.Events.FAVORITES_SAVED)
    Debug:Log("Favorites saved successfully")
    return true
end

function StateManager:LoadFavorites()
    if not self.initialized then
        Debug:Error("Attempted to load favorites before initialization")
        return false
    end
    
    Debug:Log("Loading favorites...")

    local function loadFromBackup(filename)
        if file.Exists(filename .. ".bak", "DATA") then
            local content = file.Read(filename .. ".bak", "DATA")
            if content then
                Debug:Log("Loading from backup:", filename)
                return util.JSONToTable(content)
            end
        end
        return nil
    end
    
    -- Initialize state if not exists
    self._state.favoriteCountries = self._state.favoriteCountries or {}
    self._state.favoriteStations = self._state.favoriteStations or {}
    
    -- Load countries
    if file.Exists(self.Config.favoriteCountriesFile, "DATA") then
        local content = file.Read(self.Config.favoriteCountriesFile, "DATA")
        local success, data = pcall(function()
            return content and util.JSONToTable(content)
        end)
        
        if not success or not data then
            Debug:Warning("Failed to load favorite countries, attempting backup")
            data = loadFromBackup(self.Config.favoriteCountriesFile)
        end
        
        if data then
            self._state.favoriteCountries = {}
            for _, country in ipairs(data) do
                if type(country) == "string" then
                    self._state.favoriteCountries[country] = true
                end
            end
            Debug:Log("Loaded favorite countries:", table.Count(self._state.favoriteCountries))
        end
    end
    
    -- Load stations
    if file.Exists(self.Config.favoriteStationsFile, "DATA") then
        local content = file.Read(self.Config.favoriteStationsFile, "DATA")
        local success, data = pcall(function()
            return content and util.JSONToTable(content)
        end)
        
        if not success or not data then
            Debug:Warning("Failed to load favorite stations, attempting backup")
            data = loadFromBackup(self.Config.favoriteStationsFile)
        end
        
        if data then
            self._state.favoriteStations = {}
            for country, stations in pairs(data) do
                if type(country) == "string" and type(stations) == "table" then
                    self._state.favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if type(stationName) == "string" and type(isFavorite) == "boolean" then
                            self._state.favoriteStations[country][stationName] = isFavorite
                        end
                    end
                end
            end
            Debug:Log("Loaded favorite stations:", table.Count(self._state.favoriteStations))
        end
    end
    
    self:Emit(self.Events.FAVORITES_LOADED, {
        countries = self._state.favoriteCountries,
        stations = self._state.favoriteStations
    })
    
    Debug:Log("Favorites loaded successfully")
    return true
end

function StateManager:UpdateStationCount()
    local count = 0
    for entIndex, streamData in pairs(StreamManager._streams) do
        if StreamManager:IsValid(entIndex) then
            count = count + 1
        end
    end
    self:SetState("activeStationCount", count)
    return count
end

function StateManager:GetFavoritesList(lang, filterText)
    local cacheKey = lang .. "_" .. (filterText or "")
    
    -- Check if cache is valid
    if self._cache.favoritesList and 
       self._cache.favoritesList.key == cacheKey and 
       self._cache.favoritesList.timestamp > self._lastStateUpdate then
        return self._cache.favoritesList.data
    end

    local favoritesList = {}
    
    -- Iterate through favorite stations
    for country, stations in pairs(self._state.favoriteStations) do
        for stationName, isFavorite in pairs(stations) do
            if isFavorite and (not filterText or stationName:lower():find(filterText:lower(), 1, true)) then
                local translatedCountry = self:GetTranslatedCountryName(country, lang)
                table.insert(favoritesList, {
                    station = { name = stationName },
                    country = country,
                    countryName = translatedCountry
                })
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

function StateManager:GetTranslatedCountryName(country, lang)
    local cacheKey = country .. "_" .. lang
    
    if self._cache.countryTranslations[cacheKey] then
        return self._cache.countryTranslations[cacheKey]
    end

    local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    
    local translatedName = (Misc and Misc.Language and Misc.Language:GetCountryTranslation(lang, formattedCountry)) or formattedCountry
    self._cache.countryTranslations[cacheKey] = translatedName
    
    return translatedName
end

function StateManager:InvalidateCache(cacheType)
    if cacheType == "favorites" then
        self._cache.favoritesList = nil
        self._lastStateUpdate = CurTime()
        self:Emit(self.Events.FAVORITES_CHANGED)
    elseif cacheType == "translations" then
        self._cache.countryTranslations = {}
    end
end

function StateManager:InitializeStreamEvents(StreamManager)
    if not StreamManager then return end
    
    StreamManager:On(StreamManager.Events.STATE_CHANGED, function(data)
        if data.type == "stream_created" then
            self:SetState("currentlyPlayingStations", StreamManager:GetPlayingStations())
        elseif data.type == "stream_stopped" then
            self:SetState("currentlyPlayingStations", StreamManager:GetPlayingStations())
        end
    end)
end

return StateManager 