if (rRadio.isClientLoadDisabled()) then
    function ENT:Draw()
        self:DrawModel()
    end
end

include("shared.lua")

local math_sin = math.sin
local math_min = math.min
local math_max = math.max
local math_Clamp = math.Clamp
local math_abs = math.abs
local math_floor = math.floor

local surface_SetFont = surface.SetFont
local surface_GetTextSize = surface.GetTextSize
local draw_RoundedBox = draw.RoundedBox
local draw_SimpleText = draw.SimpleText

local ColorAlpha = ColorAlpha
local Lerp = Lerp
local CurTime = CurTime
local LocalPlayer = LocalPlayer
local FrameTime = FrameTime

local FADE_START_SQR = 400 * 400
local FADE_END_SQR = 500 * 500
local FADE_RANGE_INV = 1 / (FADE_END_SQR - FADE_START_SQR)
local MODEL_CULL_DISTANCE_SQR = 7500 * 7500

local HUD = {
    DIMENSIONS = {
        HEIGHT = 28,
        PADDING = 11,
        ICON_SIZE = 14,
        HEIGHT_MULT = 1.5
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
        boombox = {
            BACKGROUND = Color(0, 0, 0, 255),
            ACCENT = Color(58, 114, 255),
            TEXT = Color(240, 240, 250),
            INACTIVE = Color(180, 180, 180)
        },
        golden_boombox = {
            BACKGROUND = Color(20, 20, 20, 255),
            ACCENT = Color(255, 215, 0),
            TEXT = Color(255, 248, 220),
            INACTIVE = Color(218, 165, 32)
        }
    }
}

local HUD_PADDING = HUD.DIMENSIONS.PADDING
local HUD_HEIGHT = HUD.DIMENSIONS.HEIGHT * HUD.DIMENSIONS.HEIGHT_MULT
local HUD_HALF_HEIGHT = HUD_HEIGHT * 0.5
local HUD_Y = -HUD_HALF_HEIGHT
local ICON_SIZE = HUD.DIMENSIONS.ICON_SIZE
local HUD_ICON_OFFSET = HUD_PADDING * 2 + ICON_SIZE + 8

local ACCENT_ALPHA_BRIGHT = 0.8
local ACCENT_ALPHA_DIM = 0.2

local ActiveBoomboxes = ActiveBoomboxes or {}
local DIST_CHECK_VECTOR = Vector(0, 0, 0)
local UPDATE_INTERVAL = 0.1
local CLEANUP_INTERVAL = 5

local entityVolumes = entityVolumes or {}
local entityColorSchemes = setmetatable({}, {__mode = "k"})

local HUD_DIMS = {
    MIN_WIDTH = 380,
    ICON_OFFSET = HUD_ICON_OFFSET,
    TEXT_MAX_OFFSET = HUD_PADDING * 4 + ICON_SIZE + 16
}

local cached_dots = {
    [0] = "",
    [1] = ".",
    [2] = "..",
    [3] = "...",
    [4] = "...."
}

local color_cache = setmetatable({}, {
    __index = function(t, k)
        if type(k) ~= "table" or type(k.r) ~= "number" or type(k.g) ~= "number" or type(k.b) ~= "number" then
            return {}
        end
        local colorKey = string.format("%d,%d,%d", math.floor(k.r), math.floor(k.g), math.floor(k.b))
        t[k] = setmetatable({}, {
            __index = function(t2, alpha)
                if type(alpha) ~= "number" then return nil end
                local ok, col = pcall(Color, k.r * alpha / 255, k.g * alpha / 255, k.b * alpha / 255, alpha)
                if not ok or type(col) ~= "table" then return nil end
                t2[alpha] = col
                return t2[alpha]
            end
        })
        return t[k]
    end
})

local TEXT_STATE_CACHE = {
    width = {},
    clipped = {},
    interact = {
        text = rRadio.config.Lang["Interact"] or "Press E to Interact",
        width = 0
    },
    paused = {
        text = rRadio.config.Lang["Paused"] or "PAUSED",
        width = 0
    },
    tuning = {
        text = rRadio.config.Lang["TuningIn"] or "Tuning in",
        width = 0
    }
}

