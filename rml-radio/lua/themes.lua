local themes = {}

-- Dark Theme
themes["dark"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(40, 40, 40),
    HeaderColor = Color(50, 50, 50),
    TextColor = Color(255, 255, 255),
    ButtonColor = Color(60, 60, 60),
    ButtonHoverColor = Color(80, 80, 80),
    PlayingButtonColor = Color(30, 30, 30),
    CloseButtonColor = Color(50, 50, 50),
    CloseButtonHoverColor = Color(70, 70, 70),
    ScrollbarColor = Color(60, 60, 60),
    ScrollbarGripColor = Color(100, 100, 100),
    SearchBoxColor = Color(50, 50, 50),
}

-- Light Theme
themes["light"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(245, 245, 245),
    HeaderColor = Color(220, 220, 220),
    TextColor = Color(30, 30, 30),
    ButtonColor = Color(230, 230, 230),
    ButtonHoverColor = Color(200, 200, 200),
    PlayingButtonColor = Color(180, 180, 180),
    CloseButtonColor = Color(220, 220, 220),
    CloseButtonHoverColor = Color(200, 200, 200),
    ScrollbarColor = Color(210, 210, 210),
    ScrollbarGripColor = Color(180, 180, 180),
    SearchBoxColor = Color(230, 230, 230),
}

-- Ocean Theme
themes["ocean"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(20, 60, 100),
    HeaderColor = Color(15, 45, 75),
    TextColor = Color(255, 255, 255),
    ButtonColor = Color(25, 75, 125),
    ButtonHoverColor = Color(30, 90, 150),
    PlayingButtonColor = Color(10, 50, 90),
    CloseButtonColor = Color(15, 45, 75),
    CloseButtonHoverColor = Color(30, 90, 150),
    ScrollbarColor = Color(20, 60, 100),
    ScrollbarGripColor = Color(30, 90, 150),
    SearchBoxColor = Color(15, 45, 75),
}

-- Forest Theme
themes["forest"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(34, 60, 34),
    HeaderColor = Color(40, 85, 40),
    TextColor = Color(255, 255, 255),
    ButtonColor = Color(45, 100, 45),
    ButtonHoverColor = Color(50, 110, 50),
    PlayingButtonColor = Color(30, 70, 30),
    CloseButtonColor = Color(40, 85, 40),
    CloseButtonHoverColor = Color(50, 110, 50),
    ScrollbarColor = Color(45, 100, 45),
    ScrollbarGripColor = Color(60, 120, 60),
    SearchBoxColor = Color(40, 85, 40),
}

-- Solarized Theme
themes["solarized"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(0, 43, 54),
    HeaderColor = Color(7, 54, 66),
    TextColor = Color(131, 148, 150),
    ButtonColor = Color(88, 110, 117),
    ButtonHoverColor = Color(101, 123, 131),
    PlayingButtonColor = Color(42, 161, 152),
    CloseButtonColor = Color(7, 54, 66),
    CloseButtonHoverColor = Color(108, 113, 196),
    ScrollbarColor = Color(88, 110, 117),
    ScrollbarGripColor = Color(133, 153, 0),
    SearchBoxColor = Color(7, 54, 66),
}

-- Midnight Theme
themes["midnight"] = {
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
}

-- Coral Theme
themes["coral"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(255, 127, 80),
    HeaderColor = Color(255, 99, 71),
    TextColor = Color(255, 255, 255),
    ButtonColor = Color(255, 160, 122),
    ButtonHoverColor = Color(255, 140, 105),
    PlayingButtonColor = Color(205, 92, 92),
    CloseButtonColor = Color(255, 99, 71),
    CloseButtonHoverColor = Color(205, 92, 92),
    ScrollbarColor = Color(255, 160, 122),
    ScrollbarGripColor = Color(255, 140, 105),
    SearchBoxColor = Color(255, 99, 71),
}

-- Minimalist Theme
themes["minimalist"] = {
    FrameSize = { width = 400, height = 500 },
    BackgroundColor = Color(240, 240, 240),
    HeaderColor = Color(200, 200, 200),
    TextColor = Color(50, 50, 50),
    ButtonColor = Color(220, 220, 220),
    ButtonHoverColor = Color(180, 180, 180),
    PlayingButtonColor = Color(150, 150, 150),
    CloseButtonColor = Color(200, 200, 200),
    CloseButtonHoverColor = Color(150, 150, 150),
    ScrollbarColor = Color(220, 220, 220),
    ScrollbarGripColor = Color(180, 180, 180),
    SearchBoxColor = Color(200, 200, 200),
}

