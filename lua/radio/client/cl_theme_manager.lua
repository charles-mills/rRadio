--[[
    Radio Addon Client-Side Themes
    Author: Charles Mills
    Description: This file defines various visual themes for the Radio Addon's user interface.
                 It includes color schemes and style settings for different UI elements,
                 allowing users to customize the look and feel of the radio menu.
    Date: November 3, 2024
]]--

local DEFAULT_FRAME_SIZE = { width = 600, height = 800 }

local ThemeFactory = {
    defaultTheme = "dark",
    
    createTheme = function(self, name, baseColors, category)
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
            category = category or "other",
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
    background = Color(13, 13, 28),
    header = Color(20, 20, 45),
    text = Color(255, 255, 255),
    button = Color(25, 25, 55),
    buttonHover = Color(35, 35, 75),
    playing = Color(30, 30, 65),
    close = Color(20, 20, 45),
    closeHover = Color(50, 50, 100),
    scrollbar = Color(25, 25, 55),
    scrollbarGrip = Color(50, 50, 100),
    search = Color(20, 20, 45),
    accent = Color(82, 130, 255),
    separator = Color(35, 35, 75),
    icon = Color(255, 255, 255, 220),
    volumeSlider = Color(82, 130, 255),
    volumeKnob = Color(40, 40, 80),
    statusIndicator = Color(0, 255, 150),
    favoriteStar = Color(255, 215, 0),
    messageBackground = Color(25, 25, 55, 230),
    keyHighlight = Color(40, 40, 80)
}, "main"))

safeAddTheme("retro", ThemeFactory:createTheme("retro", {
    background = Color(245, 225, 185),
    header = Color(205, 185, 145),
    text = Color(70, 50, 30),
    button = Color(225, 205, 165),
    buttonHover = Color(205, 185, 145),
    playing = Color(185, 165, 125),
    close = Color(205, 185, 145),
    closeHover = Color(185, 165, 125),
    scrollbar = Color(225, 205, 165),
    scrollbarGrip = Color(185, 165, 125),
    search = Color(205, 185, 145),
    accent = Color(170, 150, 110),
    separator = Color(185, 165, 125),
    icon = Color(90, 70, 50, 220),
    volumeSlider = Color(170, 150, 110),
    volumeKnob = Color(185, 165, 125),
    statusIndicator = Color(130, 190, 130),
    favoriteStar = Color(210, 170, 90),
    messageBackground = Color(225, 205, 165, 230),
    keyHighlight = Color(205, 185, 145)
}, "other"))

safeAddTheme("nord", ThemeFactory:createTheme("nord", {
    background = Color(46, 52, 64),
    header = Color(59, 66, 82),
    text = Color(236, 239, 244),
    button = Color(67, 76, 94),
    buttonHover = Color(76, 86, 106),
    playing = Color(94, 129, 172),
    close = Color(59, 66, 82),
    closeHover = Color(191, 97, 106),
    scrollbar = Color(67, 76, 94),
    scrollbarGrip = Color(136, 192, 208),
    search = Color(59, 66, 82),
    accent = Color(129, 161, 193),
    separator = Color(76, 86, 106),
    icon = Color(236, 239, 244, 220),
    volumeSlider = Color(136, 192, 208),
    volumeKnob = Color(76, 86, 106),
    statusIndicator = Color(163, 190, 140),
    favoriteStar = Color(235, 203, 139),
    messageBackground = Color(67, 76, 94, 230),
    keyHighlight = Color(76, 86, 106)
}, "main"))

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
    icon = Color(248, 248, 242, 220),
    volumeSlider = Color(139, 233, 253),
    volumeKnob = Color(98, 114, 164),
    statusIndicator = Color(80, 250, 123),
    favoriteStar = Color(241, 250, 140),
    messageBackground = Color(68, 71, 90, 230),
    keyHighlight = Color(98, 114, 164)
}, "other"))

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
}, "main"))

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
}, "other"))

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
}, "main"))

