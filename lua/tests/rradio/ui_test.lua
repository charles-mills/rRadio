local function setupTestEnv()
    -- Mock required functions
    _G.ScreenScale = function(size) return size * 2 end
    _G.Lerp = function(t, a, b) return a + (b - a) * t end
    _G.Color = function(r, g, b, a) return {r = r, g = g, b = b, a = a or 255} end
    
    surface = surface or {
        CreateFont = function() end,
        SetFont = function() end,
        GetTextSize = function() return 50, 20 end,
        SetDrawColor = function() end,
        SetMaterial = function() end,
        DrawTexturedRect = function() end
    }
    
    draw = draw or {
        SimpleText = function() end,
        RoundedBox = function() end
    }

    -- Mock Misc.UIPerformance
    Misc = Misc or {
        UIPerformance = {
            GetScale = function(value) return value end
        }
    }
end

return {
    groupName = "rRadio UI",
    
    beforeEach = function()
        setupTestEnv()
        include("radio/client/cl_core.lua")
    end,

    cases = {
        {
            name = "Should lerp colors correctly",
            func = function()
                local col1 = Color(0, 0, 0, 255)
                local col2 = Color(255, 255, 255, 255)
                local result = LerpColor(0.5, col1, col2)
                
                expect(result.r).to.equal(127)
                expect(result.g).to.equal(127)
                expect(result.b).to.equal(127)
                expect(result.a).to.equal(255)
            end
        },
        {
            name = "Should calculate font size for stop button correctly",
            func = function()
                local fontName = calculateFontSizeForStopButton("STOP", 100, 50)
                expect(fontName).to.equal("DynamicStopButtonFont")
            end
        }
    }
}
