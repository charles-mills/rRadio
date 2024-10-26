local UIPerformance = {
    -- Cache commonly used values
    cachedScales = {},
    cachedFonts = {},
    cachedMaterials = {},
    lastFrameTime = 0,
    frameUpdateThreshold = 0.016, -- ~60fps
    
    -- Panel update tracking
    panelUpdateQueue = {},
    deferredUpdates = {},
    
    -- Performance monitoring
    stats = {
        totalRedraws = 0,
        skippedRedraws = 0,
        cachedDraws = 0
    }
}

-- Cache scale calculations
function UIPerformance:GetScale(value)
    if not self.cachedScales[value] then
        self.cachedScales[value] = value * (ScrW() / 2560)
    end
    return self.cachedScales[value]
end

-- Cache material loading
function UIPerformance:GetMaterial(path)
    if not self.cachedMaterials[path] then
        self.cachedMaterials[path] = Material(path, "smooth")
    end
    return self.cachedMaterials[path]
end

-- Optimize panel updates
function UIPerformance:QueuePanelUpdate(panel, updateFn)
    if not IsValid(panel) then return end
    
    local currentTime = RealTime()
    if not self.panelUpdateQueue[panel] then
        self.panelUpdateQueue[panel] = {
            lastUpdate = 0,
            fn = updateFn
        }
    end
    
    -- Check if enough time has passed since last update
    if currentTime - self.panelUpdateQueue[panel].lastUpdate >= self.frameUpdateThreshold then
        updateFn()
        self.panelUpdateQueue[panel].lastUpdate = currentTime
    else
        -- Queue update for next frame
        self.deferredUpdates[panel] = updateFn
    end
end

-- Process deferred updates
function UIPerformance:ProcessDeferredUpdates()
    local currentTime = RealTime()
    
    for panel, updateFn in pairs(self.deferredUpdates) do
        -- Check if panel and its queue entry are valid
        if IsValid(panel) and self.panelUpdateQueue[panel] and self.panelUpdateQueue[panel].lastUpdate then
            -- Only update if enough time has passed
            if currentTime - self.panelUpdateQueue[panel].lastUpdate >= (self.frameUpdateThreshold or 0.016) then
                updateFn()
                self.panelUpdateQueue[panel].lastUpdate = currentTime
                self.deferredUpdates[panel] = nil
            end
        else
            -- Clean up invalid entries
            self.deferredUpdates[panel] = nil
            if self.panelUpdateQueue[panel] then
                self.panelUpdateQueue[panel] = nil
            end
        end
    end
end

-- Clear panel from update queue when removed
function UIPerformance:RemovePanel(panel)
    self.panelUpdateQueue[panel] = nil
    self.deferredUpdates[panel] = nil
end

-- Optimize paint operations
function UIPerformance:OptimizePaintFunction(panel, paintFn)
    local lastPaint = 0
    local cachedResult = nil
    local threshold = self.frameUpdateThreshold -- Store the threshold locally
    
    return function(self, w, h)
        local currentTime = RealTime()
        
        -- Check if we need to repaint with proper nil checks
        if not threshold then threshold = 0.016 end -- Fallback if threshold is nil
        
        if not lastPaint or not cachedResult or (currentTime - lastPaint) >= threshold then
            cachedResult = paintFn(self, w, h)
            lastPaint = currentTime
            UIPerformance.stats.totalRedraws = UIPerformance.stats.totalRedraws + 1
        else
            UIPerformance.stats.skippedRedraws = UIPerformance.stats.skippedRedraws + 1
        end
        
        return cachedResult
    end
end

-- Add cleanup hook
hook.Add("Think", "ProcessDeferredUIUpdates", function()
    UIPerformance:ProcessDeferredUpdates()
end)

return UIPerformance