safeAddTheme("dark", ThemeFactory:createTheme("dark", {
    background = Color(18, 18, 24),
    header = Color(24, 24, 32),
    text = Color(240, 240, 250),
    button = Color(28, 28, 36),
    buttonHover = Color(35, 35, 45),
    playing = Color(32, 32, 42),
    close = Color(24, 24, 32),
    closeHover = Color(35, 35, 45),
    scrollbar = Color(28, 28, 36),
    scrollbarGrip = Color(45, 45, 55),
    search = Color(24, 24, 32),
    accent = Color(82, 130, 255),
    separator = Color(35, 35, 45),
    icon = Color(240, 240, 250, 200),
    volumeSlider = Color(82, 130, 255),
    volumeKnob = Color(45, 45, 55),
    statusIndicator = Color(82, 255, 168),
    favoriteStar = Color(255, 215, 0),
    messageBackground = Color(28, 28, 36, 230),
    keyHighlight = Color(35, 35, 45)
}, "main"))

safeAddTheme("cyberpunk", ThemeFactory:createTheme("cyberpunk", {
    background = Color(13, 13, 34),
    header = Color(20, 20, 45),
    text = Color(0, 255, 255),
    button = Color(25, 25, 55),
    buttonHover = Color(35, 35, 75),
    playing = Color(45, 0, 90),
    close = Color(20, 20, 45),
    closeHover = Color(35, 35, 75),
    scrollbar = Color(25, 25, 55),
    scrollbarGrip = Color(255, 0, 255),
    search = Color(20, 20, 45),
    accent = Color(255, 0, 255),
    separator = Color(0, 255, 255, 50),
    icon = Color(0, 255, 255, 200),
    volumeSlider = Color(255, 0, 255),
    volumeKnob = Color(0, 255, 255),
    statusIndicator = Color(0, 255, 128),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(25, 25, 55, 230),
    keyHighlight = Color(35, 35, 75)
}, "strange"))

safeAddTheme("sunset", ThemeFactory:createTheme("sunset", {
    background = Color(35, 15, 35),
    header = Color(45, 20, 45),
    text = Color(255, 245, 235),
    button = Color(82, 42, 50),
    buttonHover = Color(125, 55, 55),
    playing = Color(195, 85, 55),
    close = Color(45, 20, 45),
    closeHover = Color(225, 95, 75),
    scrollbar = Color(82, 42, 50),
    scrollbarGrip = Color(255, 145, 95),
    search = Color(45, 20, 45),
    accent = Color(255, 125, 85),
    separator = Color(125, 55, 55),
    icon = Color(255, 245, 235, 220),
    volumeSlider = Color(255, 125, 85),
    volumeKnob = Color(195, 85, 55),
    statusIndicator = Color(255, 175, 125),
    favoriteStar = Color(255, 215, 145),
    messageBackground = Color(82, 42, 50, 230),
    keyHighlight = Color(125, 55, 55)
}, "other"))

safeAddTheme("forest", ThemeFactory:createTheme("forest", {
    background = Color(22, 33, 22),
    header = Color(28, 42, 28),
    text = Color(219, 231, 220),
    button = Color(33, 49, 33),
    buttonHover = Color(41, 61, 41),
    playing = Color(45, 67, 45),
    close = Color(28, 42, 28),
    closeHover = Color(41, 61, 41),
    scrollbar = Color(33, 49, 33),
    scrollbarGrip = Color(92, 133, 92),
    search = Color(28, 42, 28),
    accent = Color(133, 187, 101),
    separator = Color(41, 61, 41),
    icon = Color(219, 231, 220, 200),
    volumeSlider = Color(133, 187, 101),
    volumeKnob = Color(41, 61, 41),
    statusIndicator = Color(162, 208, 73),
    favoriteStar = Color(238, 208, 113),
    messageBackground = Color(33, 49, 33, 230),
    keyHighlight = Color(41, 61, 41)
}, "other"))

safeAddTheme("ocean", ThemeFactory:createTheme("ocean", {
    background = Color(15, 25, 35),
    header = Color(20, 33, 46),
    text = Color(236, 244, 255),
    button = Color(25, 42, 58),
    buttonHover = Color(32, 54, 75),
    playing = Color(37, 62, 86),
    close = Color(20, 33, 46),
    closeHover = Color(32, 54, 75),
    scrollbar = Color(25, 42, 58),
    scrollbarGrip = Color(64, 144, 208),
    search = Color(20, 33, 46),
    accent = Color(64, 144, 208),
    separator = Color(32, 54, 75),
    icon = Color(236, 244, 255, 200),
    volumeSlider = Color(64, 144, 208),
    volumeKnob = Color(32, 54, 75),
    statusIndicator = Color(72, 202, 228),
    favoriteStar = Color(255, 198, 88),
    messageBackground = Color(25, 42, 58, 230),
    keyHighlight = Color(32, 54, 75)
}, "other"))

