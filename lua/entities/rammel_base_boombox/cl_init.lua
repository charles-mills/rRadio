include("shared.lua")

if rRadio.isClientLoadDisabled() and rRadio.config.ClientHardDisable then
    function ENT:Draw() self:DrawModel() end
    return
end

local cvHud = GetConVar("rammel_rradio_boombox_hud")
local cvEnabled = GetConVar("rammel_rradio_enabled")

local FADE_START_SQR = 350 * 350
local FADE_END_SQR = 450 * 450
local FADE_RANGE_INV = 1 / (FADE_END_SQR - FADE_START_SQR)
local MODEL_CULL_DISTANCE_SQR = 7000 * 7000

local CurTime = CurTime
local LocalPlayer = LocalPlayer
local FrameTime = FrameTime
local draw_RoundedBox = draw.RoundedBox
local draw_SimpleText = draw.SimpleText

local STATIC_TEXTS = {}
local STATIC_TEXT_WIDTHS = {}
local ActiveBoomboxes = ActiveBoomboxes or {}
local DIST_CHECK_VECTOR = Vector(0, 0, 0)
local CLEANUP_INTERVAL = 4
local MAX_DYNAMIC_TEXT_ENTRIES = 80
local dynamicTextOrder = {}
local DYNAMIC_TEXT_WIDTHS = {}
local CLIPPED_TEXT_CACHE = {}
local entityVolumes = entityVolumes or {}
local entityColorSchemes = setmetatable({}, {__mode = "k"})

local cached_dots = {"", ".", "..", "...", "...."}

local DEFAULT_UI = {
    BackgroundColor = Color(0, 0, 0, 255),
    AccentPrimary = Color(50, 100, 255),
    Highlight = Color(50, 100, 255),
    TextColor = Color(255, 255, 255, 255),
    Disabled = Color(170, 170, 170, 255)
}

local HUD = {
    DIMENSIONS = {
        HEIGHT = 24,
        PADDING = 10,
        ICON_SIZE = 12,
        HEIGHT_MULT = 1.4
    },
    ANIMATION = {
        SPEED = 5,
        BOUNCE = 0.04,
        EQUALIZER_SMOOTHING = 0.12
    },
    EQUALIZER = {
        BARS = 3,
        MIN_HEIGHT = 0.25,
        MAX_HEIGHT = 0.65,
        FREQUENCIES = {1.4, 1.9, 2.4}
    },
    COLORS = {
        boombox = {
            BACKGROUND = Color(10, 10, 10, 245),
            ACCENT = Color(50, 100, 255),
            TEXT = Color(245, 245, 255),
            INACTIVE = Color(170, 170, 170)
        },
        golden_boombox = {
            BACKGROUND = Color(15, 15, 15, 245),
            ACCENT = Color(255, 200, 0),
            TEXT = Color(255, 245, 210),
            INACTIVE = Color(200, 150, 30)
        }
    }
}

local HUD_PADDING = HUD.DIMENSIONS.PADDING
local HUD_HEIGHT = HUD.DIMENSIONS.HEIGHT * HUD.DIMENSIONS.HEIGHT_MULT
local HUD_HALF_HEIGHT = HUD_HEIGHT * 0.5
local HUD_Y = -HUD_HALF_HEIGHT
local ICON_SIZE = HUD.DIMENSIONS.ICON_SIZE
local HUD_ICON_OFFSET = HUD_PADDING * 2 + ICON_SIZE + 6
HUD.COLORS.default = HUD.COLORS.boombox

local HUD_DIMS = {
    MIN_WIDTH = 360,
    ICON_OFFSET = HUD_ICON_OFFSET,
    TEXT_MAX_OFFSET = HUD_PADDING * 3 + ICON_SIZE + 14
}

local function LerpColor(t, c1, c2)
    return Color(
        c1.r + (c2.r - c1.r) * t,
        c1.g + (c2.g - c1.b) * t,
        c1.b + (c2.b - c1.b) * t,
        c1.a + (c2.a - c1.a) * t
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
        paused = rRadio.config.Lang["Paused"] or "Paused",
        tuning = rRadio.config.Lang["TuningIn"] or "Tuning in"
    }
end

local function initializeStaticTextWidths()
    surface.SetFont("rRadio.Roboto22")
    STATIC_TEXT_WIDTHS = {
        [STATIC_TEXTS.interact] = surface.GetTextSize(STATIC_TEXTS.interact),
        [STATIC_TEXTS.paused] = surface.GetTextSize(STATIC_TEXTS.paused),
        [STATIC_TEXTS.tuning] = surface.GetTextSize(STATIC_TEXTS.tuning)
    }
end

initializeStaticTexts()
initializeStaticTextWidths()

local color_cache = {}
local function GetCachedColor(baseColor, alpha)
    if type(baseColor) ~= "table" or not baseColor.r then
        return Color(255, 255, 255, math.floor(alpha or 255))
    end
    local r, g, b, a = math.floor(baseColor.r), math.floor(baseColor.g), math.floor(baseColor.b), math.floor(alpha or 255)
    local baseKey = r .. "," .. g .. "," .. b
    local bucket = color_cache[baseKey] or {}
    color_cache[baseKey] = bucket
    local col = bucket[a] or Color(r * a / 255, g * a / 255, b * a / 255, a)
    bucket[a] = col
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

