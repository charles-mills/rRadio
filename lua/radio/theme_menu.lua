include("radio/utils.lua")
include("radio/key_names.lua")
include("themes.lua")
include("language_manager.lua")

-- Hook to update the UI when the language is changed
hook.Add("LanguageUpdated", "UpdateCountryListOnLanguageChange", function()
    if radioMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)  -- Repopulate the list
    end
end)

--[[
    Function: sortKeys
    Description: Sorts key codes based on single-letter, numeric, and multi-letter names.
    @return (table): A sorted table of keys.
]]
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

    table.sort(singleLetterKeys, function(a, b) return a.name < b.name end)
    table.sort(numericKeys, function(a, b) return tonumber(a.name) < tonumber(b.name) end)
    table.sort(otherKeys, function(a, b) return a.name < b.name end)

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

--[[
    Function: CreateSettingsMenu
    Description: Creates the settings menu in the spawnmenu.
    @param panel (Panel): The parent panel.
]]
local function CreateSettingsMenu(panel)
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

    -- Add themes to dropdown
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
            utils.applyTheme(lowerValue)
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

    -- Add languages to dropdown
    for code, name in pairs(languageManager.languages) do
        languageDropdown:AddChoice(name, code)
    end

    local currentLanguage = GetConVar("radio_language"):GetString()
    if currentLanguage and languageManager.languages[currentLanguage] then
        languageDropdown:SetValue(languageManager.languages[currentLanguage])
    end

    languageDropdown.OnSelect = function(panel, index, value, data)
        utils.applyLanguage(data)
        RunConsoleCommand("radio_language", data)
    end

    panel:AddItem(languageDropdown)

    -- Key Selection Section
    local keySelectionHeader = vgui.Create("DLabel", panel)
    keySelectionHeader:SetText("Select Key to Open Radio Menu")
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

    -- Add keys to dropdown
    local sortedKeys = sortKeys()
    for _, key in ipairs(sortedKeys) do
        keyDropdown:AddChoice(key.name, key.code)
    end

    -- Set current key
    local currentKey = GetConVar("car_radio_open_key"):GetInt()
    if keyCodeMapping[currentKey] then
        keyDropdown:SetValue(keyCodeMapping[currentKey])
    end

    keyDropdown.OnSelect = function(panel, index, value, data)
        RunConsoleCommand("car_radio_open_key", data)
    end

    panel:AddItem(keyDropdown)

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
    chatMessageCheckbox:SetTextColor(Color(0, 0, 0))
    chatMessageCheckbox:SetValue(GetConVar("car_radio_show_messages"):GetBool())
    chatMessageCheckbox:SetTooltip("Enable or disable the display of car radio messages.")
    panel:AddItem(chatMessageCheckbox)

    -- Show Boombox Hover Text Toggle
    local showTextCheckbox = vgui.Create("DCheckBoxLabel", panel)
    showTextCheckbox:SetText("Show Boombox Hover Text")
    showTextCheckbox:SetConVar("boombox_show_text")
    showTextCheckbox:Dock(TOP)
    showTextCheckbox:DockMargin(0, 0, 0, 0)
    showTextCheckbox:SetTextColor(Color(0, 0, 0))
    showTextCheckbox:SetValue(GetConVar("boombox_show_text"):GetBool())
    showTextCheckbox:SetTooltip("Enable or disable the display of text above the boombox.")
    panel:AddItem(showTextCheckbox)
end

-- Add the settings menu to the spawnmenu
hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Rammel's Radio", "ThemeVolumeSelection", "Settings", "", "", CreateSettingsMenu)
end)