--[[
    Radio Addon Client-Side Themes
    Author: Charles Mills
    Description: This file defines various visual themes for the Radio Addon's user interface.
                 It includes color schemes and style settings for different UI elements,
                 allowing users to customize the look and feel of the radio menu.
    Date: October 31, 2024
]]--

local DEFAULT_FRAME_SIZE = { width = 600, height = 800 }

local ThemeFactory = {
    defaultTheme = "midnight",
    
    createTheme = function(self, name, baseColors)
        if not baseColors then 
            print("[Radio Theme] No base colors provided for theme:", name)
            return nil 
        end
        
        -- Validate required colors
        local requiredColors = {
            "background", "header", "text", "button", "buttonHover",
            "playing", "close", "closeHover", "scrollbar", "scrollbarGrip",
            "search"
        }
        
        local missingColors = {}
        for _, colorName in ipairs(requiredColors) do
            if not baseColors[colorName] then
                table.insert(missingColors, colorName)
            end
        end
        
        if #missingColors > 0 then
            print("[Radio Theme] Missing required colors for theme " .. name .. ":")
            PrintTable(missingColors)
            return nil
        end
        
        -- Validate that all colors are valid Color objects
        for colorName, colorValue in pairs(baseColors) do
            if not IsColor(colorValue) then
                print("[Radio Theme] Invalid color value for", colorName, "in theme:", name)
                return nil
            end
        end
        
        local theme = {
            name = name,
            FrameSize = DEFAULT_FRAME_SIZE,
            BackgroundColor = baseColors.background,
            HeaderColor = baseColors.header,
            TextColor = baseColors.text,
            ButtonColor = baseColors.button,
            ButtonHoverColor = baseColors.buttonHover,
            PlayingButtonColor = baseColors.playing,
            CloseButtonColor = baseColors.close,
            CloseButtonHoverColor = baseColors.closeHover,
            ScrollbarColor = baseColors.scrollbar,
            ScrollbarGripColor = baseColors.scrollbarGrip,
            SearchBoxColor = baseColors.search,
            AccentColor = baseColors.accent,
            SeparatorColor = baseColors.separator or baseColors.button,
            IconColor = baseColors.icon or baseColors.text,
            VolumeSliderColor = baseColors.volumeSlider or baseColors.accent,
            VolumeKnobColor = baseColors.volumeKnob or baseColors.button,
            StatusIndicatorColor = baseColors.statusIndicator or baseColors.accent,
            FavoriteStarColor = baseColors.favoriteStar or baseColors.accent,
            MessageBackgroundColor = baseColors.messageBackground or baseColors.header,
            KeyHighlightColor = baseColors.keyHighlight or baseColors.button,
        }
        
        -- Validate the created theme
        if not self:validateTheme(theme) then
            print("[Radio Theme] Created theme failed validation:", name)
            return nil
        end
        
        return theme
    end,
    
    validateTheme = function(self, theme)
        if not theme then return false end
        
        local requiredProperties = {
            "BackgroundColor", "HeaderColor", "TextColor", "ButtonColor",
            "ButtonHoverColor", "PlayingButtonColor", "CloseButtonColor",
            "CloseButtonHoverColor", "ScrollbarColor", "ScrollbarGripColor",
            "SearchBoxColor"
        }
        
        for _, prop in ipairs(requiredProperties) do
            if not theme[prop] then
                return false
            end
        end
        
        return true
    end,
    
    getDefaultTheme = function(self)
        return self.defaultTheme
    end,
    
    getDefaultThemeData = function(self)
        return {
            name = self.defaultTheme,
            FrameSize = { width = 600, height = 800 },
            BackgroundColor = Color(10, 10, 35),
            HeaderColor = Color(20, 20, 50),
            TextColor = Color(255, 255, 255),
            ButtonColor = Color(30, 30, 60),
            ButtonHoverColor = Color(50, 50, 100),
            PlayingButtonColor = Color(15, 15, 45),
            CloseButtonColor = Color(20, 20, 50),
            CloseButtonHoverColor = Color(50, 50, 100),
            ScrollbarColor = Color(30, 30, 60),
            ScrollbarGripColor = Color(50, 50, 100),
            SearchBoxColor = Color(20, 20, 50),
            AccentColor = Color(0, 150, 255)
        }
    end
}

local themes = {}

local function safeAddTheme(name, themeData)
    if not themeData then
        print("[Radio Theme] Failed to create theme:", name)
        return false
    end
    
    if not ThemeFactory:validateTheme(themeData) then
        print("[Radio Theme] Theme failed validation:", name)
        return false
    end
    
    themes[name] = themeData
    return true
