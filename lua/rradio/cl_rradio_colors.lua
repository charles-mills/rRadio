RRADIO = RRADIO or {}
RRADIO.Colors = {
    BG_LIGHT = Color(255, 255, 255),
    BG_DARK = Color(18, 18, 18),
    TEXT_LIGHT = Color(0, 0, 0),
    TEXT_DARK = Color(255, 255, 255),
    ACCENT = Color(0, 122, 255),
    BUTTON_LIGHT = Color(240, 240, 240),
    BUTTON_DARK = Color(30, 30, 30),
    BUTTON_HOVER_LIGHT = Color(230, 230, 230),
    BUTTON_HOVER_DARK = Color(40, 40, 40),
    DIVIDER_LIGHT = Color(200, 200, 200),
    DIVIDER_DARK = Color(50, 50, 50),
    SCROLL_BG_LIGHT = Color(245, 245, 247),
    SCROLL_BG_DARK = Color(28, 28, 30),
    TEXT_PLACEHOLDER_LIGHT = Color(150, 150, 150),
    TEXT_PLACEHOLDER_DARK = Color(120, 120, 120),
}

RRADIO.DarkModeConVar = CreateClientConVar("rradio_dark_mode", "0", true, false, "Toggle dark mode for rRadio")

function RRADIO.GetColors()
    local isDarkMode = RRADIO.DarkModeConVar:GetBool()
    local colors = {
        bg = isDarkMode and RRADIO.Colors.BG_DARK or RRADIO.Colors.BG_LIGHT,
        text = isDarkMode and RRADIO.Colors.TEXT_DARK or RRADIO.Colors.TEXT_LIGHT,
        button = isDarkMode and RRADIO.Colors.BUTTON_DARK or RRADIO.Colors.BUTTON_LIGHT,
        buttonHover = isDarkMode and RRADIO.Colors.BUTTON_HOVER_DARK or RRADIO.Colors.BUTTON_HOVER_LIGHT,
        divider = isDarkMode and RRADIO.Colors.DIVIDER_DARK or RRADIO.Colors.DIVIDER_LIGHT,
        accent = RRADIO.Colors.ACCENT,
        scrollBg = isDarkMode and RRADIO.Colors.SCROLL_BG_DARK or RRADIO.Colors.SCROLL_BG_LIGHT,
        text_placeholder = isDarkMode and RRADIO.Colors.TEXT_PLACEHOLDER_DARK or RRADIO.Colors.TEXT_PLACEHOLDER_LIGHT,
    }

    -- Ensure all colors are valid
    for k, v in pairs(colors) do
        if not IsColor(v) then
            colors[k] = Color(255, 255, 255) -- Default to white if invalid
        end
    end

    return colors
end

function RRADIO.ToggleDarkMode()
    RRADIO.DarkModeConVar:SetBool(not RRADIO.DarkModeConVar:GetBool())
end

hook.Add("rRadio_ColorSchemeChanged", "UpdateRRadioColors", function()
    -- This hook can be used to update any panels that use the color scheme
end)
