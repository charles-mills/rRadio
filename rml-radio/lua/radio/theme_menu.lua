-- Include the themes.lua file to access the defined themes
local themes = include("themes.lua")

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
hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Radio Addon", "ThemeVolumeSelection", "Settings", "", "", function(panel)
        panel:ClearControls()
        
        -- Section for Theme Selection
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

        -- Section for Volume Control
        panel:Help("Set the global maximum volume for all radios:")

        local volumeSlider = vgui.Create("DNumSlider", panel)
        volumeSlider:SetText("Max Radio Volume")
        volumeSlider:SetMin(0)
        volumeSlider:SetMax(1)
        volumeSlider:SetDecimals(2)
        volumeSlider:SetConVar("radio_max_volume") -- Bind to the ConVar
        volumeSlider:SetValue(GetConVar("radio_max_volume"):GetFloat()) -- Set initial value

        panel:AddItem(volumeSlider)
    end)
end)
