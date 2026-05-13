rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}

local boomboxHud = rRadio.client.hud
local textModule = boomboxHud.text
local layout = boomboxHud.layout
local renderer = boomboxHud.renderer
local paint = boomboxHud.paint
local stateModule = boomboxHud.state
local visibility = boomboxHud.visibility
local theme = boomboxHud.theme

local HOOK_ID = "rRadio_BoomboxHUD_DrawAll"
local MODE_CALLBACK_ID = "rRadio.BoomboxHUDModeChanged"
local GOLD_THEME_CALLBACK_ID = "rRadio.BoomboxHUDGoldThemeChanged"
local RENDER_BOUNDS_EXTRA_Z = 20

local initialized = false
local conVars = {}


local function addExistingEntitiesByClass( className )
    for _, entity in ipairs( ents.FindByClass( className ) ) do
        boomboxHud.Register( entity )
    end
end


local function registerExistingEntities()
    local classes = rRadio.constants.EntityClasses
    addExistingEntitiesByClass( classes.BOOMBOX )
    addExistingEntitiesByClass( classes.GOLDEN_BOOMBOX )
end


local function shouldDraw()
    if visibility.CountRegistered() <= 0 then return false end
    if not conVars.enabled:GetBool() then return false end
    if not conVars.boomboxHud:GetBool() then return false end

    return true
end


local function getHudMode()
    local value = conVars.hudMode:GetString()
    if value == "basic" or value == "compact" then return "basic" end

    return "full"
end


local function drawAll()
    if not shouldDraw() then return end

    local player = LocalPlayer()
    if not IsValid( player ) then return end

    local now = CurTime()
    local mode = getHudMode()
    local maxVolume = conVars.maxVolume:GetFloat()

    visibility.Refresh( player, now )

    local visibleStates, visibleCount = visibility.GetVisible()
    if visibleCount <= 0 then return end

    renderer.BeginFrame()
    for index = 1, visibleCount do
        local hudState = visibleStates[index]
        if IsValid( hudState.entity ) then
            stateModule.RefreshPresentation( hudState, now, mode, maxVolume )
            if hudState.layoutDirty then layout.Rebuild( hudState ) end

            stateModule.UpdateAnimation( hudState, now )
            stateModule.UpdateTransform( hudState )
            stateModule.UpdateColors( hudState, theme.GetScheme( hudState ) )

            renderer.BeginHud( hudState )
                paint.Paint( hudState, renderer )
            renderer.EndHud()
        end
    end
end


function boomboxHud.Register( entity )
    if not IsValid( entity ) then return end

    boomboxHud.ApplyRenderBounds( entity )
    visibility.Register( entity )
end


function boomboxHud.Unregister( entity )
    visibility.Unregister( entity )
end


function boomboxHud.ApplyRenderBounds( entity )
    if not IsValid( entity ) then return end

    local mins, maxs = entity:GetModelBounds()
    maxs.z = maxs.z + RENDER_BOUNDS_EXTRA_Z
    entity:SetRenderBounds( mins, maxs )
end


function boomboxHud.ClearCaches()
    textModule.ClearCaches()
    theme.ClearCaches()
    stateModule.ClearStaticTexts()
    visibility.MarkAllLayoutDirty()
end


function boomboxHud.GetStats()
    local visibilityStats = visibility.GetStats()
    local textStats = textModule.GetStats()

    return {
        registered = visibilityStats.registered,
        visible = visibilityStats.visible,
        maxVisible = visibilityStats.maxVisible,
        lastRefresh = visibilityStats.lastRefresh,
        measuredTexts = textStats.measuredTexts,
        fittedTexts = textStats.fittedTexts
    }
end


function boomboxHud.Init()
    if initialized then return end
    initialized = true

    conVars.enabled = GetConVar( "rammel_rradio_enabled" )
    conVars.boomboxHud = GetConVar( "rammel_rradio_boombox_hud" )
    conVars.hudMode = GetConVar( "rammel_rradio_boombox_hud_mode" )
    conVars.maxVolume = GetConVar( "rammel_rradio_max_volume" )

    textModule.Init()
    registerExistingEntities()

    cvars.AddChangeCallback( "rammel_rradio_boombox_hud_mode", function()
        visibility.MarkAllLayoutDirty()
    end, MODE_CALLBACK_ID )

    cvars.AddChangeCallback( "rammel_rradio_gold_boombox_theme", boomboxHud.ClearCaches, GOLD_THEME_CALLBACK_ID )

    hook.Add( "PostDrawOpaqueRenderables", HOOK_ID, drawAll )
    hook.Add( "rRadio_LanguageChanged", "rRadio_BoomboxHUD_ClearCaches", boomboxHud.ClearCaches )
    hook.Add( "rRadio_ThemeChanged", "rRadio_BoomboxHUD_ClearCaches", boomboxHud.ClearCaches )
end


return boomboxHud
