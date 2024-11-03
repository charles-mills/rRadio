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
    
    -- Easing functions
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

-- Update the PulseEffects module to handle menu-wide pulses
Modules.PulseEffects = {
    menuPulse = nil,
    
    -- Simplified pulse creation for menu
    CreateMenuPulse = function(self, duration)
        -- Only allow one menu pulse at a time for performance
        if self.menuPulse then return end
        
        self.menuPulse = {
            startTime = CurTime(),
            duration = duration,
            lastUpdate = 0,
            updateInterval = 0.016 -- ~60fps cap
        }
    end,
    
    -- Optimized think function
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
    [KEY_A] = "A",
    [KEY_B] = "B",
    [KEY_C] = "C",
    [KEY_D] = "D",
    [KEY_E] = "E",
    [KEY_F] = "F",
    [KEY_G] = "G",
    [KEY_H] = "H",
    [KEY_I] = "I",
    [KEY_J] = "J",
    [KEY_K] = "K",
    [KEY_L] = "L",
    [KEY_M] = "M",
    [KEY_N] = "N",
    [KEY_O] = "O",
    [KEY_P] = "P",
    [KEY_Q] = "Q",
    [KEY_R] = "R",
    [KEY_S] = "S",
    [KEY_T] = "T",
    [KEY_U] = "U",
    [KEY_V] = "V",
    [KEY_W] = "W",
    [KEY_X] = "X",
    [KEY_Y] = "Y",
    [KEY_Z] = "Z",
    [KEY_0] = "0",
    [KEY_1] = "1",
    [KEY_2] = "2",
    [KEY_3] = "3",
    [KEY_4] = "4",
    [KEY_5] = "5",
    [KEY_6] = "6",
    [KEY_7] = "7",
    [KEY_8] = "8",
    [KEY_9] = "9",
    [KEY_PAD_0] = "NP 0",
    [KEY_PAD_1] = "NP 1",
    [KEY_PAD_2] = "NP 2",
    [KEY_PAD_3] = "NP 3",
    [KEY_PAD_4] = "NP 4",
    [KEY_PAD_5] = "NP 5",
    [KEY_PAD_6] = "NP 6",
    [KEY_PAD_7] = "NP 7",
    [KEY_PAD_8] = "NP 8",
    [KEY_PAD_9] = "NP 9",
    [KEY_PAD_DIVIDE] = "NP /",
    [KEY_PAD_MULTIPLY] = "NP *",
    [KEY_PAD_MINUS] = "NP -",
    [KEY_PAD_PLUS] = "NP +",
    [KEY_PAD_ENTER] = "NP Enter",
    [KEY_PAD_DECIMAL] = "NP .",
    [KEY_LSHIFT] = "L Shift",
    [KEY_RSHIFT] = "R Shift",
    [KEY_LALT] = "L Alt",
    [KEY_RALT] = "R Alt",
    [KEY_LCONTROL] = "L Ctrl",
    [KEY_RCONTROL] = "R Ctrl",
    [KEY_SPACE] = "Space",
    [KEY_ENTER] = "Enter",
    [KEY_BACKSPACE] = "Backspace",
    [KEY_TAB] = "Tab",
    [KEY_CAPSLOCK] = "Caps Lock",
    [KEY_ESCAPE] = "Escape",
    [KEY_SCROLLLOCK] = "Scroll Lock",
    [KEY_INSERT] = "Insert",
    [KEY_DELETE] = "Delete",
    [KEY_HOME] = "Home",
    [KEY_END] = "End",
    [KEY_PAGEUP] = "Page Up",
    [KEY_PAGEDOWN] = "Page Down",
    [KEY_BREAK] = "Break",
    [KEY_NUMLOCK] = "Num Lock",
    [KEY_SEMICOLON] = ";",
    [KEY_EQUAL] = "=",
    [KEY_MINUS] = "-",
    [KEY_COMMA] = ",",
    [KEY_PERIOD] = ".",
    [KEY_SLASH] = "/",
    [KEY_BACKSLASH] = "\\",
    [KEY_BACKQUOTE] = "`",
    [KEY_F1] = "F1",
    [KEY_F2] = "F2",
    [KEY_F3] = "F3",
    [KEY_F4] = "F4",
    [KEY_F5] = "F5",
    [KEY_F6] = "F6",
    [KEY_F7] = "F7",
    [KEY_F8] = "F8",
    [KEY_F9] = "F9",
    [KEY_F10] = "F10",
    [KEY_F11] = "F11",
    [KEY_F12] = "F12",
    [KEY_CAPSLOCKTOGGLE] = "Caps Lock",
    [KEY_NUMLOCKTOGGLE] = "Num Lock",
    [KEY_LAST] = "Last Key",

    GetKeyName = function(self, keyCode)
        return self[keyCode] or "UNKNOWN"
    end
}

hook.Add("Think", "RadioMiscModulesThink", function()
    Modules.Animations:Think()
    Modules.PulseEffects:Think()
end)

return Modules 