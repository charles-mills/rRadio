include("shared.lua")
local Config = include("radio/shared/sh_config.lua")
local utils = include("radio/shared/sh_utils.lua")
local Misc = include("radio/client/cl_misc.lua")
local Themes = include("radio/client/cl_theme_manager.lua")

CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox.")

timer.Simple(0, function()
    if not Misc or not Misc.Language then
        error("[rRadio] Failed to initialize Language module")
        return
    end
end)

local HUD = {
    FADE_DISTANCE = {
        START = 400,
        END = 500
    },
    DIMENSIONS = {
        HEIGHT = 28,
        PADDING = 11,
        ICON_SIZE = 14
    },
    ANIMATION = {
        SPEED = 4,
        BOUNCE = 0.05,
        EQUALIZER_SMOOTHING = 0.15
    },
    EQUALIZER = {
        BARS = 3,
        MIN_HEIGHT = 0.2,
        MAX_HEIGHT = 0.75,
        FREQUENCIES = {1.8, 2.2, 2.6}
    },
    COLORS = {
        BACKGROUND = Color(20, 20, 20, 255),
        ACCENT = Color(0, 255, 128),
        TEXT = Color(255, 255, 255),
        INACTIVE = Color(180, 180, 180)
    },
    TRUNCATE_LENGTH = 30
}

local GOLDEN_HUD = {
    BACKGROUND = Color(40, 35, 25, 255),
    ACCENT = Color(255, 215, 0),
    TEXT = Color(255, 235, 180),
    INACTIVE = Color(180, 160, 120)
}

local function UpdateHUDColors()
    local themeName = GetConVar("radio_theme"):GetString()
    local currentTheme = Themes.themes[themeName]
    
    if not currentTheme then 
        print("[Boombox] Warning: Theme not found:", themeName)
        currentTheme = Themes.themes[Themes.factory:getDefaultTheme()]
    end
    
    if not currentTheme then
        print("[Boombox] Error: Could not load default theme")
        return
    end
    
    print("[Boombox] Updating HUD colors with theme:", themeName)
    
    -- Store default colors
    HUD.DEFAULT_COLORS = {
        BACKGROUND = currentTheme.BackgroundColor,
        ACCENT = currentTheme.AccentColor,
        TEXT = currentTheme.TextColor,
        INACTIVE = currentTheme.ScrollbarColor
    }
    
    HUD.COLORS = table.Copy(HUD.DEFAULT_COLORS)
end

hook.Add("ThemeChanged", "UpdateBoomboxHUDColors", function(themeName)
    print("[Boombox] Theme changed to:", themeName)
    timer.Simple(0, UpdateHUDColors)
end)

timer.Simple(0, UpdateHUDColors)

surface.CreateFont("BoomboxHUD", {
    font = "Roboto",
    size = 24,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("BoomboxHUDSmall", {
    font = "Roboto",
    size = 18,
    weight = 400,
    antialias = true,
    extended = true
})

local function LerpColor(t, col1, col2)
    -- Pre-calculate alpha to avoid unnecessary Lerp call if both alphas are 255
    local alpha = (col1.a ~= 255 or col2.a ~= 255) and 
        Lerp(t, col1.a or 255, col2.a or 255) or 255
    
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        alpha
    )
end

-- Cache frequently used values
local sin, cos, min, max = math.sin, math.cos, math.min, math.max
local ColorAlpha = ColorAlpha
local SimpleText = draw.SimpleText
local RoundedBox = draw.RoundedBox

-- Reusable color objects to avoid creating new ones
local tempColor = Color(0, 0, 0)
local function GetColorAlpha(color, alpha)
    tempColor.r = color.r
    tempColor.g = color.g
    tempColor.b = color.b
    tempColor.a = alpha
    return tempColor
end

BoomboxStatuses = BoomboxStatuses or {}
local entityVolumes = {} -- Cached values
net.Receive("rRadio_UpdateRadioVolume", function()
    local entity = net.ReadEntity() -- Network message handler
    local volume = net.ReadFloat()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = volume end
end)

hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    if IsValid(ent) then -- Cleanup handler
        entityVolumes[ent:EntIndex()] = nil
    end
end)

