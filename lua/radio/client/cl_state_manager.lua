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
    -- Existing favorites saving logic moved here
    local favCountriesList = {}
    for country, _ in pairs(self.favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    
    -- Save to file logic...
end

function StateManager:LoadFavorites()
    -- Existing favorites loading logic moved here
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