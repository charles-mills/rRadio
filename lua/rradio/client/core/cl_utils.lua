rRadio.interface = rRadio.interface or {}
local ICON_VOL_MUTE = Material( "hud/vol_mute.png", "smooth" )
local ICON_VOL_DOWN = Material( "hud/vol_down.png", "smooth" )
local ICON_VOL_UP = Material( "hud/vol_up.png", "smooth" )
local stringLower = string.lower
local stringSub = string.sub
local stringFind = string.find
local utf8Len = utf8.len
local utf8Sub = utf8.sub
local IsValid = IsValid
local BASE_WIDTH = 2560
local MENU_SCALE_CVAR = "rammel_rradio_menu_scale"
local MENU_WIDTH_SCALE_CVAR = "rammel_rradio_menu_width_scale"
local scaleRatio = ScrW() / BASE_WIDTH
local menuFontScaleKey
function rRadio.cl.getEntityVolume( entity )
    if not IsValid( entity ) then return 0.5 end
    local vol = rRadio.cl.entityVolumes[entity]
    if vol then return vol end
    local cfg = rRadio.interface.getEntityConfig( entity )
    return cfg and cfg.Volume or 0.5
end

function rRadio.cl.updateVolumeIcon( volumeIcon, value )
    if not IsValid( volumeIcon ) then return end
    local v = type( value ) == "function" and value() or value
    volumeIcon:SetMaterial( rRadio.interface.GetVolumeIcon( v ) )
end

function rRadio.cl.sendPendingVolume()
    if not IsValid( rRadio.cl.pendingEntity ) then return end
    net.Start( "rRadio.SetRadioVolume" )
    net.WriteEntity( rRadio.cl.pendingEntity )
    net.WriteFloat( rRadio.cl.pendingVolume )
    net.SendToServer()
end

