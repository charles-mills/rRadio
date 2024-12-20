--[[
    Radio Addon Client-Side Miscellaneous Modules
    Author: Charles Mills
    Description: This file contains various utility modules for the Radio Addon,
                 including animations, transitions, and other helper functions.
    Date: November 01, 2024
]]--

local Modules = {}

-- ------------------------------
--      Animation Module
-- ------------------------------
Modules.Animations = {
    activeTweens = {},
    nextId = 1,

    Easing = {
        OutQuint = function(x)
            return 1 - math.pow(1 - x, 5)
        end,
        
        InOutQuint = function(x)
            return x < 0.5 and 16 * x * x * x * x * x or 1 - math.pow(-2 * x + 2, 5) / 2
        end,
        
        OutBack = function(x)
            local c1 = 1.70158
            local c3 = c1 + 1
            return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
        end
    },
    
    CreateTween = function(self, duration, from, to, onUpdate, onComplete, easing)
        local id = self.nextId
        self.nextId = self.nextId + 1
        
        self.activeTweens[id] = {
            startTime = CurTime(),
            duration = duration,
            from = from,
            to = to,
            onUpdate = onUpdate,
            onComplete = onComplete,
            easing = easing or self.Easing.OutQuint,
            completed = false
        }
        
        return id
    end,
    
    StopTween = function(self, id)
        self.activeTweens[id] = nil
    end,
    
    Think = function(self)
        local currentTime = CurTime()
        
        for id, tween in pairs(self.activeTweens) do
            if not tween.completed then
                local progress = math.Clamp((currentTime - tween.startTime) / tween.duration, 0, 1)
                local easedProgress = tween.easing(progress)
                
                if type(tween.from) == "number" then
                    local current = Lerp(easedProgress, tween.from, tween.to)
                    if tween.onUpdate(current) == false then
                        self.activeTweens[id] = nil
                        continue
                    end
                elseif IsColor(tween.from) then
                    local current = LerpColor(easedProgress, tween.from, tween.to)
                    if tween.onUpdate(current) == false then
                        self.activeTweens[id] = nil
                        continue
                    end
                end
                
                if progress >= 1 then
                    tween.completed = true
                    if tween.onComplete then
                        tween.onComplete()
                    end
                    self.activeTweens[id] = nil
                end
            end
        end
    end
}

-- ------------------------------
--      Transition Module
-- ------------------------------
Modules.Transitions = {
    activeTransitions = {},
    
    SlideElement = function(self, element, duration, direction, onComplete)
        if not IsValid(element) then return end
        
        -- Validate parameters
        if type(duration) ~= "number" then
            duration = 0.3 -- Default duration if invalid
        end
        
        -- Cache element reference and validity state
        local elementRef = element
        local isValid = true
        
        local startX = direction == "in" and element:GetWide() or 0
        local endX = direction == "in" and 0 or -element:GetWide()
        
        element:SetVisible(true)
        element:SetAlpha(255)
        
        return Modules.Animations:CreateTween(
            duration,
            startX,
            endX,
            function(value)
                -- Single validity check that updates cached state
                if isValid and not IsValid(elementRef) then
                    isValid = false
                    return false
                end
                
                if isValid then
                    elementRef:SetPos(value, elementRef:GetY())
                end
            end,
            function()
                if isValid and onComplete then
                    onComplete()
                end
            end,
            Modules.Animations.Easing.OutQuint
        )
    end,
    
    FadeElement = function(self, element, direction, duration, onComplete)
        if not IsValid(element) then return end
        
        -- Validate parameters
        if type(duration) ~= "number" then
            duration = 0.2 -- Default duration if invalid
        end
        
        -- Cache element reference and validity state
        local elementRef = element
        local isValid = true
        
        local startAlpha = direction == "in" and 0 or 255
        local endAlpha = direction == "in" and 255 or 0
        
        element:SetVisible(true)
        
        return Modules.Animations:CreateTween(
            duration,
            startAlpha,
            endAlpha,
            function(value)
                -- Single validity check that updates cached state
                if isValid and not IsValid(elementRef) then
                    isValid = false
                    return false
                end
                
                if isValid then
                    elementRef:SetAlpha(value)
                end
            end,
            function()
                if isValid and onComplete then
                    onComplete()
                end
            end,
            Modules.Animations.Easing.OutQuint
        )
    end
}

