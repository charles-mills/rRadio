local themes = include("themes.lua")
local languageManager = include("language_manager.lua")

-- Create the client convar to enable/disable chat messages
CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")

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
        themeHeader:DockMargin(0, 0, 0, 0)
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
        languageHeader:DockMargin(0, 20, 0, 0)
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

        -- Volume Control Section
        local volumeHeader = vgui.Create("DLabel", panel)
        volumeHeader:SetText("Volume Control")
        volumeHeader:SetFont("Trebuchet18")
        volumeHeader:SetTextColor(Color(50, 50, 50))
        volumeHeader:Dock(TOP)
        volumeHeader:DockMargin(0, 20, 0, 0)
        panel:AddItem(volumeHeader)

        local volumeSlider = vgui.Create("DNumSlider", panel)
        volumeSlider:SetText("Max Radio Volume")
        volumeSlider:SetMin(0)
        volumeSlider:SetMax(1)
        volumeSlider:SetDecimals(2)
        volumeSlider:SetConVar("radio_max_volume")
        volumeSlider:Dock(TOP)
        volumeSlider:DockMargin(0, 0, 0, 10)
        volumeSlider:SetValue(GetConVar("radio_max_volume"):GetFloat())
        volumeSlider:SetTooltip("Adjust the maximum volume level for the radio.")

        panel:AddItem(volumeSlider)

        -- Chat Message Toggle Section
        local chatHeader = vgui.Create("DLabel", panel)
        chatHeader:SetText("Chat Message Settings")
        chatHeader:SetFont("Trebuchet18")
        chatHeader:SetTextColor(Color(50, 50, 50))
        chatHeader:Dock(TOP)
        chatHeader:DockMargin(0, 20, 0, 0)
        panel:AddItem(chatHeader)

        local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
        chatMessageCheckbox:SetText("Show Car Radio Messages")
        chatMessageCheckbox:SetConVar("car_radio_show_messages")
        chatMessageCheckbox:Dock(TOP)
        chatMessageCheckbox:DockMargin(0, 0, 0, 0)
        chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool())
        chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio messages.")

        panel:AddItem(chatMessageCheckbox)
    end)
end)
