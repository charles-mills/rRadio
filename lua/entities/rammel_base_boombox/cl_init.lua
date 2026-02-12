include( "shared.lua" )
local cvHud = GetConVar( "rammel_rradio_boombox_hud" )
local cvBasicHud = GetConVar( "rammel_rradio_basic_hud" )
local cvEnabled = GetConVar( "rammel_rradio_enabled" )
local cvMaxVolume = GetConVar( "rammel_rradio_max_volume" )
local FADE_START_SQR, FADE_END_SQR = 400 * 400, 500 * 500
local FADE_RANGE_INV = 1 / ( FADE_END_SQR - FADE_START_SQR )
local MODEL_CULL_DISTANCE_SQR = 7500 * 7500
local HUD_OFFSET_FORWARD, HUD_OFFSET_UP, HUD_SCALE = 4.6, 14.5, 0.06
local HUD_LOCAL_OFFSET = Vector( HUD_OFFSET_FORWARD, 0, HUD_OFFSET_UP )
local HUD_ANG_OFFSET = Angle( 0, 0, 0 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Up(), -90 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Forward(), 90 )
HUD_ANG_OFFSET:RotateAroundAxis( HUD_ANG_OFFSET:Right(), 180 )
local ACCENT_ALPHA_BRIGHT, ACCENT_ALPHA_DIM = 0.8, 0.2
local HUD_TICK = 1 / 25
local TUNING_SPEED = 1.5
local PULSE_SPEED = 2
local CurTime, LocalPlayer = CurTime, LocalPlayer
local math_floor, math_sin, math_abs = math.floor, math.sin, math.abs
local math_min, math_max, math_Clamp = math.min, math.max, math.Clamp
local draw_SimpleText, surface_SetFont, surface_GetTextSize = draw.SimpleText, surface.SetFont, surface.GetTextSize
local cam_Start3D2D, cam_End3D2D = cam.Start3D2D, cam.End3D2D
local SIN_SAMPLES = 1024
local SIN_LUT = {}
for i = 0, SIN_SAMPLES - 1 do
    SIN_LUT[i] = math_sin( i * math.pi * 2 / SIN_SAMPLES )
end

local function fastsin( t )
    return SIN_LUT[math_floor( t * SIN_SAMPLES ) % SIN_SAMPLES]
end

local MAT_RECT = CreateMaterial( "rradio_rect", "UnlitGeneric", {
    ["$basetexture"] = "color/white",
    ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1"
} )

