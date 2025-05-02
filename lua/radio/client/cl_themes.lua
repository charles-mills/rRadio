rRadio.themes = rRadio.themes or {}

local function CreateColor(r, g, b, a)
    return Color(math.Clamp(r, 0, 255), math.Clamp(g, 0, 255), math.Clamp(b, 0, 255), a or 255)
end

local function CreateTheme(colors)
    local defaults = {
        FrameSize = { width = 600, height = 800 },
        BackgroundColor = CreateColor(20, 20, 20),
        HeaderColor = CreateColor(30, 30, 30),
        TextColor = CreateColor(240, 240, 240),
        ButtonColor = CreateColor(40, 40, 40),
        ButtonHoverColor = CreateColor(50, 50, 50),
        PlayingButtonColor = CreateColor(60, 60, 60),
        CloseButtonColor = CreateColor(30, 30, 30),
        CloseButtonHoverColor = CreateColor(50, 50, 50),
        ScrollbarColor = CreateColor(40, 40, 40),
        ScrollbarGripColor = CreateColor(60, 60, 60),
        SearchBoxColor = CreateColor(30, 30, 30),
        AccentPrimary = CreateColor(100, 100, 255),
        AccentSecondary = CreateColor(150, 150, 255),
        Success = CreateColor(50, 200, 50),
        Error = CreateColor(200, 50, 50),
        Loading = CreateColor(200, 200, 50),
        Disabled = CreateColor(60, 60, 60),
        Border = CreateColor(50, 50, 50),
        Highlight = CreateColor(70, 70, 70, 50)
    }

    for key, color in pairs(colors) do
        if IsColor(color) then
            defaults[key] = color
        end
    end

    return defaults
end

rRadio.themes["dark"] = CreateTheme({
    BackgroundColor = CreateColor(18, 18, 24),
    HeaderColor = CreateColor(24, 24, 32),
    TextColor = CreateColor(240, 240, 250),
    ButtonColor = CreateColor(28, 28, 36),
    ButtonHoverColor = CreateColor(35, 35, 45),
    PlayingButtonColor = CreateColor(45, 45, 55),
    CloseButtonColor = CreateColor(24, 24, 32),
    CloseButtonHoverColor = CreateColor(35, 35, 45),
    ScrollbarColor = CreateColor(28, 28, 36),
    ScrollbarGripColor = CreateColor(45, 45, 55),
    SearchBoxColor = CreateColor(24, 24, 32),
    AccentPrimary = CreateColor(86, 97, 245),
    AccentSecondary = CreateColor(149, 128, 255),
    Success = CreateColor(46, 160, 67),
    Error = CreateColor(248, 81, 73),
    Loading = CreateColor(246, 190, 0),
    Disabled = CreateColor(48, 48, 56),
    Border = CreateColor(38, 38, 46),
    Highlight = CreateColor(56, 56, 66, 50)
})

rRadio.themes["sleek"] = CreateTheme({
    BackgroundColor = CreateColor(20, 23, 31),
    HeaderColor = CreateColor(30, 34, 43),
    TextColor = CreateColor(236, 239, 244),
    ButtonColor = CreateColor(36, 41, 51),
    ButtonHoverColor = CreateColor(46, 52, 64),
    PlayingButtonColor = CreateColor(94, 129, 172),
    CloseButtonColor = CreateColor(30, 34, 43),
    CloseButtonHoverColor = CreateColor(191, 97, 106),
    ScrollbarColor = CreateColor(36, 41, 51),
    ScrollbarGripColor = CreateColor(76, 86, 106),
    SearchBoxColor = CreateColor(30, 34, 43),
    AccentPrimary = CreateColor(94, 129, 172),
    AccentSecondary = CreateColor(129, 161, 193),
    Success = CreateColor(163, 190, 140),
    Error = CreateColor(191, 97, 106),
    Loading = CreateColor(235, 203, 139),
    Disabled = CreateColor(67, 76, 94),
    Border = CreateColor(46, 52, 64),
    Highlight = CreateColor(76, 86, 106, 50)
})

