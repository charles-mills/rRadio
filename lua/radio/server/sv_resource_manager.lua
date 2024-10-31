--[[
    Radio Addon Resource Manager
    Author: Charles Mills
    Description: Manages server-side resources for the Radio Addon, including stream
                 limits, connection management, and resource cleanup.
    Date: October 31, 2024
]]--

local ResourceManager = {
    -- Configuration
    Config = {
        MAX_CONCURRENT_STREAMS = 60,
        STREAM_TIMEOUT = 30,
        RETRY_ATTEMPTS = 3,
        RETRY_DELAY = 1,
        CLEANUP_INTERVAL = 60,
        MAX_STREAMS_PER_PLAYER = 5,
        CONNECTION_TIMEOUT = 10,
        RATE_LIMIT_WINDOW = 5,
        MAX_REQUESTS_PER_WINDOW = 10
    },

    -- State
    activeStreams = {},
    pendingStreams = {},
    playerStreams = {},
    streamHistory = {},
    rateLimit = {},
    
    -- Statistics
    stats = {
        totalStreams = 0,
        failedStreams = 0,
        timeouts = 0,
        retries = 0,
        lastCleanup = 0
    }
}

--[[
    Function: CanPlayerRequest
    Checks if a player can make a new stream request based on rate limiting
    @param ply (Player): The player making the request
    @return (boolean, string): Success and reason if failed
]]
function ResourceManager:CanPlayerRequest(ply)
    if not IsValid(ply) then return false, "Invalid player" end
    
    -- Initialize rate limit data
    self.rateLimit[ply] = self.rateLimit[ply] or {
        requests = 0,
        lastReset = CurTime()
    }
    
    -- Reset counter if window expired
    if CurTime() - self.rateLimit[ply].lastReset > self.Config.RATE_LIMIT_WINDOW then
        self.rateLimit[ply].requests = 0
        self.rateLimit[ply].lastReset = CurTime()
    end
    
    -- Check rate limit
    if self.rateLimit[ply].requests >= self.Config.MAX_REQUESTS_PER_WINDOW then
        return false, "Rate limit exceeded"
    end
    
    -- Check player's active streams
    local playerActiveStreams = 0
    for _, stream in pairs(self.activeStreams) do
        if stream.player == ply then
            playerActiveStreams = playerActiveStreams + 1
        end
    end
    
    if playerActiveStreams >= self.Config.MAX_STREAMS_PER_PLAYER then
        return false, "Maximum concurrent streams reached"
    end
    
    return true
end

--[[
    Function: RequestStream
    Handles a new stream request with proper queuing and validation
    @param ply (Player): The requesting player
    @param entity (Entity): The entity to play on
    @param url (string): The stream URL
    @param callback (function): Callback for stream result
    @return (boolean): Success status
]]
function ResourceManager:RequestStream(ply, entity, url, callback)
    if not IsValid(ply) then 
        print("[rRadio] Invalid player in RequestStream")
        return false, "Invalid player" 
    end

    if not IsValid(entity) then 
        print("[rRadio] Invalid entity in RequestStream")
        return false, "Invalid entity" 
    end

    -- Store entity index for validation
    local entIndex = entity:EntIndex()
    print("[rRadio Debug] Processing stream request for entity:", entIndex)
    
    local canRequest, reason = self:CanPlayerRequest(ply)
    if not canRequest then
        if callback then callback(false, reason) end
        return false, reason
    end
    
    -- Update rate limit
    self.rateLimit[ply] = self.rateLimit[ply] or {
        requests = 0,
        lastReset = CurTime()
    }
    self.rateLimit[ply].requests = self.rateLimit[ply].requests + 1
    
    -- Execute callback immediately since this is just validation
    -- The actual streaming is handled by the client
    if callback then
        callback(true)
    end
    
    return true, "Stream request accepted"
end

