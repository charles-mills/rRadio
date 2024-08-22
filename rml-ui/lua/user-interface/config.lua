local screenWidth = ScrW() -- Get the screen width
local screenHeight = ScrH() -- Get the screen height

HUDServerConfig = {
    currency = "£"
}

HUDConfig = {
    backgroundColor = Color(30, 30, 30, 200),
    textColor = Color(255, 255, 255),
    healthColor = Color(255, 0, 0, 200),
    armorColor = Color(0, 0, 255, 200),
    elements = {
        background = {
            x = 0, -- 0% of the screen width
            y = 0, -- 0% of the screen height
            width = screenWidth, -- 100% of the screen width
            height = screenHeight * 0.1 -- 10% of the screen height
        },
        rpName = {
            x = screenWidth * 0.04, -- 4% of the screen width
            y = screenHeight * 0.91, -- 91% of the screen height
            width = screenWidth * 0.28, -- 28% of the screen width
            height = screenHeight * 0.02 -- 2% of the screen height
        },
        health = {
            x = screenWidth * 0.72, -- 72% of the screen width
            y = screenHeight * 0.91, -- 91% of the screen height
            width = screenWidth * 0.24, -- 24% of the screen width
            height = screenHeight * 0.02 -- 2% of the screen height
        },
        armor = {
            x = screenWidth * 0.72, -- 72% of the screen width
            y = screenHeight * 0.94, -- 94% of the screen height
            width = screenWidth * 0.24, -- 24% of the screen width
            height = screenHeight * 0.02 -- 2% of the screen height
        },
        money = {
            x = screenWidth * 0.72, -- 72% of the screen width
            y = screenHeight * 0.97, -- 97% of the screen height
            width = screenWidth * 0.24, -- 24% of the screen width
            height = screenHeight * 0.02 -- 2% of the screen height
        }
    }
}
