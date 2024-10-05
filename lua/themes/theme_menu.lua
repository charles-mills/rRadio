--[[ 
    rRadio Addon for Garry's Mod - Theme and Settings Menu
    Description: Manages the theme, language, and key binding settings for the radio UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-05
]]

-- -------------------------------
-- 1. Includes and Initialization
-- -------------------------------
local keyCodeMapping = include("misc/key_names.lua")
local themes = include("themes/theme_palettes.lua")
local languageManager = include("localisation/language_manager.lua")

-- Add this near the top of the file, after including language_manager.lua
Config = Config or {}
Config.Lang = Config.Lang or languageManager.translations["en"] or {}

-- Declare createSettingsMenu at the top of the file
local createSettingsMenu

-- -------------------------------
-- 2. Theme and Language Functions
-- -------------------------------
local function applyTheme(themeName)
    if themes[themeName] then
        Config.UI = themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        print("Invalid theme name: " .. themeName)
    end
end

local function applyLanguage(languageCode)
    if languageManager.languages[languageCode] then
        Config.Lang = languageManager.translations[languageCode]
        hook.Run("LanguageChanged", languageCode)
        hook.Run("LanguageUpdated")
        
        -- Refresh the settings menu
        local settingsPanel = controlpanel.Get("ThemeVolumeSelection")
        if IsValid(settingsPanel) and createSettingsMenu then
            createSettingsMenu(settingsPanel)
        end
    else
        print("Invalid language code: " .. languageCode)
    end
end

local function loadSavedSettings()
    local themeName = GetConVar("radio_theme"):GetString()
    applyTheme(themeName)

    local languageCode = GetConVar("radio_language"):GetString()
    applyLanguage(languageCode)
end

-- -------------------------------
-- 3. Hooks
-- -------------------------------
hook.Add("InitPostEntity", "ApplySavedThemeAndLanguageOnJoin", loadSavedSettings)

hook.Add("LanguageUpdated", "UpdateCountryListOnLanguageChange", function()
    if radioMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)
    end
end)

-- -------------------------------
-- 4. Key Sorting Function
-- -------------------------------
local function sortKeys()
    local sortedKeys = {}
    local singleLetterKeys, numericKeys, otherKeys = {}, {}, {}

    for keyCode, keyName in pairs(keyCodeMapping) do
        if keyName:match("^%a$") then
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

    for _, key in ipairs(singleLetterKeys) do table.insert(sortedKeys, key) end
    for _, key in ipairs(numericKeys) do table.insert(sortedKeys, key) end
    for _, key in ipairs(otherKeys) do table.insert(sortedKeys, key) end

    return sortedKeys
end

-- -------------------------------
-- 5. UI Element Creation Functions
-- -------------------------------
local function createThemeDropdown(panel)
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
end

local function createLanguageDropdown(panel)
    local languageDropdown = vgui.Create("DComboBox", panel)
    languageDropdown:Dock(TOP)
    languageDropdown:SetTall(30)
    languageDropdown:SetTooltip("Select the language for the radio UI.")

    for code, name in pairs(languageManager.languages) do
        languageDropdown:AddChoice(name, code)
    end

    local function updateDropdownValue()
        local currentLanguage = GetConVar("radio_language"):GetString()
        if currentLanguage and languageManager.languages[currentLanguage] then
            languageDropdown:SetValue(languageManager.languages[currentLanguage])
        else
            languageDropdown:SetValue("Select Language")
        end
    end

    updateDropdownValue()

    languageDropdown.OnSelect = function(panel, index, value, data)
        -- Apply the language change immediately
        applyLanguage(data)
        -- Set the ConVar after applying the language
        RunConsoleCommand("radio_language", data)
        -- Update the dropdown value
        updateDropdownValue()
        -- Refresh the settings menu to reflect the new language
        timer.Simple(0, function()
            local settingsPanel = controlpanel.Get("ThemeVolumeSelection")
            if IsValid(settingsPanel) then
                createSettingsMenu(settingsPanel)
            end
        end)
    end

    panel:AddItem(languageDropdown)

    -- Update the dropdown value when the language changes
    cvars.AddChangeCallback("radio_language", function(convar_name, value_old, value_new)
        updateDropdownValue()
    end, "LanguageDropdownUpdate")
end

