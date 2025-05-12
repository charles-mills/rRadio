include("shared.lua")

if (rRadio.isClientLoadDisabled() and rRadio.config.ClientHardDisable) then
    function ENT:Draw()
        self:DrawModel()
    end

    return
end

local cvHud     = GetConVar("rammel_rradio_boombox_hud")
local cvEnabled = GetConVar("rammel_rradio_enabled")

local FADE_START_SQR = 400 * 400
local FADE_END_SQR = 500 * 500
local FADE_RANGE_INV = 1 / (FADE_END_SQR - FADE_START_SQR)
local MODEL_CULL_DISTANCE_SQR = 7500 * 7500

local CurTime = CurTime
local LocalPlayer = LocalPlayer
local FrameTime = FrameTime
local draw_RoundedBox = draw.RoundedBox
local draw_SimpleText = draw.SimpleText

local STATIC_TEXTS = nil
local STATIC_TEXT_WIDTHS = nil

local HUD_OFFSET_FORWARD = 4.6
local HUD_OFFSET_UP      = 14.5
local HUD_SCALE          = 0.06

local ACCENT_ALPHA_BRIGHT = 0.8
local ACCENT_ALPHA_DIM = 0.2

local ActiveBoomboxes = ActiveBoomboxes or {}
local DIST_CHECK_VECTOR = Vector(0, 0, 0)
local CLEANUP_INTERVAL = 5

local MAX_DYNAMIC_TEXT_ENTRIES = 100
local dynamicTextOrder = {}
local DYNAMIC_TEXT_WIDTHS = {}
local CLIPPED_TEXT_CACHE = {}

local entityVolumes = entityVolumes or {}
local entityColorSchemes = setmetatable({}, {__mode = "k"})

local cached_dots = {
    [0] = "",
    [1] = ".",
    [2] = "..",
    [3] = "...",
    [4] = "...."
}

local DEFAULT_UI = {
    BackgroundColor = Color(0,0,0,255),
    AccentPrimary   = Color(58,114,255),
    Highlight       = Color(58,114,255),
    TextColor       = Color(255,255,255,255),
    Disabled        = Color(180,180,180,255)
}

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

HUD.COLORS.default = HUD.COLORS.boombox

local HUD_DIMS = {
    MIN_WIDTH = 380,
    ICON_OFFSET = HUD_ICON_OFFSET,
    TEXT_MAX_OFFSET = HUD_PADDING * 4 + ICON_SIZE + 16
}

local function LerpColor(t, c1, c2)
    return Color(
        math.floor(c1.r + (c2.r - c1.r) * t),
        math.floor(c1.g + (c2.g - c1.g) * t),
        math.floor(c1.b + (c2.b - c1.b) * t),
        math.floor(c1.a + (c2.a - c1.a) * t)
    )
end

local function AddDynamicTextEntry(text, width)
    DYNAMIC_TEXT_WIDTHS[text] = width
    table.insert(dynamicTextOrder, text)
    if #dynamicTextOrder > MAX_DYNAMIC_TEXT_ENTRIES then
        local oldest = table.remove(dynamicTextOrder, 1)
        DYNAMIC_TEXT_WIDTHS[oldest] = nil
        CLIPPED_TEXT_CACHE[oldest] = nil
    end
end

local function initializeStaticTexts()
    STATIC_TEXTS = {
        interact = rRadio.config.Lang["Interact"] or "Press E to Interact",
        paused   = rRadio.config.Lang["Paused"] or "Paused",
        tuning   = rRadio.config.Lang["TuningIn"] or "Tuning in",
    }
end

local function initializeStaticTextWidths()
    surface.SetFont("rRadio.Roboto24")
    STATIC_TEXT_WIDTHS = {
        [STATIC_TEXTS.interact] = surface.GetTextSize(STATIC_TEXTS.interact),
        [STATIC_TEXTS.paused]   = surface.GetTextSize(STATIC_TEXTS.paused),
        [STATIC_TEXTS.tuning]   = surface.GetTextSize(STATIC_TEXTS.tuning),
    }
end

initializeStaticTexts()
initializeStaticTextWidths()

local color_cache = {}
local function GetCachedColor(baseColor, alpha)
    if type(baseColor) ~= "table" or type(baseColor.r) ~= "number" then
        return Color(255,255,255, math.floor(alpha or 255))
    end
    local r = math.floor(baseColor.r)
    local g = math.floor(baseColor.g)
    local b = math.floor(baseColor.b)
    local a = tonumber(alpha) or 255
    local baseKey = r..","..g..","..b
    local bucket = color_cache[baseKey]
    if not bucket then
        bucket = {}
        color_cache[baseKey] = bucket
    end
    local aKey = math.floor(a)
    local col = bucket[aKey]
    if not col then
        col = Color(r * aKey / 255, g * aKey / 255, b * aKey / 255, aKey)
        bucket[aKey] = col
    end
    return col
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
end

