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
    
    SlideElements = function(self, oldElement, newElement, duration, onComplete)
        if not IsValid(oldElement) or not IsValid(newElement) then return end
        
        local width = oldElement:GetWide()
        
        -- Set initial positions
        oldElement:SetPos(0, oldElement:GetY())
        newElement:SetPos(width, newElement:GetY())
        newElement:SetVisible(true)
        newElement:SetAlpha(255)
        
        -- Create parallel animations
        Modules.Animations:CreateTween(
            duration,
            0,
            -width,
            function(value)
                if IsValid(oldElement) then
                    oldElement:SetPos(value, oldElement:GetY())
                else
                    return false
                end
            end,
            function()
                if IsValid(oldElement) then
                    oldElement:SetVisible(false)
                end
            end,
            Modules.Animations.Easing.OutQuint
        )
        
        return Modules.Animations:CreateTween(
            duration,
            width,
            0,
            function(value)
                if IsValid(newElement) then
                    newElement:SetPos(value, newElement:GetY())
                else
                    return false
                end
            end,
            onComplete,
            Modules.Animations.Easing.OutQuint
        )
    end,
    
    FadeElements = function(self, oldElement, newElement, duration, onComplete)
        if not IsValid(oldElement) or not IsValid(newElement) then return end
        
        newElement:SetVisible(true)
        newElement:SetAlpha(0)
        
        -- Create parallel animations
        Modules.Animations:CreateTween(
            duration,
            255,
            0,
            function(value)
                if IsValid(oldElement) then
                    oldElement:SetAlpha(value)
                else
                    return false
                end
            end,
            function()
                if IsValid(oldElement) then
                    oldElement:SetVisible(false)
                end
            end,
            Modules.Animations.Easing.OutQuint
        )
        
        return Modules.Animations:CreateTween(
            duration,
            0,
            255,
            function(value)
                if IsValid(newElement) then
                    newElement:SetAlpha(value)
                else
                    return false
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

-- Think hook for animations
hook.Add("Think", "RadioMiscModulesThink", function()
    Modules.Animations:Think()
end)

return Modules 