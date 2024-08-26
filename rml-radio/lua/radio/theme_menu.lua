-- Include the themes.lua file to access the defined themes
local themes = include("themes.lua")

-- Create the client convar to enable/disable chat messages
CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")

-- Function to apply the selected theme
local function applyTheme(themeName)
    Config = Config or {}

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
    spawnmenu.AddToolMenuOption("Utilities", "Rammel's Radio", "ThemeVolumeSelection", "Settings", "", "", function(panel)
        panel:ClearControls()
        
        -- Adding padding and margin for better spacing
        panel:DockPadding(10, 0, 30, 10)

        -- Section Header for Theme Selection
        local themeHeader = vgui.Create("DLabel", panel)
        themeHeader:SetText("Theme Selection")
        themeHeader:SetFont("Trebuchet18")
        themeHeader:SetTextColor(Color(50, 50, 50))  -- Darker color for visibility on light background
        themeHeader:Dock(TOP)
        themeHeader:DockMargin(0, 0, 0, 0)
        panel:AddItem(themeHeader)

        local themeDropdown = vgui.Create("DComboBox", panel)
        themeDropdown:SetValue("Select Theme")
        themeDropdown:Dock(TOP)
        themeDropdown:SetTall(30)
        themeDropdown:SetTooltip("Select the theme for the radio UI.") -- Tooltip text

        -- Dynamically add all available themes to the dropdown
        for themeName, _ in pairs(themes) do
            themeDropdown:AddChoice(themeName:gsub("^%l", string.upper)) -- Capitalizes the first letter of the theme name for display
        end

        -- Set the current value to the saved theme
        local currentTheme = GetConVar("radio_theme"):GetString()
        if currentTheme and themes[currentTheme] then
            themeDropdown:SetValue(currentTheme:gsub("^%l", string.upper))
        end

        themeDropdown.OnSelect = function(panel, index, value)
            local lowerValue = value:lower()
            if themes[lowerValue] then
                applyTheme(lowerValue)
                RunConsoleCommand("radio_theme", lowerValue)
            end
        end

        panel:AddItem(themeDropdown)

        -- Section Header for Volume Control
        local volumeHeader = vgui.Create("DLabel", panel)
        volumeHeader:SetText("Volume Control")
        volumeHeader:SetFont("Trebuchet18")
        volumeHeader:SetTextColor(Color(50, 50, 50))  -- Darker color for visibility on light background
        volumeHeader:Dock(TOP)
        volumeHeader:DockMargin(0, 20, 0, 0)
        panel:AddItem(volumeHeader)

        local volumeSlider = vgui.Create("DNumSlider", panel)
        volumeSlider:SetText("Max Radio Volume")
        volumeSlider:SetMin(0)
        volumeSlider:SetMax(1)
        volumeSlider:SetDecimals(2)
        volumeSlider:SetConVar("radio_max_volume") -- Bind to the ConVar
        volumeSlider:Dock(TOP)
        volumeSlider:DockMargin(0, 0, 0, 10)
        volumeSlider:SetValue(GetConVar("radio_max_volume"):GetFloat()) -- Set initial value
        volumeSlider:SetTooltip("Adjust the maximum volume level for the radio.") -- Tooltip text

        panel:AddItem(volumeSlider)

        -- Section Header for Chat Message Toggle
        local chatHeader = vgui.Create("DLabel", panel)
        chatHeader:SetText("Chat Message Settings")
        chatHeader:SetFont("Trebuchet18")
        chatHeader:SetTextColor(Color(50, 50, 50))  -- Darker color for visibility on light background
        chatHeader:Dock(TOP)
        chatHeader:DockMargin(0, 20, 0, 0)
        panel:AddItem(chatHeader)

        local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
        chatMessageCheckbox:SetText("Show Car Radio Messages")
        chatMessageCheckbox:SetConVar("car_radio_show_messages") -- Bind to the ConVar
        chatMessageCheckbox:Dock(TOP)
        chatMessageCheckbox:DockMargin(0, 0, 0, 0)
        chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool()) -- Set initial value
        chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio messages.") -- Tooltip text

        panel:AddItem(chatMessageCheckbox)
    end)
end)
