local function setupTestEnv()
    -- Mock required functions and objects
    MemoryManager = {
        TrackSound = function() end,
        TrackTimer = function() end,
        TrackHook = function() end,
        CleanupEntity = function() end
    }
end

return {
    groupName = "rRadio Source Management",
    
    beforeEach = function(state)
        setupTestEnv()
        include("radio/client/cl_core.lua")
        
        state.entity = {
            EntIndex = function() return 1 end,
            IsValid = function() return true end,
            GetPos = function() return Vector(0, 0, 0) end,
            GetClass = function() return "boombox" end,
            SetNWString = function() end,
            SetNWBool = function() end
        }
        
        state.station = {
            SetPos = function() end,
            SetVolume = function() end,
            Stop = function() end
        }
    end,

    cases = {
        {
            name = "Should add radio source correctly",
            func = function(state)
                RadioSourceManager:addSource(state.entity, state.station, "Test Station")
                expect(RadioSourceManager.activeSources[1]).to.exist()
            end
        },
        {
            name = "Should remove radio source correctly",
            func = function(state)
                RadioSourceManager:addSource(state.entity, state.station, "Test Station")
                RadioSourceManager:removeSource(state.entity)
                expect(RadioSourceManager.activeSources[1]).to.equal(nil)
            end
        },
        {
            name = "Should update source status correctly",
            func = function(state)
                RadioSourceManager:setStatus(state.entity, "playing", "Test Station")
                expect(RadioSourceManager.sourceStatuses[1].stationStatus)
                    .to.equal("playing")
            end
        }
    }
}