local function GetCachedColor(baseColor, alpha)
    local bucket = color_cache[baseColor]
    if not bucket or type(alpha) ~= "number" then
        return Color(255,255,255, math_floor(alpha or 255))
    end
    local key = math_floor(alpha)
    local col = bucket[key]
    if not col then
        if type(baseColor) == "table" and type(baseColor.r) == "number" then
            local ok, c = pcall(Color, baseColor.r * alpha/255, baseColor.g * alpha/255, baseColor.b * alpha/255, alpha)
            if ok and type(c) == "table" then return c end
        end
        return Color(255,255,255, key)
    end
    return col
end

local function UpdateTextStateCache()
    TEXT_STATE_CACHE.width = {}
    TEXT_STATE_CACHE.clipped = {}

    surface_SetFont("rRadio_BoomboxHUD")
    TEXT_STATE_CACHE.interact.text = rRadio.config.Lang["Interact"] or "Press E to Interact"
    TEXT_STATE_CACHE.paused.text = rRadio.config.Lang["Paused"] or "PAUSED"
    TEXT_STATE_CACHE.tuning.text = rRadio.config.Lang["TuningIn"] or "Tuning in"
    
    TEXT_STATE_CACHE.interact.width = surface_GetTextSize(TEXT_STATE_CACHE.interact.text)
    TEXT_STATE_CACHE.paused.width = surface_GetTextSize(TEXT_STATE_CACHE.paused.text)
    TEXT_STATE_CACHE.tuning.width = surface_GetTextSize(TEXT_STATE_CACHE.tuning.text)
end

local function LerpColor(t, col1, col2)
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        Lerp(t, col1.a or 255, col2.a or 255)
    )
end

local function createAnimationState()
    return {
        progress = 0,
        textOffset = 0,
        lastStatus = "",
        statusTransition = 0,
        equalizerHeights = {0, 0, 0},
        tuningOffset = 0
    }
end

local function GetLocalPlayerEyePos()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:EyePos() or Vector(0, 0, 0)
end

local function CleanupInvalidBoomboxes()
    local removed = false
    for ent in pairs(ActiveBoomboxes) do
        if not IsValid(ent) then
            ActiveBoomboxes[ent] = nil
            removed = true
        end
    end
    if removed and not next(ActiveBoomboxes) then
        timer.Pause("BoomboxDistanceCheck")
    end
end

timer.Create("BoomboxCleanup", CLEANUP_INTERVAL, 0, CleanupInvalidBoomboxes)

local function BoomboxDistanceCheck()
    if not next(ActiveBoomboxes) then
        timer.Pause("BoomboxDistanceCheck")
        return
    end
    
    local playerPos = GetLocalPlayerEyePos()
    local fadeEndSqr = FADE_END_SQR
    local cullDistSqr = MODEL_CULL_DISTANCE_SQR
    
    for ent in pairs(ActiveBoomboxes) do
        DIST_CHECK_VECTOR:Set(playerPos)
        DIST_CHECK_VECTOR:Sub(ent:GetPos())
        local distSqr = DIST_CHECK_VECTOR:LengthSqr()
        
        ent.lastDistanceResult = distSqr
        local wasVisible = ent.hudVisible
        ent.hudVisible = distSqr < fadeEndSqr

        local shouldBeHidden = distSqr >= cullDistSqr
        if shouldBeHidden ~= ent.isHidden then
            ent:SetNoDraw(shouldBeHidden)
            ent.isHidden = shouldBeHidden
        end
    end
end

timer.Create("BoomboxDistanceCheck", UPDATE_INTERVAL, 0, BoomboxDistanceCheck)

local function UpdateNetworkedValues(self)
    local oldStatus = self.nwStatus
    self.nwStatus = self:GetNWString("Status", "stopped")
    self.nwStationName = self:GetNWString("StationName", "")
    self.nwOwner = self:GetNWEntity("Owner")

    if oldStatus ~= self.nwStatus and self.anim then
        self.anim.lastStatus = oldStatus
    end
