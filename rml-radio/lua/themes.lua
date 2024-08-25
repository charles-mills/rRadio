local darkTheme = {
    FrameSize = {width = 400, height = 550}, -- Width and height of the main frame
    BackgroundColor = Color(45, 45, 45, 250), -- Background color of the main frame
    HeaderColor = Color(35, 35, 35, 255), -- Color of the header
    TextColor = Color(255, 255, 255), -- Text color
    CloseButtonColor = Color(200, 50, 50, 250), -- Close button color
    CloseButtonHoverColor = Color(220, 70, 70, 250), -- Close button hover color
    SearchBoxColor = Color(60, 60, 60, 250), -- Background color of the search box
    ScrollbarColor = Color(35, 35, 35, 255), -- Color of the scrollbar
    ScrollbarGripColor = Color(100, 100, 100, 255), -- Color of the scrollbar grip
    ButtonColor = Color(60, 60, 60, 250), -- Default button background color
    ButtonHoverColor = Color(80, 80, 80, 250), -- Button background color when hovered
    PlayingButtonColor = Color(70, 130, 180, 250), -- Color of the currently playing station button (SteelBlue)
}

local lightTheme = {
    FrameSize = {width = 400, height = 550}, -- Width and height of the main frame
    BackgroundColor = Color(230, 230, 230, 250), -- Background color of the main frame
    HeaderColor = Color(200, 200, 200, 255), -- Color of the header
    TextColor = Color(0, 0, 0), -- Text color
    CloseButtonColor = Color(200, 50, 50, 250), -- Close button color
    CloseButtonHoverColor = Color(220, 70, 70, 250), -- Close button hover color
    SearchBoxColor = Color(180, 180, 180, 250), -- Background color of the search box
    ScrollbarColor = Color(200, 200, 200, 255), -- Color of the scrollbar
    ScrollbarGripColor = Color(150, 150, 150, 255), -- Color of the scrollbar grip
    ButtonColor = Color(180, 180, 180, 250), -- Default button background color
    ButtonHoverColor = Color(160, 160, 160, 250), -- Button background color when hovered
    PlayingButtonColor = Color(70, 130, 180, 250), -- Color of the currently playing station button (SteelBlue)
}

return {
    darkTheme = darkTheme,
    lightTheme = lightTheme
}
