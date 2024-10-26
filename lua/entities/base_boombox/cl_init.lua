--[[
    Modern Boombox HUD
    Sleek, minimal, and professional design
]]--

include("shared.lua")
include("radio/shared/sh_config.lua")

-- Constants for modern design
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
        MIN_HEIGHT = 0.3,
        MAX_HEIGHT = 0.7,
        FREQUENCIES = {1.5, 2.0, 2.5}
    },
    COLORS = {
        BACKGROUND = Color(20, 20, 20, 255),
        ACCENT = Color(0, 255, 128),
        TEXT = Color(255, 255, 255),
        INACTIVE = Color(180, 180, 180)
    }
}

-- Create modern fonts
surface.CreateFont("BoomboxHUD", {
    font = "Roboto",
    size = 15,
    weight = 400,
    antialias = true,
    extended = true
})

surface.CreateFont("BoomboxHUDSmall", {
    font = "Roboto",
    size = 12,
    weight = 300,
    antialias = true,
    extended = true
})

-- Utility functions
local function LerpColor(t, col1, col2)
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        Lerp(t, col1.a or 255, col2.a or 255)
    )
end

-- Animation state
local function createAnimationState()
    return {
        progress = 0,
        textOffset = 0,
        lastStatus = "",
        statusTransition = 0,
        equalizerHeights = {0, 0, 0}
    }
end

BoomboxStatuses = BoomboxStatuses or {}

-- Cached values
local iconMaterial = Material("materials/hud/volume.png", "smooth")
local mathSin, mathClamp = math.sin, math.Clamp
local textColor = Color(255, 255, 255)
local errorColor = Color(255, 50, 50)
local entityVolumes = {}

-- Network message handler
net.Receive("UpdateRadioVolume", function()
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    if IsValid(entity) then
        entityVolumes[entity:EntIndex()] = volume
    end
end)

-- Cleanup handler
hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    if IsValid(ent) then
        entityVolumes[ent:EntIndex()] = nil
    end
end)

function ENT:Initialize()
    self:SetRenderBounds(self:OBBMins(), self:OBBMaxs())
    self.anim = createAnimationState()
end

function ENT:Draw()
    self:DrawModel()
    
    if not GetConVar("boombox_show_text"):GetBool() then return end

    -- Get entity status
    local entIndex = self:EntIndex()
    local statusData = BoomboxStatuses[entIndex] or {}
    local status = statusData.stationStatus or self:GetNWString("Status", "stopped")
    local stationName = statusData.stationName or self:GetNWString("StationName", "")
    
    -- Calculate visibility
    local alpha = self:CalculateVisibility()
    if alpha <= 0 then return end
    
    -- Update animations
    self:UpdateAnimations(status, FrameTime())
    
    local pos = self:GetPos() + self:GetForward() * 4.6 + self:GetUp() * 14.5
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 180)

    -- Use pcall to ensure cam.End3D2D is always called
    cam.Start3D2D(pos, ang, 0.1)
    local success, err = pcall(function()
        self:DrawModernHUD(status, stationName, alpha)
    end)
    cam.End3D2D()
    
    if not success then
        ErrorNoHalt("Error in DrawModernHUD: " .. tostring(err) .. "\n")
    end
end

function ENT:CalculateVisibility()
    local playerPos = LocalPlayer():EyePos()
    local entPos = self:GetPos()
    local distance = playerPos:Distance(entPos)
    
    -- Full opacity up to START distance (400 units)
    if distance <= HUD.FADE_DISTANCE.START then 
        return 255
    end
    
    -- Fade out between START and END distance
    if distance > HUD.FADE_DISTANCE.END then 
        return 0 
    end
    
    -- Calculate fade only between 400 and 500 units
    local alpha = math.Clamp(255 * (1 - (distance - HUD.FADE_DISTANCE.START) / 
            (HUD.FADE_DISTANCE.END - HUD.FADE_DISTANCE.START)), 0, 255)
    
    -- Only fade when player is behind the boombox
    local dotProduct = self:GetForward():Dot((playerPos - entPos):GetNormalized())
    if dotProduct < -0.5 then -- Only fade when player is more than 120 degrees behind
        return 0
    end
    
    return alpha
end

function ENT:UpdateAnimations(status, dt)
    -- Ensure animation state exists
    if not self.anim then
        self.anim = createAnimationState()
    end
    
    local targetProgress = (status == "playing" or status == "tuning") and 1 or 0
    
    -- Smooth progress animation
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    
    -- Status transition effect
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    self.anim.statusTransition = math.min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)
    
    -- Text slide animation
    self.anim.textOffset = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.textOffset, 
        math.sin(CurTime() * 2) * HUD.ANIMATION.BOUNCE)
end

function ENT:DrawModernHUD(status, stationName, alpha)
    local text = self:GetDisplayText(status, stationName)
    surface.SetFont("BoomboxHUD")
    local textWidth = surface.GetTextSize(text)
    
    local minWidth = 230
    local widthMultiplier = 1.0
    local width = math.max(textWidth + HUD.DIMENSIONS.PADDING * 3 + HUD.DIMENSIONS.ICON_SIZE, minWidth) * widthMultiplier
    local height = HUD.DIMENSIONS.HEIGHT
    
    -- Draw background
    self:DrawBackground(width, height, alpha)
    
    -- Draw accent line at the bottom
    local lineHeight = 2
    draw.RoundedBox(0,
        -width/2,
        height/2 - lineHeight,
        width,
        lineHeight,
        ColorAlpha(HUD.COLORS.ACCENT, alpha * 0.8)
    )
    
    -- Draw status indicator and text
    self:DrawContent(text, width, height, status, alpha)