local function CleanupInvalidBoomboxes()
    for ent in pairs(ActiveBoomboxes) do
        if not IsValid(ent) then ActiveBoomboxes[ent] = nil end
    end
end

timer.Create("BoomboxCleanup", CLEANUP_INTERVAL, 0, CleanupInvalidBoomboxes)

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
    maxs.z = maxs.z + 18
    self:SetRenderBounds(mins, maxs)
    self.anim = createAnimationState()
    self.lastVisibilityCheck = 0
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
    if status == "stopped" then
        return rRadio.utils.canInteractWithBoombox(LocalPlayer(), self) and STATIC_TEXTS.interact or STATIC_TEXTS.paused,
               STATIC_TEXT_WIDTHS[rRadio.utils.canInteractWithBoombox(LocalPlayer(), self) and STATIC_TEXTS.interact or STATIC_TEXTS.paused]
    elseif status == "tuning" then
        local text = STATIC_TEXTS.tuning .. cached_dots[math.floor(CurTime() * 2) % #cached_dots]
        local w = DYNAMIC_TEXT_WIDTHS[text] or (surface.SetFont("rRadio.Roboto22") surface.GetTextSize(text) AddDynamicTextEntry(text, w) w)
        return text, w
    elseif stationName ~= "" then
        local text = stationName
        local w = DYNAMIC_TEXT_WIDTHS[text] or (surface.SetFont("rRadio.Roboto22") surface.GetTextSize(text) AddDynamicTextEntry(text, w) w)
        return text, w
    end
    local text = "Radio"
    local w = STATIC_TEXT_WIDTHS[text] or DYNAMIC_TEXT_WIDTHS[text] or 50
    return text, w
end

function ENT:ProcessDisplayText(status, stationName)
    local text, textWidth = self:GetDisplayText(status, stationName)
    if self.cachedText == text then return self.cachedText end
    local finalText, finalWidth = text, textWidth
    local maxWidth = HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET
    if finalWidth > maxWidth then
        local cachedTxt = CLIPPED_TEXT_CACHE[text]
        if cachedTxt then
            finalText, finalWidth = cachedTxt, DYNAMIC_TEXT_WIDTHS[cachedTxt] or surface.GetTextSize(cachedTxt)
        else
            local clipped = text
            surface.SetFont("rRadio.Roboto22")
            while finalWidth > maxWidth and #clipped > 0 do
                clipped = clipped:sub(1, -2)
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
    if status == "tuning" then
        local barWidth = self.cachedWidth * 0.25
        local tuningOffset = self.anim.tuningOffset * (self.cachedWidth - barWidth)
        local c1 = GetCachedColor(accent, alpha * 0.7)
        surface.SetDrawColor(c1)
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 1.5, self.cachedWidth, 1.5)
        local c2 = GetCachedColor(accent, alpha)
        surface.SetDrawColor(c2)
        surface.DrawRect(-self.halfWidth + tuningOffset, HUD_HALF_HEIGHT - 1.5, barWidth, 1.5)
    else
        local c = GetCachedColor(accent, alpha)
        surface.SetDrawColor(c)
        surface.DrawRect(-self.halfWidth, HUD_HALF_HEIGHT - 1.5, self.cachedWidth, 1.5)
    end
end

local function DrawIndicatorBar(self, status, alpha)
    if status ~= "playing" then
        local color = self:GetStatusColor(status)
        local c = GetCachedColor(color, alpha)
        surface.SetDrawColor(c)
        surface.DrawRect(self.hudX, HUD_Y + HUD_HEIGHT / 3, 3, HUD_HEIGHT / 3)
    end
end

