local Radio = rRadio
local Utils = Radio.utils
local Status = Radio.status
local Config = Radio.config

include("shared.lua")

local cvHud, cvBasicHud, cvEnabled, cvMaxVolume =
      GetConVar("rammel_rradio_boombox_hud"),
      GetConVar("rammel_rradio_basic_hud"),
      GetConVar("rammel_rradio_enabled"),
      GetConVar("rammel_rradio_max_volume")

local FADE_START_SQR, FADE_END_SQR = 400*400, 500*500
local FADE_RANGE_INV                = 1 / (FADE_END_SQR - FADE_START_SQR)
local MODEL_CULL_DISTANCE_SQR       = 7500*7500

local HUD_OFFSET_FORWARD, HUD_OFFSET_UP, HUD_SCALE = 4.6, 14.5, 0.06
local ACCENT_ALPHA_BRIGHT, ACCENT_ALPHA_DIM = 0.8, 0.2
local HUD_TICK       = 1/25
local TUNING_SPEED   = 1.5
local PULSE_SPEED    = 2

local CurTime, LocalPlayer = CurTime, LocalPlayer
local math_floor, math_sin, math_abs, math_min, math_max, math_Clamp =
      math.floor, math.sin, math.abs, math.min, math.max, math.Clamp
local draw_SimpleText, surface_SetFont, surface_GetTextSize =
      draw.SimpleText, surface.SetFont, surface.GetTextSize
local cam_Start3D2D, cam_End3D2D  = cam.Start3D2D, cam.End3D2D

local SIN_SAMPLES = 1024
local SIN_LUT = {}; for i = 0, SIN_SAMPLES-1 do SIN_LUT[i] = math_sin(i * math.pi * 2 / SIN_SAMPLES) end
local function fastsin(t) return SIN_LUT[math_floor(t * SIN_SAMPLES) % SIN_SAMPLES] end

local MAT_RECT = CreateMaterial("rradio_rect", "UnlitGeneric", {
    ["$basetexture"] = "color/white", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1"
})

local STATIC_TEXTS, TEXT_WIDTH_CACHE, dynamicTextOrder = nil, {}, {}
local MAX_DYNAMIC = 100
local UTF8_LEN = string.utf8len or (utf8 and utf8.len) or function(s) return #s end
local UTF8_SUB = string.utf8sub or (utf8 and utf8.sub) or function(s,i,j) return string.sub(s,i,j) end
local DOTS = {"", ".", "..", "..."}