local function createAnimationState()
    return {
        progress = 0,
        statusTransition = 0,
        textOffset = 0,
        lastStatus = "",
        equalizerHeights = {0, 0, 0},
        lastHeights = {0, 0, 0},  -- Initialize lastHeights here
        lastVolume = 0
    }
end

-- Add near the top with other local variables
local VISIBILITY_CACHE_TIME = 0.1  -- Cache visibility for 100ms
local DISTANT_UPDATE_INTERVAL = 0.25  -- Update distant boomboxes every 250ms
local EQUALIZER_UPDATE_INTERVAL = 0.008  -- ~120fps update rate for ultra-smooth animation
local ANIMATION_CLEANUP_INTERVAL = 30  -- Cleanup unused states every 30 seconds
local MAX_CACHE_ENTRIES = 100  -- Prevent cache from growing too large

-- Cache structures
local visibilityCache = {}
local textWidthCache = {}
local sinePatternCache = {}
local lastFontSet = ""

-- Pre-calculate sine patterns
local function initSinePatterns()
    local steps = 120
    for i = 1, HUD.EQUALIZER.BARS do
        sinePatternCache[i] = {}
        local freq = HUD.EQUALIZER.FREQUENCIES[i]
        for step = 0, steps do
            local time = step * (math.pi * 2 / steps)
            -- Smoother pattern with gentle secondary wave
            local primary = math.abs(math.sin(time * freq))
            local secondary = math.sin(time * freq * 0.5) * 0.15
            sinePatternCache[i][step] = primary + secondary
        end
    end
end
initSinePatterns()

-- Optimized color handling
local cachedColors = {}
local function getCachedColor(r, g, b, a)
    local key = string.format("%d_%d_%d_%d", r, g, b, a or 255)
    if not cachedColors[key] then
        cachedColors[key] = Color(r, g, b, a or 255)
    end
    return cachedColors[key]
end

-- Optimized visibility calculation
function ENT:CalculateVisibility()
    local currentTime = RealTime()
    local entIndex = self:EntIndex()
    
    -- Check cache
    if visibilityCache[entIndex] and 
       currentTime - visibilityCache[entIndex].time < VISIBILITY_CACHE_TIME then
        return visibilityCache[entIndex].alpha
    end
    
    -- Early distance check using squared distance
    local playerPos = LocalPlayer():EyePos()
    local entPos = self:GetPos()
    local distSqr = playerPos:DistToSqr(entPos)
    
    -- Quick reject if too far
    if distSqr > (HUD.FADE_DISTANCE.END * HUD.FADE_DISTANCE.END) then
        visibilityCache[entIndex] = {alpha = 0, time = currentTime}
        return 0
    end
    
    -- Full opacity check
    if distSqr <= (HUD.FADE_DISTANCE.START * HUD.FADE_DISTANCE.START) then
        visibilityCache[entIndex] = {alpha = 255, time = currentTime}
        return 255
    end
    
    -- Calculate dot product for facing check
    local dotProduct = self:GetForward():Dot((playerPos - entPos):GetNormalized())
    if dotProduct < -0.5 then
        visibilityCache[entIndex] = {alpha = 0, time = currentTime}
        return 0
    end
    
    -- Calculate fade
    local distance = math.sqrt(distSqr) -- Only one sqrt calculation when needed
    local alpha = math.Clamp(255 * (1 - (distance - HUD.FADE_DISTANCE.START) / 
                 (HUD.FADE_DISTANCE.END - HUD.FADE_DISTANCE.START)), 0, 255)
    
    -- Cache result
    visibilityCache[entIndex] = {alpha = alpha, time = currentTime}
    return alpha
end

-- Optimized animation updates
function ENT:UpdateAnimations(status, dt)
    if not self or not IsValid(self) then return end
    
    -- Ensure animation state exists
    if not self.anim then
        self.anim = createAnimationState()
    end
    
    -- Rest of the existing UpdateAnimations code...
    local targetProgress = (status == "playing" or status == "tuning") and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    
    self.anim.statusTransition = math.min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)
    
    -- Optimize bounce calculation using pre-calculated patterns
    local timeIndex = math.floor((CurTime() * 2) % 100)
    self.anim.textOffset = sinePatternCache[1][timeIndex] * HUD.ANIMATION.BOUNCE