-- ------------------------------
--      Visual Effects Module
-- ------------------------------
Modules.Effects = {
    CreateRipple = function(self, x, y, duration, maxRadius, color)
        local startTime = CurTime()
        local ripple = {
            x = x,
            y = y,
            duration = duration,
            maxRadius = maxRadius,
            color = color,
            startTime = startTime
        }
        
        return Modules.Animations:CreateTween(
            duration,
            0,
            maxRadius,
            function(radius)
                -- Ripple drawing logic here
                local alpha = 255 * (1 - (radius / maxRadius))
                draw.NoTexture()
                surface.SetDrawColor(ColorAlpha(color, alpha))
                draw.Circle(x, y, radius, 32)
            end
        )
    end,
    
    CreatePulse = function(self, element, duration, scale)
        if not IsValid(element) then return end
        
        return Modules.Animations:CreateTween(
            duration,
            1,
            scale,
            function(value)
                if IsValid(element) then
                    element:SetScale(value)
                end
            end,
            function()
                if IsValid(element) then
                    element:SetScale(1)
                end
            end,
            Modules.Animations.Easing.OutBack
        )
    end
}

Modules.PulseEffects = {
    menuPulse = nil,
    
    CreateMenuPulse = function(self, duration)
        if self.menuPulse then return end
        
        self.menuPulse = {
            startTime = CurTime(),
            duration = duration,
            lastUpdate = 0,
            updateInterval = 0.016 -- ~60fps cap
        }
    end,

    Think = function(self)
        if not self.menuPulse then return end
        
        local currentTime = CurTime()
        
        -- Skip update if too soon
        if (currentTime - self.menuPulse.lastUpdate) < self.menuPulse.updateInterval then
            return
        end
        
        local progress = (currentTime - self.menuPulse.startTime) / self.menuPulse.duration
        if progress >= 1 then
            self.menuPulse = nil
        else
            self.menuPulse.lastUpdate = currentTime
        end
    end,
    
    -- Get current menu pulse scale
    GetMenuScale = function(self)
        if not self.menuPulse then return 1 end
        
        local progress = (CurTime() - self.menuPulse.startTime) / self.menuPulse.duration
        progress = math.Clamp(progress, 0, 1)
        
        -- Quick scale up, slower scale down
        local scale = 1 + (0.02 * math.sin(progress * math.pi)) -- 2% max scale
        return scale
    end
}

