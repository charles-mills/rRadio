local themes = include("themes.lua")
local languageManager = include("language_manager.lua")

-- Create the client convar to enable/disable chat messages
CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox.")

-- Function to apply the selected theme
local function applyTheme(themeName)
    if themes[themeName] then
        Config.UI = themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        print("Invalid theme name: " .. themeName)
    end
end

-- Function to apply the selected language
local function applyLanguage(languageCode)
    if languageManager.languages[languageCode] then
        Config.Lang = languageManager.translations[languageCode]  -- Get the translations from the language manager
        hook.Run("LanguageChanged", languageCode)
        hook.Run("LanguageUpdated")  -- Custom hook to trigger list update
    else
        print("Invalid language code: " .. languageCode)
    end
end

-- Load the saved theme and language from convars and apply them
local function loadSavedSettings()
    local themeName = GetConVar("radio_theme"):GetString()
    applyTheme(themeName)

    local languageCode = GetConVar("radio_language"):GetString()
    applyLanguage(languageCode)
end

-- Call loadSavedSettings when the client finishes loading all entities
hook.Add("InitPostEntity", "ApplySavedThemeAndLanguageOnJoin", function()
    loadSavedSettings()
end)

-- Hook to update the UI when the language is changed
hook.Add("LanguageUpdated", "UpdateCountryListOnLanguageChange", function()
    if radioMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)  -- Repopulate the list
    end
end)

-- Create a new tool menu in the "Utilities" section
hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Rammel's Radio", "ThemeVolumeSelection", "Settings", "", "", function(panel)
        panel:ClearControls()
        panel:DockPadding(10, 0, 30, 10)

        -- Theme Selection Section
        local themeHeader = vgui.Create("DLabel", panel)
        themeHeader:SetText("Theme Selection")
        themeHeader:SetFont("Trebuchet18")
        themeHeader:SetTextColor(Color(50, 50, 50))
        themeHeader:Dock(TOP)
        themeHeader:DockMargin(0, 0, 0, 5)
        panel:AddItem(themeHeader)

        local themeDropdown = vgui.Create("DComboBox", panel)
        themeDropdown:SetValue("Select Theme")
        themeDropdown:Dock(TOP)
        themeDropdown:SetTall(30)
        themeDropdown:SetTooltip("Select the theme for the radio UI.")

        -- Dynamically add all available themes to the dropdown
        for themeName, _ in pairs(themes) do
            themeDropdown:AddChoice(themeName:gsub("^%l", string.upper))
        end

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

        -- Language Selection Section
        local languageHeader = vgui.Create("DLabel", panel)
        languageHeader:SetText("Language Selection")
        languageHeader:SetFont("Trebuchet18")
        languageHeader:SetTextColor(Color(50, 50, 50))
        languageHeader:Dock(TOP)
        languageHeader:DockMargin(0, 20, 0, 5)
        panel:AddItem(languageHeader)

        local languageDropdown = vgui.Create("DComboBox", panel)
        languageDropdown:SetValue("Select Language")
        languageDropdown:Dock(TOP)
        languageDropdown:SetTall(30)
        languageDropdown:SetTooltip("Select the language for the radio UI.")

        -- Dynamically add all available languages to the dropdown
        for code, name in pairs(languageManager.languages) do
            languageDropdown:AddChoice(name, code)
        end

        local currentLanguage = GetConVar("radio_language"):GetString()
        if currentLanguage and languageManager.languages[currentLanguage] then
            languageDropdown:SetValue(languageManager.languages[currentLanguage])
        end

        languageDropdown.OnSelect = function(panel, index, value, data)
            applyLanguage(data)
            RunConsoleCommand("radio_language", data)
        end

        panel:AddItem(languageDropdown)

        -- General Options Section
        local generalOptionsHeader = vgui.Create("DLabel", panel)
        generalOptionsHeader:SetText("General Options")
        generalOptionsHeader:SetFont("Trebuchet18")
        generalOptionsHeader:SetTextColor(Color(50, 50, 50))
        generalOptionsHeader:Dock(TOP)
        generalOptionsHeader:DockMargin(0, 20, 0, 5)
        panel:AddItem(generalOptionsHeader)

        -- Show Car Radio Messages Toggle
        local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
        chatMessageCheckbox:SetText("Show Car Radio Messages")
        chatMessageCheckbox:SetConVar("car_radio_show_messages")
        chatMessageCheckbox:Dock(TOP)
        chatMessageCheckbox:DockMargin(0, 0, 0, 5)
        chatMessageCheckbox:SetTextColor(Color(0, 0, 0))  -- Set text color to black
        chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool())
        chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio messages.")
        panel:AddItem(chatMessageCheckbox)

        -- Show Boombox Hover Text Toggle
        local showTextCheckbox = vgui.Create("DCheckBoxLabel", panel)
        showTextCheckbox:SetText("Show Boombox Hover Text")
        showTextCheckbox:SetConVar("boombox_show_text")
        showTextCheckbox:Dock(TOP)
        showTextCheckbox:DockMargin(0, 0, 0, 0)
        showTextCheckbox:SetTextColor(Color(0, 0, 0))  -- Set text color to black
        showTextCheckbox:SetValue(GetConVar("boombox_show_text"):GetBool())
        showTextCheckbox:SetTooltip("Enable or disable the display of text above the boombox.")
        panel:AddItem(showTextCheckbox)
    end)
end)
