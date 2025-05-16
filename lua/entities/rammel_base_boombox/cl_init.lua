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
local math_min = math.min
local math_max = math.max
local string_rep = string.rep
local utf8len = string.utf8len or (utf8 and utf8.len) or function(s) return #s end
local utf8sub = string.utf8sub or (utf8 and utf8.sub) or function(s,i,j) return string.sub(s,i,j) end

local STATIC_TEXTS = nil

local TEXT_WIDTH_CACHE = {}
local MAX_DYNAMIC_TEXT_ENTRIES = 100
local dynamicTextOrder = {}

local HUD_OFFSET_FORWARD = 4.6
local HUD_OFFSET_UP      = 14.5
local HUD_SCALE          = 0.06

local ACCENT_ALPHA_BRIGHT = 0.8
local ACCENT_ALPHA_DIM = 0.2

local ActiveBoomboxes = ActiveBoomboxes or {}
local entityVolumes = entityVolumes or {}
local entityColorSchemes = setmetatable({}, {__mode = "k"})

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
        FREQUENCIES = {1.5, 2.0, 2.5},
        OFFSETS    = {0,    0.33, 0.66}
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

local surface_SetFont, surface_GetTextSize = surface.SetFont, surface.GetTextSize
local math_sin, math_abs, math_floor, math_Clamp = math.sin, math.abs, math.floor, math.Clamp
local Lerp = Lerp
local cam_Start3D2D, cam_End3D2D = cam.Start3D2D, cam.End3D2D
local vector_origin = vector_origin

local function LerpColor(t, c1, c2)
    return Color(
        math_floor(c1.r + (c2.r - c1.r) * t),
        math_floor(c1.g + (c2.g - c1.g) * t),
        math_floor(c1.b + (c2.b - c1.b) * t),
        math_floor(c1.a + (c2.a - c1.a) * t)
    )
end

local function GetTextWidth(text)
    local entry = TEXT_WIDTH_CACHE[text]
    if entry then return entry.width end
    surface_SetFont("rRadio.Roboto24")
    local w = surface_GetTextSize(text)
    TEXT_WIDTH_CACHE[text] = { width = w, isStatic = false }
    table.insert(dynamicTextOrder, text)
    if #dynamicTextOrder > MAX_DYNAMIC_TEXT_ENTRIES then
        local oldest = table.remove(dynamicTextOrder, 1)
        local oe = TEXT_WIDTH_CACHE[oldest]
        if oe and not oe.isStatic then
            TEXT_WIDTH_CACHE[oldest] = nil
        end
    end
    return w
end

local function initializeStaticTexts()
    STATIC_TEXTS = {
        interact = rRadio.config.Lang["Interact"] or "Press E to Interact",
        paused   = rRadio.config.Lang["Paused"] or "Paused",
        tuning   = rRadio.config.Lang["TuningIn"] or "Tuning in",
    }
end

local function initializeStaticTextWidths()
    surface_SetFont("rRadio.Roboto24")
    for _, txt in pairs(STATIC_TEXTS) do
        local w = surface_GetTextSize(txt)
        TEXT_WIDTH_CACHE[txt] = { width = w, isStatic = true }
    end
end

initializeStaticTexts()
initializeStaticTextWidths()

local color_cache = {}
local function GetCachedColor(baseColor, alpha)
    if type(baseColor) ~= "table" or type(baseColor.r) ~= "number" then
        return Color(255,255,255, math_floor(alpha or 255))
    end
    local a = math_floor(alpha or baseColor.a or 255)
    if a == 255 then
        return baseColor
    end

    local key = baseColor.r..","..baseColor.g..","..baseColor.b..","..a
    local col = color_cache[key]
    if not col then
        local r = math_floor(baseColor.r * a / 255)
        local g = math_floor(baseColor.g * a / 255)
        local b = math_floor(baseColor.b * a / 255)
        col = Color(r, g, b, a)
        color_cache[key] = col
    end
    return col
end

local AnimMT = {
   __index = function(self, key)
       if key == "progress"         then rawset(self,"progress",0);         return 0 end
       if key == "textOffset"       then rawset(self,"textOffset",0);       return 0 end
       if key == "lastStatus"       then rawset(self,"lastStatus","" );    return "" end
       if key == "statusTransition" then rawset(self,"statusTransition",0); return 0 end
       if key == "equalizerHeights" then
           local arr = {}
           for i = 1, HUD.EQUALIZER.BARS do arr[i] = 0 end
           rawset(self,"equalizerHeights",arr);
           return arr
       end
       if key == "tuningOffset"     then rawset(self,"tuningOffset",0);    return 0 end
       return nil
   end
}