safeAddTheme("monochrome", ThemeFactory:createTheme("monochrome", {
    background = Color(12, 12, 12),
    header = Color(18, 18, 18),
    text = Color(255, 255, 255),
    button = Color(24, 24, 24),
    buttonHover = Color(32, 32, 32),
    playing = Color(36, 36, 36),
    close = Color(18, 18, 18),
    closeHover = Color(32, 32, 32),
    scrollbar = Color(24, 24, 24),
    scrollbarGrip = Color(48, 48, 48),
    search = Color(18, 18, 18),
    accent = Color(160, 160, 160),
    separator = Color(32, 32, 32),
    icon = Color(255, 255, 255, 200),
    volumeSlider = Color(160, 160, 160),
    volumeKnob = Color(32, 32, 32),
    statusIndicator = Color(200, 200, 200),
    favoriteStar = Color(255, 255, 255),
    messageBackground = Color(24, 24, 24, 230),
    keyHighlight = Color(32, 32, 32)
}, "main"))

safeAddTheme("neon", ThemeFactory:createTheme("neon", {
    background = Color(10, 10, 15),
    header = Color(15, 15, 22),
    text = Color(255, 255, 255),
    button = Color(20, 20, 30),
    buttonHover = Color(25, 25, 37),
    playing = Color(30, 30, 45),
    close = Color(15, 15, 22),
    closeHover = Color(25, 25, 37),
    scrollbar = Color(20, 20, 30),
    scrollbarGrip = Color(255, 55, 255),
    search = Color(15, 15, 22),
    accent = Color(255, 55, 255),
    separator = Color(25, 25, 37),
    icon = Color(0, 255, 255, 200),
    volumeSlider = Color(255, 55, 255),
    volumeKnob = Color(25, 25, 37),
    statusIndicator = Color(0, 255, 255),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(20, 20, 30, 230),
    keyHighlight = Color(25, 25, 37)
}, "strange"))

safeAddTheme("synthwave", ThemeFactory:createTheme("synthwave", {
    background = Color(20, 10, 30),
    header = Color(30, 15, 45),
    text = Color(255, 236, 255),
    button = Color(40, 20, 60),
    buttonHover = Color(60, 30, 90),
    playing = Color(128, 0, 128),
    close = Color(30, 15, 45),
    closeHover = Color(90, 30, 90),
    scrollbar = Color(40, 20, 60),
    scrollbarGrip = Color(255, 83, 255),
    search = Color(30, 15, 45),
    accent = Color(0, 255, 255),
    separator = Color(60, 30, 90),
    icon = Color(255, 236, 255, 220),
    volumeSlider = Color(255, 83, 255),
    volumeKnob = Color(128, 0, 128),
    statusIndicator = Color(0, 255, 255),
    favoriteStar = Color(255, 210, 0),
    messageBackground = Color(40, 20, 60, 230),
    keyHighlight = Color(60, 30, 90)
}, "strange"))

safeAddTheme("arctic", ThemeFactory:createTheme("arctic", {
    background = Color(235, 240, 245),
    header = Color(220, 225, 235),
    text = Color(45, 55, 72),
    button = Color(210, 217, 230),
    buttonHover = Color(190, 200, 220),
    playing = Color(170, 180, 210),
    close = Color(220, 225, 235),
    closeHover = Color(190, 200, 220),
    scrollbar = Color(210, 217, 230),
    scrollbarGrip = Color(145, 160, 190),
    search = Color(220, 225, 235),
    accent = Color(100, 130, 180),
    separator = Color(190, 200, 220),
    icon = Color(45, 55, 72, 220),
    volumeSlider = Color(100, 130, 180),
    volumeKnob = Color(170, 180, 210),
    statusIndicator = Color(80, 160, 190),
    favoriteStar = Color(240, 180, 0),
    messageBackground = Color(210, 217, 230, 230),
    keyHighlight = Color(190, 200, 220)
}, "other"))

