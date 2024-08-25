local darkTheme = {
    FrameSize = {width = 400, height = 550},
    BackgroundColor = Color(30, 30, 30, 250),
    HeaderColor = Color(20, 20, 20, 255),
    TextColor = Color(255, 255, 255),
    CloseButtonColor = Color(200, 50, 50, 250),
    CloseButtonHoverColor = Color(220, 70, 70, 250),
    SearchBoxColor = Color(45, 45, 45, 250),
    ScrollbarColor = Color(35, 35, 35, 255),
    ScrollbarGripColor = Color(100, 100, 100, 255),
    ButtonColor = Color(60, 60, 60, 250),
    ButtonHoverColor = Color(80, 80, 80, 250),
    PlayingButtonColor = Color(70, 130, 180, 250),
}

local lightTheme = {
    FrameSize = {width = 400, height = 550},
    BackgroundColor = Color(245, 245, 245, 250),
    HeaderColor = Color(220, 220, 220, 255),
    TextColor = Color(0, 0, 0),
    CloseButtonColor = Color(200, 50, 50, 250),
    CloseButtonHoverColor = Color(220, 70, 70, 250),
    SearchBoxColor = Color(230, 230, 230, 250),
    ScrollbarColor = Color(200, 200, 200, 255),
    ScrollbarGripColor = Color(150, 150, 150, 255),
    ButtonColor = Color(200, 200, 200, 250),
    ButtonHoverColor = Color(180, 180, 180, 250),
    PlayingButtonColor = Color(100, 150, 200, 250),
}

local oceanTheme = {
    FrameSize = {width = 400, height = 550},
    BackgroundColor = Color(20, 30, 60, 250),
    HeaderColor = Color(15, 25, 50, 255),
    TextColor = Color(220, 240, 255),
    CloseButtonColor = Color(200, 50, 50, 250),
    CloseButtonHoverColor = Color(220, 70, 70, 250),
    SearchBoxColor = Color(25, 40, 80, 250),
    ScrollbarColor = Color(15, 25, 50, 255),
    ScrollbarGripColor = Color(70, 90, 130, 255),
    ButtonColor = Color(40, 60, 100, 250),
    ButtonHoverColor = Color(50, 75, 120, 250),
    PlayingButtonColor = Color(0, 120, 160, 250),
}

local forestTheme = {
    FrameSize = {width = 400, height = 550},
    BackgroundColor = Color(34, 45, 34, 250),
    HeaderColor = Color(28, 38, 28, 255),
    TextColor = Color(200, 220, 200),
    CloseButtonColor = Color(200, 50, 50, 250),
    CloseButtonHoverColor = Color(220, 70, 70, 250),
    SearchBoxColor = Color(45, 60, 45, 250),
    ScrollbarColor = Color(28, 38, 28, 255),
    ScrollbarGripColor = Color(80, 100, 80, 255),
    ButtonColor = Color(50, 70, 50, 250),
    ButtonHoverColor = Color(60, 85, 60, 250),
    PlayingButtonColor = Color(50, 120, 50, 250),
}

-- Return the themes table so it can be used in other scripts
return {
    dark = darkTheme,
    light = lightTheme,
    ocean = oceanTheme,
    forest = forestTheme
}
