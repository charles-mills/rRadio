return {
    groupName = "rRadio Station Queue",
    
    beforeEach = function(state)
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
            async = true,
            timeout = 1,
            func = function(state, done)
                local processCount = 0
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
                
                StationQueue:add(state.entity, data1)
                StationQueue:add(state.entity, data2)
                
                timer.Simple(0.2, function()
                    expect(processCount).to.equal(2)
                    done()
                end)
            end
        }
    }
}