local function UpdateNetworkedValues(self)
    local oldStatus = self.nwStatus
    self.nwStatus = self:GetNWInt("Status", rRadio.status.STOPPED)
    self.nwStationName = self:GetNWString("StationName", "")
    self.nwOwner = self:GetNWEntity("Owner")

    if oldStatus ~= self.nwStatus and self.anim then
        self.anim.lastStatus = oldStatus
    end
end

hook.Add("NetworkEntityCreated", "rRadio.BoomboxNetworkedValues", function(ent)
    if not IsValid(ent) or not rRadio.utils.IsBoombox(ent) or ent.anim then return end
    ent.anim = setmetatable({}, AnimMT)
    ActiveBoomboxes[ent] = true
    UpdateNetworkedValues(ent)
end)

hook.Add("EntityRemoved", "rRadio.CleanupBoomboxVolumes", function(ent)
    entityVolumes[ent:EntIndex()] = nil
    ActiveBoomboxes[ent] = nil
end)

function ENT:Initialize()
    local mins, maxs = self:GetModelBounds()
    maxs.z = maxs.z + 20
    self:SetRenderBounds(mins, maxs)
    
    self.anim = setmetatable({}, AnimMT)
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

local function ClipTextToWidth(text, maxWidth)
    local suffix = "..."
    local suffixW = GetTextWidth(suffix)
    local fullW = GetTextWidth(text)
    if fullW <= maxWidth - suffixW then return text, fullW end
    local len = utf8len(text)
    local low, high, best = 1, len, 1
    while low <= high do
        local mid = math_floor((low + high)/2)
        local sub = utf8sub(text, 1, mid)
        local w = GetTextWidth(sub)
        if w + suffixW <= maxWidth then best, low = mid, mid+1 else high = mid-1 end
    end
    local final = utf8sub(text, 1, best) .. suffix
    return final, GetTextWidth(final)
end

function ENT:GetDisplayText(status, stationName)
    local text
    if status == rRadio.status.STOPPED then
        if rRadio.utils.canInteractWithBoombox(LocalPlayer(), self) then
            text = STATIC_TEXTS.interact
        else
            text = STATIC_TEXTS.paused
        end
    elseif status == rRadio.status.TUNING then
        local dotCount = math_floor(CurTime() * 2) % 4
        text = STATIC_TEXTS.tuning .. string_rep(".", dotCount)
    elseif stationName ~= "" then
        text = stationName
    else
        text = "Radio"
    end

    local textWidth = GetTextWidth(text)
    if self.lastRawText == text then
        return self.cachedText
    end
    self.lastRawText = text
    local finalText = text
    local finalWidth = textWidth
    local maxWidth = HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET
    if finalWidth > maxWidth then
        finalText, finalWidth = ClipTextToWidth(text, maxWidth)
        TEXT_WIDTH_CACHE[finalText] = { width = finalWidth, isStatic = true }
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
    local text = self:GetDisplayText(status, stationName)
    if stationName and utf8len(stationName) > rRadio.config.MAX_NAME_CHARS then
        stationName = utf8sub(stationName, 1, rRadio.config.MAX_NAME_CHARS)
    end
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

function ENT:GetColorScheme()
    local scheme = entityColorSchemes[self]
    if not scheme then
        if self:GetClass() == "rammel_boombox_gold" then
            scheme = HUD.COLORS.golden_boombox
        else
            local theme = rRadio.config.UI or DEFAULT_UI
            scheme = {
                BACKGROUND = theme.BackgroundColor,
                ACCENT     = theme.AccentPrimary or theme.Highlight,
                TEXT       = theme.TextColor,
                INACTIVE   = theme.Disabled or theme.TextColor
            }
        end
        entityColorSchemes[self] = scheme
    end
    return scheme
end

function ENT:DrawHUD(status, stationName, alpha)
    local bgAlpha = alpha * 1.0
    local colors = self:GetColorScheme()
    local background, accent, textColor, inactive = colors.BACKGROUND, colors.ACCENT, colors.TEXT, colors.INACTIVE
    
    do local c = GetCachedColor(background, bgAlpha) surface.SetDrawColor(c.r, c.g, c.b, c.a) end
    surface.DrawRect(-self.halfWidth, HUD_Y, self.cachedWidth, HUD_HEIGHT)
    
    DrawAccentBar(self, status, accent, alpha)
    DrawIndicatorBar(self, status, alpha)
    DrawTextAndEqualizer(self, status, stationName, alpha, textColor)
end

function ENT:GetStatusColor(status)
    local ct = CurTime()
    local colors = self:GetColorScheme()
    local accent = colors.ACCENT
    local inactive = colors.INACTIVE
    if status == rRadio.status.PLAYING then
        return accent
    elseif status == rRadio.status.TUNING then
        local pulse = math_sin(ct * 4) * 0.5 + 0.5
        return LerpColor(pulse, inactive, accent)
    else
        return inactive
    end
end