Modules.KeyNames = {
    -- Letters
    [KEY_A] = "A", [KEY_B] = "B", [KEY_C] = "C", [KEY_D] = "D", [KEY_E] = "E",
    [KEY_F] = "F", [KEY_G] = "G", [KEY_H] = "H", [KEY_I] = "I", [KEY_J] = "J",
    [KEY_K] = "K", [KEY_L] = "L", [KEY_M] = "M", [KEY_N] = "N", [KEY_O] = "O",
    [KEY_P] = "P", [KEY_Q] = "Q", [KEY_R] = "R", [KEY_S] = "S", [KEY_T] = "T",
    [KEY_U] = "U", [KEY_V] = "V", [KEY_W] = "W", [KEY_X] = "X", [KEY_Y] = "Y",
    [KEY_Z] = "Z",

    -- Numbers
    [KEY_0] = "0", [KEY_1] = "1", [KEY_2] = "2", [KEY_3] = "3", [KEY_4] = "4",
    [KEY_5] = "5", [KEY_6] = "6", [KEY_7] = "7", [KEY_8] = "8", [KEY_9] = "9",

    -- Numpad
    [KEY_PAD_0] = "NP 0", [KEY_PAD_1] = "NP 1", [KEY_PAD_2] = "NP 2",
    [KEY_PAD_3] = "NP 3", [KEY_PAD_4] = "NP 4", [KEY_PAD_5] = "NP 5",
    [KEY_PAD_6] = "NP 6", [KEY_PAD_7] = "NP 7", [KEY_PAD_8] = "NP 8",
    [KEY_PAD_9] = "NP 9", [KEY_PAD_DIVIDE] = "NP /", [KEY_PAD_MULTIPLY] = "NP *",
    [KEY_PAD_MINUS] = "NP -", [KEY_PAD_PLUS] = "NP +", [KEY_PAD_ENTER] = "NP Enter",
    [KEY_PAD_DECIMAL] = "NP .",

    -- Modifiers
    [KEY_LSHIFT] = "L Shift", [KEY_RSHIFT] = "R Shift",
    [KEY_LALT] = "L Alt", [KEY_RALT] = "R Alt",
    [KEY_LCONTROL] = "L Ctrl", [KEY_RCONTROL] = "R Ctrl",

    -- Common keys
    [KEY_SPACE] = "Space", [KEY_ENTER] = "Enter", [KEY_BACKSPACE] = "Backspace",
    [KEY_TAB] = "Tab", [KEY_CAPSLOCK] = "Caps Lock", [KEY_ESCAPE] = "Escape",
    [KEY_SCROLLLOCK] = "Scroll Lock", [KEY_INSERT] = "Insert", [KEY_DELETE] = "Delete",
    [KEY_HOME] = "Home", [KEY_END] = "End", [KEY_PAGEUP] = "Page Up",
    [KEY_PAGEDOWN] = "Page Down", [KEY_BREAK] = "Break", [KEY_NUMLOCK] = "Num Lock",

    -- Symbols
    [KEY_SEMICOLON] = ";", [KEY_EQUAL] = "=", [KEY_MINUS] = "-", [KEY_COMMA] = ",",
    [KEY_PERIOD] = ".", [KEY_SLASH] = "/", [KEY_BACKSLASH] = "\\", [KEY_BACKQUOTE] = "`",

    -- Function keys
    [KEY_F1] = "F1", [KEY_F2] = "F2", [KEY_F3] = "F3", [KEY_F4] = "F4",
    [KEY_F5] = "F5", [KEY_F6] = "F6", [KEY_F7] = "F7", [KEY_F8] = "F8",
    [KEY_F9] = "F9", [KEY_F10] = "F10", [KEY_F11] = "F11", [KEY_F12] = "F12",

    -- Toggle states
    [KEY_CAPSLOCKTOGGLE] = "Caps Lock",
    [KEY_NUMLOCKTOGGLE] = "Num Lock",
    [KEY_LAST] = "Last Key",

    GetKeyName = function(self, keyCode)
        return self[keyCode] or "UNKNOWN"
    end
}