end

function ENT:Initialize()
    local mins, maxs = self:GetModelBounds()
    maxs.z = maxs.z + 20
    self:SetRenderBounds(mins, maxs)
    
    self.anim = createAnimationState()
    self.lastVisibilityCheck = 0
    self.lastVisibilityResult = 0
    self.lastDistanceResult = 0
    self.hudVisible = true
    self.isHidden = false

    self.cachedWidth = HUD_DIMS.MIN_WIDTH
    self.halfWidth = HUD_DIMS.MIN_WIDTH * 0.5
    self.hudX = -self.halfWidth + HUD_PADDING

    UpdateNetworkedValues(self)
    
    ActiveBoomboxes[self] = true
    timer.UnPause("BoomboxDistanceCheck")
end

function ENT:OnRemove()
    ActiveBoomboxes[self] = nil
end

function ENT:Draw()
    self:DrawModel()
    
    if not GetConVar("rammel_rradio_boombox_hud"):GetBool() or not self.hudVisible then 
        return 
    end

    if not GetConVar("rammel_rradio_enabled"):GetBool() then return end
    
    local alpha = self:CalculateVisibility()
    if alpha <= 0 then return end

    UpdateNetworkedValues(self)
    
    local entIndex = self:EntIndex()
    local statusData = BoomboxStatuses[entIndex] or {}
    local status = statusData.stationStatus or self.nwStatus
    local stationName = statusData.stationName or self.nwStationName
    
    self:UpdateAnimations(status, FrameTime())
    
    local pos = self:GetPos()
    pos:Add(self:GetForward() * 4.6)
    pos:Add(self:GetUp() * 14.5)
    
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 180)
    
    cam.Start3D2D(pos, ang, 0.06)
    local success, err = pcall(function() self:DrawHUD(status, stationName, alpha) end)
    cam.End3D2D()
    
    if not success then ErrorNoHalt("Error in DrawHUD: " .. tostring(err) .. "\n") end
end

function ENT:GetDisplayText(status, stationName)
    if status == "stopped" then
        if LocalPlayer() == self.nwOwner or LocalPlayer():IsSuperAdmin() then
            return TEXT_STATE_CACHE.interact.text, TEXT_STATE_CACHE.interact.width
        end
        return TEXT_STATE_CACHE.paused.text, TEXT_STATE_CACHE.paused.width
    end
    
    if status == "tuning" then
        local dots = cached_dots[math_floor(CurTime() * 2) % 4]
        local fullText = TEXT_STATE_CACHE.tuning.text .. dots
        local cachedWidth = TEXT_STATE_CACHE.width[fullText]
        if not cachedWidth then
            surface_SetFont("rRadio_BoomboxHUD")
            cachedWidth = surface_GetTextSize(fullText)
            TEXT_STATE_CACHE.width[fullText] = cachedWidth
        end
        return fullText, cachedWidth
    end
    
    if stationName ~= "" then
        local cachedWidth = TEXT_STATE_CACHE.width[stationName]
        if not cachedWidth then
            surface_SetFont("rRadio_BoomboxHUD")
            cachedWidth = surface_GetTextSize(stationName)
            TEXT_STATE_CACHE.width[stationName] = cachedWidth
        end
        return stationName, cachedWidth
    end
    
    return "Radio", TEXT_STATE_CACHE.width["Radio"] or 50
end

