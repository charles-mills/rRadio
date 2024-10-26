local function setupTestEnv()
    -- Mock timer
    timer = timer or {
        Simple = function(delay, callback) 
            callback() 
        end
    }
end

return {
    groupName = "rRadio Station Queue",
    
    beforeEach = function(state)
        setupTestEnv()
        state.entity = {
            EntIndex = function() return 1 end,
            IsValid = function() return true end,
            SetNWString = function() end,
            SetNWFloat = function() end,
            SetNWBool = function() end
        }
        
        StationQueue.queues = {}
        StationQueue.processing = {}
    end,

    cases = {
        {
            name = "Should add stations to queue",
            func = function(state)
                local data = {
                    stationName = "Test Station",
                    url = "http://test.url",
                    volume = 0.5,
                    player = nil
                }
                
                StationQueue:add(state.entity, data)
                
                local entIndex = state.entity:EntIndex()
                expect(StationQueue.queues[entIndex]).to.exist()
                expect(#StationQueue.queues[entIndex]).to.equal(1)
            end
        },
        {
            name = "Should process queue in order",
            func = function(state)
                local processCount = 0
                local processOrder = {}
                
                local data1 = {
                    stationName = "Station 1",
                    url = "http://test1.url",
                    volume = 0.5,
                    player = nil
                }
                
                local data2 = {
                    stationName = "Station 2", 
                    url = "http://test2.url",
                    volume = 0.5,
                    player = nil
                }

                -- Override process function to track calls
                local oldProcess = StationQueue.process
                StationQueue.process = function(self, entIndex)
                    processCount = processCount + 1
                    table.insert(processOrder, self.queues[entIndex][1].stationName)
                    oldProcess(self, entIndex)
                end
                
                StationQueue:add(state.entity, data1)
                StationQueue:add(state.entity, data2)
                
                expect(processCount).to.equal(2)
                expect(processOrder[1]).to.equal("Station 1")
                expect(processOrder[2]).to.equal("Station 2")
            end
        }
    }
}