Modules.Language = {
    currentLanguage = "en",
    languages = {
        de = "Deutsch",
        en = "English",
        es = "Español",
        fr = "Français",
        it = "Italiano",
        ja = "日本語",
        ko = "한국어",
        pt_br = "Português (Brasil)",
        ru = "Русский",
        zh_cn = "简体中文",
        tr = "Türkçe",
    },
    
    translations = {},
    countryTranslations = {},

    Initialize = function(self)
        -- Load base translations
        self:LoadTranslations()
        -- Set initial language
        self:SetLanguage(GetConVar("radio_language"):GetString() or "en")
    end,

    LoadTranslations = function(self)
        -- Load base translations
        self.translations = include("radio/client/lang/cl_localisation_strings.lua") or {}
        -- Load country translations
        local translationsA = include("radio/client/lang/cl_country_translations_a.lua") or {}
        local translationsB = include("radio/client/lang/cl_country_translations_b.lua") or {}
        
        -- Merge country translations
        for lang, translations in pairs(translationsA) do
            if type(translations) == "table" then
                self.countryTranslations[lang] = self.countryTranslations[lang] or {}
                table.Merge(self.countryTranslations[lang], translations)
            end
        end
        
        for lang, translations in pairs(translationsB) do
            if type(translations) == "table" then
                self.countryTranslations[lang] = self.countryTranslations[lang] or {}
                table.Merge(self.countryTranslations[lang], translations)
            end
        end
    end,

    SetLanguage = function(self, lang)
        if not self.languages[lang] then
            print("[rRadio] Invalid language code:", lang)
            lang = "en"
        end
        
        self.currentLanguage = lang
        
        -- Update Config.Lang reference
        if Config then
            Config.Lang = self.translations[lang] or {}
        end
        
        -- Notify state change
        if StateManager then
            StateManager:SetState("currentLanguage", lang)
            StateManager:Emit(StateManager.Events.LANGUAGE_CHANGED, lang)
        end
    end,

    GetLanguageName = function(self, code)
        return self.languages[code] or "Unknown"
    end,

    GetAvailableLanguages = function(self)
        return self.languages
    end,

    GetCountryTranslation = function(self, lang, country)
        if not self.countryTranslations[lang] then return country end
        return self.countryTranslations[lang][country] or country
    end,

    -- Helper function to add translations
    AddTranslations = function(self, lang, translations)
        self.translations[lang] = self.translations[lang] or {}
        table.Merge(self.translations[lang], translations)
    end,

    -- Helper function to add country translations
    AddCountryTranslations = function(self, lang, translations)
        self.countryTranslations[lang] = self.countryTranslations[lang] or {}
        table.Merge(self.countryTranslations[lang], translations)
    end
}

-- Initialize Language module
Modules.Language:Initialize()

