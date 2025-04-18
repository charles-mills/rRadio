local keyCodeMapping = include("radio/client/cl_key_names.lua")
local themes = include("radio/client/cl_themes.lua")
local languageManager = include("radio/client/lang/cl_language_manager.lua")
CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio animation.")
CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the HUD for the boombox.")
CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
local function applyTheme(themeName)
    if themes[themeName] then
        Config.UI = themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        print("[rRADIO] Invalid theme name: " .. themeName)
    end
end
local function applyLanguage(languageCode)
    if languageManager.languages[languageCode] then
        Config.Lang = languageManager.translations[languageCode]
        hook.Run("LanguageChanged", languageCode)
        hook.Run("LanguageUpdated")
    else
        print("[rRADIO] Invalid language code: " .. languageCode)
    end
end
local function loadSavedSettings()
    local themeName = GetConVar("radio_theme"):GetString()
    applyTheme(themeName)
    local languageCode = GetConVar("radio_language"):GetString()
    applyLanguage(languageCode)
end
hook.Add(
    "InitPostEntity",
    "ApplySavedThemeAndLanguageOnJoin",
    function()
        loadSavedSettings()
    end
)
hook.Add(
    "LanguageUpdated",
    "UpdateCountryListOnLanguageChange",
    function()
        if radioMenuOpen then
            populateList(stationListPanel, backButton, searchBox, true)
        end
    end
)
local function sortKeys()
    local sortedKeys = {}
    local singleLetterKeys = {}
    local numericKeys = {}
    local otherKeys = {}
    for keyCode, keyName in pairs(keyCodeMapping) do
        if #keyName == 1 and keyName:match("%a") then
            table.insert(singleLetterKeys, {name = keyName, code = keyCode})
        elseif keyName:match("^%d$") then
            table.insert(numericKeys, {name = keyName, code = keyCode})
        else
            table.insert(otherKeys, {name = keyName, code = keyCode})
        end
    end
    table.sort(
        singleLetterKeys,
        function(a, b)
            return a.name < b.name
        end
    )
    table.sort(
        numericKeys,
        function(a, b)
            return tonumber(a.name) < tonumber(b.name)
        end
    )
    table.sort(
        otherKeys,
        function(a, b)
            return a.name < b.name
        end
    )
    for _, key in ipairs(singleLetterKeys) do
        table.insert(sortedKeys, key)
    end
    for _, key in ipairs(numericKeys) do
        table.insert(sortedKeys, key)
    end
    for _, key in ipairs(otherKeys) do
        table.insert(sortedKeys, key)
    end
    return sortedKeys
end
hook.Add(
    "PopulateToolMenu",
    "AddThemeAndVolumeSelectionMenu",
    function()
        spawnmenu.AddToolMenuOption(
            "Utilities",
            "rlib",
            "ThemeVolumeSelection",
            "rRadio Settings",
            "",
            "",
            function(panel)
                panel:ClearControls()
                panel:DockPadding(10, 0, 30, 10)
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
                local keySelectionHeader = vgui.Create("DLabel", panel)
                keySelectionHeader:SetText(Config.Lang["CarRadioKey"] or "Car Radio Key")
                keySelectionHeader:SetFont("Trebuchet18")
                keySelectionHeader:SetTextColor(Color(50, 50, 50))
                keySelectionHeader:Dock(TOP)
                keySelectionHeader:DockMargin(0, 20, 0, 5)
                panel:AddItem(keySelectionHeader)
                local keyDropdown = vgui.Create("DComboBox", panel)
                keyDropdown:SetValue("Select Key")
                keyDropdown:Dock(TOP)
                keyDropdown:SetTall(30)
                keyDropdown:SetTooltip("Select the key to open the car radio menu.")
                local sortedKeys = sortKeys()
                for _, key in ipairs(sortedKeys) do
                    keyDropdown:AddChoice(key.name, key.code)
                end
                local currentKey = GetConVar("car_radio_open_key"):GetInt()
                if keyCodeMapping[currentKey] then
                    keyDropdown:SetValue(keyCodeMapping[currentKey])
                end
                keyDropdown.OnSelect = function(panel, index, value, data)
                    RunConsoleCommand("car_radio_open_key", data)
                end
                panel:AddItem(keyDropdown)
                local generalOptionsHeader = vgui.Create("DLabel", panel)
                generalOptionsHeader:SetText("General Options")
                generalOptionsHeader:SetFont("Trebuchet18")
                generalOptionsHeader:SetTextColor(Color(50, 50, 50))
                generalOptionsHeader:Dock(TOP)
                generalOptionsHeader:DockMargin(0, 20, 0, 5)
                panel:AddItem(generalOptionsHeader)
                local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
                chatMessageCheckbox:SetText(Config.Lang["ShowCarMessages"] or "Play Animation When Entering Vehicle")
                chatMessageCheckbox:SetConVar("car_radio_show_messages")
                chatMessageCheckbox:Dock(TOP)
                chatMessageCheckbox:DockMargin(0, 0, 0, 5)
                chatMessageCheckbox:SetTextColor(Color(0, 0, 0))
                chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool())
                chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio animations.")
                panel:AddItem(chatMessageCheckbox)
                local showTextCheckbox = vgui.Create("DCheckBoxLabel", panel)
                showTextCheckbox:SetText("Show Boombox HUD")
                showTextCheckbox:SetConVar("boombox_show_text")
                showTextCheckbox:Dock(TOP)
                showTextCheckbox:DockMargin(0, 0, 0, 0)
                showTextCheckbox:SetTextColor(Color(0, 0, 0))
                showTextCheckbox:SetValue(GetConVar("boombox_show_text"):GetBool())
                showTextCheckbox:SetTooltip("Enable or disable the display of the boombox HUD.")
                panel:AddItem(showTextCheckbox)
            end
        )
    end
)