local STATIC_TEXTS, TEXT_WIDTH_CACHE, dynamicTextOrder = nil, {}, {}
local MAX_DYNAMIC = 100
local UTF8_LEN = utf8.len
local UTF8_SUB = utf8.sub
local DOTS = { "", ".", "..", "..." }
local function GetTextWidth( t )
    local e = TEXT_WIDTH_CACHE[t]
    if e then return e.width end
    surface_SetFont( "rRadio.Roboto24" )
    local w = surface_GetTextSize( t )
    TEXT_WIDTH_CACHE[t] = {
        width = w,
        isStatic = false
    }

    dynamicTextOrder[#dynamicTextOrder + 1] = t
    if #dynamicTextOrder > MAX_DYNAMIC then
        local old = table.remove( dynamicTextOrder, 1 )
        if not TEXT_WIDTH_CACHE[old].isStatic then TEXT_WIDTH_CACHE[old] = nil end
    end
    return w
end

local colour_cache = {}
local colour_cache_order = {}
local MAX_COLOR_CACHE = 512
local function Premul( c, a )
    a = math_floor( math_Clamp( a, 0, 255 ) + 0.5 )
    if not c then
        rRadio.logger.Warn( "Premul called with nil color" )
        return Color( 255, 255, 255, a )
    end

    if a >= 255 then return c end
    local k = ( ( c.r * 256 + c.g ) * 256 + c.b ) * 256 + a
    local hit = colour_cache[k]
    if hit then return hit end
    local pc = Color( math_floor( c.r * a / 255 ), math_floor( c.g * a / 255 ), math_floor( c.b * a / 255 ), a )
    colour_cache[k] = pc
    colour_cache_order[#colour_cache_order + 1] = k
    if #colour_cache_order > MAX_COLOR_CACHE then
        local old = table.remove( colour_cache_order, 1 )
        colour_cache[old] = nil
    end
    return pc
end

local ActiveBoomboxes = ActiveBoomboxes or {}
local entityVolumes = rRadio.cl and rRadio.cl.entityVolumes or {}
local entityColorSchemes = setmetatable( {}, {
    __mode = "k"
} )

local HUD = {
    DIMENSIONS = {
        HEIGHT = 28,
        PADDING = 11,
        ICON_SIZE = 14,
        HEIGHT_MULT = 1.5
    },
    EQUALIZER = {
        BARS = 5,
        MIN_H = 0.25,
        MAX_H = 0.75,
        FREQ = { 0.9, 1.1, 1.3, 1.5, 1.7 },
        OFF = { 0, 0.2, 0.4, 0.6, 0.8 }
    }
}

local HUD_HEIGHT = HUD.DIMENSIONS.HEIGHT * HUD.DIMENSIONS.HEIGHT_MULT
local HUD_HALF_HEIGHT = HUD_HEIGHT * 0.5
local PAD, ICON = HUD.DIMENSIONS.PADDING, HUD.DIMENSIONS.ICON_SIZE
local HUD_ICON_OFFSET = PAD * 2 + ICON + 8
local HUD_DIMS = {
    MIN_WIDTH = 380,
    ICON_OFFSET = HUD_ICON_OFFSET,
    TEXT_MAX_OFFSET = PAD * 4 + ICON + 16
}

local function initTexts()
    STATIC_TEXTS = {
        interact = rRadio.L( "Interact", "Press E to Interact" ),
        paused = rRadio.L( "Paused", "Paused" ),
        tuning = rRadio.L( "TuningIn", "Tuning in" ),
        error = rRadio.L( "StationFailed", "Station Failed" )
    }

    surface_SetFont( "rRadio.Roboto24" )
    for _, t in pairs( STATIC_TEXTS ) do
        TEXT_WIDTH_CACHE[t] = {
            width = surface_GetTextSize( t ),
            isStatic = true
        }
    end
end

initTexts()
local ENT = ENT
local NWK = "_nw"

function ENT:Initialize()
    local mn, mx = self:GetModelBounds()
    mx.z = mx.z + 20
    self:SetRenderBounds( mn, mx )
    self.anim = {
        progress = 0,
        lastStatus = 0,
        statusTransition = 0,
        tuningOffset = 0,
        equaliser = { 0, 0, 0, 0, 0 }
    }
    self.nextAnimTick = 0
    self.cachedWidth = HUD_DIMS.MIN_WIDTH
    self.halfWidth = HUD_DIMS.MIN_WIDTH * 0.5
    self.hudX = -self.halfWidth + PAD
    self[NWK] = {}
    ActiveBoomboxes[self] = true
end

function ENT:OnRemove()
    ActiveBoomboxes[self] = nil
    entityVolumes[self] = nil
end

hook.Add( "EntityNetworkedVarChanged", "rRadio.BoomboxNWCache", function( e, n, _, v )
    if n ~= "Status" and n ~= "StationName" and n ~= "Owner" then return end
    if not rRadio.utils.IsBoombox or not rRadio.utils.IsBoombox( e ) then return end
    local c = e[NWK]
    if not c then return end
    c[n] = v
end )

local function ClipText( t, maxW )
    local suff, suffW = "...", GetTextWidth( "..." )
    if GetTextWidth( t ) <= maxW then return t end
    local lo, hi, best = 1, UTF8_LEN( t ), 1
    while lo <= hi do
        local mid = math_floor( ( lo + hi ) / 2 )
        if GetTextWidth( UTF8_SUB( t, 1, mid ) ) + suffW <= maxW then
            best, lo = mid, mid + 1
        else
            hi = mid - 1
        end
    end

    local fin = UTF8_SUB( t, 1, best ) .. suff
    GetTextWidth( fin )
    return fin
end

function ENT:GetDisplayTextForMode( st, station, basicHud )
    local raw
    if st == rRadio.status.STOPPED then
        raw = rRadio.utils.CanInteractWithBoombox( LocalPlayer(), self )
            and STATIC_TEXTS.interact or STATIC_TEXTS.paused
    elseif st == rRadio.status.ERROR then
        raw = STATIC_TEXTS.error
    elseif st == rRadio.status.TUNING then
        raw = basicHud and STATIC_TEXTS.tuning or STATIC_TEXTS.tuning .. DOTS[math_floor( CurTime() * 2 ) % 4 + 1]
    elseif station ~= "" then
        raw = station
    else
        raw = "Radio"
    end

    local cacheKey = basicHud and raw or raw .. "\1"
    if self.lastRawTextKey == cacheKey then return self.cachedText end
    self.lastRawTextKey = cacheKey
    local fin = ClipText( raw, HUD_DIMS.MIN_WIDTH - HUD_DIMS.TEXT_MAX_OFFSET )
    local w = GetTextWidth( fin )
    local newW = math_max( w + PAD * 3 + ICON, HUD_DIMS.MIN_WIDTH )
    if newW ~= self.cachedWidth then
        self.cachedWidth = newW
        self.halfWidth = newW * 0.5
        self.hudX = -self.halfWidth + PAD
    end

    self.cachedText = fin
    return fin
end

function ENT:GetDisplayText( st, station )
    return self:GetDisplayTextForMode( st, station, false )
end

function ENT:GetDisplayTextBasic( st, station )
    return self:GetDisplayTextForMode( st, station, true )
end

function ENT:GetColorScheme()
    local s = entityColorSchemes[self]
    if s then return s end
    if self:GetClass() == "rammel_boombox_gold" then
        s = {
            BG = Color( 20, 20, 20 ),
            ACCENT = Color( 255, 215, 0 ),
            TEXT = Color( 255, 248, 220 ),
            INACTIVE = Color( 218, 165, 32 ),
            ERROR = Color( 232, 76, 61 )
        }
    else
        local ui = rRadio.config.UI
        s = {
            BG = ui.BackgroundColor,
            ACCENT = ui.AccentPrimary or ui.Highlight,
            TEXT = ui.TextColor,
            INACTIVE = ui.Disabled or ui.TextColor,
            ERROR = ui.Error or Color( 248, 81, 73 )
        }
    end

    entityColorSchemes[self] = s
    return s
end

function ENT:UpdateEqualiser( vol, dt )
    local e = self.anim.equaliser
    local ct = CurTime()
    local sm = math_Clamp( dt / 0.1, 0, 1 )
    for i = 1, HUD.EQUALIZER.BARS do
        local wave = ( fastsin( ( ct + HUD.EQUALIZER.OFF[i] ) * HUD.EQUALIZER.FREQ[i] )
            + fastsin( ( ct + HUD.EQUALIZER.OFF[i] ) * HUD.EQUALIZER.FREQ[i] * 1.5 ) ) * 0.5
        local tgt = HUD.EQUALIZER.MIN_H + math_abs( wave ) * HUD.EQUALIZER.MAX_H * vol
        e[i] = e[i] + ( tgt - e[i] ) * sm
    end
end

function ENT:UpdateAnim( st, dt )
    local a = self.anim
    a.progress = Lerp( dt * 4, a.progress, ( st == rRadio.status.PLAYING or st == rRadio.status.TUNING ) and 1 or 0 )
    if st ~= a.lastStatus then
        a.lastStatus = st
        a.statusTransition = 0
    end

    a.statusTransition = math_min( 1, a.statusTransition + dt * 4 )
    if st == rRadio.status.TUNING then a.tuningOffset = fastsin( CurTime() * TUNING_SPEED ) * 0.5 + 0.5 end
end

local lastR, lastG, lastB, lastA = -1, -1, -1, -1
local function fastRect( x, y, w, h, col )
    if col.r ~= lastR or col.g ~= lastG or col.b ~= lastB or col.a ~= lastA then
        surface.SetDrawColor( col.r, col.g, col.b, col.a )
        lastR, lastG, lastB, lastA = col.r, col.g, col.b, col.a
    end

    surface.DrawTexturedRect( x, y, w, h )
end

function ENT:DrawEqualiser( x, y, a, col )
    local c = Premul( col, a )
    surface.SetDrawColor( c.r, c.g, c.b, c.a )
    local barW, gap, maxH = 3, 2, HUD.DIMENSIONS.HEIGHT * 0.65
    for i = 1, HUD.EQUALIZER.BARS do
        local h = maxH * self.anim.equaliser[i]
        surface.DrawTexturedRect( x + ( i - 1 ) * ( barW + gap ), y - h * 0.5, barW, h )
    end
end

function ENT:GetStatusColour( st, ct )
    local sch = self:GetColorScheme()
    if st == rRadio.status.PLAYING then return sch.ACCENT end
    if st == rRadio.status.ERROR then return sch.ERROR end
    if st == rRadio.status.TUNING then
        local p = fastsin( ( ct or CurTime() ) * PULSE_SPEED ) * 0.5 + 0.5
        local c = self.tuningStatusColour or Color( 0, 0, 0, 255 )
        c.r = math_floor( sch.INACTIVE.r + ( sch.ACCENT.r - sch.INACTIVE.r ) * p )
        c.g = math_floor( sch.INACTIVE.g + ( sch.ACCENT.g - sch.INACTIVE.g ) * p )
        c.b = math_floor( sch.INACTIVE.b + ( sch.ACCENT.b - sch.INACTIVE.b ) * p )
        c.a = 255
        self.tuningStatusColour = c
        return c
    end
    return sch.INACTIVE
end

function ENT:RenderBasicHUD( st, station, a, pos, ang, sch )
    local bg = Premul( sch.BG, a )
    local txt = Premul( sch.TEXT, a )
    cam_Start3D2D( pos, ang, HUD_SCALE )
    surface.SetMaterial( MAT_RECT )
    fastRect( -self.halfWidth, -HUD_HALF_HEIGHT, self.cachedWidth, HUD_HEIGHT, bg )
    draw_SimpleText(
        self:GetDisplayTextBasic( st, station ), "rRadio.Roboto24",
        -self.halfWidth + PAD * 2, 0, txt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )
    cam_End3D2D()
end

function ENT:RenderHUD( eyePos )
    local distSqr = eyePos:DistToSqr( self:GetPos() )
    if distSqr > MODEL_CULL_DISTANCE_SQR then return end
    local a = math_Clamp( 255 * ( 1 - ( distSqr - FADE_START_SQR ) * FADE_RANGE_INV ), 0, 255 )
    if a <= 0 then return end
    local ct = CurTime()
    local isBasicHud = cvBasicHud:GetBool()
    local st, station
    if ct >= self.nextAnimTick then
        self.nextAnimTick = ct + HUD_TICK
        local nw = self[NWK]
        local localStatus = rRadio.cl.boomboxStatuses[self:EntIndex()]
        if localStatus and localStatus.stationStatus == rRadio.status.ERROR then
            st = rRadio.status.ERROR
            station = localStatus.stationName or ""
        else
            st = nw.Status or self:GetNWInt( "Status", rRadio.status.STOPPED )
            station = nw.StationName or self:GetNWString( "StationName", "" )
            if st == rRadio.status.PLAYING and not rRadio.cl.connectedStations[self] then st = rRadio.status.TUNING end
        end

        self.lastStatusRendered, self.lastStationRendered = st, station
        local live = rRadio.cl.entityVolumes or {}
        local vol = live[self] or live[self:EntIndex()] or 1
        if rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[self] then vol = 0 end
        vol = math_Clamp( vol * cvMaxVolume:GetFloat(), 0, 1 )
        if not isBasicHud then
            local now = ct
            local dtTick = now - ( self.lastAnimTime or now )
            self.lastAnimTime = now
            self:UpdateEqualiser( vol, dtTick * 2 )
            self:UpdateAnim( st, dtTick )
        end
    else
        st, station = self.lastStatusRendered, self.lastStationRendered
    end

    local sch = self:GetColorScheme()
    local statusCol = self:GetStatusColour( st, ct )
    local bg = Premul( sch.BG, a )
    local accBright = Premul( sch.ACCENT, a * ACCENT_ALPHA_BRIGHT )
    local txt = Premul( sch.TEXT, a * ( isBasicHud and 1 or self.anim.statusTransition ) )
    local pos = self:LocalToWorld( HUD_LOCAL_OFFSET )
    local ang = self:LocalToWorldAngles( HUD_ANG_OFFSET )
    if isBasicHud then
        self:RenderBasicHUD( st, station, a, pos, ang, sch )
        return
    end

    cam_Start3D2D( pos, ang, HUD_SCALE )
    surface.SetMaterial( MAT_RECT )
    fastRect( -self.halfWidth, -HUD_HALF_HEIGHT, self.cachedWidth, HUD_HEIGHT, bg )
    if st == rRadio.status.TUNING then
        local barW = self.cachedWidth * 0.3
        local off = self.anim.tuningOffset * ( self.cachedWidth - barW )
        fastRect(
            -self.halfWidth, HUD_HALF_HEIGHT - 2,
            self.cachedWidth, 2, Premul( sch.ACCENT, a * ACCENT_ALPHA_DIM )
        )
        fastRect( -self.halfWidth + off, HUD_HALF_HEIGHT - 2, barW, 2, accBright )
    else
        fastRect( -self.halfWidth, HUD_HALF_HEIGHT - 2, self.cachedWidth, 2, accBright )
    end

    if st ~= rRadio.status.PLAYING then
        fastRect( self.hudX, -HUD_HALF_HEIGHT + HUD_HEIGHT / 3, 4, HUD_HEIGHT / 3, Premul( statusCol, a ) )
    end
    local slideY = ( 1 - self.anim.statusTransition ) * 4
    draw_SimpleText(
        self:GetDisplayText( st, station ), "rRadio.Roboto24",
        self.hudX + HUD_ICON_OFFSET, slideY, txt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )
    if st == rRadio.status.PLAYING then self:DrawEqualiser( self.hudX, slideY, a, statusCol ) end
    cam_End3D2D()
end

function ENT:Draw()
    self:DrawModel()
end

hook.Add( "PostDrawOpaqueRenderables", "rRadio.DrawAllBoomboxHUDs", function()
    if not ( cvHud:GetBool() and cvEnabled:GetBool() ) then return end
    lastR, lastG, lastB, lastA = -1, -1, -1, -1
    local eye = LocalPlayer():EyePos()
    for ent in pairs( ActiveBoomboxes ) do
        if IsValid( ent ) then
            ent:RenderHUD( eye )
        else
            ActiveBoomboxes[ent] = nil
        end
    end
end )

local function clearCaches()
    initTexts()
    for k in pairs( entityColorSchemes ) do
        entityColorSchemes[k] = nil
    end

    for k, v in pairs( TEXT_WIDTH_CACHE ) do
        if not v.isStatic then TEXT_WIDTH_CACHE[k] = nil end
    end

    table.Empty( dynamicTextOrder )
    table.Empty( colour_cache )
    table.Empty( colour_cache_order )
end

hook.Add( "LanguageUpdated", "rRadio.BoomboxClearCaches", clearCaches )
hook.Add( "ThemeChanged", "rRadio.BoomboxClearCaches", clearCaches )
