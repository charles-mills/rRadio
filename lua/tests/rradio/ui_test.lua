local function setupTestEnv()
    -- Mock required functions
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