function ENT:ProcessDisplayText(status, stationName)
    local text, textWidth = self:GetDisplayText(status, stationName)
    if self.cachedText == text then
        return self.cachedText
    end

    local finalText = text
    local finalWidth = textWidth
    local maxWidth = HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET

    if textWidth > maxWidth then
        local cachedClipped = TEXT_STATE_CACHE.clipped[text]
        if cachedClipped then
            finalText = cachedClipped
            finalWidth = TEXT_STATE_CACHE.width[cachedClipped]
        else
            local clippedText = text
            while finalWidth > maxWidth and #clippedText > 0 do
                clippedText = string.sub(clippedText, 1, #clippedText - 1)
                finalWidth = surface_GetTextSize(clippedText .. "...")
            end
            finalText = clippedText .. "..."
            TEXT_STATE_CACHE.clipped[text] = finalText
            TEXT_STATE_CACHE.width[finalText] = finalWidth
        end
    end

    self.cachedText = finalText

    local newWidth = math_max(finalWidth + HUD_PADDING * 3 + ICON_SIZE, HUD_DIMS.MIN_WIDTH)
    if newWidth ~= self.cachedWidth then
        self.cachedWidth = newWidth
        self.halfWidth = newWidth * 0.5
        self.hudX = -self.halfWidth + HUD_PADDING
    end
    
    return finalText
end

function ENT:DrawHUD(status, stationName, alpha)
    local bgAlpha = alpha * 1.0
    local colors
    if self:GetClass() == "golden_boombox" then
        colors = HUD.COLORS.golden_boombox
    else
        local theme = rRadio.config.UI or {}
        colors = {
            BACKGROUND = theme.BackgroundColor or Color(0,0,0,255),
            ACCENT = theme.AccentPrimary or theme.Highlight,
            TEXT = theme.TextColor or Color(255,255,255,255),
            INACTIVE = theme.Disabled or theme.TextColor or Color(180,180,180,255)
        }
    end
    local background, accent, textColor, inactive = colors.BACKGROUND, colors.ACCENT, colors.TEXT, colors.INACTIVE
    local text = self:ProcessDisplayText(status, stationName)
    
    do local c = GetCachedColor(background, bgAlpha) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
    surface.DrawRect(-self.halfWidth, HUD_Y, self.cachedWidth, HUD_HEIGHT)
    
    if status == "tuning" then
        local barWidth = self.cachedWidth * 0.3
        local tuningOffset = self.anim.tuningOffset * (self.cachedWidth - barWidth)
        
        do local c = GetCachedColor(accent, alpha * ACCENT_ALPHA_DIM) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 2, self.cachedWidth, 2)
        
        do local c = GetCachedColor(accent, alpha * ACCENT_ALPHA_BRIGHT) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
        surface.DrawRect(-self.halfWidth + tuningOffset, HUD_HALF_HEIGHT - 2, barWidth, 2)
    else
        do local c = GetCachedColor(accent, alpha * ACCENT_ALPHA_BRIGHT) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 2, self.cachedWidth, 2)
    end
    
    local indicatorColor = self:GetStatusColor(status)
    if status ~= "playing" then
        do local c = GetCachedColor(indicatorColor, alpha) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
        surface.DrawRect(self.hudX, HUD_Y + HUD_HEIGHT / 3, 4, HUD_HEIGHT / 3)
    end
    
    draw_SimpleText(
        text,
        "rRadio_BoomboxHUD",
        self.hudX + HUD_ICON_OFFSET,
        HUD_Y + HUD_HALF_HEIGHT,
        GetCachedColor(textColor, alpha * self.anim.statusTransition),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    
    if status == "playing" then
        self:DrawEqualizer(self.hudX, HUD_Y + HUD_HALF_HEIGHT, alpha, indicatorColor)
    end
end

function ENT:GetStatusColor(status)
    if self:GetClass() == "golden_boombox" then
        local colors = HUD.COLORS.golden_boombox
        if status == "playing" then
            return colors.ACCENT
        elseif status == "tuning" then
            local pulse = math_sin(CurTime() * 4) * 0.5 + 0.5
            return LerpColor(pulse, colors.INACTIVE, colors.ACCENT)
        else
            return colors.INACTIVE
        end
    end
    local theme = rRadio.config.UI or {}
    local accent = theme.AccentPrimary or theme.Highlight
    local inactive = theme.Disabled or theme.TextColor
    if status == "playing" then
        return accent
    elseif status == "tuning" then
        local pulse = math_sin(CurTime() * 4) * 0.5 + 0.5
        return LerpColor(pulse, inactive, accent)
    else
        return inactive
    end
end

function ENT:DrawEqualizer(x, y, alpha, color)
    if not self.anim then self.anim = createAnimationState() end
    if not self.anim.equalizerHeights then self.anim.equalizerHeights = {0, 0, 0} end
    
    local barWidth = 4
    local spacing = 4
    local maxHeight = HUD.DIMENSIONS.HEIGHT * 0.7
    local volume = entityVolumes[self] or 1

    self:UpdateEqualizerHeights(volume, FrameTime() * 2)
    
    local colorWithAlpha = GetCachedColor(color, alpha)
    local baseY = y
    
    for i = 1, HUD.EQUALIZER.BARS do
        local height = maxHeight * (self.anim.equalizerHeights[i] or 0)
        draw_RoundedBox(1, x + (i - 1) * (barWidth + spacing), baseY - height * 0.5, barWidth, height, colorWithAlpha)
    end
end

function ENT:UpdateEqualizerHeights(volume, dt)
    local curTime = CurTime()
    local timeOffsets = {0, 0.33, 0.66}
    
    for i = 1, HUD.EQUALIZER.BARS do
        local wave1 = math_sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i])
        local wave2 = math_sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i] * 1.5)
        local combinedWave = (wave1 + wave2) * 0.5
        
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + (math_abs(combinedWave) * HUD.EQUALIZER.MAX_HEIGHT * volume)
        self.anim.equalizerHeights[i] = Lerp(dt * 4, self.anim.equalizerHeights[i], targetHeight)
    end