end

safeAddTheme("midnight", ThemeFactory:createTheme("midnight", {
    background = Color(10, 10, 35),
    header = Color(20, 20, 50),
    text = Color(255, 255, 255),
    button = Color(30, 30, 60),
    buttonHover = Color(50, 50, 100),
    playing = Color(15, 15, 45),
    close = Color(20, 20, 50),
    closeHover = Color(50, 50, 100),
    scrollbar = Color(30, 30, 60),
    scrollbarGrip = Color(50, 50, 100),
    search = Color(20, 20, 50),
    accent = Color(0, 150, 255),
    separator = Color(40, 40, 80),
    icon = Color(255, 255, 255, 200),
    volumeSlider = Color(0, 150, 255),
    volumeKnob = Color(40, 40, 80),
    statusIndicator = Color(0, 255, 150),
    favoriteStar = Color(255, 215, 0),
    messageBackground = Color(25, 25, 60, 230),
    keyHighlight = Color(40, 40, 80)
}))

safeAddTheme("dark", ThemeFactory:createTheme("dark", {
    background = Color(30, 30, 30),
    header = Color(40, 40, 40),
    text = Color(240, 240, 240),
    button = Color(70, 70, 70),
    buttonHover = Color(90, 90, 90),
    playing = Color(40, 40, 40),
    close = Color(60, 60, 60),
    closeHover = Color(80, 80, 80),
    scrollbar = Color(70, 70, 70),
    scrollbarGrip = Color(120, 120, 120),
    search = Color(60, 60, 60),
    accent = Color(100, 100, 100),
    separator = Color(90, 90, 90),
    icon = Color(240, 240, 240, 200),
    volumeSlider = Color(120, 120, 120),
    volumeKnob = Color(90, 90, 90),
    statusIndicator = Color(100, 200, 100),
    favoriteStar = Color(255, 215, 0),
    messageBackground = Color(50, 50, 50, 230),
    keyHighlight = Color(80, 80, 80)
}))

-- Cyberpunk theme
safeAddTheme("cyberpunk", ThemeFactory:createTheme("cyberpunk", {
    background = Color(20, 10, 30),
    header = Color(30, 15, 45),
    text = Color(0, 255, 255),
    button = Color(40, 20, 60),
    buttonHover = Color(60, 30, 90),
    playing = Color(128, 0, 255),
    close = Color(30, 15, 45),
    closeHover = Color(60, 30, 90),
    scrollbar = Color(40, 20, 60),
    scrollbarGrip = Color(0, 255, 255),
    search = Color(30, 15, 45),
    accent = Color(255, 0, 128),
    separator = Color(0, 255, 255, 50),
    icon = Color(255, 0, 255, 200),
    volumeSlider = Color(255, 0, 128),
    volumeKnob = Color(0, 255, 255),
    statusIndicator = Color(0, 255, 128),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(40, 20, 60, 230),
    keyHighlight = Color(60, 30, 90)
}))

-- Retro theme
safeAddTheme("retro", ThemeFactory:createTheme("retro", {
    background = Color(240, 220, 180),
    header = Color(200, 180, 140),
    text = Color(80, 60, 40),
    button = Color(220, 200, 160),
    buttonHover = Color(200, 180, 140),
    playing = Color(180, 160, 120),
    close = Color(200, 180, 140),
    closeHover = Color(180, 160, 120),
    scrollbar = Color(220, 200, 160),
    scrollbarGrip = Color(180, 160, 120),
    search = Color(200, 180, 140),
    accent = Color(160, 140, 100),
    separator = Color(180, 160, 120),
    icon = Color(100, 80, 60, 200),
    volumeSlider = Color(160, 140, 100),
    volumeKnob = Color(180, 160, 120),
    statusIndicator = Color(120, 180, 120),
    favoriteStar = Color(200, 160, 80),
    messageBackground = Color(220, 200, 160, 230),
    keyHighlight = Color(200, 180, 140)
}))

-- Nord theme
safeAddTheme("nord", ThemeFactory:createTheme("nord", {
    background = Color(46, 52, 64),
    header = Color(59, 66, 82),
    text = Color(236, 239, 244),
    button = Color(67, 76, 94),
    buttonHover = Color(76, 86, 106),
    playing = Color(94, 129, 172),
    close = Color(59, 66, 82),
    closeHover = Color(76, 86, 106),
    scrollbar = Color(67, 76, 94),
    scrollbarGrip = Color(129, 161, 193),
    search = Color(59, 66, 82),
    accent = Color(136, 192, 208),
    separator = Color(76, 86, 106),
    icon = Color(236, 239, 244, 200),
    volumeSlider = Color(136, 192, 208),
    volumeKnob = Color(76, 86, 106),
    statusIndicator = Color(163, 190, 140),
    favoriteStar = Color(235, 203, 139),
    messageBackground = Color(67, 76, 94, 230),
    keyHighlight = Color(76, 86, 106)
}))

