include("shared.lua")
include("radio/shared/sh_config.lua")
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

local function LerpColor(t, col1, col2) -- Utility functions
    return Color(Lerp(t, col1.r, col2.r), Lerp(t, col1.g, col2.g), Lerp(t, col1.b, col2.b), Lerp(t, col1.a or 255, col2.a or 255))
end

local function createAnimationState() -- Animation state
    return {
        progress = 0,
        textOffset = 0,
        lastStatus = "",
        statusTransition = 0,
        equalizerHeights = {0, 0, 0}
    }
end

BoomboxStatuses = BoomboxStatuses or {}
local entityVolumes = {} -- Cached values
net.Receive("UpdateRadioVolume", function()
    local entity = net.ReadEntity() -- Network message handler
    local volume = net.ReadFloat()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = volume end
end)

hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    if IsValid(ent) then -- Cleanup handler
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
    local entIndex = self:EntIndex() -- Get entity status
    local statusData = BoomboxStatuses[entIndex] or {}
    local status = statusData.stationStatus or self:GetNWString("Status", "stopped")
    local stationName = statusData.stationName or self:GetNWString("StationName", "")
    local alpha = self:CalculateVisibility() -- Calculate visibility
    if alpha <= 0 then return end
    self:UpdateAnimations(status, FrameTime()) -- Update animations
    local pos = self:GetPos() + self:GetForward() * 4.6 + self:GetUp() * 14.5
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 180)
    cam.Start3D2D(pos, ang, 0.06) -- Reduced scale from 0.1 to 0.06 for sharper text
    local success, err = pcall(function() self:DrawModernHUD(status, stationName, alpha) end)
    cam.End3D2D()
    if not success then ErrorNoHalt("Error in DrawModernHUD: " .. tostring(err) .. "\n") end
end

function ENT:CalculateVisibility()
    local playerPos = LocalPlayer():EyePos()
    local entPos = self:GetPos()
    local distance = playerPos:Distance(entPos)
    if distance <= HUD.FADE_DISTANCE.START then -- Full opacity up to START distance (400 units)
        return 255
    end

    if distance > HUD.FADE_DISTANCE.END then -- Fade out between START and END distance
        return 0
    end

    local alpha = math.Clamp(255 * (1 - (distance - HUD.FADE_DISTANCE.START) / (HUD.FADE_DISTANCE.END - HUD.FADE_DISTANCE.START)), 0, 255) -- Calculate fade only between 400 and 500 units
    local dotProduct = self:GetForward():Dot((playerPos - entPos):GetNormalized()) -- Only fade when player is behind the boombox
    if dotProduct < -0.5 then -- Only fade when player is more than 120 degrees behind
        return 0
    end
    return alpha
end

function ENT:UpdateAnimations(status, dt)
    if not self.anim then -- Ensure animation state exists
        self.anim = createAnimationState()
    end

    local targetProgress = (status == "playing" or status == "tuning") and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress) -- Smooth progress animation
    if status ~= self.anim.lastStatus then -- Status transition effect
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end

    self.anim.statusTransition = math.min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)
    self.anim.textOffset = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.textOffset, math.sin(CurTime() * 2) * HUD.ANIMATION.BOUNCE) -- Text slide animation
end

function ENT:DrawModernHUD(status, stationName, alpha)
    local text = self:GetDisplayText(status, stationName)
    surface.SetFont("BoomboxHUD")
    local textWidth = surface.GetTextSize(text)
    local minWidth = 380
    local widthMultiplier = 1.0
    local width = math.max(textWidth + HUD.DIMENSIONS.PADDING * 3 + HUD.DIMENSIONS.ICON_SIZE, minWidth) * widthMultiplier
    local height = HUD.DIMENSIONS.HEIGHT * 1.5
    self:DrawBackground(width, height, alpha) -- Draw background
    local lineHeight = 2 -- Draw accent line at the bottom
    draw.RoundedBox(0, -width / 2, height / 2 - lineHeight, width, lineHeight, ColorAlpha(HUD.COLORS.ACCENT, alpha * 0.8))
    self:DrawContent(text, width, height, status, alpha) -- Draw status indicator and text
end

