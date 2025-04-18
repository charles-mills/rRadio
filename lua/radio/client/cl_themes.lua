local themes = {}

local function CreateTheme(colors)
    return {
        FrameSize = {width = 600, height = 800},
        BackgroundColor = colors.background,
        HeaderColor = colors.header,
        TextColor = colors.text,
        ButtonColor = colors.button,
        ButtonHoverColor = colors.buttonHover,
        PlayingButtonColor = colors.playing,
        CloseButtonColor = colors.close,
        CloseButtonHoverColor = colors.closeHover,
        ScrollbarColor = colors.scrollbar,
        ScrollbarGripColor = colors.scrollbarGrip,
        SearchBoxColor = colors.searchBox,
        AccentPrimary = colors.accentPrimary,
        AccentSecondary = colors.accentSecondary,
        Success = colors.success,
        Error = colors.error,
        Loading = colors.loading,
        Disabled = colors.disabled,
        Border = colors.border,
        Highlight = colors.highlight
    }
end

themes["dark"] =
    CreateTheme(
    {
        background = Color(18, 18, 24),
        header = Color(24, 24, 32),
        text = Color(240, 240, 250),
        button = Color(28, 28, 36),
        buttonHover = Color(35, 35, 45),
        playing = Color(45, 45, 55),
        close = Color(24, 24, 32),
        closeHover = Color(35, 35, 45),
        scrollbar = Color(28, 28, 36),
        scrollbarGrip = Color(45, 45, 55),
        searchBox = Color(24, 24, 32),
        accentPrimary = Color(86, 97, 245),
        accentSecondary = Color(149, 128, 255),
        success = Color(46, 160, 67),
        error = Color(248, 81, 73),
        loading = Color(246, 190, 0),
        disabled = Color(48, 48, 56),
        border = Color(38, 38, 46),
        highlight = Color(56, 56, 66)
    }
)

themes["sleek"] =
    CreateTheme(
    {
        background = Color(20, 23, 31),
        header = Color(30, 34, 43),
        text = Color(236, 239, 244),
        button = Color(36, 41, 51),
        buttonHover = Color(46, 52, 64),
        playing = Color(94, 129, 172),
        close = Color(30, 34, 43),
        closeHover = Color(191, 97, 106),
        scrollbar = Color(36, 41, 51),
        scrollbarGrip = Color(76, 86, 106),
        searchBox = Color(30, 34, 43),
        accentPrimary = Color(94, 129, 172),
        accentSecondary = Color(129, 161, 193),
        success = Color(163, 190, 140),
        error = Color(191, 97, 106),
        loading = Color(235, 203, 139),
        disabled = Color(67, 76, 94),
        border = Color(46, 52, 64),
        highlight = Color(76, 86, 106)
    }
)

themes["cyberpunk"] =
    CreateTheme(
    {
        background = Color(13, 13, 23),
        header = Color(20, 20, 35),
        text = Color(0, 255, 255),
        button = Color(25, 25, 45),
        buttonHover = Color(35, 35, 60),
        playing = Color(255, 0, 128),
        close = Color(20, 20, 35),
        closeHover = Color(255, 0, 128),
        scrollbar = Color(25, 25, 45),
        scrollbarGrip = Color(0, 255, 255),
        searchBox = Color(20, 20, 35),
        accentPrimary = Color(255, 0, 128),
        accentSecondary = Color(128, 0, 255),
        success = Color(0, 255, 128),
        error = Color(255, 0, 64),
        loading = Color(255, 191, 0),
        disabled = Color(40, 40, 60),
        border = Color(0, 255, 255, 50),
        highlight = Color(128, 0, 255, 30)
    }
)

themes["sunset"] =
    CreateTheme(
    {
        background = Color(44, 54, 76),
        header = Color(34, 42, 59),
        text = Color(255, 241, 230),
        button = Color(54, 66, 93),
        buttonHover = Color(64, 78, 110),
        playing = Color(255, 123, 84),
        close = Color(34, 42, 59),
        closeHover = Color(255, 89, 94),
        scrollbar = Color(54, 66, 93),
        scrollbarGrip = Color(255, 170, 110),
        searchBox = Color(34, 42, 59),
        accentPrimary = Color(255, 123, 84),
        accentSecondary = Color(255, 170, 110),
        success = Color(115, 192, 136),
        error = Color(255, 89, 94),
        loading = Color(255, 198, 127),
        disabled = Color(74, 86, 113),
        border = Color(64, 78, 110),
        highlight = Color(255, 123, 84, 30)
    }
)

