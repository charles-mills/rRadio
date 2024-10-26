return {
    groupName = "rRadio Server Managers",
    
    beforeEach = function(state)
        -- Reset managers for each test
        TimerManager = {
            volume = {},
            station = {},
            retry = {},
            cleanup = function(self, entIndex)
                if not entIndex then return end
                local timerNames = {
                    "VolumeUpdate_" .. entIndex,
                    "StationUpdate_" .. entIndex,
                    "NetworkQueue_" .. entIndex
                }
                for _, name in ipairs(timerNames) do
                    if timer.Exists(name) then timer.Remove(name) end
                end
                self.volume[entIndex] = nil
                self.station[entIndex] = nil
                self.retry[entIndex] = nil
            end
        }

        RadioManager = {
            active = {},
            count = 0,
            add = function(self, entity, stationName, url, volume)
                if not IsValid(entity) then return end
                if self.count >= MAX_ACTIVE_RADIOS then self:removeOldest() end
                local entIndex = entity:EntIndex()
                self.active[entIndex] = {
                    entity = entity,
                    stationName = stationName,
                    url = url,
                    volume = volume,
                    timestamp = CurTime()
                }
                self.count = self.count + 1
            end
        }
    end,

    cases = {
        {
            name = "TimerManager should cleanup all timers for an entity",
            func = function()
                local entIndex = 1
                local timersCleaned = false
                
                timer.Remove = function() timersCleaned = true end
                
                TimerManager:cleanup(entIndex)
                expect(timersCleaned).to.equal(true)
                expect(TimerManager.volume[entIndex]).to.equal(nil)
            end
        },
        {
            name = "RadioManager should respect maximum active radios",
            func = function()
                local entity1 = {
                    EntIndex = function() return 1 end,
                    IsValid = function() return true end
                }
                local entity2 = {
                    EntIndex = function() return 2 end,
                    IsValid = function() return true end
                }
                
                local OLD_MAX = MAX_ACTIVE_RADIOS
                MAX_ACTIVE_RADIOS = 1
                
                RadioManager:add(entity1, "Test1", "url1", 0.5)
                RadioManager:add(entity2, "Test2", "url2", 0.5)
                
                expect(RadioManager.count).to.equal(1)
                expect(RadioManager.active[2]).to.exist()
                expect(RadioManager.active[1]).to.equal(nil)
                
                MAX_ACTIVE_RADIOS = OLD_MAX
            end
        }
    }
}