function ENT:GetDisplayText(status, stationName)
    if status == "stopped" then
        if LocalPlayer() == self:GetNWEntity("Owner") or LocalPlayer():IsSuperAdmin() then
            return Config.Lang["Interact"] or "Press E to Interact"
        else
            return Config.Lang["Paused"] or "PAUSED"
        end
    elseif status == "tuning" then
        local baseText = Config.Lang["TuningIn"] or "Tuning in"
        local dots = string.rep(".", math.floor(CurTime() * 2) % 4)
        return baseText .. dots .. string.rep(" ", 3 - #dots) -- Keep consistent width with spaces
    else
        return stationName ~= "" and stationName or "Radio"
    end
end

function ENT:DrawBackground(width, height, alpha)
    local bgAlpha = alpha * 1.0 -- Main background with solid colors
    draw.RoundedBox(4, -width / 2, -height / 2, width, height, Color(0, 0, 0, bgAlpha))
    draw.RoundedBox(4, -width / 2, -height / 2, width, height, ColorAlpha(HUD.COLORS.BACKGROUND, bgAlpha))
end

function ENT:DrawContent(text, width, height, status, alpha)
    local x = -width / 2 + HUD.DIMENSIONS.PADDING
    local y = -height / 2
    local indicatorColor = self:GetStatusColor(status) -- Get the status color first
    local indicatorX = x -- Status indicator and equalizer position (fixed at left)
    if status == "playing" then
        self:DrawEqualizer(indicatorX, y + height / 2, alpha, indicatorColor)
    else
        draw.RoundedBox(2, indicatorX, y + height / 3, 4, height / 3, ColorAlpha(indicatorColor, alpha))
    end

    local textX = x + HUD.DIMENSIONS.PADDING * 2 + HUD.DIMENSIONS.ICON_SIZE + 8 -- Fixed text position (after equalizer/indicator)
    local maxTextWidth = width - (HUD.DIMENSIONS.PADDING * 4 + HUD.DIMENSIONS.ICON_SIZE + 16) -- Clip text if too long
    local clippedText = text
    surface.SetFont("BoomboxHUD")
    local textWidth = surface.GetTextSize(text)
    if textWidth > maxTextWidth then
        while textWidth > maxTextWidth and #clippedText > 0 do
            clippedText = string.sub(clippedText, 1, #clippedText - 1) -- Keep shortening the text until it fits
            textWidth = surface.GetTextSize(clippedText .. "...")
        end

        clippedText = clippedText .. "..."
    end

    draw.SimpleText(clippedText, "BoomboxHUD", textX, y + height / 2, ColorAlpha(HUD.COLORS.TEXT, alpha * self.anim.statusTransition), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Draw text
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

function ENT:DrawEqualizer(x, y, alpha, color)
    if not self.anim then -- Ensure animation state exists
        self.anim = createAnimationState()
    end

    if not self.anim.equalizerHeights then -- Ensure equalizer heights are initialized
        self.anim.equalizerHeights = {0, 0, 0}
    end

    local barWidth = 4
    local spacing = 4
    local maxHeight = HUD.DIMENSIONS.HEIGHT * 0.7
    local volume = entityVolumes[self] or 1
    self:UpdateEqualizerHeights(volume, FrameTime()) -- Update equalizer heights
    for i = 1, HUD.EQUALIZER.BARS do
        local height = maxHeight * (self.anim.equalizerHeights[i] or 0) -- Add fallback value
        draw.RoundedBox(1, x + (i - 1) * (barWidth + spacing), y - height / 2, barWidth, height, ColorAlpha(color, alpha))
    end
end

function ENT:UpdateEqualizerHeights(volume, dt)
    if not self.anim then self.anim = createAnimationState() end
    if not self.anim.equalizerHeights then self.anim.equalizerHeights = {0, 0, 0} end
    for i = 1, HUD.EQUALIZER.BARS do
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + (math.abs(math.sin(CurTime() * HUD.EQUALIZER.FREQUENCIES[i])) * HUD.EQUALIZER.MAX_HEIGHT * volume)
        self.anim.equalizerHeights[i] = Lerp(dt / HUD.ANIMATION.EQUALIZER_SMOOTHING, self.anim.equalizerHeights[i] or 0, targetHeight)
    end
end