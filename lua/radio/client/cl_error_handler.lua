local ErrorHandler = {
    MAX_RETRIES = 3,
    RETRY_DELAY = 2,
    CONNECTION_TIMEOUT = 10,
    retryAttempts = {},
    timeoutTimers = {},
    
    ErrorTypes = {
        TIMEOUT = "timeout",
        CONNECTION_FAILED = "connection_failed",
        INVALID_URL = "invalid_url",
        STREAM_ERROR = "stream_error",
        UNKNOWN = "unknown"
    },
    
    -- Maps error IDs to user-friendly messages
    ErrorMessages = {
        [1] = "Failed to connect to radio station",
        [2] = "Invalid radio station URL",
        [3] = "Stream not found or unavailable",
        [4] = "Connection timed out",
        [5] = "Network error",
        timeout = "Connection timed out",
        connection_failed = "Failed to connect to station",
        invalid_url = "Invalid station URL",
        stream_error = "Stream error occurred",
        unknown = "Unknown error occurred"
    }
}

-- Initialize retry tracking for an entity
function ErrorHandler:InitEntity(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    self.retryAttempts[entIndex] = self.retryAttempts[entIndex] or {
        count = 0,
        lastAttempt = 0,
        currentUrl = "",
        currentStation = ""
    }
end

-- Clear retry tracking for an entity
function ErrorHandler:ClearEntity(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    self.retryAttempts[entIndex] = nil
    if self.timeoutTimers[entIndex] then
        timer.Remove("RadioTimeout_" .. entIndex)
        self.timeoutTimers[entIndex] = nil
    end
end

-- Handle connection error and attempt retry if appropriate
function ErrorHandler:HandleError(entity, errorType, errorID, errorName, retryCallback)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Initialize tracking if needed
    self:InitEntity(entity)
    local attempts = self.retryAttempts[entIndex]
    
    -- Update entity status
    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        entity:SetNWString("Status", "error")
        BoomboxStatuses[entIndex] = {
            stationStatus = "error",
            stationName = attempts.currentStation,
            errorMessage = self.ErrorMessages[errorType] or self.ErrorMessages.unknown
        }
    end
    
    -- Show error message to user
    local errorMsg = self.ErrorMessages[errorType] or self.ErrorMessages[errorID] or self.ErrorMessages.unknown
    chat.AddText(
        Color(255, 50, 50), "[Radio Error] ",
        Color(255, 255, 255), errorMsg,
        Color(200, 200, 200), " (Station: " .. attempts.currentStation .. ")"
    )
    
    -- Handle retry logic
    if attempts.count < self.MAX_RETRIES then
        attempts.count = attempts.count + 1
        attempts.lastAttempt = CurTime()
        
        chat.AddText(
            Color(255, 165, 0), "[Radio] ",
            Color(255, 255, 255), string.format("Retrying connection... (Attempt %d/%d)", 
            attempts.count, self.MAX_RETRIES)
        )
        
        timer.Simple(self.RETRY_DELAY, function()
            if IsValid(entity) then
                retryCallback()
            end
        end)
    else
        -- Max retries reached
        chat.AddText(
            Color(255, 50, 50), "[Radio] ",
            Color(255, 255, 255), "Failed to connect after multiple attempts. Please try again later."
        )
        self:ClearEntity(entity)
    end
end

-- Start timeout monitoring for a connection attempt
function ErrorHandler:StartTimeout(entity, timeoutCallback)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    -- Clear any existing timeout timer
    if self.timeoutTimers[entIndex] then
        timer.Remove("RadioTimeout_" .. entIndex)
    end
    
    -- Set new timeout timer
    self.timeoutTimers[entIndex] = true
    timer.Create("RadioTimeout_" .. entIndex, self.CONNECTION_TIMEOUT, 1, function()
        if IsValid(entity) then
            self:HandleError(entity, self.ErrorTypes.TIMEOUT, nil, nil, timeoutCallback)
        end
    end)
end

-- Stop timeout monitoring
function ErrorHandler:StopTimeout(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    
    if self.timeoutTimers[entIndex] then
        timer.Remove("RadioTimeout_" .. entIndex)
        self.timeoutTimers[entIndex] = nil
    end
end

-- Track connection attempt
function ErrorHandler:TrackAttempt(entity, stationName, url)
    if not IsValid(entity) then return end
    self:InitEntity(entity)
    
    local entIndex = entity:EntIndex()
    self.retryAttempts[entIndex].currentStation = stationName
    self.retryAttempts[entIndex].currentUrl = url
end

return ErrorHandler