local function GetTextWidth(t)
    local e = TEXT_WIDTH_CACHE[t]; if e then return e.width end
    surface_SetFont("rRadio.Roboto24")
    local w = surface_GetTextSize(t)
    TEXT_WIDTH_CACHE[t] = {width = w, isStatic = false}
    dynamicTextOrder[#dynamicTextOrder+1] = t
    if #dynamicTextOrder > MAX_DYNAMIC then
        local old = table.remove(dynamicTextOrder, 1)
        if not TEXT_WIDTH_CACHE[old].isStatic then TEXT_WIDTH_CACHE[old] = nil end
    end
    return w
end

local colour_cache = {}
local function Premul(c, a)
    if not c then return Color(255,255,255,a) end
    if a >= 255 then return c end
    local k = c.r..","..c.g..","..c.b..","..a
    local hit = colour_cache[k]; if hit then return hit end
    local pc = Color(math_floor(c.r*a/255), math_floor(c.g*a/255),
                     math_floor(c.b*a/255), a)
    colour_cache[k] = pc; return pc
end

local ActiveBoomboxes = ActiveBoomboxes or {}
local entityVolumes   = Radio.cl and Radio.cl.entityVolumes or {}
local entityColorSchemes = setmetatable({}, {__mode = "k"})

local HUD = {
    DIMENSIONS = {HEIGHT = 28, PADDING = 11, ICON_SIZE = 14, HEIGHT_MULT = 1.5},
    EQUALIZER  = {BARS = 3, MIN_H = 0.3, MAX_H = 0.7, FREQ = {1.0, 1.3, 1.6}, OFF = {0, 0.33, 0.66}}
}
local HUD_HEIGHT      = HUD.DIMENSIONS.HEIGHT * HUD.DIMENSIONS.HEIGHT_MULT
local HUD_HALF_HEIGHT = HUD_HEIGHT * 0.5
local PAD, ICON       = HUD.DIMENSIONS.PADDING, HUD.DIMENSIONS.ICON_SIZE
local HUD_ICON_OFFSET = PAD*2 + ICON + 8
local HUD_DIMS        = {MIN_WIDTH = 380, ICON_OFFSET = HUD_ICON_OFFSET,
                         TEXT_MAX_OFFSET = PAD*4 + ICON + 16}

local function initTexts()
    STATIC_TEXTS = {
        interact = Config.Lang["Interact"] or "Press E to Interact",
        paused   = Config.Lang["Paused"]   or "Paused",
        tuning   = Config.Lang["TuningIn"] or "Tuning in"
    }
    surface_SetFont("rRadio.Roboto24")
    for _, t in pairs(STATIC_TEXTS) do
        TEXT_WIDTH_CACHE[t] = {width = surface_GetTextSize(t), isStatic = true}
    end
end
initTexts()

local ENT = ENT; local NWK = "_nw"
local AnimMT = {__index = function(s,k)
    if k=="progress"         then s.progress=0 return 0 end
    if k=="lastStatus"       then s.lastStatus=0 return 0 end
    if k=="statusTransition" then s.statusTransition=0 return 0 end
    if k=="tuningOffset"     then s.tuningOffset=0 return 0 end
    if k=="equaliser"        then local t={0,0,0}; s.equaliser=t; return t end
end}

function ENT:Initialize()
    local mn,mx = self:GetModelBounds(); mx.z = mx.z + 20; self:SetRenderBounds(mn,mx)
    self.anim = setmetatable({}, AnimMT); self.nextAnimTick = 0
    self.cachedWidth = HUD_DIMS.MIN_WIDTH; self.halfWidth = HUD_DIMS.MIN_WIDTH * 0.5
    self.hudX = -self.halfWidth + PAD; self[NWK] = {}; ActiveBoomboxes[self] = true
end
function ENT:OnRemove() ActiveBoomboxes[self] = nil; entityVolumes[self] = nil end

hook.Add("EntityNetworkedVarChanged","rRadio.BoomboxNWCache",function(e,n,_,v)
    if not Utils.IsBoombox or not Utils.IsBoombox(e) then return end
    local c = e[NWK]; if not c then return end
    if   n == "Status"      then c.Status      = v
    elseif n == "StationName" then c.StationName = v
    elseif n == "Owner"       then c.Owner       = v end
end)

local function ClipText(t, maxW)
    local suff, suffW = "...", GetTextWidth("...")
    if GetTextWidth(t) <= maxW - suffW then return t end
    local lo, hi, best = 1, UTF8_LEN(t), 1
    while lo <= hi do
        local mid = math_floor((lo + hi) / 2)
        if GetTextWidth(UTF8_SUB(t,1,mid)) + suffW <= maxW then
            best, lo = mid, mid + 1
        else hi = mid - 1 end
    end
    local fin = UTF8_SUB(t,1,best)..suff
    TEXT_WIDTH_CACHE[fin] = {width = GetTextWidth(fin), isStatic = true}
    return fin
end

function ENT:GetDisplayText(st, station)
    local raw
    if     st == Status.STOPPED then
        raw = Utils.CanInteractWithBoombox(LocalPlayer(), self) and STATIC_TEXTS.interact or STATIC_TEXTS.paused
    elseif st == Status.TUNING  then
        raw = STATIC_TEXTS.tuning .. DOTS[(math_floor(CurTime()*2) % 4) + 1]
    elseif station ~= ""               then raw = station
    else raw = "Radio" end
    if self.lastRawText == raw then return self.cachedText end
    self.lastRawText = raw
    local fin = ClipText(raw, HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET)
    local w = GetTextWidth(fin)
    local newW = math_max(w + PAD*3 + ICON, HUD_DIMS.MIN_WIDTH)
    if newW ~= self.cachedWidth then
        self.cachedWidth = newW; self.halfWidth = newW*0.5; self.hudX = -self.halfWidth + PAD
    end
    self.cachedText = fin; return fin
end

function ENT:GetDisplayTextBasic(st, station)
    local raw
    if     st == Status.STOPPED then
        raw = Utils.CanInteractWithBoombox(LocalPlayer(), self) and STATIC_TEXTS.interact or STATIC_TEXTS.paused
    elseif st == Status.TUNING  then
        raw = STATIC_TEXTS.tuning
    elseif station ~= ""               then raw = station
    else raw = "Radio" end
    if self.lastRawText == raw then return self.cachedText end
    self.lastRawText = raw
    local fin = ClipText(raw, HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET)
    local w = GetTextWidth(fin)
    local newW = math_max(w + PAD*3 + ICON, HUD_DIMS.MIN_WIDTH)
    if newW ~= self.cachedWidth then
        self.cachedWidth = newW
        self.halfWidth = newW * 0.5
        self.hudX = -self.halfWidth + PAD
    end
    self.cachedText = fin
    return fin
end

function ENT:GetColorScheme()
    local s = entityColorSchemes[self]; if s then return s end
    if self:GetClass() == "rammel_boombox_gold" then
        s = {BG = Color(20,20,20), ACCENT = Color(255,215,0),
             TEXT = Color(255,248,220), INACTIVE = Color(218,165,32)}
    else
        local ui = Config.UI
        s = {BG = ui.BackgroundColor,
             ACCENT = ui.AccentPrimary or ui.Highlight,
             TEXT = ui.TextColor,
             INACTIVE = ui.Disabled or ui.TextColor}
    end
    entityColorSchemes[self] = s; return s
end

function ENT:UpdateEqualiser(vol, dt)
    local e = self.anim.equaliser; local ct = CurTime()
    local sm = math_Clamp(dt / 0.1, 0, 1)
    for i = 1, HUD.EQUALIZER.BARS do
        local wave = (fastsin((ct + HUD.EQUALIZER.OFF[i]) * HUD.EQUALIZER.FREQ[i]) +
                      fastsin((ct + HUD.EQUALIZER.OFF[i]) * HUD.EQUALIZER.FREQ[i] * 1.5)) * 0.5
        local tgt = HUD.EQUALIZER.MIN_H + math_abs(wave) * HUD.EQUALIZER.MAX_H * vol
        e[i] = e[i] + (tgt - e[i]) * sm
    end
end

function ENT:UpdateAnim(st, dt)
    local a = self.anim
    a.progress = Lerp(dt*4, a.progress,
                     (st == Status.PLAYING or st == Status.TUNING) and 1 or 0)
    if st ~= a.lastStatus then a.lastStatus = st; a.statusTransition = 0 end
    a.statusTransition = math_min(1, a.statusTransition + dt*4)
    if st == Status.TUNING then a.tuningOffset = fastsin(CurTime()*TUNING_SPEED)*0.5 + 0.5 end
end

local lastR, lastG, lastB, lastA = -1,-1,-1,-1
local function fastRect(x,y,w,h,col)
    if col.r~=lastR or col.g~=lastG or col.b~=lastB or col.a~=lastA then
        surface.SetDrawColor(col.r,col.g,col.b,col.a)
        lastR,lastG,lastB,lastA = col.r,col.g,col.b,col.a
    end
    surface.DrawTexturedRect(x,y,w,h)
end

function ENT:DrawEqualiser(x,y,a,col)
    local c = Premul(col,a)
    surface.SetDrawColor(c.r,c.g,c.b,c.a)
    local barW,gap,maxH = 4,4,HUD.DIMENSIONS.HEIGHT*0.7
    for i = 1, HUD.EQUALIZER.BARS do
        local h = maxH * self.anim.equaliser[i]
        surface.DrawTexturedRect(x + (i-1)*(barW+gap), y - h*0.5, barW, h)
    end
end

function ENT:GetStatusColour(st)
    local sch = self:GetColorScheme()
    if st == Status.PLAYING then return sch.ACCENT end
    if st == Status.TUNING then
        local p = fastsin(CurTime()*PULSE_SPEED)*0.5 + 0.5
        return Color(math_floor(sch.INACTIVE.r + (sch.ACCENT.r - sch.INACTIVE.r)*p),
                     math_floor(sch.INACTIVE.g + (sch.ACCENT.g - sch.INACTIVE.g)*p),
                     math_floor(sch.INACTIVE.b + (sch.ACCENT.b - sch.INACTIVE.b)*p), 255)
    end
    return sch.INACTIVE
end

function ENT:RenderBasicHUD(st, station, a, pos, ang, sch)
    local bg  = Premul(sch.BG, a)
    local txt = Premul(sch.TEXT, a)

    cam_Start3D2D(pos, ang, HUD_SCALE)
        surface.SetMaterial(MAT_RECT)
        fastRect(-self.halfWidth, -HUD_HALF_HEIGHT, self.cachedWidth, HUD_HEIGHT, bg)
        draw_SimpleText(self:GetDisplayTextBasic(st, station), "rRadio.Roboto24",
                        -self.halfWidth + PAD * 2, 0, txt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    cam_End3D2D()
end

function ENT:RenderHUD(eyePos)
    local distSqr = eyePos:DistToSqr(self:GetPos()); if distSqr > MODEL_CULL_DISTANCE_SQR then return end
    local a = math_Clamp(255 * (1 - (distSqr - FADE_START_SQR) * FADE_RANGE_INV), 0, 255); if a <= 0 then return end

    local ct = CurTime()
    local st, station
    if ct >= self.nextAnimTick then
        self.nextAnimTick = ct + HUD_TICK
        local nw = self[NWK]
        st = nw.Status or self:GetNWInt("Status", Status.STOPPED)
        station = nw.StationName or self:GetNWString("StationName", "")
        if st == Status.PLAYING and not Radio.cl.connectedStations[self] then st = Status.TUNING end
        self.lastStatusRendered, self.lastStationRendered = st, station

        local live = Radio.cl.entityVolumes or {}
        local vol  = live[self] or live[self:EntIndex()] or 1
        if Radio.cl.mutedBoomboxes and Radio.cl.mutedBoomboxes[self] then vol = 0 end
        vol = math_Clamp(vol * cvMaxVolume:GetFloat(), 0, 1)

        if not cvBasicHud:GetBool() then
            local now = ct
            local dtTick = now - (self.lastAnimTime or now)
            self.lastAnimTime = now
            self:UpdateEqualiser(vol, dtTick * 2)
            self:UpdateAnim(st, dtTick)
        end
    else
        st, station = self.lastStatusRendered, self.lastStationRendered
    end

    local sch = self:GetColorScheme()
    local bg  = Premul(sch.BG, a)
    local accBright = Premul(sch.ACCENT, a * ACCENT_ALPHA_BRIGHT)
    local txt = Premul(sch.TEXT, a * (cvBasicHud:GetBool() and 1 or self.anim.statusTransition))

    local pos = self:GetPos(); pos:Add(self:GetForward()*HUD_OFFSET_FORWARD); pos:Add(self:GetUp()*HUD_OFFSET_UP)
    local ang = self:GetAngles(); ang:RotateAroundAxis(ang:Up(), -90); ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 180)

    if cvBasicHud:GetBool() then
        self:RenderBasicHUD(st, station, a, pos, ang, sch)
        return
    end

    cam_Start3D2D(pos, ang, HUD_SCALE)
        surface.SetMaterial(MAT_RECT)
        fastRect(-self.halfWidth, -HUD_HALF_HEIGHT, self.cachedWidth, HUD_HEIGHT, bg)

        if st == Status.TUNING then
            local barW = self.cachedWidth * 0.3; local off = self.anim.tuningOffset*(self.cachedWidth - barW)
            fastRect(-self.halfWidth,     HUD_HALF_HEIGHT-2, self.cachedWidth, 2,
                     Premul(sch.ACCENT, a*ACCENT_ALPHA_DIM))
            fastRect(-self.halfWidth+off, HUD_HALF_HEIGHT-2, barW, 2, accBright)
        else
            fastRect(-self.halfWidth, HUD_HALF_HEIGHT-2, self.cachedWidth, 2, accBright)
        end

        if st ~= Status.PLAYING then
            fastRect(self.hudX, -HUD_HALF_HEIGHT + HUD_HEIGHT/3, 4, HUD_HEIGHT/3,
                     Premul(self:GetStatusColour(st), a))
        end

        draw_SimpleText(self:GetDisplayText(st, station), "rRadio.Roboto24",
                        self.hudX+HUD_ICON_OFFSET, 0, txt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if st == Status.PLAYING then
            self:DrawEqualiser(self.hudX, 0, a, self:GetStatusColour(st))
        end
    cam_End3D2D()
end

function ENT:Draw() self:DrawModel() end

hook.Add("PostDrawOpaqueRenderables", "rRadio.DrawAllBoomboxHUDs", function()
    if not (cvHud:GetBool() and cvEnabled:GetBool()) then return end
    local eye = LocalPlayer():EyePos()
    for ent in pairs(ActiveBoomboxes) do
        if IsValid(ent) then ent:RenderHUD(eye) end
    end
end)

local function clearCaches()
    initTexts()
    for k in pairs(entityColorSchemes) do entityColorSchemes[k]=nil end
    for k,v in pairs(TEXT_WIDTH_CACHE) do if not v.isStatic then TEXT_WIDTH_CACHE[k]=nil end end
end
hook.Add("LanguageUpdated", "rRadio.BoomboxClearCaches", clearCaches)
hook.Add("ThemeChanged",   "rRadio.BoomboxClearCaches", clearCaches)