timer.Create("BoomboxCleanup", CLEANUP_INTERVAL, 0, CleanupInvalidBoomboxes)
local function UpdateNetworkedValues(self)
    local oldStatus = self.nwStatus
    self.nwStatus = self:GetNWInt("Status", rRadio.status.STOPPED)
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
end

function ENT:OnRemove()
    ActiveBoomboxes[self] = nil
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:GetDisplayText(status, stationName)
    if status == rRadio.status.STOPPED then
        if rRadio.utils.canInteractWithBoombox(LocalPlayer(), self) then
            return STATIC_TEXTS.interact, STATIC_TEXT_WIDTHS[STATIC_TEXTS.interact]
        end
        
        return STATIC_TEXTS.paused, STATIC_TEXT_WIDTHS[STATIC_TEXTS.paused]
    elseif status == rRadio.status.TUNING then
        local base = STATIC_TEXTS.tuning
        local dots = cached_dots[math.floor(CurTime() * 2) % #cached_dots]
        local text = base .. dots
        local w = DYNAMIC_TEXT_WIDTHS[text]
        if not w then
            surface.SetFont("rRadio.Roboto24")
            w = surface.GetTextSize(text)
            AddDynamicTextEntry(text, w)
        end
        return text, w
    elseif stationName ~= "" then
        local text = stationName
        local w = DYNAMIC_TEXT_WIDTHS[text]
        if not w then
            surface.SetFont("rRadio.Roboto24")
            w = surface.GetTextSize(text)
            AddDynamicTextEntry(text, w)
        end
        return text, w
    end
    local text = "Radio"
    local w = STATIC_TEXT_WIDTHS[text] or DYNAMIC_TEXT_WIDTHS[text] or 50
    return text, w
end

function ENT:ProcessDisplayText(status, stationName)
    local text, textWidth = self:GetDisplayText(status, stationName)
    if self.cachedText == text then return self.cachedText end
    local finalText = text
    local finalWidth = textWidth
    local maxWidth = HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET
    if finalWidth > maxWidth then
        local cachedTxt = CLIPPED_TEXT_CACHE[text]
        if cachedTxt then
            finalText = cachedTxt
            finalWidth = DYNAMIC_TEXT_WIDTHS[cachedTxt] or surface.GetTextSize(cachedTxt)
        else
            local clipped = text
            surface.SetFont("rRadio.Roboto24")
            while finalWidth > maxWidth and #clipped > 0 do
                clipped = string.sub(clipped, 1, #clipped - 1)
                finalWidth = surface.GetTextSize(clipped .. "...")
            end
            finalText = clipped .. "..."
            CLIPPED_TEXT_CACHE[text] = finalText
            AddDynamicTextEntry(finalText, finalWidth)
        end
    end
    self.cachedText = finalText
    local newWidth = math.max(finalWidth + HUD_PADDING * 3 + ICON_SIZE, HUD_DIMS.MIN_WIDTH)
    if newWidth ~= self.cachedWidth then
        self.cachedWidth = newWidth
        self.halfWidth = newWidth * 0.5
        self.hudX = -self.halfWidth + HUD_PADDING
    end
    return finalText
end

local function DrawAccentBar(self, status, accent, alpha)
    if status == rRadio.status.TUNING then
        local barWidth = self.cachedWidth * 0.3
        local tuningOffset = self.anim.tuningOffset * (self.cachedWidth - barWidth)
        local c1 = GetCachedColor(accent, alpha * ACCENT_ALPHA_DIM)
        surface.SetDrawColor(c1.r, c1.g, c1.b, c1.a)
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 2, self.cachedWidth, 2)
        local c2 = GetCachedColor(accent, alpha * ACCENT_ALPHA_BRIGHT)
        surface.SetDrawColor(c2.r, c2.g, c2.b, c2.a)
        surface.DrawRect(-self.halfWidth + tuningOffset, HUD_HALF_HEIGHT - 2, barWidth, 2)
    else
        local c = GetCachedColor(accent, alpha * ACCENT_ALPHA_BRIGHT)
        surface.SetDrawColor(c.r, c.g, c.b, c.a)
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 2, self.cachedWidth, 2)
    end
end

local function DrawIndicatorBar(self, status, alpha)
    if status ~= rRadio.status.PLAYING then
        local color = self:GetStatusColor(status)
        local c = GetCachedColor(color, alpha)
        surface.SetDrawColor(c.r, c.g, c.b, c.a)
        surface.DrawRect(self.hudX, HUD_Y + HUD_HEIGHT / 3, 4, HUD_HEIGHT / 3)
    end
end

