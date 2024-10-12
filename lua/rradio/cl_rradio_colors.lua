--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-13

    Description:
    Defines a modern color scheme and related functions for the rRadio addon.
]]

RRADIO = RRADIO or {}
RRADIO.Colors = {
    -- Light Mode Colors
    BG_LIGHT = Color(250, 250, 252),
    TEXT_LIGHT = Color(33, 33, 33),
    BUTTON_LIGHT = Color(255, 255, 255),
    BUTTON_HOVER_LIGHT = Color(245, 245, 247),
    DIVIDER_LIGHT = Color(230, 230, 235),
    SCROLL_BG_LIGHT = Color(240, 240, 245),
    TEXT_PLACEHOLDER_LIGHT = Color(150, 150, 155),
    HEADER_LIGHT = Color(255, 255, 255, 230),
    FOOTER_LIGHT = Color(245, 245, 250, 230),

    -- Dark Mode Colors
    BG_DARK = Color(18, 18, 22),
    TEXT_DARK = Color(243, 245, 240),
    BUTTON_DARK = Color(2, 2, 2),
    BUTTON_HOVER_DARK = Color(27, 27, 27),
    DIVIDER_DARK = Color(60, 60, 65),
    SCROLL_BG_DARK = Color(10, 10, 12),
    TEXT_PLACEHOLDER_DARK = Color(130, 130, 135),
    HEADER_DARK = Color(18, 18, 22, 230),
    FOOTER_DARK = Color(22, 22, 26, 230),

    -- Accent Colors
    ACCENT_PRIMARY = Color(66, 135, 245),  -- Blue
    ACCENT_SECONDARY = Color(255, 122, 89),  -- Coral
}

RRADIO.DarkModeConVar = CreateClientConVar("rradio_dark_mode", "0", true, false, "Toggle dark mode for rRadio")

function RRADIO.GetColors()
    local isDarkMode = RRADIO.DarkModeConVar:GetBool()
    return {
        bg = isDarkMode and RRADIO.Colors.BG_DARK or RRADIO.Colors.BG_LIGHT,
        text = isDarkMode and RRADIO.Colors.TEXT_DARK or RRADIO.Colors.TEXT_LIGHT,
        button = isDarkMode and RRADIO.Colors.BUTTON_DARK or RRADIO.Colors.BUTTON_LIGHT,
        buttonHover = isDarkMode and RRADIO.Colors.BUTTON_HOVER_DARK or RRADIO.Colors.BUTTON_HOVER_LIGHT,
        divider = isDarkMode and RRADIO.Colors.DIVIDER_DARK or RRADIO.Colors.DIVIDER_LIGHT,
        accent = RRADIO.Colors.ACCENT_PRIMARY,
        accentSecondary = RRADIO.Colors.ACCENT_SECONDARY,
        scrollBg = isDarkMode and RRADIO.Colors.SCROLL_BG_DARK or RRADIO.Colors.SCROLL_BG_LIGHT,
        text_placeholder = isDarkMode and RRADIO.Colors.TEXT_PLACEHOLDER_DARK or RRADIO.Colors.TEXT_PLACEHOLDER_LIGHT,
        header = isDarkMode and RRADIO.Colors.HEADER_DARK or RRADIO.Colors.HEADER_LIGHT,
        footer = isDarkMode and RRADIO.Colors.FOOTER_DARK or RRADIO.Colors.FOOTER_LIGHT,
    }
end

function RRADIO.ToggleDarkMode()
    RRADIO.DarkModeConVar:SetBool(not RRADIO.DarkModeConVar:GetBool())
    hook.Run("rRadio_ColorSchemeChanged")
end

hook.Add("rRadio_ColorSchemeChanged", "UpdateRRadioColors", function()
    -- This hook can be used to update any panels that use the color scheme
end)
