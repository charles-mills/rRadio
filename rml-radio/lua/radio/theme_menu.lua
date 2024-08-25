CreateClientConVar("radio_theme", "dark", true, false)

-- Include the themes.lua file to access the defined themes
local themes = include("themes.lua")

-- Function to apply the selected theme
local function applyTheme(themeName)
    if themeName == "dark" then
        Config.UI = themes.darkTheme
    elseif themeName == "light" then
        Config.UI = themes.lightTheme
    end
    -- Refresh or rebuild your UI elements to apply the new theme
    -- This could involve closing and reopening UI frames or updating their colors
    hook.Run("ThemeChanged", themeName) -- Custom hook to notify the rest of the addon that the theme changed
end

-- Load the saved theme from convar and apply it
local function loadSavedTheme()
    local themeName = GetConVar("radio_theme"):GetString()
    applyTheme(themeName)
end

loadSavedTheme()

-- Create a new tool menu in the "Utilities" section
hook.Add("PopulateToolMenu", "AddThemeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Radio Addon", "ThemeSelection", "Select Theme", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Select your preferred theme for the radio addon UI:")

        local themeDropdown = vgui.Create("DComboBox", panel)
        themeDropdown:SetValue("Select Theme")
        themeDropdown:AddChoice("Dark")
        themeDropdown:AddChoice("Light")

        -- Set the current value to the saved theme
        local currentTheme = GetConVar("radio_theme"):GetString()
        if currentTheme == "dark" then
            themeDropdown:SetValue("Dark")
        elseif currentTheme == "light" then
            themeDropdown:SetValue("Light")
        end

        themeDropdown.OnSelect = function(panel, index, value)
            if value == "Dark" then
                applyTheme("dark")
                RunConsoleCommand("radio_theme", "dark")
            elseif value == "Light" then
                applyTheme("light")
                RunConsoleCommand("radio_theme", "light")
            end
        end

        panel:AddItem(themeDropdown)
    end)
end)