end

-- Optimized equalizer update
function ENT:UpdateEqualizerHeights(volume, dt)
    -- Ensure animation state exists with all fields
    if not self.anim then
        self.anim = createAnimationState()
    end
    
    -- Moderate update rate
    local currentTime = RealTime()
    if self.lastEqUpdate and (currentTime - self.lastEqUpdate) < 0.016 then
        return
    end
    self.lastEqUpdate = currentTime
    
    -- Moderate pattern cycling
    local timeBase = CurTime() * 20  -- Slower base movement
    
    for i = 1, HUD.EQUALIZER.BARS do
        -- Get current pattern value with slight offset per bar
        local timeIndex = math.floor(timeBase * (1 + i * 0.1) % 120)
        local patternValue = sinePatternCache[i][timeIndex]
        
        -- Small amount of randomness
        local jitter = math.random() * 0.1
        
        -- Calculate target with volume influence
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + 
            ((patternValue + jitter) * (HUD.EQUALIZER.MAX_HEIGHT - HUD.EQUALIZER.MIN_HEIGHT) * volume)
        
        -- Quick but not instant response
        self.anim.equalizerHeights[i] = Lerp(0.3, self.anim.equalizerHeights[i] or 0, targetHeight)
        
        -- Gentle bounce on changes
        if math.abs((self.anim.lastHeights[i] or 0) - targetHeight) > 0.25 then
            self.anim.equalizerHeights[i] = targetHeight * 1.1  -- Smaller overshoot
        end
        
        self.anim.lastHeights[i] = self.anim.equalizerHeights[i]
    end
end

-- Optimized text handling
function ENT:DrawContent(text, width, height, status, alpha)
    -- Cache font setting
    if lastFontSet ~= "BoomboxHUD" then
        surface.SetFont("BoomboxHUD")
        lastFontSet = "BoomboxHUD"
    end
    
    -- Cache text width calculations
    if not textWidthCache[text] then
        textWidthCache[text] = surface.GetTextSize(text)
        -- Prevent cache from growing too large
        if table.Count(textWidthCache) > MAX_CACHE_ENTRIES then
            textWidthCache = {}
        end
    end
end

-- Cleanup hooks
hook.Add("EntityRemoved", "CleanupBoomboxCaches", function(ent)
    if not IsValid(ent) then return end
    local entIndex = ent:EntIndex()
    visibilityCache[entIndex] = nil
    if ent.anim then ent.anim = nil end
end)

-- Periodic cache cleanup
timer.Create("BoomboxCacheCleanup", ANIMATION_CLEANUP_INTERVAL, 0, function()
    -- Cleanup visibility cache
    local currentTime = RealTime()
    for entIndex, data in pairs(visibilityCache) do
        if currentTime - data.time > VISIBILITY_CACHE_TIME * 2 then
            visibilityCache[entIndex] = nil
        end
    end
    
    -- Cleanup text width cache if too large
    if table.Count(textWidthCache) > MAX_CACHE_ENTRIES then
        textWidthCache = {}
    end
end)

function ENT:Initialize()
    self:SetRenderBounds(self:OBBMins(), self:OBBMaxs())
    
    -- Always create animation state
    self.anim = createAnimationState()
    
    -- Initialize status if not already set
    local entIndex = self:EntIndex()
    if not BoomboxStatuses[entIndex] then
        BoomboxStatuses[entIndex] = {
            stationStatus = self:GetNWString("Status", "stopped"),
            stationName = self:GetNWString("StationName", ""),
            isPlaying = self:GetNWBool("IsPlaying", false)
        }
    end
    
    -- Ensure UpdateAnimations method exists
    if not self.UpdateAnimations then
        self.UpdateAnimations = ENT.UpdateAnimations
    end
end

function ENT:Think()
    -- Only update if within hearing distance
    if self:GetPos():DistToSqr(LocalPlayer():GetPos()) <= (HUD.FADE_DISTANCE.END * HUD.FADE_DISTANCE.END) then
        if not self.anim then
            self.anim = createAnimationState()
        end
        
        local status = self:GetNWString("Status", "stopped")
        self:UpdateAnimations(status, FrameTime())
    end