function ENT:DrawEqualizer(x, y, alpha, color)
    local barWidth, spacing = 4, 4
    local maxHeight = HUD.DIMENSIONS.HEIGHT * 0.7
    local c = GetCachedColor(color, alpha)
    for i = 1, #self.anim.equalizerHeights do
        local height = maxHeight * self.anim.equalizerHeights[i]
        draw_RoundedBox(1, x + (i - 1) * (barWidth + spacing), y - height * 0.5, barWidth, height, c)
    end
end

function ENT:UpdateEqualizerHeights(volume, dt)
    local ct = CurTime()
    for i = 1, HUD.EQUALIZER.BARS do
        local offset = HUD.EQUALIZER.OFFSETS[i]
        local freq   = HUD.EQUALIZER.FREQUENCIES[i]
        local wave1  = math_sin((ct + offset) * freq)
        local wave2  = math_sin((ct + offset) * freq * 1.5)
        local combined = (wave1 + wave2) * 0.5
        local target = HUD.EQUALIZER.MIN_HEIGHT + (math_abs(combined) * HUD.EQUALIZER.MAX_HEIGHT * volume)
        self.anim.equalizerHeights[i] = Lerp(dt * 4, self.anim.equalizerHeights[i], target)
    end
end

function ENT:UpdateAnimations(status, dt)
    local ct = CurTime()
    local targetProgress = (status == rRadio.status.PLAYING or status == rRadio.status.TUNING) and 1 or 0
    self.anim.progress = Lerp(dt * HUD.ANIMATION.SPEED, self.anim.progress, targetProgress)
    if status ~= self.anim.lastStatus then
        self.anim.statusTransition = 0
        self.anim.lastStatus = status
    end
    self.anim.statusTransition = math_min(1, self.anim.statusTransition + dt * HUD.ANIMATION.SPEED)
    if status == rRadio.status.TUNING then
        self.anim.tuningOffset = (math_sin(ct * 3) * 0.5 + 0.5)
    end
end

net.Receive("rRadio.SetRadioVolume", function()
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    if IsValid(entity) then entityVolumes[entity:EntIndex()] = volume end
end)

hook.Add("Think", "rRadio.StepBoomboxAnimation", function()
    local eqDt = FrameTime() * 2
    for ent in pairs(ActiveBoomboxes) do
        local rawVol = entityVolumes[ent:EntIndex()]
        local defaultVol = rawVol or 1
        local isMuted = rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[ent]
        local vol = isMuted and 0 or defaultVol
        ent:UpdateEqualizerHeights(vol, eqDt)
    end
end)

hook.Add("LanguageUpdated", "rRadio.ClearBoomboxTextCache", function()
    initializeStaticTexts()
    initializeStaticTextWidths()

    for ent in pairs(entityColorSchemes) do entityColorSchemes[ent] = nil end
end)

hook.Add("ThemeChanged", "rRadio.ClearBoomboxColorCache", function()
    for ent in pairs(entityColorSchemes) do entityColorSchemes[ent] = nil end
end)

hook.Add("PostDrawOpaqueRenderables", "rRadio_DrawAllBoomboxHUDs", function()
    local plyEye = LocalPlayer():EyePos()
    local dt = FrameTime()

    for ent in pairs(ActiveBoomboxes) do
        local distSqr = plyEye:DistToSqr(ent:GetPos())
        if distSqr <= MODEL_CULL_DISTANCE_SQR and cvHud:GetBool() and cvEnabled:GetBool() then
            local alpha = math_Clamp(255 * (1 - (distSqr - FADE_START_SQR) * FADE_RANGE_INV), 0, 255)
            if alpha > 0 then
                local idx = ent:EntIndex()
                local statusData = rRadio.cl.BoomboxStatuses[idx] or {}
                local status = statusData.stationStatus ~= nil and statusData.stationStatus or ent:GetNWInt("Status", rRadio.status.STOPPED)
                local stationName = statusData.stationName or ent:GetNWString("StationName", "")

                -- Gate PLAYING display until stream actually connected
                if status == rRadio.status.PLAYING and not rRadio.cl.connectedStations[ent] then
                    status = rRadio.status.TUNING
                end
                
                ent:UpdateAnimations(status, dt)

                local pos = ent:GetPos()
                pos:Add(ent:GetForward() * HUD_OFFSET_FORWARD)
                pos:Add(ent:GetUp() * HUD_OFFSET_UP)

                local ang = ent:GetAngles()
                ang:RotateAroundAxis(ang:Up(), -90)
                ang:RotateAroundAxis(ang:Forward(), 90)
                ang:RotateAroundAxis(ang:Right(), 180)

                cam_Start3D2D(pos, ang, HUD_SCALE)
                    ent:DrawHUD(status, stationName, alpha)
                cam_End3D2D()
            end
        end
    end
end)