-- Then define Settings module
Modules.Settings = {
    themeModule = include("radio/client/cl_theme_manager.lua"),

    -- Create base ConVars
    Initialize = function(self)
        CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
        CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
        CreateClientConVar("boombox_show_text", "1", true, false, "Show or hide the text above the boombox.")
        CreateClientConVar("car_radio_open_key", "21", true, false, "Select the key to open the car radio menu.")
        CreateClientConVar("radio_max_vehicle_volume", "1", true, false, "Maximum volume for vehicle radios (0-1)")
        CreateClientConVar("radio_max_boombox_volume", "1", true, false, "Maximum volume for boomboxes (0-1)")
    end,

    -- Theme management
    ApplyTheme = function(self, themeName)
        if self.themeModule.themes[themeName] and self.themeModule.factory:validateTheme(self.themeModule.themes[themeName]) then
            Config.UI = self.themeModule.themes[themeName]
            
            -- Debug print
            print("[Radio] Applying theme:", themeName)
            
            -- Fire theme change hooks
            hook.Run("ThemeChanged", themeName)
            hook.Run("RadioThemeChanged", themeName)
        else
            print("[rRadio] Invalid theme name:", themeName)
            -- Fallback to default theme
            local defaultTheme = self.themeModule.factory:getDefaultTheme()
            Config.UI = self.themeModule.factory:getDefaultThemeData()
            RunConsoleCommand("radio_theme", defaultTheme)
        end
    end,

    -- Language management
    ApplyLanguage = function(self, languageCode)
        if Modules.Language.languages[languageCode] then
            Modules.Language:SetLanguage(languageCode)
        else
            print("[rRadio] Invalid language code:", languageCode)
        end
    end,

    -- Load saved settings
    LoadSavedSettings = function(self)
        local themeName = GetConVar("radio_theme"):GetString()
        self:ApplyTheme(themeName)

        local languageCode = GetConVar("radio_language"):GetString()
        self:ApplyLanguage(languageCode)
    end,

    -- Populate tool menu
    PopulateToolMenu = function(self)
        spawnmenu.AddToolMenuOption("Utilities", "rlib", "ThemeVolumeSelection", "rRadio Settings", "", "", function(panel)
            panel:ClearControls()
            panel:DockPadding(10, 0, 30, 10)

            -- Theme selection
            self:AddThemeSelection(panel)
            
            -- Language selection
            self:AddLanguageSelection(panel)
            
            -- Key selection
            self:AddKeySelection(panel)
            
            -- Volume Limits (moved above General Options)
            local volumeHeader = self:CreateHeader(panel, "Volume Limits")
            
            -- Vehicle volume slider
            local vehicleVolume = vgui.Create("DNumSlider", panel)
            vehicleVolume:SetText("Vehicles")
            vehicleVolume:SetMin(0)
            vehicleVolume:SetMax(1)
            vehicleVolume:SetDecimals(2)
            vehicleVolume:SetConVar("radio_max_vehicle_volume")
            vehicleVolume:SetDefaultValue(1)
            vehicleVolume:SetDark(true)
            vehicleVolume:Dock(TOP)
            vehicleVolume:DockMargin(0, 5, 0, 5)
            vehicleVolume.OnValueChanged = function(_, value)
                value = math.Clamp(value, 0, 1)
                RunConsoleCommand("radio_max_vehicle_volume", tostring(value))
                
                if StreamManager and StreamManager.activeStreams then
                    for _, streamData in pairs(StreamManager.activeStreams) do
                        if IsValid(streamData.entity) and IsValid(streamData.stream) and streamData.entity:IsVehicle() then
                            local currentVolume = streamData.stream:GetVolume()
                            if currentVolume > value then
                                streamData.stream:SetVolume(value)
                            end
                        end
                    end
                end
            end
            panel:AddItem(vehicleVolume)
            
            -- Boombox volume slider
            local boomboxVolume = vgui.Create("DNumSlider", panel)
            boomboxVolume:SetText("Boomboxes")
            boomboxVolume:SetMin(0)
            boomboxVolume:SetMax(1)
            boomboxVolume:SetDecimals(2)
            boomboxVolume:SetConVar("radio_max_boombox_volume")
            boomboxVolume:SetDefaultValue(1)
            boomboxVolume:SetDark(true)
            boomboxVolume:Dock(TOP)
            boomboxVolume:DockMargin(0, 5, 0, 5)
            boomboxVolume.OnValueChanged = function(_, value)
                value = math.Clamp(value, 0, 1)
                RunConsoleCommand("radio_max_boombox_volume", tostring(value))
                
                if StreamManager and StreamManager.activeStreams then
                    for _, streamData in pairs(StreamManager.activeStreams) do
                        if IsValid(streamData.entity) and IsValid(streamData.stream) and 
                           (streamData.entity:GetClass() == "boombox" or streamData.entity:GetClass() == "golden_boombox") then
                            local currentVolume = streamData.stream:GetVolume()
                            if currentVolume > value then
                                streamData.stream:SetVolume(value)
                            end
                        end
                    end
                end
            end
            panel:AddItem(boomboxVolume)
            
            -- Volume limits help text
            local helpText = vgui.Create("DLabel", panel)
            helpText:SetText("These volume limits only affect your client and override server settings.")
            helpText:SetTextColor(Color(100, 100, 100))
            helpText:SetWrap(true)
            helpText:SetAutoStretchVertical(true)
            helpText:Dock(TOP)
            helpText:DockMargin(5, 0, 5, 15)
            helpText:SetContentAlignment(7)
            panel:AddItem(helpText)
            
            -- Add divider
            local divider = vgui.Create("DPanel", panel)
            divider:SetTall(1)
            divider:Dock(TOP)
            divider:DockMargin(0, 5, 0, 5)
            divider.Paint = function(self, w, h)
                surface.SetDrawColor(200, 200, 200, 100)
                surface.DrawRect(0, 0, w, h)
            end
            panel:AddItem(divider)
            
            -- General options (moved below Volume Limits)
            self:AddGeneralOptions(panel)
        end)
    end,

    -- Helper functions for tool menu
    AddThemeSelection = function(self, panel)
        local header = self:CreateHeader(panel, "Theme Selection")
        local dropdown = self:CreateDropdown(panel, "Select Theme")
        
        for themeName, _ in pairs(self.themeModule.themes) do
            dropdown:AddChoice(themeName:gsub("^%l", string.upper))
        end

        local currentTheme = GetConVar("radio_theme"):GetString()
        if currentTheme and self.themeModule.themes[currentTheme] then
            dropdown:SetValue(currentTheme:gsub("^%l", string.upper))
        end

        dropdown.OnSelect = function(_, _, value)
            local lowerValue = value:lower()
            if self.themeModule.themes[lowerValue] then
                RunConsoleCommand("radio_theme", lowerValue)
                timer.Simple(0, function()
                    self:ApplyTheme(lowerValue)
                end)
            end
        end
    end,

    AddLanguageSelection = function(self, panel)
        local header = self:CreateHeader(panel, "Language Selection")
        local dropdown = self:CreateDropdown(panel, "Select Language")
        
        for code, name in pairs(Modules.Language.languages) do
            dropdown:AddChoice(name, code)
        end

        local currentLanguage = GetConVar("radio_language"):GetString()
        if currentLanguage and Modules.Language.languages[currentLanguage] then
            dropdown:SetValue(Modules.Language.languages[currentLanguage])
        end

        dropdown.OnSelect = function(_, _, _, data)
            self:ApplyLanguage(data)
            RunConsoleCommand("radio_language", data)
        end
    end,

    AddKeySelection = function(self, panel)
        local header = self:CreateHeader(panel, "Select Key to Open Radio Menu")
        local dropdown = self:CreateDropdown(panel, "Select Key")
        
        local sortedKeys = self:SortKeys()
        for _, key in ipairs(sortedKeys) do
            dropdown:AddChoice(key.name, key.code)
        end

        local currentKey = GetConVar("car_radio_open_key"):GetInt()
        local currentKeyName = Modules.KeyNames:GetKeyName(currentKey)
        if currentKeyName then
            dropdown:SetValue(currentKeyName)
        end

        dropdown.OnSelect = function(_, _, _, data)
            RunConsoleCommand("car_radio_open_key", data)
        end
    end,

    AddGeneralOptions = function(self, panel)
        local header = self:CreateHeader(panel, "General Options")
        
        local chatMessageCheckbox = self:CreateCheckbox(panel, "Show Animation on Car Enter", "car_radio_show_messages")
        local showTextCheckbox = self:CreateCheckbox(panel, "Show Boombox HUD", "boombox_show_text")
    end,

    CreateHeader = function(self, panel, text)
        local header = vgui.Create("DLabel", panel)
        header:SetText(text)
        header:SetFont("Trebuchet18")
        header:SetTextColor(Color(50, 50, 50))
        header:Dock(TOP)
        header:DockMargin(0, 20, 0, 5)
        panel:AddItem(header)
        return header
    end,

    CreateDropdown = function(self, panel, placeholder)
        local dropdown = vgui.Create("DComboBox", panel)
        dropdown:SetValue(placeholder)
        dropdown:Dock(TOP)
        dropdown:SetTall(30)
        dropdown:DockMargin(0, 0, 0, 5)
        panel:AddItem(dropdown)
        return dropdown
    end,

    CreateCheckbox = function(self, panel, text, convar)
        local checkbox = vgui.Create("DCheckBoxLabel", panel)
        checkbox:SetText(text)
        checkbox:SetConVar(convar)
        checkbox:Dock(TOP)
        checkbox:DockMargin(0, 0, 0, 5)
        checkbox:SetTextColor(Color(0, 0, 0))
        checkbox:SetValue(GetConVar(convar):GetBool())
        panel:AddItem(checkbox)
        return checkbox
    end,

    -- Key sorting helper
    SortKeys = function(self)
        local letterKeys = {}
        local numberKeys = {}
        local functionKeys = {}
        local otherKeys = {}

        for keyCode, keyName in pairs(Modules.KeyNames) do
            if type(keyName) == "string" and keyCode ~= "GetKeyName" then
                local entry = {code = tonumber(keyCode), name = keyName}
                
                if keyName:match("^%a$") then
                    table.insert(letterKeys, entry)
                elseif keyName:match("^%d$") then
                    table.insert(numberKeys, entry)
                elseif keyName:match("^F%d+$") then
                    table.insert(functionKeys, entry)
                else
                    table.insert(otherKeys, entry)
                end
            end
        end

        table.sort(letterKeys, function(a, b) return a.name < b.name end)
        table.sort(numberKeys, function(a, b) return tonumber(a.name) < tonumber(b.name) end)
        table.sort(functionKeys, function(a, b) 
            return tonumber(a.name:match("%d+")) < tonumber(b.name:match("%d+"))
        end)
        table.sort(otherKeys, function(a, b) return a.name < b.name end)

        local sortedKeys = {}
        for _, key in ipairs(letterKeys) do table.insert(sortedKeys, key) end
        for _, key in ipairs(numberKeys) do table.insert(sortedKeys, key) end
        for _, key in ipairs(functionKeys) do table.insert(sortedKeys, key) end
        for _, key in ipairs(otherKeys) do table.insert(sortedKeys, key) end

        return sortedKeys
    end,

    GetMaxVolume = function(self, entity)
        if not IsValid(entity) then return 1 end
        
        -- Create ConVars if they don't exist
        if not GetConVar("radio_max_vehicle_volume") then
            CreateClientConVar("radio_max_vehicle_volume", "1", true, false, "Maximum volume for vehicle radios (0-1)")
        end
        if not GetConVar("radio_max_boombox_volume") then
            CreateClientConVar("radio_max_boombox_volume", "1", true, false, "Maximum volume for boomboxes (0-1)")
        end
        
        -- Get appropriate volume limit based on entity type
        if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
            return GetConVar("radio_max_boombox_volume"):GetFloat()
        elseif entity:IsVehicle() then
            return GetConVar("radio_max_vehicle_volume"):GetFloat()
        end
        
        return 1 -- Default fallback
    end
}