end

function ENT:Draw()
    self:DrawModel()
    if not GetConVar("boombox_show_text"):GetBool() then return end
    
    -- Check if this is a golden boombox and set appropriate colors
    if self:GetClass() == "golden_boombox" then
        HUD.COLORS = GOLDEN_HUD
    else
        HUD.COLORS = HUD.DEFAULT_COLORS
    end
    
    local entIndex = self:EntIndex()
    local statusData = BoomboxStatuses[entIndex] or {}
    local status = statusData.stationStatus or self:GetNWString("Status", "stopped")
    local stationName = statusData.stationName or self:GetNWString("StationName", "")

    -- Safely handle text truncation
    if type(stationName) == "string" and #stationName > HUD.TRUNCATE_LENGTH then
        stationName = utils.truncateStationName(stationName, HUD.TRUNCATE_LENGTH)
    end

    local alpha = self:CalculateVisibility()
    if alpha <= 0 then return end
    
    local pos = self:GetPos() + self:GetForward() * 4.6 + self:GetUp() * 14.5
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 180)
    
    cam.Start3D2D(pos, ang, 0.06)
    local success, err = pcall(function() self:DrawHUD(status, stationName, alpha) end)
    cam.End3D2D()
    if not success then ErrorNoHalt("Error in DrawHUD: " .. tostring(err) .. "\n") end
end

function ENT:DrawHUD(status, stationName, alpha)
    local text = self:GetDisplayText(status, stationName)
    
    -- Use cached font
    if lastFontSet ~= "BoomboxHUD" then
        surface.SetFont("BoomboxHUD")
        lastFontSet = "BoomboxHUD"
    end
    
    -- Use cached text width
    local textWidth = textWidthCache[text] or surface.GetTextSize(text)
    if not textWidthCache[text] then
        textWidthCache[text] = textWidth
        if table.Count(textWidthCache) > MAX_CACHE_ENTRIES then
            textWidthCache = {}
            textWidthCache[text] = textWidth
        end
    end
    
    -- Cache calculated values
    local padding = HUD.DIMENSIONS.PADDING
    local iconSize = HUD.DIMENSIONS.ICON_SIZE
    local minWidth = 380
    local width = max(textWidth + padding * 3 + iconSize, minWidth)
    local height = HUD.DIMENSIONS.HEIGHT * 1.5
    
    self:DrawBackground(width, height, alpha)
    
    -- Draw accent line at bottom using cached colors
    local lineColor = getCachedColor(
        HUD.COLORS.ACCENT.r,
        HUD.COLORS.ACCENT.g,
        HUD.COLORS.ACCENT.b,
        alpha * 0.8
    )
    draw.RoundedBox(0, -width / 2, height / 2 - 2, width, 2, lineColor)
    
    self:DrawContent(text, width, height, status, alpha)
end