safeAddTheme("coffee", ThemeFactory:createTheme("coffee", {
    background = Color(40, 30, 25),
    header = Color(50, 38, 32),
    text = Color(225, 210, 195),
    button = Color(65, 48, 40),
    buttonHover = Color(85, 62, 52),
    playing = Color(95, 70, 58),
    close = Color(50, 38, 32),
    closeHover = Color(85, 62, 52),
    scrollbar = Color(65, 48, 40),
    scrollbarGrip = Color(120, 90, 75),
    search = Color(50, 38, 32),
    accent = Color(180, 140, 100),
    separator = Color(85, 62, 52),
    icon = Color(225, 210, 195, 220),
    volumeSlider = Color(180, 140, 100),
    volumeKnob = Color(95, 70, 58),
    statusIndicator = Color(160, 120, 80),
    favoriteStar = Color(230, 190, 140),
    messageBackground = Color(65, 48, 40, 230),
    keyHighlight = Color(85, 62, 52)
}, "other"))

safeAddTheme("matrix", ThemeFactory:createTheme("matrix", {
    background = Color(0, 10, 0),
    header = Color(0, 20, 0),
    text = Color(0, 255, 0),
    button = Color(0, 30, 0),
    buttonHover = Color(0, 40, 0),
    playing = Color(0, 50, 0),
    close = Color(0, 20, 0),
    closeHover = Color(0, 40, 0),
    scrollbar = Color(0, 30, 0),
    scrollbarGrip = Color(0, 180, 0),
    search = Color(0, 20, 0),
    accent = Color(0, 255, 0),
    separator = Color(0, 40, 0),
    icon = Color(0, 255, 0, 220),
    volumeSlider = Color(0, 255, 0),
    volumeKnob = Color(0, 50, 0),
    statusIndicator = Color(0, 255, 0),
    favoriteStar = Color(180, 255, 0),
    messageBackground = Color(0, 30, 0, 230),
    keyHighlight = Color(0, 40, 0)
}, "strange"))

safeAddTheme("quantum", ThemeFactory:createTheme("quantum", {
    background = Color(10, 12, 20),
    header = Color(15, 18, 30),
    text = Color(0, 255, 200),
    button = Color(20, 24, 40),
    buttonHover = Color(25, 30, 50),
    playing = Color(0, 40, 30),
    close = Color(15, 18, 30),
    closeHover = Color(30, 36, 60),
    scrollbar = Color(20, 24, 40),
    scrollbarGrip = Color(0, 255, 200, 100),
    search = Color(15, 18, 30),
    accent = Color(0, 255, 200),
    separator = Color(0, 255, 200, 30),
    icon = Color(0, 255, 200),
    volumeSlider = Color(0, 255, 200),
    volumeKnob = Color(20, 24, 40),
    statusIndicator = Color(0, 255, 150),
    favoriteStar = Color(0, 255, 200),
    messageBackground = Color(20, 24, 40, 230),
    keyHighlight = Color(25, 30, 50)
}, "strange"))

safeAddTheme("haunted", ThemeFactory:createTheme("haunted", {
    background = Color(20, 15, 25),
    header = Color(30, 20, 35),
    text = Color(200, 180, 255),
    button = Color(35, 25, 45),
    buttonHover = Color(45, 30, 60),
    playing = Color(60, 0, 80),
    close = Color(30, 20, 35),
    closeHover = Color(80, 0, 100),
    scrollbar = Color(35, 25, 45),
    scrollbarGrip = Color(120, 80, 160),
    search = Color(30, 20, 35),
    accent = Color(160, 0, 255),
    separator = Color(120, 80, 160, 40),
    icon = Color(200, 180, 255),
    volumeSlider = Color(160, 0, 255),
    volumeKnob = Color(45, 30, 60),
    statusIndicator = Color(255, 0, 255),
    favoriteStar = Color(255, 200, 255),
    messageBackground = Color(35, 25, 45, 230),
    keyHighlight = Color(45, 30, 60)
}, "strange"))

