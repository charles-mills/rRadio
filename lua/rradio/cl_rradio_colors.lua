--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Defines color schemes and related functions for the rRadio addon.
]]

RRADIO = RRADIO or {}
RRADIO.Colors = {
    BG_LIGHT = Color(248, 248, 248),
    BG_DARK = Color(28, 28, 30),
    TEXT_LIGHT = Color(0, 0, 0),
    TEXT_DARK = Color(255, 255, 255),
    ACCENT = Color(0, 122, 255),
    BUTTON_LIGHT = Color(255, 255, 255),
    BUTTON_DARK = Color(58, 58, 60),
    BUTTON_HOVER_LIGHT = Color(242, 242, 242),
    BUTTON_HOVER_DARK = Color(68, 68, 70),
    DIVIDER_LIGHT = Color(229, 229, 234),
    DIVIDER_DARK = Color(44, 44, 46),
    SCROLL_BG_LIGHT = Color(242, 242, 247),
    SCROLL_BG_DARK = Color(38, 38, 40),
    TEXT_PLACEHOLDER_LIGHT = Color(142, 142, 147),
    TEXT_PLACEHOLDER_DARK = Color(142, 142, 147),
    HEADER_LIGHT = Color(248, 248, 248, 230),
    HEADER_DARK = Color(28, 28, 30, 230),
    FOOTER_LIGHT = Color(248, 248, 248, 230),
    FOOTER_DARK = Color(28, 28, 30, 230),
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
        accent = RRADIO.Colors.ACCENT,
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