local function DrawTextAndEqualizer(self, status, stationName, alpha, textColor)
    local text = self:ProcessDisplayText(status, stationName)
    draw_SimpleText(
        text,
        "rRadio.Roboto24",
        self.hudX + HUD_ICON_OFFSET,
        HUD_Y + HUD_HALF_HEIGHT,
        GetCachedColor(textColor, alpha * self.anim.statusTransition),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    if status == rRadio.status.PLAYING then
        self:DrawEqualizer(self.hudX, HUD_Y + HUD_HALF_HEIGHT, alpha, self:GetStatusColor(status))
    end
end

function ENT:DrawHUD(status, stationName, alpha)
    local bgAlpha = alpha * 1.0
    local colors
    if self:GetClass() == "rammel_boombox_gold" then
        colors = HUD.COLORS.golden_boombox
    else
        local theme = rRadio.config.UI or DEFAULT_UI
        colors = {
            BACKGROUND = theme.BackgroundColor,
            ACCENT     = theme.AccentPrimary or theme.Highlight,
            TEXT       = theme.TextColor,
            INACTIVE   = theme.Disabled or theme.TextColor
        }
    end
    local background, accent, textColor, inactive = colors.BACKGROUND, colors.ACCENT, colors.TEXT, colors.INACTIVE
    
    do local c = GetCachedColor(background, bgAlpha) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
    surface.DrawRect(-self.halfWidth, HUD_Y, self.cachedWidth, HUD_HEIGHT)
    
    DrawAccentBar(self, status, accent, alpha)
    DrawIndicatorBar(self, status, alpha)
    DrawTextAndEqualizer(self, status, stationName, alpha, textColor)
end

function ENT:GetStatusColor(status)
    if self:GetClass() == "rammel_boombox_gold" then
        local colors = HUD.COLORS.golden_boombox
        if status == rRadio.status.PLAYING then
            return colors.ACCENT
        elseif status == rRadio.status.TUNING then
            local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5
            return LerpColor(pulse, colors.INACTIVE, colors.ACCENT)
        else
            return colors.INACTIVE
        end
    end
    local theme = rRadio.config.UI or {}
    local accent = theme.AccentPrimary or theme.Highlight
    local inactive = theme.Disabled or theme.TextColor
    if status == rRadio.status.PLAYING then
        return accent
    elseif status == rRadio.status.TUNING then
        local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5
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
    local volume = entityVolumes[self:EntIndex()] or 1

    if rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[self] then
        volume = 0
    end

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
        local wave1 = math.sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i])
        local wave2 = math.sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i] * 1.5)
        local combinedWave = (wave1 + wave2) * 0.5
        
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + (math.abs(combinedWave) * HUD.EQUALIZER.MAX_HEIGHT * volume)
        self.anim.equalizerHeights[i] = Lerp(dt * 4, self.anim.equalizerHeights[i], targetHeight)
    end
end

function ENT:UpdateAnimations(status, dt)
    if not self.anim then
        self.anim = createAnimationState()
    end
    local targetProgress = (status == rRadio.status.PLAYING or status == rRadio.status.TUNING) and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    self.anim.statusTransition = math.min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)

    if status == rRadio.status.TUNING then
        self.anim.tuningOffset = (math.sin(CurTime() * 3) * 0.5 + 0.5)
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

net.Receive("rRadio.SetRadioVolume", function()
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = volume end
end)

hook.Add("LanguageUpdated", "rRadio.ClearBoomboxTextCache", function()
    initializeStaticTexts()
    initializeStaticTextWidths()
end)

hook.Add("NetworkEntityCreated", "BoomboxNetworkedValues", function(ent)
    if not IsValid(ent) or not rRadio.utils.IsBoombox(ent) then return end

    timer.Simple(0, function()
        if IsValid(ent) then
            UpdateNetworkedValues(ent)
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    entityVolumes[ent:EntIndex()] = nil
    ActiveBoomboxes[ent] = nil
end)

hook.Add("ShutDown", "CleanupBoomboxTimers", function()
    timer.Remove("BoomboxCleanup")
end)

hook.Add("PostDrawOpaqueRenderables", "rRadio_DrawAllBoomboxHUDs", function()
    local plyEye = LocalPlayer():EyePos()
    local dt = FrameTime()

    for ent in pairs(ActiveBoomboxes) do
        local distSqr = plyEye:DistToSqr(ent:GetPos())
        if distSqr <= MODEL_CULL_DISTANCE_SQR and cvHud:GetBool() and cvEnabled:GetBool() then
            local alpha = math.Clamp(255 * (1 - (distSqr - FADE_START_SQR) * FADE_RANGE_INV), 0, 255)
            if alpha > 0 then
                local idx = ent:EntIndex()
                local statusData = rRadio.cl.BoomboxStatuses[idx] or {}
                local status = statusData.stationStatus or ent.nwStatus
                local stationName = statusData.stationName or ent.nwStationName

                ent:UpdateAnimations(status, dt)

                local pos = ent:GetPos()
                pos:Add(ent:GetForward() * HUD_OFFSET_FORWARD)
                pos:Add(ent:GetUp() * HUD_OFFSET_UP)

                local ang = ent:GetAngles()
                ang:RotateAroundAxis(ang:Up(), -90)
                ang:RotateAroundAxis(ang:Forward(), 90)
                ang:RotateAroundAxis(ang:Right(), 180)

                cam.Start3D2D(pos, ang, HUD_SCALE)
                    ent:DrawHUD(status, stationName, alpha)
                cam.End3D2D()
            end
        end
    end
end)