safeAddTheme("vaporwave", ThemeFactory:createTheme("vaporwave", {
    background = Color(25, 0, 50),
    header = Color(35, 0, 70),
    text = Color(255, 100, 255),
    button = Color(45, 0, 90),
    buttonHover = Color(60, 0, 120),
    playing = Color(80, 0, 160),
    close = Color(35, 0, 70),
    closeHover = Color(100, 0, 200),
    scrollbar = Color(45, 0, 90),
    scrollbarGrip = Color(255, 100, 255),
    search = Color(35, 0, 70),
    accent = Color(0, 255, 255),
    separator = Color(255, 100, 255, 40),
    icon = Color(0, 255, 255),
    volumeSlider = Color(255, 100, 255),
    volumeKnob = Color(60, 0, 120),
    statusIndicator = Color(0, 255, 255),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(45, 0, 90, 230),
    keyHighlight = Color(60, 0, 120)
}, "strange"))

safeAddTheme("hologram", ThemeFactory:createTheme("hologram", {
    background = Color(0, 20, 40, 200),
    header = Color(0, 30, 60, 200),
    text = Color(0, 255, 255),
    button = Color(0, 40, 80, 200),
    buttonHover = Color(0, 60, 120, 200),
    playing = Color(0, 80, 160, 200),
    close = Color(0, 30, 60, 200),
    closeHover = Color(0, 100, 200, 200),
    scrollbar = Color(0, 40, 80, 200),
    scrollbarGrip = Color(0, 255, 255, 150),
    search = Color(0, 30, 60, 200),
    accent = Color(0, 255, 255),
    separator = Color(0, 255, 255, 30),
    icon = Color(0, 255, 255),
    volumeSlider = Color(0, 255, 255),
    volumeKnob = Color(0, 60, 120, 200),
    statusIndicator = Color(0, 255, 128),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(0, 40, 80, 200),
    keyHighlight = Color(0, 60, 120, 200)
}, "strange"))

safeAddTheme("blood", ThemeFactory:createTheme("blood", {
    background = Color(20, 0, 0),
    header = Color(30, 0, 0),
    text = Color(255, 200, 200),
    button = Color(40, 0, 0),
    buttonHover = Color(60, 0, 0),
    playing = Color(80, 0, 0),
    close = Color(30, 0, 0),
    closeHover = Color(100, 0, 0),
    scrollbar = Color(40, 0, 0),
    scrollbarGrip = Color(120, 0, 0),
    search = Color(30, 0, 0),
    accent = Color(255, 0, 0),
    separator = Color(255, 0, 0, 30),
    icon = Color(255, 200, 200),
    volumeSlider = Color(255, 0, 0),
    volumeKnob = Color(60, 0, 0),
    statusIndicator = Color(255, 50, 50),
    favoriteStar = Color(255, 100, 100),
    messageBackground = Color(40, 0, 0, 230),
    keyHighlight = Color(60, 0, 0)
}, "strange"))

safeAddTheme("nature", ThemeFactory:createTheme("nature", {
    background = Color(20, 40, 20),
    header = Color(30, 60, 30),
    text = Color(200, 255, 200),
    button = Color(40, 80, 40),
    buttonHover = Color(50, 100, 50),
    playing = Color(60, 120, 60),
    close = Color(30, 60, 30),
    closeHover = Color(70, 140, 70),
    scrollbar = Color(40, 80, 40),
    scrollbarGrip = Color(100, 200, 100),
    search = Color(30, 60, 30),
    accent = Color(100, 255, 100),
    separator = Color(100, 255, 100, 30),
    icon = Color(200, 255, 200),
    volumeSlider = Color(100, 255, 100),
    volumeKnob = Color(50, 100, 50),
    statusIndicator = Color(150, 255, 150),
    favoriteStar = Color(255, 255, 150),
    messageBackground = Color(40, 80, 40, 230),
    keyHighlight = Color(50, 100, 50)
}, "other"))

safeAddTheme("sunset_beach", ThemeFactory:createTheme("sunset_beach", {
    background = Color(40, 20, 50),
    header = Color(60, 30, 75),
    text = Color(255, 220, 200),
    button = Color(80, 40, 100),
    buttonHover = Color(100, 50, 125),
    playing = Color(120, 60, 150),
    close = Color(60, 30, 75),
    closeHover = Color(140, 70, 175),
    scrollbar = Color(80, 40, 100),
    scrollbarGrip = Color(255, 150, 100),
    search = Color(60, 30, 75),
    accent = Color(255, 150, 100),
    separator = Color(255, 150, 100, 30),
    icon = Color(255, 220, 200),
    volumeSlider = Color(255, 150, 100),
    volumeKnob = Color(100, 50, 125),
    statusIndicator = Color(255, 200, 150),
    favoriteStar = Color(255, 200, 100),
    messageBackground = Color(80, 40, 100, 230),
    keyHighlight = Color(100, 50, 125)
}, "other"))

