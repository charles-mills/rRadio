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
    
    SlideElement = function(self, element, direction, duration, onComplete)
        if not IsValid(element) then return end
        
        local startX = direction == "in" and element:GetWide() or 0
        local endX = direction == "in" and 0 or -element:GetWide()
        
        element:SetVisible(true)
        element:SetAlpha(255)
        
        return Modules.Animations:CreateTween(
            duration,
            startX,
            endX,
            function(value)
                if IsValid(element) then
                    element:SetPos(value, element:GetY())
                end
            end,
            onComplete,
            Modules.Animations.Easing.OutQuint
        )
    end,
    
    FadeElement = function(self, element, direction, duration, onComplete)
        if not IsValid(element) then return end
        
        local startAlpha = direction == "in" and 0 or 255
        local endAlpha = direction == "in" and 255 or 0
        
        element:SetVisible(true)
        
        return Modules.Animations:CreateTween(
            duration,
            startAlpha,
            endAlpha,
            function(value)
                if IsValid(element) then
                    element:SetAlpha(value)
                end
            end,
            onComplete,
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

-- Think hook for animations
hook.Add("Think", "RadioMiscModulesThink", function()
    Modules.Animations:Think()
    Modules.PulseEffects:Think()
end)

return Modules 