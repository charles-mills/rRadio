rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.theme = rRadio.client.hud.theme or {}

local theme = rRadio.client.hud.theme

local GOLD_SCHEME = {
    background = Color( 20, 20, 20 ),
    accent = Color( 255, 215, 0 ),
    text = Color( 255, 248, 220 ),
    inactive = Color( 218, 165, 32 ),
    error = Color( 232, 76, 61 ),
    shadow = Color( 0, 0, 0, 190 )
}

local normalScheme


local function isGoldThemeEnabled()
    local conVar = GetConVar( "rammel_rradio_gold_boombox_theme" )
    return not conVar or conVar:GetBool()
end


local function buildNormalScheme()
    local ui = rRadio.config.UI

    normalScheme = {
        background = ui.BackgroundColor or Color( 18, 18, 18 ),
        accent = ui.AccentPrimary or ui.Highlight or Color( 57, 255, 20 ),
        text = ui.TextColor or Color( 255, 255, 255 ),
        inactive = ui.Disabled or ui.ScrollbarGripColor or ui.TextColor or Color( 160, 160, 160 ),
        error = ui.Error or Color( 248, 81, 73 ),
        shadow = Color( 0, 0, 0, 190 )
    }
end


function theme.GetScheme( view )
    if view.isGolden and isGoldThemeEnabled() then return GOLD_SCHEME end
    if not normalScheme then buildNormalScheme() end

    return normalScheme
end


function theme.ClearCaches()
    normalScheme = nil
end


return theme
