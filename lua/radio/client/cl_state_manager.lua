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
        favoriteCountriesFile = "favorite_countries.json",
        favoriteStationsFile = "favorite_stations.json",
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
        Debug:Log("Created data directory:", self.Config.dataDir)
    end
    
    -- Initialize state storage with default values
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
    
    -- Initialize cache
    self._cache = {
        favoritesList = nil,
        countryTranslations = {},
        lastUpdate = 0
    }
    
    self.initialized = true
    Debug:Log("StateManager initialized successfully")
    
    -- Create initial favorites files if they don't exist
    if not file.Exists(self.Config.favoriteCountriesFile, "DATA") then
        Debug:Log("Creating initial favorites files")
        local initialData = {
            countries = {},
            stations = {},
            metadata = {
                version = 2,
                timestamp = os.time(),
                checksum = util.CRC("{}{}"),
                stationCount = 0,
                countryCount = 0
            }
        }
        
        file.Write(self.Config.favoriteCountriesFile, util.TableToJSON({}))
        file.Write(self.Config.favoriteStationsFile, util.TableToJSON({
            metadata = initialData.metadata,
            stations = {}
        }))
        Debug:Log("Created initial favorites files")
    end
    
    -- Load saved data after initialization
    local loadSuccess = self:LoadFavorites()
    if not loadSuccess then
        Debug:Warning("Failed to load favorites, using empty defaults")
        -- Ensure we have valid empty states even if load fails
        self._state.favoriteCountries = {}
        self._state.favoriteStations = {}
    end
    
    self:Emit(self.Events.INITIALIZED)
    
    -- Add shutdown hook
    hook.Add("ShutDown", "SaveFavoritesOnShutdown", function()
        Debug:Log("Game shutting down - saving favorites")
        self:SaveFavorites()
    end)

    -- Add disconnect hook
    hook.Add("OnPlayerDisconnected", "SaveFavoritesOnDisconnect", function(ply)
        if ply == LocalPlayer() then
            Debug:Log("Player disconnecting - saving favorites")
            self:SaveFavorites()
        end
    end)

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

    -- Ensure data directory exists
    if not file.IsDir(self.Config.dataDir, "DATA") then
        Debug:Log("Creating data directory:", self.Config.dataDir)
        file.CreateDir(self.Config.dataDir)
        
        -- Verify directory was created
        if not file.IsDir(self.Config.dataDir, "DATA") then
            Debug:Error("Failed to create data directory")
            Debug:Log("Attempted to create:", self.Config.dataDir)
            Debug:Log("Current directories:", file.Find("*", "DATA"))
            return false
        end
    end

    -- Prepare data structure
    local favoritesData = {
        countries = {},
        stations = {}
    }

    -- Process countries with validation
    for country, _ in pairs(self._state.favoriteCountries) do
        if type(country) == "string" then
            favoritesData.countries[country] = true
        end
    end

    -- Process stations with validation
    for country, stations in pairs(self._state.favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favoritesData.stations[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and isFavorite then
                    favoritesData.stations[country][stationName] = true
                end
            end
        end
    end

    -- Convert to JSON with error handling
    local countriesJson = util.TableToJSON(favoritesData.countries, true)
    local stationsJson = util.TableToJSON(favoritesData.stations, true)

    if not countriesJson or not stationsJson then
        Debug:Error("Failed to convert data to JSON")
        return false
    end

    -- Construct full file paths
    local countriesPath = self.Config.dataDir .. "/" .. self.Config.favoriteCountriesFile
    local stationsPath = self.Config.dataDir .. "/" .. self.Config.favoriteStationsFile

    Debug:Log("Writing to files...")
    Debug:Log("Countries path:", countriesPath)
    Debug:Log("Stations path:", stationsPath)

    -- Create directory structure if it doesn't exist
    local dirPath = string.GetPathFromFilename(countriesPath)
    if dirPath and dirPath ~= "" and not file.IsDir(dirPath, "DATA") then
        Debug:Log("Creating directory structure:", dirPath)
        file.CreateDir(dirPath)
    end

    -- Write files with error handling and verification
    local function writeAndVerify(path, content)
        -- Write file
        local writeSuccess = file.Write(path, content)
        if not writeSuccess then
            Debug:Error("Failed to write file:", path)
            Debug:Log("Write permissions check:", file.IsDir(self.Config.dataDir, "DATA"))
            return false
        end

        -- Verify content was written
        local readContent = file.Read(path, "DATA")
        if not readContent or readContent == "" then
            Debug:Error("Failed to verify file content:", path)
            return false
        end

        return true
    end

    -- Write countries file
    if not writeAndVerify(countriesPath, countriesJson) then
        Debug:Error("Failed to write/verify countries file")
        return false
    end

    -- Write stations file
    if not writeAndVerify(stationsPath, stationsJson) then
        Debug:Error("Failed to write/verify stations file")
        return false
    end

    Debug:Log("Favorites saved successfully")
    Debug:Log("- Countries:", table.Count(favoritesData.countries))
    Debug:Log("- Stations:", table.Count(favoritesData.stations))
    Debug:Log("- Countries file size:", string.len(countriesJson))
    Debug:Log("- Stations file size:", string.len(stationsJson))

    return true
end

function StateManager:LoadFavorites()
    if not self.initialized then
        Debug:Error("Attempted to load favorites before initialization")
        return false
    end
    
    Debug:Log("Loading favorites...")

    -- Initialize state
    self._state.favoriteCountries = {}
    self._state.favoriteStations = {}

    -- Construct full file paths
    local countriesPath = self.Config.dataDir .. "/" .. self.Config.favoriteCountriesFile
    local stationsPath = self.Config.dataDir .. "/" .. self.Config.favoriteStationsFile

    -- Read files
    local countriesContent = file.Read(countriesPath, "DATA")
    local stationsContent = file.Read(stationsPath, "DATA")

    -- If files don't exist, create them with empty data
    if not countriesContent then
        file.Write(countriesPath, "{}")
        countriesContent = "{}"
    end
    if not stationsContent then
        file.Write(stationsPath, "{}")
        stationsContent = "{}"
    end

    -- Parse data
    local success, countries = pcall(util.JSONToTable, countriesContent)
    local success2, stations = pcall(util.JSONToTable, stationsContent)

    if not success or not success2 then
        Debug:Error("Failed to parse favorites data")
        return false
    end

    -- Load countries
    if type(countries) == "table" then
        for country, value in pairs(countries) do
            if type(country) == "string" then
                self._state.favoriteCountries[country] = true
            end
        end
    end

    -- Load stations
    if type(stations) == "table" then
        for country, countryStations in pairs(stations) do
            if type(country) == "string" and type(countryStations) == "table" then
                self._state.favoriteStations[country] = {}
                for stationName, isFavorite in pairs(countryStations) do
                    if type(stationName) == "string" and type(isFavorite) == "boolean" then
                        self._state.favoriteStations[country][stationName] = isFavorite
                    end
                end
            end
        end
    end

    Debug:Log("Loaded favorites successfully")
    Debug:Log("- Countries:", table.Count(self._state.favoriteCountries))
    Debug:Log("- Stations:", table.Count(self._state.favoriteStations))

    -- Emit load event
    self:Emit(self.Events.FAVORITES_LOADED, {
        countries = self._state.favoriteCountries,
        stations = self._state.favoriteStations
    })

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
    
    -- Check if cache is valid and recent
    if self._cache.favoritesList and 
       self._cache.favoritesList.key == cacheKey and 
       (CurTime() - self._cache.favoritesList.timestamp) < 1.0 then
        return self._cache.favoritesList.data
    end

    -- Create optimized favorites list
    local favoritesList = {}
    local translationCache = {}
    
    -- Pre-cache translations for better performance
    for country, stations in pairs(self._state.favoriteStations) do
        translationCache[country] = self:GetTranslatedCountryName(country, lang)
    end

    -- Build list with filtering
    local filterLower = filterText and filterText:lower()
    for country, stations in pairs(self._state.favoriteStations) do
        local translatedCountry = translationCache[country]
        
        for stationName, isFavorite in pairs(stations) do
            if isFavorite and (not filterLower or 
               stationName:lower():find(filterLower, 1, true) or
               translatedCountry:lower():find(filterLower, 1, true)) then
                table.insert(favoritesList, {
                    station = { name = stationName },
                    country = country,
                    countryName = translatedCountry
                })
            end
        end
    end

    -- Sort with pre-computed translated names
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

local AUTOSAVE_INTERVAL = 60 -- Save every minute

timer.Create("FavoritesAutoSave", AUTOSAVE_INTERVAL, 0, function()
    if StateManager.initialized then
        StateManager:SaveFavorites()
    end
end)

return StateManager 