themes["emerald"] =
    CreateTheme(
    {
        background = Color(0, 48, 51),
        header = Color(0, 38, 41),
        text = Color(236, 255, 244),
        button = Color(0, 58, 61),
        buttonHover = Color(0, 68, 71),
        playing = Color(0, 196, 140),
        close = Color(0, 38, 41),
        closeHover = Color(255, 76, 76),
        scrollbar = Color(0, 58, 61),
        scrollbarGrip = Color(0, 196, 140),
        searchBox = Color(0, 38, 41),
        accentPrimary = Color(0, 196, 140),
        accentSecondary = Color(0, 168, 120),
        success = Color(0, 196, 140),
        error = Color(255, 76, 76),
        loading = Color(255, 186, 8),
        disabled = Color(0, 78, 81),
        border = Color(0, 88, 91),
        highlight = Color(0, 196, 140, 30)
    }
)

themes["synthwave"] =
    CreateTheme(
    {
        background = Color(23, 12, 45),
        header = Color(30, 15, 58),
        text = Color(255, 149, 249),
        button = Color(38, 20, 71),
        buttonHover = Color(48, 25, 89),
        playing = Color(142, 45, 226),
        close = Color(30, 15, 58),
        closeHover = Color(255, 56, 100),
        scrollbar = Color(38, 20, 71),
        scrollbarGrip = Color(108, 8, 213),
        searchBox = Color(30, 15, 58),
        accentPrimary = Color(255, 56, 100),
        accentSecondary = Color(142, 45, 226),
        success = Color(0, 255, 170),
        error = Color(255, 56, 100),
        loading = Color(255, 198, 0),
        disabled = Color(58, 30, 91),
        border = Color(68, 35, 111),
        highlight = Color(142, 45, 226, 30)
    }
)

themes["forest"] =
    CreateTheme(
    {
        background = Color(28, 32, 26),
        header = Color(35, 40, 32),
        text = Color(220, 233, 213),
        button = Color(42, 48, 38),
        buttonHover = Color(52, 59, 47),
        playing = Color(106, 153, 78),
        close = Color(35, 40, 32),
        closeHover = Color(179, 88, 88),
        scrollbar = Color(42, 48, 38),
        scrollbarGrip = Color(106, 153, 78),
        searchBox = Color(35, 40, 32),
        accentPrimary = Color(106, 153, 78),
        accentSecondary = Color(147, 191, 121),
        success = Color(106, 153, 78),
        error = Color(179, 88, 88),
        loading = Color(209, 178, 94),
        disabled = Color(52, 59, 47),
        border = Color(62, 71, 56),
        highlight = Color(106, 153, 78, 30)
    }
)

themes["ocean"] =
    CreateTheme(
    {
        background = Color(16, 37, 66),
        header = Color(21, 48, 85),
        text = Color(224, 241, 255),
        button = Color(26, 59, 104),
        buttonHover = Color(31, 70, 123),
        playing = Color(64, 144, 208),
        close = Color(21, 48, 85),
        closeHover = Color(208, 64, 64),
        scrollbar = Color(26, 59, 104),
        scrollbarGrip = Color(64, 144, 208),
        searchBox = Color(21, 48, 85),
        accentPrimary = Color(64, 144, 208),
        accentSecondary = Color(96, 176, 240),
        success = Color(64, 208, 144),
        error = Color(208, 64, 64),
        loading = Color(240, 176, 64),
        disabled = Color(31, 70, 123),
        border = Color(41, 92, 161),
        highlight = Color(64, 144, 208, 30)
    }
)

themes["volcanic"] =
    CreateTheme(
    {
        background = Color(38, 25, 25),
        header = Color(48, 31, 31),
        text = Color(255, 225, 225),
        button = Color(58, 37, 37),
        buttonHover = Color(71, 45, 45),
        playing = Color(205, 71, 71),
        close = Color(48, 31, 31),
        closeHover = Color(255, 89, 89),
        scrollbar = Color(58, 37, 37),
        scrollbarGrip = Color(205, 71, 71),
        searchBox = Color(48, 31, 31),
        accentPrimary = Color(205, 71, 71),
        accentSecondary = Color(237, 103, 103),
        success = Color(103, 237, 135),
        error = Color(255, 89, 89),
        loading = Color(237, 186, 103),
        disabled = Color(71, 45, 45),
        border = Color(81, 52, 52),
        highlight = Color(205, 71, 71, 30)
    }
)

return themes
