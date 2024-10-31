local StateManager = {
    -- Events enum
    Events = {
        STATE_CHANGED = "RadioStateChanged",
        VOLUME_CHANGED = "RadioVolumeChanged",
        STATION_CHANGED = "RadioStationChanged",
        FAVORITES_CHANGED = "RadioFavoritesChanged",
        RADIO_STATUS_CHANGED = "RadioStatusChanged",
        RADIO_STOPPED = "RadioStopped",
        ENTITY_REMOVED = "RadioEntityRemoved",
        SETTINGS_CHANGED = "RadioSettingsChanged",
        THEME_CHANGED = "RadioThemeChanged",
        LANGUAGE_CHANGED = "RadioLanguageChanged"
    },

    -- Core state
    radioMenuOpen = false,
    settingsMenuOpen = false,
    favoritesMenuOpen = false,
    selectedCountry = nil,
    isSearching = false,
    
    -- Audio state
    currentRadioSources = {},
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

local eventListeners = {}

function StateManager:On(event, callback)
    eventListeners[event] = eventListeners[event] or {}
    table.insert(eventListeners[event], callback)
end

function StateManager:Emit(event, ...)
    if eventListeners[event] then
        for _, callback in ipairs(eventListeners[event]) do
            callback(...)
        end
    end
end

function StateManager:SetState(key, value)
    if self[key] ~= value then
        self[key] = value
        self:Emit(self.Events.STATE_CHANGED, key, value)
    end
end

function StateManager:GetState(key)
    return self[key]
end

function StateManager:UpdateVolume(entity, volume)
    if not IsValid(entity) then return end
    
    self.entityVolumes[entity] = volume
    self:Emit(self.Events.VOLUME_CHANGED, entity, volume)
end

function StateManager:UpdateStation(entity, stationData)
    if not IsValid(entity) then return end
    
    self.currentlyPlayingStations[entity] = stationData
    self:Emit(self.Events.STATION_CHANGED, entity, stationData)
end

function StateManager:UpdateRadioSource(entity, source)
    if not IsValid(entity) then return end
    
    self.currentRadioSources[entity] = source
    self:UpdateStationCount()
end

function StateManager:UpdateStationCount()
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

function StateManager:SaveFavorites()
    local dataDir = "rradio"
    local favoriteCountriesFile = dataDir .. "/favorite_countries.json"
    local favoriteStationsFile = dataDir .. "/favorite_stations.json"

    -- Create backup of existing files
    local function createBackup(filename)
        if file.Exists(filename, "DATA") then
            file.Write(filename .. ".bak", file.Read(filename, "DATA"))
        end
    end

    -- Save favorite countries
    local favCountriesList = {}
    for country, _ in pairs(self.favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    
    local countriesJson = util.TableToJSON(favCountriesList, true)
    if countriesJson then
        createBackup(favoriteCountriesFile)
        file.Write(favoriteCountriesFile, countriesJson)
    else
        print("[Radio] Error converting favorite countries to JSON")
        return false
    end

    -- Save favorite stations
    local favStationsTable = {}
    for country, stations in pairs(self.favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and type(isFavorite) == "boolean" then
                    favStationsTable[country][stationName] = isFavorite
                end
            end
            -- Clean up empty country entries
            if next(favStationsTable[country]) == nil then
                favStationsTable[country] = nil
            end
        end
    end
    
    local stationsJson = util.TableToJSON(favStationsTable, true)
    if stationsJson then
        createBackup(favoriteStationsFile)
        file.Write(favoriteStationsFile, stationsJson)
    else
        print("[Radio] Error converting favorite stations to JSON")
        return false
    end

    self:Emit(self.Events.FAVORITES_CHANGED, {
        countries = self.favoriteCountries,
        stations = self.favoriteStations
    })
    return true
end

function StateManager:LoadFavorites()
    local dataDir = "rradio"
    local favoriteCountriesFile = dataDir .. "/favorite_countries.json"
    local favoriteStationsFile = dataDir .. "/favorite_stations.json"

    if not file.IsDir(dataDir, "DATA") then
        file.CreateDir(dataDir)
    end

    local function loadFromBackup(filename)
        if file.Exists(filename .. ".bak", "DATA") then
            print("[Radio] Attempting to load from backup file")
            return util.JSONToTable(file.Read(filename .. ".bak", "DATA"))
        end
        return nil
    end

    -- Load favorite countries
    if file.Exists(favoriteCountriesFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(favoriteCountriesFile, "DATA"))
        end)
        
        if not success or not data then
            data = loadFromBackup(favoriteCountriesFile)
            if not data then
                print("[Radio] Error loading favorite countries, resetting")
                self.favoriteCountries = {}
                return
            end
        end

        self.favoriteCountries = {}
        for _, country in ipairs(data) do
            if type(country) == "string" then
                self.favoriteCountries[country] = true
            end
        end
    end

    -- Load favorite stations
    if file.Exists(favoriteStationsFile, "DATA") then
        local success, data = pcall(function()
            return util.JSONToTable(file.Read(favoriteStationsFile, "DATA"))
        end)
        
        if not success or not data then
            data = loadFromBackup(favoriteStationsFile)
            if not data then
                print("[Radio] Error loading favorite stations, resetting")
                self.favoriteStations = {}
                return
            end
        end

        self.favoriteStations = {}
        for country, stations in pairs(data) do
            if type(country) == "string" and type(stations) == "table" then
                self.favoriteStations[country] = {}
                for stationName, isFavorite in pairs(stations) do
                    if type(stationName) == "string" and type(isFavorite) == "boolean" then
                        self.favoriteStations[country][stationName] = isFavorite
                    end
                end
                -- Clean up empty country entries
                if next(self.favoriteStations[country]) == nil then
                    self.favoriteStations[country] = nil
                end
            end
        end
    end

    self:Emit(self.Events.FAVORITES_LOADED, {
        countries = self.favoriteCountries,
        stations = self.favoriteStations
    })
end

function StateManager:CleanupEntity(entity)
    if not IsValid(entity) then return end
    
    if self.currentRadioSources[entity] then
        if IsValid(self.currentRadioSources[entity]) then
            self.currentRadioSources[entity]:Stop()
        end
        self.currentRadioSources[entity] = nil
        self:UpdateStationCount()
    end
    
    self.entityVolumes[entity] = nil
    self.currentlyPlayingStations[entity] = nil
    self.BoomboxStatuses[entity:EntIndex()] = nil
end

return StateManager 