safeAddTheme("deep_sea", ThemeFactory:createTheme("deep_sea", {
    background = Color(0, 20, 40),
    header = Color(0, 30, 60),
    text = Color(150, 200, 255),
    button = Color(0, 40, 80),
    buttonHover = Color(0, 50, 100),
    playing = Color(0, 60, 120),
    close = Color(0, 30, 60),
    closeHover = Color(0, 70, 140),
    scrollbar = Color(0, 40, 80),
    scrollbarGrip = Color(0, 100, 200),
    search = Color(0, 30, 60),
    accent = Color(0, 150, 255),
    separator = Color(0, 150, 255, 30),
    icon = Color(150, 200, 255),
    volumeSlider = Color(0, 150, 255),
    volumeKnob = Color(0, 50, 100),
    statusIndicator = Color(0, 200, 255),
    favoriteStar = Color(255, 255, 150),
    messageBackground = Color(0, 40, 80, 230),
    keyHighlight = Color(0, 50, 100)
}, "other"))

safeAddTheme("retro_computer", ThemeFactory:createTheme("retro_computer", {
    background = Color(0, 40, 0),
    header = Color(0, 60, 0),
    text = Color(0, 255, 0),
    button = Color(0, 80, 0),
    buttonHover = Color(0, 100, 0),
    playing = Color(0, 120, 0),
    close = Color(0, 60, 0),
    closeHover = Color(0, 140, 0),
    scrollbar = Color(0, 80, 0),
    scrollbarGrip = Color(0, 200, 0),
    search = Color(0, 60, 0),
    accent = Color(0, 255, 0),
    separator = Color(0, 255, 0, 30),
    icon = Color(0, 255, 0),
    volumeSlider = Color(0, 255, 0),
    volumeKnob = Color(0, 100, 0),
    statusIndicator = Color(0, 255, 0),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(0, 80, 0, 230),
    keyHighlight = Color(0, 100, 0)
}, "strange"))

safeAddTheme("cherry_blossom", ThemeFactory:createTheme("cherry_blossom", {
    background = Color(45, 35, 45),
    header = Color(60, 45, 60),
    text = Color(255, 235, 245),
    button = Color(75, 55, 75),
    buttonHover = Color(95, 70, 95),
    playing = Color(150, 100, 130),
    close = Color(60, 45, 60),
    closeHover = Color(120, 80, 100),
    scrollbar = Color(75, 55, 75),
    scrollbarGrip = Color(255, 182, 193),
    search = Color(60, 45, 60),
    accent = Color(255, 182, 193),
    separator = Color(95, 70, 95),
    icon = Color(255, 235, 245, 220),
    volumeSlider = Color(255, 182, 193),
    volumeKnob = Color(95, 70, 95),
    statusIndicator = Color(255, 192, 203),
    favoriteStar = Color(255, 223, 186),
    messageBackground = Color(75, 55, 75, 230),
    keyHighlight = Color(95, 70, 95)
}, "other"))

safeAddTheme("golden_hour", ThemeFactory:createTheme("golden_hour", {
    background = Color(40, 25, 15),
    header = Color(55, 35, 20),
    text = Color(255, 245, 225),
    button = Color(70, 45, 25),
    buttonHover = Color(90, 60, 35),
    playing = Color(120, 80, 40),
    close = Color(55, 35, 20),
    closeHover = Color(140, 90, 45),
    scrollbar = Color(70, 45, 25),
    scrollbarGrip = Color(255, 195, 85),
    search = Color(55, 35, 20),
    accent = Color(255, 195, 85),
    separator = Color(90, 60, 35),
    icon = Color(255, 245, 225, 220),
    volumeSlider = Color(255, 195, 85),
    volumeKnob = Color(90, 60, 35),
    statusIndicator = Color(255, 215, 125),
    favoriteStar = Color(255, 223, 186),
    messageBackground = Color(70, 45, 25, 230),
    keyHighlight = Color(90, 60, 35)
}, "other"))