--[[
    Function: StartStream
    Initiates a stream with proper error handling and timeout management
    @param streamRequest (table): The stream request data
    @return (boolean): Success status
]]
function ResourceManager:StartStream(streamRequest)
    if not IsValid(streamRequest.entity) or not IsValid(streamRequest.player) then
        return false
    end
    
    -- Set up timeout
    local timeoutTimer = "RadioStream_Timeout_" .. streamRequest.id
    timer.Create(timeoutTimer, self.Config.CONNECTION_TIMEOUT, 1, function()
        self:HandleStreamTimeout(streamRequest)
    end)
    
    -- Add to active streams
    self.activeStreams[streamRequest.id] = {
        request = streamRequest,
        startTime = CurTime(),
        timeoutTimer = timeoutTimer
    }
    
    -- Update player streams
    self.playerStreams[streamRequest.player] = self.playerStreams[streamRequest.player] or {}
    table.insert(self.playerStreams[streamRequest.player], streamRequest.id)
    
    -- Update statistics
    self.stats.totalStreams = self.stats.totalStreams + 1
    
    return true
end

--[[
    Function: HandleStreamTimeout
    Handles stream timeout with retry logic
    @param streamRequest (table): The stream request data
]]
function ResourceManager:HandleStreamTimeout(streamRequest)
    local activeStream = self.activeStreams[streamRequest.id]
    if not activeStream then return end
    
    streamRequest.attempts = streamRequest.attempts + 1
    self.stats.timeouts = self.stats.timeouts + 1
    
    if streamRequest.attempts < self.Config.RETRY_ATTEMPTS then
        -- Retry
        self.stats.retries = self.stats.retries + 1
        timer.Simple(self.Config.RETRY_DELAY, function()
            self:StartStream(streamRequest)
        end)
    else
        -- Failed permanently
        self:CleanupStream(streamRequest.id, "Timeout after retries")
        self.stats.failedStreams = self.stats.failedStreams + 1
    end
end

--[[
    Function: CleanupStream
    Cleans up a stream and its associated resources
    @param streamId (string): The stream ID to cleanup
    @param reason (string): The reason for cleanup
]]
function ResourceManager:CleanupStream(streamId, reason)
    local stream = self.activeStreams[streamId]
    if not stream then return end
    
    -- Clear timeout timer
    if timer.Exists(stream.timeoutTimer) then
        timer.Remove(stream.timeoutTimer)
    end
    
    -- Remove from active streams
    self.activeStreams[streamId] = nil
    
    -- Remove from player streams
    if IsValid(stream.request.player) then
        local playerStreamList = self.playerStreams[stream.request.player]
        if playerStreamList then
            table.RemoveByValue(playerStreamList, streamId)
        end
    end
    
    -- Add to history
    table.insert(self.streamHistory, {
        id = streamId,
        player = stream.request.player,
        entity = stream.request.entity,
        startTime = stream.startTime,
        endTime = CurTime(),
        reason = reason
    })
    
    -- Process pending streams
    self:ProcessPendingStreams()
end

--[[
    Function: ProcessPendingStreams
    Processes any pending streams if resources are available
]]
function ResourceManager:ProcessPendingStreams()
    while #self.pendingStreams > 0 and table.Count(self.activeStreams) < self.Config.MAX_CONCURRENT_STREAMS do
        local nextStream = table.remove(self.pendingStreams, 1)
        if IsValid(nextStream.player) and IsValid(nextStream.entity) then
            self:StartStream(nextStream)
        end
    end
end

--[[
    Function: PerformCleanup
    Performs periodic cleanup of resources and invalid streams
]]
function ResourceManager:PerformCleanup()
    local currentTime = CurTime()
    
    -- Cleanup invalid streams
    for id, stream in pairs(self.activeStreams) do
        if not IsValid(stream.request.player) or not IsValid(stream.request.entity) then
            self:CleanupStream(id, "Invalid references")
        elseif currentTime - stream.startTime > self.Config.STREAM_TIMEOUT then
            self:CleanupStream(id, "Stream timeout")
        end
    end
    
    -- Cleanup rate limit data
    for ply, data in pairs(self.rateLimit) do
        if not IsValid(ply) or currentTime - data.lastReset > self.Config.RATE_LIMIT_WINDOW * 2 then
            self.rateLimit[ply] = nil
        end
    end
    
    -- Trim history
    while #self.streamHistory > 1000 do
        table.remove(self.streamHistory, 1)
    end
    
    self.stats.lastCleanup = currentTime
end

-- Set up periodic cleanup
timer.Create("RadioResourceCleanup", ResourceManager.Config.CLEANUP_INTERVAL, 0, function()
    ResourceManager:PerformCleanup()
end)

return ResourceManager 