-- Neon Dark Theme
themes["neon"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(28, 28, 28),  -- Charcoal
    HeaderColor = Color(40, 40, 40),
    TextColor = Color(224, 224, 224),  -- Light Gray
    ButtonColor = Color(60, 60, 60),  -- Dark Gray
    ButtonHoverColor = Color(255, 110, 110),  -- Neon Red (Accent)
    PlayingButtonColor = Color(255, 76, 76),
    CloseButtonColor = Color(50, 50, 50),
    CloseButtonHoverColor = Color(255, 110, 110),  -- Neon Red (Accent)
    ScrollbarColor = Color(60, 60, 60),
    ScrollbarGripColor = Color(100, 100, 100),
    SearchBoxColor = Color(50, 50, 50),
    AccentColor = Color(255, 110, 110),  -- Neon Red (used for highlights)
}

-- Pastel Theme
themes["pastel"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(247, 243, 233),  -- Cream
    HeaderColor = Color(255, 182, 193),  -- Light Pink
    TextColor = Color(74, 74, 74),  -- Dark Gray
    ButtonColor = Color(255, 209, 220),  -- Very Light Pink
    ButtonHoverColor = Color(157, 214, 223),  -- Soft Blue (Accent)
    PlayingButtonColor = Color(120, 173, 183),
    CloseButtonColor = Color(255, 160, 122),  -- Light Coral
    CloseButtonHoverColor = Color(205, 92, 92),  -- Dark Coral (Accent)
    ScrollbarColor = Color(133, 193, 204),
    ScrollbarGripColor = Color(157, 214, 223),  -- Soft Blue (Accent)
    SearchBoxColor = Color(255, 182, 193),  -- Light Pink
    AccentColor = Color(157, 214, 223),  -- Soft Blue (used for highlights)
}

-- Synthwave Theme
themes["synthwave"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(42, 0, 51),  -- Deep Purple
    HeaderColor = Color(88, 0, 160),  -- Darker Purple
    TextColor = Color(255, 255, 255),  -- White
    ButtonColor = Color(255, 0, 160),  -- Magenta (Accent)
    ButtonHoverColor = Color(8, 247, 254),  -- Neon Cyan (Accent)
    PlayingButtonColor = Color(25, 0, 30),
    CloseButtonColor = Color(88, 0, 160),
    CloseButtonHoverColor = Color(8, 247, 254),  -- Neon Cyan (Accent)
    ScrollbarColor = Color(88, 0, 160),
    ScrollbarGripColor = Color(8, 247, 254),  -- Neon Cyan (Accent)
    SearchBoxColor = Color(88, 0, 160),
    AccentColor = Color(255, 0, 160),  -- Magenta (used for text highlights, borders)
}

-- Gold Theme
themes["gold"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(15, 15, 15),
    HeaderColor = Color(25, 25, 25),
    TextColor = Color(228, 161, 15),
    ButtonColor = Color(35, 35, 35),
    ButtonHoverColor = Color(46, 45, 43),
    PlayingButtonColor = Color(46, 45, 43),
    CloseButtonColor = Color(25, 25, 25),
    CloseButtonHoverColor = Color(228, 161, 15),
    ScrollbarColor = Color(35, 35, 35),
    ScrollbarGripColor = Color(228, 161, 15),
    SearchBoxColor = Color(25, 25, 25),
    AccentColor = Color(228, 161, 15),
}

themes["main"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(15, 15, 15),
    HeaderColor = Color(25, 25, 25),
    TextColor = Color(228, 161, 15),
    ButtonColor = Color(35, 35, 35),
    ButtonHoverColor = Color(46, 45, 43),
    PlayingButtonColor = Color(46, 45, 43),
    CloseButtonColor = Color(25, 25, 25),
    CloseButtonHoverColor = Color(228, 161, 15),
    ScrollbarColor = Color(35, 35, 35),
    ScrollbarGripColor = Color(228, 161, 15),
    SearchBoxColor = Color(25, 25, 25),
    AccentColor = Color(228, 161, 15),
}

return themes