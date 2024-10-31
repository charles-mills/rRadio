--[[
    Radio Addon Client-Side Themes
    Author: Charles Mills
    Description: This file defines various visual themes for the Radio Addon's user interface.
                 It includes color schemes and style settings for different UI elements,
                 allowing users to customize the look and feel of the radio menu.
    Date: October 31, 2024
]]--

local themes = {}

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

themes["dark"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(30, 30, 30),
    HeaderColor = Color(40, 40, 40),
    TextColor = Color(240, 240, 240),
    ButtonColor = Color(70, 70, 70),
    ButtonHoverColor = Color(90, 90, 90),
    PlayingButtonColor = Color(40, 40, 40),
    CloseButtonColor = Color(60, 60, 60),
    CloseButtonHoverColor = Color(80, 80, 80),
    ScrollbarColor = Color(70, 70, 70),
    ScrollbarGripColor = Color(120, 120, 120),
    SearchBoxColor = Color(60, 60, 60),
}

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

themes["gold"] = {
    FrameSize = { width = 600, height = 800 },
    BackgroundColor = Color(15, 15, 15),
    HeaderColor = Color(25, 25, 25),
    TextColor = Color(228, 161, 15),
    ButtonColor = Color(35, 35, 35),
    ButtonHoverColor = Color(22, 22, 22),
    PlayingButtonColor = Color(8, 8, 8),
    CloseButtonColor = Color(25, 25, 25),
    CloseButtonHoverColor = Color(39, 39, 39),
    ScrollbarColor = Color(35, 35, 35),
    ScrollbarGripColor = Color(228, 161, 15),
    SearchBoxColor = Color(25, 25, 25),
    AccentColor = Color(228, 161, 15),
}

return themes
