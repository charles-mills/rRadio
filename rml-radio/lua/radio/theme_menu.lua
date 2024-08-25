CreateClientConVar("radio_theme", "dark", true, false)

-- Include the themes.lua file to access the defined themes
local themes = include("themes.lua") -- Make sure the path is correct

-- Function to apply the selected theme
local function applyTheme(themeName)
    if themes[themeName] then
        Config.UI = themes[themeName]
        -- You may need to refresh your UI elements to apply the new theme
        hook.Run("ThemeChanged", themeName)
    else
        print("Invalid theme name: " .. themeName)
    end
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
        themeDropdown:AddChoice("Ocean")
        themeDropdown:AddChoice("Forest")

        -- Set the current value to the saved theme
        local currentTheme = GetConVar("radio_theme"):GetString()
        if currentTheme == "dark" then
            themeDropdown:SetValue("Dark")
        elseif currentTheme == "light" then
            themeDropdown:SetValue("Light")
        elseif currentTheme == "ocean" then
            themeDropdown:SetValue("Ocean")
        elseif currentTheme == "forest" then
            themeDropdown:SetValue("Forest")
        end

        themeDropdown.OnSelect = function(panel, index, value)
            local lowerValue = value:lower()
            if themes[lowerValue] then
                applyTheme(lowerValue)
                RunConsoleCommand("radio_theme", lowerValue)
            end
        end

        panel:AddItem(themeDropdown)
    end)
end)