safeAddTheme("electric_dreams", ThemeFactory:createTheme("electric_dreams", {
    background = Color(15, 10, 35),
    header = Color(25, 15, 55),
    text = Color(220, 255, 255),
    button = Color(35, 20, 75),
    buttonHover = Color(45, 25, 95),
    playing = Color(60, 30, 120),
    close = Color(25, 15, 55),
    closeHover = Color(70, 35, 140),
    scrollbar = Color(35, 20, 75),
    scrollbarGrip = Color(0, 255, 255),
    search = Color(25, 15, 55),
    accent = Color(255, 0, 255),
    separator = Color(45, 25, 95),
    icon = Color(0, 255, 255, 220),
    volumeSlider = Color(0, 255, 255),
    volumeKnob = Color(45, 25, 95),
    statusIndicator = Color(255, 0, 255),
    favoriteStar = Color(255, 255, 0),
    messageBackground = Color(35, 20, 75, 230),
    keyHighlight = Color(45, 25, 95)
}, "strange"))

safeAddTheme("frozen_aurora", ThemeFactory:createTheme("frozen_aurora", {
    background = Color(15, 25, 35),
    header = Color(20, 35, 50),
    text = Color(200, 255, 255),
    button = Color(25, 45, 65),
    buttonHover = Color(30, 55, 80),
    playing = Color(35, 65, 95),
    close = Color(20, 35, 50),
    closeHover = Color(40, 75, 110),
    scrollbar = Color(25, 45, 65),
    scrollbarGrip = Color(140, 230, 255),
    search = Color(20, 35, 50),
    accent = Color(140, 230, 255),
    separator = Color(30, 55, 80),
    icon = Color(200, 255, 255, 220),
    volumeSlider = Color(140, 230, 255),
    volumeKnob = Color(30, 55, 80),
    statusIndicator = Color(170, 255, 255),
    favoriteStar = Color(255, 255, 200),
    messageBackground = Color(25, 45, 65, 230),
    keyHighlight = Color(30, 55, 80)
}, "other"))

safeAddTheme("cosmic_dust", ThemeFactory:createTheme("cosmic_dust", {
    background = Color(20, 15, 30),
    header = Color(30, 22, 45),
    text = Color(230, 220, 255),
    button = Color(40, 30, 60),
    buttonHover = Color(50, 38, 75),
    playing = Color(60, 45, 90),
    close = Color(30, 22, 45),
    closeHover = Color(70, 53, 105),
    scrollbar = Color(40, 30, 60),
    scrollbarGrip = Color(180, 150, 255),
    search = Color(30, 22, 45),
    accent = Color(180, 150, 255),
    separator = Color(50, 38, 75),
    icon = Color(230, 220, 255, 220),
    volumeSlider = Color(180, 150, 255),
    volumeKnob = Color(50, 38, 75),
    statusIndicator = Color(200, 180, 255),
    favoriteStar = Color(255, 220, 180),
    messageBackground = Color(40, 30, 60, 230),
    keyHighlight = Color(50, 38, 75)
}, "strange"))

safeAddTheme("desert_nights", ThemeFactory:createTheme("desert_nights", {
    background = Color(35, 25, 20),
    header = Color(50, 35, 25),
    text = Color(255, 240, 220),
    button = Color(65, 45, 30),
    buttonHover = Color(80, 55, 35),
    playing = Color(95, 65, 40),
    close = Color(50, 35, 25),
    closeHover = Color(110, 75, 45),
    scrollbar = Color(65, 45, 30),
    scrollbarGrip = Color(255, 200, 150),
    search = Color(50, 35, 25),
    accent = Color(255, 200, 150),
    separator = Color(80, 55, 35),
    icon = Color(255, 240, 220, 220),
    volumeSlider = Color(255, 200, 150),
    volumeKnob = Color(80, 55, 35),
    statusIndicator = Color(255, 220, 180),
    favoriteStar = Color(255, 230, 150),
    messageBackground = Color(65, 45, 30, 230),
    keyHighlight = Color(80, 55, 35)
}, "other"))

CreateClientConVar("radio_theme", ThemeFactory:getDefaultTheme(), true, false, "Select the theme for the radio UI.")

return {
    themes = themes,
    factory = ThemeFactory
}