local function buildCharMap( s )
    local map = {}
    if not s then return map end
    s = stringLower( s )
    for i = 1, #s do
        local c = stringSub( s, i, i )
        map[c] = map[c] or {}
        map[c][#map[c] + 1] = i
    end
    return map
end

local function binarySearch( arr, last )
    local lo, hi = 1, #arr
    local result
    while lo <= hi do
        local mid = math.floor( ( lo + hi ) / 2 )
        if arr[mid] > last then
            result, hi = arr[mid], mid - 1
        else
            lo = mid + 1
        end
    end
    return result
end

local function subsequenceTest( needle, haystackMap )
    if #needle == 0 then return true end
    local lastPos = 0
    for i = 1, #needle do
        local c = stringSub( needle, i, i )
        local positions = haystackMap[c]
        if not positions then return false end
        lastPos = binarySearch( positions, lastPos )
        if not lastPos then return false end
    end
    return true
end

rRadio.interface.buildCharMap = buildCharMap
rRadio.interface.subsequenceTest = subsequenceTest

function rRadio.interface.ensureSearchFields( station )
    if not station or not station.name then return end
    station.nameLower = station.nameLower or string.lower( station.name )
    station.charMap = station.charMap or buildCharMap( station.name )
end
rRadio.interface.favoriteCountries = rRadio.interface.favoriteCountries or {}
rRadio.interface.favoriteStations = rRadio.interface.favoriteStations or {}
local DATA_DIR = "rradio"
rRadio.interface.favoriteCountriesFile = DATA_DIR .. "/favorite_countries.json"
rRadio.interface.favoriteStationsFile = DATA_DIR .. "/favorite_stations.json"
local SAVE_FAVORITES_TIMER = "rRadio.SaveFavorites"
local SAVE_FAVORITES_DELAY = 0.25
local function readJSON( path )
    if not file.Exists( path, "DATA" ) then return nil end
    local success, data = pcall( function() return util.JSONToTable( file.Read( path, "DATA" ) ) end )
    return success and data or nil
end

local function writeJSON( path, tbl )
    local json = util.TableToJSON( tbl, true )
    if not json then
        rRadio.logger.ErrorScope( "favorites", "Error converting table to JSON for", path )
        return
    end

    if file.Exists( path, "DATA" ) then file.Write( path .. ".bak", file.Read( path, "DATA" ) ) end
    file.Write( path, json )
end

local enabledCvar = GetConVar( "rammel_rradio_enabled" )
local function radioEnabled()
    return enabledCvar:GetBool()
end

if not file.IsDir( DATA_DIR, "DATA" ) then file.CreateDir( DATA_DIR ) end
local scaledFontCache = {}
hook.Add( "LanguageUpdated", "rRadio.ClearScaledFontCache", function() scaledFontCache = {} end )
local _lastVolumes = {}
local _volThreshold = 0.01
function rRadio.interface.scale( val )
    return val * scaleRatio
end

local function getScaleBounds( minKey, maxKey, defaultKey )
    local cfg = rRadio.config and rRadio.config.MenuScale or {}
    local minVal = tonumber( cfg[minKey] ) or tonumber( cfg[defaultKey] ) or 1
    local maxVal = tonumber( cfg[maxKey] ) or minVal
    if maxVal < minVal then maxVal = minVal end
    return minVal, maxVal
end

local function clampScale( scale, minKey, maxKey, defaultKey )
    local normalized = tonumber( scale ) or 1
    local minVal, maxVal = getScaleBounds( minKey, maxKey, defaultKey )
    return math.Round( math.Clamp( normalized, minVal, maxVal ), 2 )
end

function rRadio.interface.GetMenuScaleRange()
    return getScaleBounds( "Min", "Max", "Default" )
end

function rRadio.interface.GetMenuWidthScaleRange()
    return getScaleBounds( "WidthMin", "WidthMax", "WidthDefault" )
end

function rRadio.interface.GetMenuScaleDefault()
    local cfg = rRadio.config and rRadio.config.MenuScale or {}
    return tonumber( cfg.Default ) or 1.0
end

function rRadio.interface.GetMenuWidthScaleDefault()
    local cfg = rRadio.config and rRadio.config.MenuScale or {}
    return tonumber( cfg.WidthDefault ) or 1.0
end

function rRadio.interface.ClampMenuScale( scale )
    return clampScale( scale, "Min", "Max", "Default" )
end

function rRadio.interface.ClampMenuWidthScale( scale )
    return clampScale( scale, "WidthMin", "WidthMax", "WidthDefault" )
end

function rRadio.interface.GetMenuScale()
    if rRadio.cl and rRadio.cl.menuScale then return rRadio.interface.ClampMenuScale( rRadio.cl.menuScale ) end
    local cvar = GetConVar( MENU_SCALE_CVAR )
    if not cvar then return 1 end
    return rRadio.interface.ClampMenuScale( cvar:GetFloat() )
end

function rRadio.interface.GetMenuWidthScale()
    if rRadio.cl and rRadio.cl.menuWidthScale then return rRadio.interface.ClampMenuWidthScale( rRadio.cl.menuWidthScale ) end
    local cvar = GetConVar( MENU_WIDTH_SCALE_CVAR )
    if not cvar then return 1 end
    return rRadio.interface.ClampMenuWidthScale( cvar:GetFloat() )
end

function rRadio.interface.SetMenuScale( scale, persist )
    local clamped = rRadio.interface.ClampMenuScale( scale )
    if rRadio.cl then rRadio.cl.menuScale = clamped end
    rRadio.interface.RefreshMenuFonts()
    if persist then RunConsoleCommand( MENU_SCALE_CVAR, string.format( "%.2f", clamped ) ) end
    return clamped
end

function rRadio.interface.SetMenuWidthScale( scale, persist )
    local clamped = rRadio.interface.ClampMenuWidthScale( scale )
    if rRadio.cl then rRadio.cl.menuWidthScale = clamped end
    if persist then RunConsoleCommand( MENU_WIDTH_SCALE_CVAR, string.format( "%.2f", clamped ) ) end
    return clamped
end

function rRadio.interface.scaleMenu( val )
    return rRadio.interface.scale( val ) * rRadio.interface.GetMenuScale()
end

local CONTROL_CORNER_RADIUS = 8
local CONTROL_BORDER_WIDTH = 1

function rRadio.interface.GetControlCornerRadius()
    return CONTROL_CORNER_RADIUS
end

function rRadio.interface.GetControlBorderWidth()
    return CONTROL_BORDER_WIDTH
end

function rRadio.interface.GetControlBorderColor()
    return rRadio.config.UI.Border
        or rRadio.config.UI.ScrollbarGripColor
        or rRadio.config.UI.ScrollbarColor
        or rRadio.config.UI.TextColor
end

function rRadio.interface.GetSurfaceColor( tier )
    if tier == "frame" then return rRadio.config.UI.SurfaceFrameColor end
    if tier == "panel" then return rRadio.config.UI.SurfacePanelColor end
    if tier == "card" then return rRadio.config.UI.SurfaceCardColor end
    if tier == "card_hover" then return rRadio.config.UI.SurfaceCardHoverColor end
    return nil
end

function rRadio.interface.DrawBorderedRoundedBox( radius, x, y, w, h, fillColor, borderColor, borderWidth )
    local cornerRadius = math.max( 0, math.floor( tonumber( radius ) or CONTROL_CORNER_RADIUS ) )
    local borderPx = math.max( 1, math.floor( tonumber( borderWidth ) or CONTROL_BORDER_WIDTH ) )
    local px = x or 0
    local py = y or 0
    local pw = math.max( 0, w or 0 )
    local ph = math.max( 0, h or 0 )
    local baseColor = fillColor or rRadio.interface.GetSurfaceColor( "card" ) or rRadio.config.UI.ButtonColor
    local edgeColor = borderColor or rRadio.interface.GetControlBorderColor()
    draw.RoundedBox( cornerRadius, px, py, pw, ph, edgeColor )
    local innerW = pw - borderPx * 2
    local innerH = ph - borderPx * 2
    if innerW <= 0 or innerH <= 0 then return end
    draw.RoundedBox(
        math.max( 0, cornerRadius - borderPx ),
        px + borderPx,
        py + borderPx,
        innerW,
        innerH,
        baseColor
    )
end

function rRadio.interface.styleSliderPaint( slider, trackRatio )
    local Scale = rRadio.interface.scaleMenu
    slider.Slider.Paint = function( self, w, h )
        local trackHeight = math.max( Scale( 4 ), math.floor( h * ( trackRatio or 0.24 ) ) )
        local y = math.floor( ( h - trackHeight ) / 2 )
        local knobInset = IsValid( self.Knob ) and math.floor( self.Knob:GetWide() * 0.5 ) or 0
        local trackW = math.max( Scale( 10 ), w - knobInset * 2 )
        draw.RoundedBox( math.floor( trackHeight / 2 ), knobInset, y, trackW, trackHeight, rRadio.config.UI.TextColor )
    end
    slider.Slider.Knob.Paint = function( _self, w, h )
        draw.RoundedBox( math.floor( math.min( w, h ) / 2 ), 0, 0, w, h, rRadio.config.UI.BackgroundColor )
    end
end

function rRadio.interface.RefreshMenuFonts( force )
    local menuScale = rRadio.interface.GetMenuScale()
    local scaleKey = math.floor( menuScale * 100 + 0.5 )
    if not force and menuFontScaleKey == scaleKey then return end
    menuFontScaleKey = scaleKey
    surface.CreateFont( "rRadio.Roboto4", {
        font = "Roboto",
        size = math.max( 9, math.floor( ScreenScale( 4 ) * menuScale ) ),
        weight = 500,
        antialias = true,
        extended = true
    } )

    surface.CreateFont( "rRadio.Roboto5", {
        font = "Roboto",
        size = math.max( 10, math.floor( ScreenScale( 5 ) * menuScale ) ),
        weight = 500,
        antialias = true,
        extended = true
    } )

    surface.CreateFont( "rRadio.Roboto8", {
        font = "Roboto",
        size = math.max( 12, math.floor( ScreenScale( 8 ) * menuScale ) ),
        weight = 700,
        antialias = true,
        extended = true
    } )
end

function rRadio.interface.playSound( sound )
    if not rRadio.config.EnableSoundEffects then return end
    if not rRadio.config.Sounds[sound] then return end
    surface.PlaySound( rRadio.config.Sounds[sound] )
end

function rRadio.interface.refreshVolume( ent )
    local src = rRadio.cl.radioSources[ent]
    if not ( IsValid( ent ) and IsValid( src ) ) then return end
    local ply = LocalPlayer()
    local dist = ply:GetPos():DistToSqr( ent:GetPos() )
    local inCar = rRadio.utils.GetVehicle( ply:GetVehicle() ) == ent
    rRadio.interface.updateRadioVolume( src, dist, inCar, ent )
end

local function fuzzyMatchLowered( lowerNeedle, lowerHaystack )
    local nLen = #lowerNeedle
    if nLen == 0 then return 1 end
    local hLen = #lowerHaystack
    local scoreSum = 0
    local lastPos = 1
    for i = 1, nLen do
        local c = stringSub( lowerNeedle, i, i )
        local found = stringFind( lowerHaystack, c, lastPos, true )
        if not found then return 0 end
        scoreSum = scoreSum + 1 - ( found - lastPos ) / hLen
        lastPos = found + 1
    end
    return scoreSum / nLen
end

local function ensureSearchMetadata( item, keyFn )
    local text = item.searchText
    if text == nil then
        text = keyFn( item ) or ""
        item.searchText = text
    end

    local lower = item.searchTextLower
    if lower == nil then
        lower = stringLower( text )
        item.searchTextLower = lower
    end

    local map = item.charMap
    if map == nil then
        map = buildCharMap( lower )
        item.charMap = map
    end
    return text, lower, map
end

local function fuzzyFilterCore( needle, items, keyFn, minScore, boostFn )
    local lowerNeedle = stringLower( needle or "" )
    local hasNeedle = #lowerNeedle > 0
    local matches = {}
    for _, item in ipairs( items ) do
        local _, lowerText, map = ensureSearchMetadata( item, keyFn )
        if not hasNeedle or map and rRadio.interface.subsequenceTest( lowerNeedle, map ) then
            local score = hasNeedle and fuzzyMatchLowered( lowerNeedle, lowerText ) or 1
            if boostFn then score = score + ( boostFn( item ) or 0 ) end
            if score >= ( minScore or 0 ) then
                matches[#matches + 1] = {
                    item = item,
                    score = score,
                    sortKey = lowerText
                }
            end
        end
    end

    if #matches == 0 then
        for _, item in ipairs( items ) do
            local _, lowerText = ensureSearchMetadata( item, keyFn )
            matches[#matches + 1] = {
                item = item,
                score = 0,
                sortKey = lowerText
            }
        end
    end

    table.sort( matches, function( a, b )
        if a.score ~= b.score then return a.score > b.score end
        return a.sortKey < b.sortKey
    end )

    local results, seen = {}, {}
    for _, v in ipairs( matches ) do
        if not seen[v.sortKey] then
            seen[v.sortKey] = true
            results[#results + 1] = v.item
        end
    end
    return results
end

rRadio.interface.fuzzyFilter = function(
    needle, items, keyFn, minScore, boostFn
)
    return fuzzyFilterCore( needle, items, keyFn, minScore, boostFn )
end

function rRadio.interface.MakeIconButton( parent, materialPath, url, xOffset )
    local icon = vgui.Create( "rRadioIconButton", parent )
    local size = rRadio.interface.scaleMenu( 32 )
    icon:SetSize( size, size )
    icon:SetPos( xOffset, ( parent:GetTall() - size ) / 2 )
    icon:SetIcon( materialPath )
    icon:SetURL( url )
    return icon
end

function rRadio.interface.TruncateText( text, font, maxWidth )
    surface.SetFont( font )
    local textW = surface.GetTextSize( text )
    if textW <= maxWidth then return text end
    local ellipsis = "..."
    local suffixW = surface.GetTextSize( ellipsis )
    local len = utf8Len( text )
    local low, high, best = 1, len, 0
    while low <= high do
        local mid = math.floor( ( low + high ) / 2 )
        local substr = utf8Sub( text, 1, mid )
        local w = surface.GetTextSize( substr )
        if w + suffixW <= maxWidth then
            best = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return utf8Sub( text, 1, best ) .. ellipsis
end

function rRadio.interface.TruncateChars( text, maxChars )
    if utf8Len( text ) <= maxChars then return text end
    return utf8Sub( text, 1, maxChars )
end

function rRadio.interface.StyleVBar( vbar )
    if not IsValid( vbar ) then return end
    vbar:SetWide( rRadio.interface.scaleMenu( 8 ) )
    if vbar.DockMargin then
        vbar:DockMargin(
            0,
            rRadio.interface.scaleMenu( 2 ),
            rRadio.interface.scaleMenu( 2 ),
            rRadio.interface.scaleMenu( 2 )
        )
    end
    vbar.Paint = function( _self, w, h )
        draw.RoundedBox( 8, 0, 0, w, h, rRadio.config.UI.ScrollbarColor )
    end
    if IsValid( vbar.btnGrip ) then vbar.btnGrip:SetCursor( "sizens" ) end
    vbar.btnGrip.Paint = function( _self, w, h )
        draw.RoundedBox(
            8, 0, 0, w, h, rRadio.config.UI.ScrollbarGripColor
        )
    end
    vbar.btnUp.Paint = function( _self, _w, _h ) end
    vbar.btnDown.Paint = function( _self, _w, _h ) end
end

function rRadio.interface.DisplayVehicleEnterAnimation( argVehicle, isDriverOverride )
    rRadio.logger.DebugScope( "cl_utils", "Displaying vehicle enter animation" )
    if not radioEnabled() then
        rRadio.logger.DebugScope( "cl_utils", "Radio disabled" )
        return
    end

    if not GetConVar( "rammel_rradio_vehicle_animation" ):GetBool() then
        rRadio.logger.DebugScope( "cl_utils", "Vehicle animation disabled" )
        return
    end

    local ply = LocalPlayer()
    rRadio.logger.DebugScope(
        "cl_utils", "argVehicle:", tostring( argVehicle ),
        "ply:GetVehicle():", tostring( ply:GetVehicle() )
    )
    local vehicle = argVehicle or ply:GetVehicle()
    if IsValid( vehicle ) then
        rRadio.logger.DebugScope(
            "cl_utils", "vehicle class:",
            vehicle:GetClass(), "entIndex:", vehicle:EntIndex()
        )
    else
        rRadio.logger.DebugScope( "cl_utils", "vehicle is invalid" )
    end

    if not IsValid( vehicle ) then
        rRadio.logger.DebugScope( "cl_utils", "Player is not in a vehicle" )
        return
    end

    local mainVehicle = rRadio.utils.GetVehicle( vehicle )
    rRadio.logger.DebugScope(
        "cl_utils", "mainVehicle:", tostring( mainVehicle ),
        IsValid( mainVehicle )
            and "class: " .. mainVehicle:GetClass()
                .. ", entIndex: " .. mainVehicle:EntIndex()
            or ""
    )
    if not IsValid( mainVehicle ) then
        rRadio.logger.DebugScope( "cl_utils", "Vehicle is not valid" )
        return
    end

    if hook.Run( "rRadio.CanOpenMenu", ply, mainVehicle ) == false then
        rRadio.logger.DebugScope( "cl_utils", "Hook disallowed" )
        return
    end

    if rRadio.config.DriverPlayOnly then
        local ok = isDriverOverride ~= nil and isDriverOverride or mainVehicle:GetDriver() == ply
        if not ok then
            rRadio.logger.DebugScope( "cl_utils", "Player is not the driver" )
            return
        end
    end

    if rRadio.utils.IsSitAnywhereSeat( mainVehicle ) then
        rRadio.logger.DebugScope( "cl_utils", "Player is in a sit anywhere seat" )
        return
    end

    ply.currentRadioEntity = mainVehicle
    rRadio.logger.DebugScope( "cl_utils", "Vehicle animation conditions met" )
    local currentTime = CurTime()
    local cooldownTime = rRadio.config.MessageCooldown
    if isMessageAnimating or lastMessageTime and currentTime - lastMessageTime < cooldownTime then
        rRadio.logger.DebugScope( "cl_utils", "Animation is already playing or cooldown not met" )
        return
    end

    rRadio.logger.DebugScope( "cl_utils", "Animation cooldown met" )
    lastMessageTime = currentTime
    isMessageAnimating = true
    local openKey = GetConVar( "rammel_rradio_menu_key" ):GetInt()
    local keyName = rRadio.GetKeyName( openKey )
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth = rRadio.interface.scale( 300 )
    local panelHeight = rRadio.interface.scale( 70 )
    local panel = vgui.Create( "DButton" )
    panel:SetSize( panelWidth, panelHeight )
    panel:SetPos( scrW, scrH * 0.2 )
    panel:SetText( "" )
    panel:MoveToFront()
    local animDuration = 1
    local showDuration = 2
    local startTime = CurTime()
    local alpha = 0
    local pulseValue = 0
    local isDismissed = false
    panel.DoClick = function()
        rRadio.interface.playSound( "ButtonPressMain" )
        rRadio.cl.openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function( self, w, h )
        local bgColor = rRadio.config.UI.HeaderColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(
            math.min( bgColor.r * hoverBrightness, 255 ),
            math.min( bgColor.g * hoverBrightness, 255 ),
            math.min( bgColor.b * hoverBrightness, 255 ),
            alpha * 255
        )
        draw.RoundedBoxEx( 12, 0, 0, w, h, bgColor, true, false, true, false )
        local keyWidth = rRadio.interface.scale( 40 )
        local keyHeight = rRadio.interface.scale( 30 )
        local keyX = rRadio.interface.scale( 20 )
        local keyY = h / 2 - keyHeight / 2
        local pulseScale = 1 + math.sin( pulseValue * math.pi * 2 ) * 0.05
        local adjustedKeyWidth = keyWidth * pulseScale
        local adjustedKeyHeight = keyHeight * pulseScale
        local adjustedKeyX = keyX - ( adjustedKeyWidth - keyWidth ) / 2
        local adjustedKeyY = keyY - ( adjustedKeyHeight - keyHeight ) / 2
        draw.RoundedBox(
            6, adjustedKeyX, adjustedKeyY,
            adjustedKeyWidth, adjustedKeyHeight,
            ColorAlpha( rRadio.config.UI.ButtonColor, alpha * 255 )
        )
        surface.SetDrawColor(
            ColorAlpha( rRadio.config.UI.TextColor, alpha * 50 )
        )
        local lineX = keyX + keyWidth + rRadio.interface.scale( 7 )
        surface.DrawLine( lineX, h * 0.3, lineX, h * 0.7 )
        draw.SimpleText(
            keyName, "rRadio.Roboto5",
            keyX + keyWidth / 2, h / 2,
            ColorAlpha( rRadio.config.UI.TextColor, alpha * 255 ),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        local messageX = keyX + keyWidth + rRadio.interface.scale( 15 )
        draw.SimpleText(
            rRadio.L( "ToOpenRadio", "to open radio" ),
            "rRadio.Roboto5", messageX, h / 2,
            ColorAlpha( rRadio.config.UI.TextColor, alpha * 255 ),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end

    panel.Think = function( self )
        local time = CurTime() - startTime
        pulseValue = ( pulseValue + FrameTime() * 1.5 ) % 1
        if time < animDuration then
            local progress = time / animDuration
            local easedProgress = math.ease.OutQuint( progress )
            self:SetPos( Lerp( easedProgress, scrW, scrW - panelWidth ), scrH * 0.2 )
            alpha = math.ease.InOutQuad( progress )
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos( scrW - panelWidth, scrH * 0.2 )
        elseif not isDismissed or time >= animDuration + showDuration then
            local progress = ( time - ( animDuration + showDuration ) ) / animDuration
            local easedProgress = math.ease.InOutQuint( progress )
            self:SetPos( Lerp( easedProgress, scrW - panelWidth, scrW ), scrH * 0.2 )
            alpha = 1 - math.ease.InOutQuad( progress )
            if progress >= 1 then
                isMessageAnimating = false
                self:Remove()
            end
        end
    end

    panel.OnRemove = function() isMessageAnimating = false end
end

function rRadio.interface.applyTheme( themeName )
    if rRadio.themes[themeName] then
        rRadio.config.UI = rRadio.themes[themeName]
        hook.Run( "ThemeChanged", themeName )
    else
        rRadio.logger.WarnScope( "theme", "Invalid theme name:", themeName )
    end
end

function rRadio.interface.loadSavedSettings()
    local themeName = GetConVar( "rammel_rradio_menu_theme" ):GetString()
    rRadio.interface.applyTheme( themeName )
end

function rRadio.interface.updateStationCount()
    local count = 0
    for ent, source in pairs( rRadio.cl.radioSources or {} ) do
        if IsValid( ent ) and IsValid( source ) then
            count = count + 1
        else
            if IsValid( source ) then source:Stop() end
            if rRadio.cl.radioSources then rRadio.cl.radioSources[ent] = nil end
        end
    end

    activeStationCount = count
    return count
end

function rRadio.interface.LerpColor( t, col1, col2 )
    return Color(
        Lerp( t, col1.r, col2.r ),
        Lerp( t, col1.g, col2.g ),
        Lerp( t, col1.b, col2.b ),
        Lerp( t, col1.a or 255, col2.a or 255 )
    )
end

function rRadio.interface.ClampVolume( volume )
    local clientMax = GetConVar( "rammel_rradio_max_volume" ):GetFloat()
    local limit = math.min( rRadio.config.MaxVolume, clientMax )
    return rRadio.utils.ClampVolume( volume, limit )
end

local function sanitizeFavoriteStations( source )
    local result = {}
    for country, stations in pairs( source ) do
        if type( country ) == "string" and type( stations ) == "table" then
            result[country] = {}
            for stationName, isFavorite in pairs( stations ) do
                if type( stationName ) == "string" and type( isFavorite ) == "boolean" then
                    result[country][stationName] = isFavorite
                end
            end

            if next( result[country] ) == nil then result[country] = nil end
        end
    end
    return result
end

function rRadio.interface.loadFavorites()
    local favoriteCountries = {}
    local favoriteStations = {}
    local data = readJSON( rRadio.interface.favoriteCountriesFile )
    if data then
        for _, country in ipairs( data ) do
            if type( country ) == "string" then favoriteCountries[country] = true end
        end
    elseif file.Exists( rRadio.interface.favoriteCountriesFile, "DATA" ) then
        rRadio.logger.WarnScope( "favorites", "Error loading favorite countries, resetting file" )
        favoriteCountries = {}
        rRadio.interface.saveFavorites()
    end

    local dataStations = readJSON( rRadio.interface.favoriteStationsFile )
    if dataStations then
        favoriteStations = sanitizeFavoriteStations( dataStations )
    elseif file.Exists( rRadio.interface.favoriteStationsFile, "DATA" ) then
        rRadio.logger.WarnScope( "favorites", "Error loading favorite stations, resetting file" )
        favoriteStations = {}
        rRadio.interface.saveFavorites()
    end

    rRadio.interface.favoriteCountries = favoriteCountries
    rRadio.interface.favoriteStations = favoriteStations
end

local function writeFavorites()
    local favoriteCountries = rRadio.interface.favoriteCountries or {}
    local favoriteStations = rRadio.interface.favoriteStations or {}
    local favCountriesList = {}
    for country, _ in pairs( favoriteCountries ) do
        if type( country ) == "string" then table.insert( favCountriesList, country ) end
    end

    writeJSON( rRadio.interface.favoriteCountriesFile, favCountriesList )
    writeJSON( rRadio.interface.favoriteStationsFile, sanitizeFavoriteStations( favoriteStations ) )
end

function rRadio.interface.saveFavorites()
    timer.Remove( SAVE_FAVORITES_TIMER )
    timer.Create( SAVE_FAVORITES_TIMER, SAVE_FAVORITES_DELAY, 1, writeFavorites )
end

function rRadio.interface.toggleFavorite( list, key, subkey )
    if subkey then
        list[key] = list[key] or {}
        if list[key][subkey] then
            list[key][subkey] = nil
            if not next( list[key] ) then list[key] = nil end
        else
            list[key][subkey] = true
        end
    else
        if list[key] then
            list[key] = nil
        else
            list[key] = true
        end
    end

    rRadio.interface.saveFavorites()
end

function rRadio.interface.getEntityConfig( entity )
    return rRadio.utils.GetEntityConfig( entity )
end

function rRadio.interface.CalculateVolume( entity, player, distanceSqr )
    if not IsValid( entity ) or not IsValid( player ) then return 0 end
    local entityConfig = rRadio.utils.GetEntityConfig( entity )
    if not entityConfig then return 0 end
    local baseVolume = rRadio.cl.entityVolumes[entity] ~= nil
        and rRadio.cl.entityVolumes[entity]
        or entity:GetNWFloat( "Volume", entityConfig.Volume )
    if player:GetVehicle() == entity
        or distanceSqr <= entityConfig.MinVolumeDistance ^ 2
    then
        return baseVolume
    end
    local maxDist = entityConfig.MaxHearingDistance
    local distance = math.sqrt( distanceSqr )
    if distance >= maxDist then return 0 end
    local falloff = 1 - math.Clamp(
        ( distance - entityConfig.MinVolumeDistance )
            / ( maxDist - entityConfig.MinVolumeDistance ),
        0, 1
    )
    return baseVolume * falloff
end

local function silenceIfChanged( station, entity )
    local prev = _lastVolumes[entity] or -1
    if prev ~= 0 then
        station:SetVolume( 0 )
        _lastVolumes[entity] = 0
    end
end

function rRadio.interface.updateRadioVolume( station, distanceSqr, isPlayerInCar, entity )
    if not radioEnabled() then
        silenceIfChanged( station, entity )
        return
    end

    if rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[entity] then
        silenceIfChanged( station, entity )
        return
    end

    local entityConfig = rRadio.interface.getEntityConfig( entity )
    if not entityConfig then return end
    local userVolume = rRadio.interface.ClampVolume(
        rRadio.cl.entityVolumes[entity]
            or entity:GetNWFloat( "Volume", entityConfig.Volume )
    )
    if userVolume <= 0.02 then
        silenceIfChanged( station, entity )
        return
    end

    if isPlayerInCar then
        station:Set3DEnabled( false )
        local prev = _lastVolumes[entity] or -1
        if math.abs( userVolume - prev ) >= _volThreshold then
            station:SetVolume( userVolume )
            _lastVolumes[entity] = userVolume
        end
        return
    end

    station:Set3DEnabled( true )
    local minDist = entityConfig.MinVolumeDistance
    local maxDist = entityConfig.MaxHearingDistance
    station:Set3DFadeDistance( minDist, maxDist )
    local finalVolume = rRadio.interface.CalculateVolume( entity, LocalPlayer(), distanceSqr )
    finalVolume = rRadio.interface.ClampVolume( finalVolume )
    local prev = _lastVolumes[entity] or -1
    if math.abs( finalVolume - prev ) >= _volThreshold then
        station:SetVolume( finalVolume )
        _lastVolumes[entity] = finalVolume
    end
end

local function getScaledFont( prefix, text, buttonWidth, buttonHeight )
    local key = prefix .. "_" .. text .. "_" .. math.floor( buttonHeight )
    if scaledFontCache[key] then return scaledFontCache[key] end
    local maxFontSize = math.floor( buttonHeight * 0.7 )
    local fontName = prefix .. "Font_" .. key
    surface.CreateFont( fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    } )

    surface.SetFont( fontName )
    local textWidth = surface.GetTextSize( text )
    while textWidth > buttonWidth * 0.9 and maxFontSize > 10 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont( fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        } )

        surface.SetFont( fontName )
        textWidth = surface.GetTextSize( text )
    end

    scaledFontCache[key] = fontName
    return fontName
end

function rRadio.interface.calculateFontSizeForStopButton( text, buttonWidth, buttonHeight )
    return getScaledFont( "Stop", text, buttonWidth, buttonHeight )
end

function rRadio.interface.calculateFontSizeForGlobalButton( text, buttonWidth, buttonHeight )
    return getScaledFont( "Global", text, buttonWidth, buttonHeight )
end

function rRadio.interface.GetVolumeIcon( vol )
    local maxVol = rRadio.config.MaxVolume or 1.0
    vol = math.min( vol, maxVol )
    if vol < 0.01 then
        return ICON_VOL_MUTE
    elseif vol <= 0.65 then
        return ICON_VOL_DOWN
    else
        return ICON_VOL_UP
    end
end

local function loadLanguage()
    rRadio.LanguageManager:UpdateCurrentLanguage()
    hook.Run( "LanguageUpdated" )
end

loadLanguage()
rRadio.interface.RefreshMenuFonts( true )
cvars.AddChangeCallback( "gmod_language", function() loadLanguage() end )
local function relayoutIfOpen()
    if rRadio.cl and rRadio.cl.uiState
        and rRadio.cl.uiState.radioMenuOpen
        and isfunction( rRadio.cl.relayoutRadioMenu )
    then
        rRadio.cl.relayoutRadioMenu( true )
    end
end

cvars.AddChangeCallback( MENU_SCALE_CVAR, function( _, _, new )
    if rRadio.cl then
        rRadio.cl.menuScale = rRadio.interface.ClampMenuScale( new )
    end
    rRadio.interface.RefreshMenuFonts( true )
    relayoutIfOpen()
end, "rRadioMenuScaleCB" )

cvars.AddChangeCallback( MENU_WIDTH_SCALE_CVAR, function( _, _, new )
    if rRadio.cl then
        rRadio.cl.menuWidthScale =
            rRadio.interface.ClampMenuWidthScale( new )
    end
    relayoutIfOpen()
end, "rRadioMenuWidthScaleCB" )

hook.Add( "OnScreenSizeChanged", "rRadio.RecalcScale", function()
    scaleRatio = ScrW() / BASE_WIDTH
    rRadio.interface.RefreshMenuFonts( true )
    relayoutIfOpen()
end )

function rRadio.GetKeyName( keyCode )
    local name = input.GetKeyName( keyCode )
    if not name then return "the Open Key" end
    return name:gsub( "_", " " ):gsub( "(%a)([%w]*)", function( first, rest )
        return first:upper() .. rest:lower()
    end )
end

local BLOCKED_MENU_KEYS = {
    [MOUSE_LEFT] = true
}

function rRadio.RejectBlockedMenuKey( binder )
    if not BLOCKED_MENU_KEYS[binder:GetSelectedNumber()] then return false end
    binder:SetValue( GetConVar( "rammel_rradio_menu_key" ):GetInt() )
    return true
end