local function createKeyDropdown(panel)
    local keyDropdown = vgui.Create("DComboBox", panel)
    keyDropdown:SetValue("Select Key")
    keyDropdown:Dock(TOP)
    keyDropdown:SetTall(30)
    keyDropdown:SetTooltip("Select the key to open the car radio menu.")

    local sortedKeys = sortKeys()
    for _, key in ipairs(sortedKeys) do
        keyDropdown:AddChoice(key.name, key.code)
    end

    local currentKey = GetConVar("radio_open_key"):GetInt()
    if keyCodeMapping[currentKey] then
        keyDropdown:SetValue(keyCodeMapping[currentKey])
    end

    keyDropdown.OnSelect = function(panel, index, value, data)
        RunConsoleCommand("radio_open_key", data)
    end

    panel:AddItem(keyDropdown)
end

local function createGeneralOptions(panel)
    local chatMessageCheckbox = vgui.Create("DCheckBoxLabel", panel)
    chatMessageCheckbox:SetText(Config.Lang["ShowCarRadioMessages"])
    chatMessageCheckbox:SetConVar("radio_show_messages")
    chatMessageCheckbox:Dock(TOP)
    chatMessageCheckbox:DockMargin(0, 0, 0, 5)
    chatMessageCheckbox:SetTextColor(Color(0, 0, 0))
    chatMessageCheckbox:SetValue(GetConVar("radio_show_messages"):GetBool())
    chatMessageCheckbox:SetTooltip(Config.Lang["ShowCarRadioMessages"])
    panel:AddItem(chatMessageCheckbox)

    local showTextCheckbox = vgui.Create("DCheckBoxLabel", panel)
    showTextCheckbox:SetText(Config.Lang["ShowBoomboxHoverPanel"])
    showTextCheckbox:SetConVar("radio_show_boombox_text")
    showTextCheckbox:Dock(TOP)
    showTextCheckbox:DockMargin(0, 0, 0, 0)
    showTextCheckbox:SetTextColor(Color(0, 0, 0))
    showTextCheckbox:SetValue(GetConVar("radio_show_boombox_text"):GetBool())
    showTextCheckbox:SetTooltip(Config.Lang["ShowBoomboxHoverPanel"])
    panel:AddItem(showTextCheckbox)
end

-- -------------------------------
-- 6. Main Settings Menu Function
-- -------------------------------
createSettingsMenu = function(panel)
    if not IsValid(panel) then return end
    panel:ClearControls()
    panel:DockPadding(10, 0, 30, 10)

    -- Theme Selection
    local themeHeader = vgui.Create("DLabel", panel)
    themeHeader:SetText(Config.Lang["ThemeSelection"] or "Theme Selection")
    themeHeader:SetFont("Trebuchet18")
    themeHeader:SetTextColor(Color(50, 50, 50))
    themeHeader:Dock(TOP)
    themeHeader:DockMargin(0, 0, 0, 5)
    panel:AddItem(themeHeader)
    createThemeDropdown(panel)

    -- Language Selection
    local languageHeader = vgui.Create("DLabel", panel)
    languageHeader:SetText(Config.Lang["LanguageSelection"] or "Language Selection")
    languageHeader:SetFont("Trebuchet18")
    languageHeader:SetTextColor(Color(50, 50, 50))
    languageHeader:Dock(TOP)
    languageHeader:DockMargin(0, 20, 0, 5)
    panel:AddItem(languageHeader)
    createLanguageDropdown(panel)

    -- Key Selection
    local keySelectionHeader = vgui.Create("DLabel", panel)
    keySelectionHeader:SetText(Config.Lang["KeySelection"] or "Select Key to Open Radio Menu")
    keySelectionHeader:SetFont("Trebuchet18")
    keySelectionHeader:SetTextColor(Color(50, 50, 50))
    keySelectionHeader:Dock(TOP)
    keySelectionHeader:DockMargin(0, 20, 0, 5)
    panel:AddItem(keySelectionHeader)
    createKeyDropdown(panel)

    -- General Options
    local generalOptionsHeader = vgui.Create("DLabel", panel)
    generalOptionsHeader:SetText(Config.Lang["GeneralOptions"] or "General Options")
    generalOptionsHeader:SetFont("Trebuchet18")
    generalOptionsHeader:SetTextColor(Color(50, 50, 50))
    generalOptionsHeader:Dock(TOP)
    generalOptionsHeader:DockMargin(0, 20, 0, 5)
    panel:AddItem(generalOptionsHeader)
    createGeneralOptions(panel)
end

-- -------------------------------
-- 7. Tool Menu Population
-- -------------------------------
hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "rRadio", "ThemeVolumeSelection", "Radio Settings", "", "", function(panel)
        panel:ClearControls()
        createSettingsMenu(panel)
    end)
end)

-- Refresh the menu when the language changes
hook.Add("LanguageChanged", "RefreshSettingsMenu", function()
    local settingsPanel = controlpanel.Get("ThemeVolumeSelection")
    if IsValid(settingsPanel) then
        createSettingsMenu(settingsPanel)
    end
end)