local function DrawTextAndEqualizer(self, status, stationName, alpha, textColor)
    local text = self:ProcessDisplayText(status, stationName)
    draw_SimpleText(text, "rRadio.Roboto22", self.hudX + HUD_ICON_OFFSET, HUD_Y + HUD_HALF_HEIGHT, GetCachedColor(textColor, alpha * self.anim.statusTransition), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if status == "playing" then
        self:DrawEqualizer(self.hudX, HUD_Y + HUD_HALF_HEIGHT, alpha, self:GetStatusColor(status))
    end
end

function ENT:DrawHUD(status, stationName, alpha)
    local colors = self:GetClass() == "rammel_boombox_gold" and HUD.COLORS.golden_boombox or (rRadio.config.UI or DEFAULT_UI)
    local background = colors.BackgroundColor or colors.BACKGROUND
    local accent = colors.AccentPrimary or colors.Highlight or colors.ACCENT
    local textColor = colors.TextColor or colors.TEXT
    surface.SetDrawColor(GetCachedColor(background, alpha))
    surface.DrawRect(-self.halfWidth, HUD_Y, self.cachedWidth, HUD_HEIGHT)
    DrawAccentBar(self, status, accent, alpha)
    DrawIndicatorBar(self, status, alpha)
    DrawTextAndEqualizer(self, status, stationName, alpha, textColor)
end

function ENT:GetStatusColor(status)
    local colors = self:GetClass() == "rammel_boombox_gold" and HUD.COLORS.golden_boombox or (rRadio.config.UI or {})
    local accent = colors.AccentPrimary or colors.Highlight or colors.ACCENT
    local inactive = colors.Disabled or colors.TextColor or colors.INACTIVE
    if status == "playing" then
        return accent
    elseif status == "tuning" then
        local pulse = math.sin(CurTime() * 4.5) * 0.5 + 0.5
        return LerpColor(pulse, inactive, accent)
    end
    return inactive
end

function ENT:DrawEqualizer(x, y, alpha, color)
    self.anim = self.anim or createAnimationState()
    self.anim.equalizerHeights = self.anim.equalizerHeights or {0, 0, 0}
    local barWidth, spacing, maxHeight = 3, 3, HUD.DIMENSIONS.HEIGHT * 0.65
    local volume = entityVolumes[self:EntIndex()] or 1
    if rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[self] then volume = 0 end
    self:UpdateEqualizerHeights(volume, FrameTime() * 2.5)
    local colorWithAlpha = GetCachedColor(color, alpha)
    for i = 1, HUD.EQUALIZER.BARS do
        local height = maxHeight * (self.anim.equalizerHeights[i] or 0)
        draw_RoundedBox(1, x + (i - 1) * (barWidth + spacing), y - height * 0.5, barWidth, height, colorWithAlpha)
    end
end

function ENT:UpdateEqualizerHeights(volume, dt)
    local curTime = CurTime()
    local timeOffsets = {0, 0.3, 0.6}
    for i = 1, HUD.EQUALIZER.BARS do
        local wave1 = math.sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i])
        local wave2 = math.sin((curTime + timeOffsets[i]) * HUD.EQUALIZER.FREQUENCIES[i] * 1.4)
        local targetHeight = HUD.EQUALIZER.MIN_HEIGHT + (math.abs(wave1 + wave2) * 0.5 * HUD.EQUALIZER.MAX_HEIGHT * volume)
        self.anim.equalizerHeights[i] = Lerp(dt * 5, self.anim.equalizerHeights[i], targetHeight)
    end
end

function ENT:UpdateAnimations(status, dt)
    self.anim = self.anim or createAnimationState()
    local targetProgress = (status == "playing" or status == "tuning") and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    self.anim.statusTransition = math.min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)
    if status == "tuning" then
        self.anim.tuningOffset = math.sin(CurTime() * 3.5) * 0.5 + 0.5
    end
end

function ENT:GetColorScheme()
    return entityColorSchemes[self] or (entityColorSchemes[self] = HUD.COLORS[self:GetClass()] or HUD.COLORS.default)
end

net.Receive("rRadio.SetRadioVolume", function()
    local entity = net.ReadEntity()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = net.ReadFloat() end
end)

hook.Add("LanguageUpdated", "rRadio.ClearBoomboxTextCache", function()
    initializeStaticTexts()
    initializeStaticTextWidths()
end)

hook.Add("NetworkEntityCreated", "BoomboxNetworkedValues", function(ent)
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        timer.Simple(0, function() if IsValid(ent) then UpdateNetworkedValues(ent) end end)
    end
end)

hook.Add("EntityRemoved", "CleanupBoomboxVolumes", function(ent)
    entityVolumes[ent:EntIndex()] = nil
    ActiveBoomboxes[ent] = nil
end)

hook.Add("ShutDown", "CleanupBoomboxTimers", function()
    timer.Remove("BoomboxCleanup")
end)

hook.Add("PostDrawOpaqueRenderables", "rRadio_DrawAllBoomboxHUDs", function()
    if not (cvHud:GetBool() and cvEnabled:GetBool()) then return end
    local plyEye = LocalPlayer():EyePos()
    local dt = FrameTime()
    for ent in pairs(ActiveBoomboxes) do
        local distSqr = plyEye:DistToSqr(ent:GetPos())
        if distSqr <= MODEL_CULL_DISTANCE_SQR then
            local alpha = math.Clamp(255 * (1 - (distSqr - FADE_START_SQR) * FADE_RANGE_INV), 0, 255)
            if alpha > 0 then
                local idx = ent:EntIndex()
                local statusData = rRadio.cl.BoomboxStatuses[idx] or {}
                local status = statusData.stationStatus or ent.nwStatus
                local stationName = statusData.stationName or ent.nwStationName
                ent:UpdateAnimations(status, dt)
                local pos = ent:GetPos() + ent:GetForward() * 4.5 + ent:GetUp() * 14
                local ang = ent:GetAngles()
                ang:RotateAroundAxis(ang:Up(), -90)
                ang:RotateAroundAxis(ang:Forward(), 90)
                ang:RotateAroundAxis(ang:Right(), 180)
                cam.Start3D2D(pos, ang, 0.05)
                    ent:DrawHUD(status, stationName, alpha)
                cam.End3D2D()
            end
        end
    end
end)