safeAddTheme("dracula", ThemeFactory:createTheme("dracula", {
    background = Color(40, 42, 54),
    header = Color(68, 71, 90),
    text = Color(248, 248, 242),
    button = Color(68, 71, 90),
    buttonHover = Color(98, 114, 164),
    playing = Color(189, 147, 249),
    close = Color(68, 71, 90),
    closeHover = Color(255, 85, 85),
    scrollbar = Color(68, 71, 90),
    scrollbarGrip = Color(139, 233, 253),
    search = Color(68, 71, 90),
    accent = Color(80, 250, 123),
    separator = Color(98, 114, 164),
    icon = Color(248, 248, 242, 200),
    volumeSlider = Color(139, 233, 253),
    volumeKnob = Color(98, 114, 164),
    statusIndicator = Color(80, 250, 123),
    favoriteStar = Color(241, 250, 140),
    messageBackground = Color(68, 71, 90, 230),
    keyHighlight = Color(98, 114, 164)
}))

safeAddTheme("material", ThemeFactory:createTheme("material", {
    background = Color(38, 50, 56),
    header = Color(55, 71, 79),
    text = Color(236, 239, 241),
    button = Color(69, 90, 100),
    buttonHover = Color(84, 110, 122),
    playing = Color(0, 150, 136),
    close = Color(55, 71, 79),
    closeHover = Color(84, 110, 122),
    scrollbar = Color(69, 90, 100),
    scrollbarGrip = Color(0, 150, 136),
    search = Color(55, 71, 79),
    accent = Color(0, 188, 212),
    separator = Color(84, 110, 122),
    icon = Color(236, 239, 241, 200),
    volumeSlider = Color(0, 188, 212),
    volumeKnob = Color(84, 110, 122),
    statusIndicator = Color(0, 150, 136),
    favoriteStar = Color(255, 235, 59),
    messageBackground = Color(69, 90, 100, 230),
    keyHighlight = Color(84, 110, 122)
}))

safeAddTheme("gruvbox", ThemeFactory:createTheme("gruvbox", {
    background = Color(40, 40, 40),
    header = Color(60, 56, 54),
    text = Color(235, 219, 178),
    button = Color(80, 73, 69),
    buttonHover = Color(102, 92, 84),
    playing = Color(184, 187, 38),
    close = Color(60, 56, 54),
    closeHover = Color(204, 36, 29),
    scrollbar = Color(80, 73, 69),
    scrollbarGrip = Color(215, 153, 33),
    search = Color(60, 56, 54),
    accent = Color(250, 189, 47),
    separator = Color(102, 92, 84),
    icon = Color(235, 219, 178, 200),
    volumeSlider = Color(215, 153, 33),
    volumeKnob = Color(102, 92, 84),
    statusIndicator = Color(184, 187, 38),
    favoriteStar = Color(250, 189, 47),
    messageBackground = Color(80, 73, 69, 230),
    keyHighlight = Color(102, 92, 84)
}))

safeAddTheme("tokyonight", ThemeFactory:createTheme("tokyonight", {
    background = Color(26, 27, 38),
    header = Color(36, 40, 59),
    text = Color(192, 202, 245),
    button = Color(41, 46, 66),
    buttonHover = Color(52, 59, 88),
    playing = Color(215, 117, 225),
    close = Color(36, 40, 59),
    closeHover = Color(247, 118, 142),
    scrollbar = Color(41, 46, 66),
    scrollbarGrip = Color(187, 154, 247),
    search = Color(36, 40, 59),
    accent = Color(187, 154, 247),
    separator = Color(52, 59, 88),
    icon = Color(192, 202, 245, 200),
    volumeSlider = Color(187, 154, 247),
    volumeKnob = Color(52, 59, 88),
    statusIndicator = Color(158, 206, 106),
    favoriteStar = Color(224, 175, 104),
    messageBackground = Color(41, 46, 66, 230),
    keyHighlight = Color(52, 59, 88)
}))

CreateClientConVar("radio_theme", ThemeFactory:getDefaultTheme(), true, false, "Select the theme for the radio UI.")

return {
    themes = themes,
    factory = ThemeFactory
}