end

function ENT:GetDisplayText(status, stationName)
    if status == "stopped" then
        -- Check if the current player is the owner
        if LocalPlayer() == self:GetNWEntity("Owner") or LocalPlayer():IsSuperAdmin() then
            return Config.Lang["Interact"] or "Press E to Interact"
        else
            return Config.Lang["Paused"] or "PAUSED"
        end
    elseif status == "tuning" then
        return "Tuning in..."
    else
        return stationName ~= "" and stationName or "Radio"
    end
end

function ENT:DrawBackground(width, height, alpha)
    -- Main background with solid colors
    local bgAlpha = alpha * 1.0
    draw.RoundedBox(4, -width/2, -height/2, width, height, Color(0, 0, 0, bgAlpha))
    draw.RoundedBox(4, -width/2, -height/2, width, height, ColorAlpha(HUD.COLORS.BACKGROUND, bgAlpha))
end

function ENT:DrawContent(text, width, height, status, alpha)
    local x = -width/2 + HUD.DIMENSIONS.PADDING
    local y = -height/2
    
    -- Get the status color first
    local indicatorColor = self:GetStatusColor(status)
    
    -- Status indicator and equalizer position (fixed at left)
    local indicatorX = x
    if status == "playing" then
        self:DrawEqualizer(indicatorX, y + height/2, alpha, indicatorColor)
    else
        draw.RoundedBox(2, indicatorX, y + height/3, 4, height/3, 
            ColorAlpha(indicatorColor, alpha))
    end
    
    -- Fixed text position (after equalizer/indicator)
    local textX = x + HUD.DIMENSIONS.PADDING * 2 + HUD.DIMENSIONS.ICON_SIZE + 8
    
    -- Clip text if too long
    local maxTextWidth = width - (HUD.DIMENSIONS.PADDING * 4 + HUD.DIMENSIONS.ICON_SIZE + 16)
    local clippedText = text
    surface.SetFont("BoomboxHUD")
    local textWidth = surface.GetTextSize(text)
    
    if textWidth > maxTextWidth then
        -- Keep shortening the text until it fits
        while textWidth > maxTextWidth and #clippedText > 0 do
            clippedText = string.sub(clippedText, 1, #clippedText - 1)
            textWidth = surface.GetTextSize(clippedText .. "...")
        end
        clippedText = clippedText .. "..."
    end
    
    -- Draw text
    draw.SimpleText(
        clippedText,
        "BoomboxHUD",
        textX,
        y + height/2,
        ColorAlpha(HUD.COLORS.TEXT, alpha * self.anim.statusTransition),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
end

function ENT:GetStatusColor(status)
    if status == "playing" then
        return HUD.COLORS.ACCENT
    elseif status == "tuning" then
        local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5
        return LerpColor(pulse, HUD.COLORS.INACTIVE, HUD.COLORS.ACCENT)
    else
        return HUD.COLORS.INACTIVE
    end
end

-- Modify the DrawEqualizer function to ensure animation state exists
function ENT:DrawEqualizer(x, y, alpha, color)
    -- Ensure animation state exists
    if not self.anim then
        self.anim = createAnimationState()
    end
    
    -- Ensure equalizer heights are initialized
    if not self.anim.equalizerHeights then
        self.anim.equalizerHeights = {0, 0, 0}
    end

    local barWidth = 4
    local spacing = 4
    local maxHeight = HUD.DIMENSIONS.HEIGHT * 0.7
    local volume = entityVolumes[self] or 1
    
    -- Update equalizer heights
    self:UpdateEqualizerHeights(volume, FrameTime())
    
    for i = 1, HUD.EQUALIZER.BARS do
        local height = maxHeight * (self.anim.equalizerHeights[i] or 0) -- Add fallback value
        draw.RoundedBox(1,
            x + (i-1) * (barWidth + spacing),
            y - height/2,
            barWidth,
            height,
            ColorAlpha(color, alpha)
        )
    end
end

-- Also modify UpdateEqualizerHeights to include safety checks
function ENT:UpdateEqualizerHeights(volume, dt)
    if not self.anim then
        self.anim = createAnimationState()
    end
    
    if not self.anim.equalizerHeights then
        self.anim.equalizerHeights = {0, 0, 0}
    end
    
    for i = 1, HUD.EQUALIZER.BARS do
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + 
            (math.abs(math.sin(CurTime() * HUD.EQUALIZER.FREQUENCIES[i])) * 
            HUD.EQUALIZER.MAX_HEIGHT * volume)
        
        self.anim.equalizerHeights[i] = Lerp(
            dt / HUD.ANIMATION.EQUALIZER_SMOOTHING,
            self.anim.equalizerHeights[i] or 0,
            targetHeight
        )
    end
end