function ENT:GetDisplayText(status, stationName)
    -- Add safety check for Config.Lang
    local Lang = Config and Config.Lang or {}

    if status == "stopped" then
        if LocalPlayer() == self:GetNWEntity("Owner") or LocalPlayer():IsSuperAdmin() then
            return Lang["Interact"] or "Press E to Interact"
        else
            return Lang["Paused"] or "PAUSED"
        end
    elseif status == "tuning" then
        local baseText = Lang["TuningIn"] or "Tuning in"
        local dots = string.rep(".", math.floor(CurTime() * 2) % 4)
        return baseText .. dots .. string.rep(" ", 3 - #dots)
    else
        -- Use utils.truncateStationName for consistency
        return stationName ~= "" and utils.truncateStationName(stationName, HUD.TRUNCATE_LENGTH) or "Radio"
    end
end

function ENT:DrawBackground(width, height, alpha)
    local bgAlpha = alpha * 1.0
    
    if self:GetClass() == "golden_boombox" then
        -- Draw outer glow using cached colors
        local glowColor = getCachedColor(
            GOLDEN_HUD.ACCENT.r,
            GOLDEN_HUD.ACCENT.g,
            GOLDEN_HUD.ACCENT.b,
            bgAlpha * 0.3
        )
        draw.RoundedBox(0, -width/2 - 2, -height/2 - 2, width + 4, height + 4, glowColor)
    end
    
    -- Main background using cached colors
    local bgColor = getCachedColor(0, 0, 0, bgAlpha)
    draw.RoundedBox(0, -width/2, -height/2, width, height, bgColor)
    
    local mainBgColor = getCachedColor(
        HUD.COLORS.BACKGROUND.r,
        HUD.COLORS.BACKGROUND.g,
        HUD.COLORS.BACKGROUND.b,
        bgAlpha
    )
    draw.RoundedBox(0, -width/2, -height/2, width, height, mainBgColor)
end

function ENT:DrawContent(text, width, height, status, alpha)
    local padding = HUD.DIMENSIONS.PADDING
    local iconSize = HUD.DIMENSIONS.ICON_SIZE
    local x = -width / 2 + padding
    local y = -height / 2
    
    -- Cache status color
    local indicatorColor = self:GetStatusColor(status)
    local indicatorX = x

    if status == "playing" then
        self:DrawEqualizer(indicatorX, y + height / 2, alpha, indicatorColor)
    else
        RoundedBox(2, indicatorX, y + height / 3, 4, height / 3, 
            GetColorAlpha(indicatorColor, alpha))
    end

    local textX = x + padding * 2 + iconSize + 8
    local maxTextWidth = width - (padding * 4 + iconSize + 16)

    -- Optimize text clipping
    local clippedText = text
    surface.SetFont("BoomboxHUD")
    local textWidth = surface.GetTextSize(text)
    
    if textWidth > maxTextWidth then
        local ratio = maxTextWidth / textWidth
        local targetLength = math.floor(#text * ratio) - 3 -- Account for "..."
        clippedText = string.sub(text, 1, targetLength) .. "..."
    end

    SimpleText(
        clippedText, 
        "BoomboxHUD", 
        textX, 
        y + height / 2, 
        GetColorAlpha(HUD.COLORS.TEXT, alpha * self.anim.statusTransition),
        TEXT_ALIGN_LEFT, 
        TEXT_ALIGN_CENTER
    )
end

function ENT:GetStatusColor(status)
    if status == "playing" then
        return HUD.COLORS.ACCENT
    elseif status == "tuning" then
        -- Use pre-calculated sine patterns for pulse
        local timeIndex = math.floor((CurTime() * 4) % 100)
        local pulse = sinePatternCache[1][timeIndex]
        return LerpColor(pulse, HUD.COLORS.INACTIVE, HUD.COLORS.ACCENT)
    else
        return HUD.COLORS.INACTIVE
    end
end

function ENT:DrawEqualizer(x, y, alpha, color)
    if not self or not IsValid(self) then return end
    
    -- Ensure animation state exists
    if not self.anim then
        self.anim = createAnimationState()
    end

    if not self.anim.equalizerHeights then
        self.anim.equalizerHeights = {0, 0, 0}
    end

    local barWidth = 4
    local spacing = 4
    local maxHeight = HUD.DIMENSIONS.HEIGHT * 0.7
    local volume = entityVolumes[self] or 1
    self:UpdateEqualizerHeights(volume, FrameTime())
    
    -- Special golden equalizer
    if self:GetClass() == "golden_boombox" then
        -- Draw glow behind bars
        for i = 1, HUD.EQUALIZER.BARS do
            local height = maxHeight * (self.anim.equalizerHeights[i] or 0)
            local glowColor = ColorAlpha(GOLDEN_HUD.ACCENT, alpha * 0.3)
            draw.RoundedBox(2, x + (i-1)*(barWidth + spacing) - 1, y - height/2 - 1, 
                          barWidth + 2, height + 2, glowColor)
        end
    end
    
    -- Draw main bars
    for i = 1, HUD.EQUALIZER.BARS do
        local height = maxHeight * (self.anim.equalizerHeights[i] or 0)
        draw.RoundedBox(1, x + (i-1)*(barWidth + spacing), y - height/2, 
                       barWidth, height, ColorAlpha(color, alpha))
    end
end