hook.Add("InitPostEntity", "ApplySavedThemeAndLanguageOnJoin", function()
    Modules.Settings:LoadSavedSettings()
end)

hook.Add("PopulateToolMenu", "AddThemeAndVolumeSelectionMenu", function()
    Modules.Settings:PopulateToolMenu()
end)

hook.Add("LanguageUpdated", "UpdateCountryListOnLanguageChange", function()
    if radioMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)
    end
end)

hook.Add("Think", "EnforceRadioVolumeLimits", function()
    if not StreamManager or not StreamManager.activeStreams then return end
    
    -- Only check every 3 seconds for background enforcement
    if not Modules.Settings.nextVolumeCheck or CurTime() > Modules.Settings.nextVolumeCheck then
        Modules.Settings.nextVolumeCheck = CurTime() + 3
        
        local vehicleMax = GetConVar("radio_max_vehicle_volume"):GetFloat()
        local boomboxMax = GetConVar("radio_max_boombox_volume"):GetFloat()
        
        for entIndex, streamData in pairs(StreamManager.activeStreams) do
            if IsValid(streamData.entity) and IsValid(streamData.stream) then
                local maxVolume = streamData.entity:IsVehicle() and vehicleMax or boomboxMax
                local currentVolume = streamData.stream:GetVolume()
                
                if currentVolume > maxVolume then
                    streamData.stream:SetVolume(maxVolume)
                end
            end
        end
    end
end)

return Modules 