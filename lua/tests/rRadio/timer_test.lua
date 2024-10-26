return {
    groupName = "rRadio Timer Management",
    cases = {
        {
            name = "TimerManager should cleanup all timers for an entity",
            func = function()
                local entIndex = 1
                local timerNames = {
                    "VolumeUpdate_" .. entIndex,
                    "StationUpdate_" .. entIndex,
                    "NetworkQueue_" .. entIndex
                }
                
                -- Create test timers
                for _, name in ipairs(timerNames) do
                    timer.Create(name, 1, 1, function() end)
                end
                
                TimerManager:cleanup(entIndex)
                
                -- Verify all timers were removed
                for _, name in ipairs(timerNames) do
                    expect(timer.Exists(name)).to.equal(false)
                end
            end
        }
    }
}