end

function ENT:CalculateVisibility()
    if not self.hudVisible then return 0 end
    
    local curTime = CurTime()
    if curTime - self.lastVisibilityCheck < UPDATE_INTERVAL then
        return self.lastVisibilityResult
    end
    self.lastVisibilityCheck = curTime

    local playerPos = GetLocalPlayerEyePos()
    DIST_CHECK_VECTOR:Set(playerPos)
    DIST_CHECK_VECTOR:Sub(self:GetPos())
    local distSqr = DIST_CHECK_VECTOR:LengthSqr()
    
    self.lastDistanceResult = distSqr

    if distSqr >= FADE_END_SQR then
        self.lastVisibilityResult = 0
        return 0
    end
    if distSqr <= FADE_START_SQR then
        self.lastVisibilityResult = 255
        return 255
    end
    
    local alpha = math_Clamp(255 * (1 - (distSqr - FADE_START_SQR) * FADE_RANGE_INV), 0, 255)
    self.lastVisibilityResult = alpha
    return alpha
end

function ENT:UpdateAnimations(status, dt)
    if not self.anim then
        self.anim = createAnimationState()
    end
    local targetProgress = (status == "playing" or status == "tuning") and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    self.anim.statusTransition = math_min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)

    if status == "tuning" then
        self.anim.tuningOffset = (math_sin(CurTime() * 3) * 0.5 + 0.5)
    end
end

function ENT:GetColorScheme()
    local scheme = entityColorSchemes[self]
    if not scheme then
        scheme = HUD.COLORS[self:GetClass()] or HUD.COLORS.default
        entityColorSchemes[self] = scheme
    end
    return scheme
end

surface.CreateFont("rRadio_BoomboxHUD", {
    font = "Roboto",
    size = 24,
    weight = 500,
    antialias = true,
    extended = true
})

net.Receive("UpdateRadioVolume", function()
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = volume end
end)

hook.Add("Initialize", "InitTextStateCache", UpdateTextStateCache)
hook.Add("LanguageUpdated", "UpdateBoomboxTextCache", UpdateTextStateCache)

hook.Add("NetworkEntityCreated", "BoomboxNetworkedValues", function(ent)
    if not IsValid(ent) or not ent:GetClass():find("boombox") then return end

    timer.Simple(0, function()
        if IsValid(ent) then
            UpdateNetworkedValues(ent)
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    if IsValid(ent) then
        entityVolumes[ent:EntIndex()] = nil
    end
end)

hook.Add("ShutDown", "CleanupBoomboxTimers", function()
    timer.Remove("BoomboxDistanceCheck")
    timer.Remove("BoomboxCleanup")
end)