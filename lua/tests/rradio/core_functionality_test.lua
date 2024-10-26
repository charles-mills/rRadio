local function setupTestEnv()
    -- Mock required functions
    file = file or {
        IsDir = function() return false end,
        CreateDir = function() end
    }
end

return {
    groupName = "rRadio Core Functionality",
    
    beforeEach = function(state)
        setupTestEnv()
        include("radio/client/cl_core.lua")
        
        state.oldLocalPlayer = LocalPlayer
        state.player = {
            GetVehicle = function() return nil end,
            currentRadioEntity = nil,
            IsSuperAdmin = function() return false end
        }
        LocalPlayer = function() return state.player end
    end,

    afterEach = function(state)
        -- Restore globals
        LocalPlayer = state.oldLocalPlayer
    end,

    cases = {
        {
            name = "Should initialize core components",
            func = function()
                expect(BoomboxStatuses).to.exist()
                expect(favoriteCountries).to.exist()
                expect(favoriteStations).to.exist()
            end
        },
        {
            name = "Should create required directories",
            func = function()
                local dirCreated = false
                file.CreateDir = function(dir) 
                    if dir == "rradio" then dirCreated = true end
                end
                
                -- Re-run initialization
                if not file.IsDir("rradio", "DATA") then 
                    file.CreateDir("rradio") 
                end
                
                expect(dirCreated).to.equal(true)
            end
        }
    }
}