rRadio.themes["cyberpunk"] = CreateTheme({
    BackgroundColor = CreateColor(13, 13, 23),
    HeaderColor = CreateColor(20, 20, 35),
    TextColor = CreateColor(0, 255, 255),
    ButtonColor = CreateColor(25, 25, 45),
    ButtonHoverColor = CreateColor(35, 35, 60),
    PlayingButtonColor = CreateColor(255, 0, 128),
    CloseButtonColor = CreateColor(20, 20, 35),
    CloseButtonHoverColor = CreateColor(255, 0, 128),
    ScrollbarColor = CreateColor(25, 25, 45),
    ScrollbarGripColor = CreateColor(0, 255, 255),
    SearchBoxColor = CreateColor(20, 20, 35),
    AccentPrimary = CreateColor(255, 0, 128),
    AccentSecondary = CreateColor(128, 0, 255),
    Success = CreateColor(0, 255, 128),
    Error = CreateColor(255, 0, 64),
    Loading = CreateColor(255, 191, 0),
    Disabled = CreateColor(40, 40, 60),
    Border = CreateColor(0, 255, 255, 128),
    Highlight = CreateColor(128, 0, 255, 50)
})

rRadio.themes["sunset"] = CreateTheme({
    BackgroundColor = CreateColor(44, 54, 76),
    HeaderColor = CreateColor(34, 42, 59),
    TextColor = CreateColor(255, 241, 230),
    ButtonColor = CreateColor(54, 66, 93),
    ButtonHoverColor = CreateColor(64, 78, 110),
    PlayingButtonColor = CreateColor(255, 123, 84),
    CloseButtonColor = CreateColor(34, 42, 59),
    CloseButtonHoverColor = CreateColor(255, 89, 94),
    ScrollbarColor = CreateColor(54, 66, 93),
    ScrollbarGripColor = CreateColor(255, 170, 110),
    SearchBoxColor = CreateColor(34, 42, 59),
    AccentPrimary = CreateColor(255, 123, 84),
    AccentSecondary = CreateColor(255, 170, 110),
    Success = CreateColor(115, 192, 136),
    Error = CreateColor(255, 89, 94),
    Loading = CreateColor(255, 198, 127),
    Disabled = CreateColor(74, 86, 113),
    Border = CreateColor(64, 78, 110),
    Highlight = CreateColor(255, 123, 84, 50)
})

rRadio.themes["emerald"] = CreateTheme({
    BackgroundColor = CreateColor(0, 48, 51),
    HeaderColor = CreateColor(0, 38, 41),
    TextColor = CreateColor(236, 255, 244),
    ButtonColor = CreateColor(0, 58, 61),
    ButtonHoverColor = CreateColor(0, 68, 71),
    PlayingButtonColor = CreateColor(0, 196, 140),
    CloseButtonColor = CreateColor(0, 38, 41),
    CloseButtonHoverColor = CreateColor(255, 76, 76),
    ScrollbarColor = CreateColor(0, 58, 61),
    ScrollbarGripColor = CreateColor(0, 196, 140),
    SearchBoxColor = CreateColor(0, 38, 41),
    AccentPrimary = CreateColor(0, 196, 140),
    AccentSecondary = CreateColor(0, 168, 120),
    Success = CreateColor(0, 196, 140),
    Error = CreateColor(255, 76, 76),
    Loading = CreateColor(255, 186, 8),
    Disabled = CreateColor(0, 78, 81),
    Border = CreateColor(0, 88, 91),
    Highlight = CreateColor(0, 196, 140, 50)
})

rRadio.themes["synthwave"] = CreateTheme({
    BackgroundColor = CreateColor(23, 12, 45),
    HeaderColor = CreateColor(30, 15, 58),
    TextColor = CreateColor(255, 149, 249),
    ButtonColor = CreateColor(38, 20, 71),
    ButtonHoverColor = CreateColor(48, 25, 89),
    PlayingButtonColor = CreateColor(142, 45, 226),
    CloseButtonColor = CreateColor(30, 15, 58),
    CloseButtonHoverColor = CreateColor(255, 56, 100),
    ScrollbarColor = CreateColor(38, 20, 71),
    ScrollbarGripColor = CreateColor(108, 8, 213),
    SearchBoxColor = CreateColor(30, 15, 58),
    AccentPrimary = CreateColor(255, 56, 100),
    AccentSecondary = CreateColor(142, 45, 226),
    Success = CreateColor(0, 255, 170),
    Error = CreateColor(255, 56, 100),
    Loading = CreateColor(255, 198, 0),
    Disabled = CreateColor(58, 30, 91),
    Border = CreateColor(68, 35, 111),
    Highlight = CreateColor(142, 45, 226, 50)
})

rRadio.themes["forest"] = CreateTheme({
    BackgroundColor = CreateColor(28, 32, 26),
    HeaderColor = CreateColor(35, 40, 32),
    TextColor = CreateColor(220, 233, 213),
    ButtonColor = CreateColor(42, 48, 38),
    ButtonHoverColor = CreateColor(52, 59, 47),
    PlayingButtonColor = CreateColor(106, 153, 78),
    CloseButtonColor = CreateColor(35, 40, 32),
    CloseButtonHoverColor = CreateColor(179, 88, 88),
    ScrollbarColor = CreateColor(42, 48, 38),
    ScrollbarGripColor = CreateColor(106, 153, 78),
    SearchBoxColor = CreateColor(35, 40, 32),
    AccentPrimary = CreateColor(106, 153, 78),
    AccentSecondary = CreateColor(147, 191, 121),
    Success = CreateColor(106, 153, 78),
    Error = CreateColor(179, 88, 88),
    Loading = CreateColor(209, 178, 94),
    Disabled = CreateColor(52, 59, 47),
    Border = CreateColor(62, 71, 56),
    Highlight = CreateColor(106, 153, 78, 50)
})

rRadio.themes["ocean"] = CreateTheme({
    BackgroundColor = CreateColor(16, 37, 66),
    HeaderColor = CreateColor(21, 48, 85),
    TextColor = CreateColor(224, 241, 255),
    ButtonColor = CreateColor(26, 59, 104),
    ButtonHoverColor = CreateColor(31, 70, 123),
    PlayingButtonColor = CreateColor(64, 144, 208),
    CloseButtonColor = CreateColor(21, 48, 85),
    CloseButtonHoverColor = CreateColor(208, 64, 64),
    ScrollbarColor = CreateColor(26, 59, 104),
    ScrollbarGripColor = CreateColor(64, 144, 208),
    SearchBoxColor = CreateColor(21, 48, 85),
    AccentPrimary = CreateColor(64, 144, 208),
    AccentSecondary = CreateColor(96, 176, 240),
    Success = CreateColor(64, 208, 144),
    Error = CreateColor(208, 64, 64),
    Loading = CreateColor(240, 176, 64),
    Disabled = CreateColor(31, 70, 123),
    Border = CreateColor(41, 92, 161),
    Highlight = CreateColor(64, 144, 208, 50)
})

rRadio.themes["volcanic"] = CreateTheme({
    BackgroundColor = CreateColor(38, 25, 25),
    HeaderColor = CreateColor(48, 31, 31),
    TextColor = CreateColor(255, 225, 225),
    ButtonColor = CreateColor(58, 37, 37),
    ButtonHoverColor = CreateColor(71, 45, 45),
    PlayingButtonColor = CreateColor(205, 71, 71),
    CloseButtonColor = CreateColor(48, 31, 31),
    CloseButtonHoverColor = CreateColor(255, 89, 89),
    ScrollbarColor = CreateColor(58, 37, 37),
    ScrollbarGripColor = CreateColor(205, 71, 71),
    SearchBoxColor = CreateColor(48, 31, 31),
    AccentPrimary = CreateColor(205, 71, 71),
    AccentSecondary = CreateColor(237, 103, 103),
    Success = CreateColor(103, 237, 135),
    Error = CreateColor(255, 89, 89),
    Loading = CreateColor(237, 186, 103),
    Disabled = CreateColor(71, 45, 45),
    Border = CreateColor(81, 52, 52),
    Highlight = CreateColor(205, 71, 71, 50)
})

return rRadio.themes
