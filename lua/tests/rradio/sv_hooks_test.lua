return {
    groupName = "rRadio Server Hooks",
    
    beforeEach = function(state)
        state.player = {
            IsValid = function() return true end,
            ChatPrint = function() end,
            SteamID = function() return "STEAM_0:1:123456" end
        }
        state.entity = {
            IsValid = function() return true end,
            GetClass = function() return "boombox" end,
            EntIndex = function() return 1 end
        }
    end,

    cases = {
        {
            name = "Should cleanup on player disconnect",
            func = function(state)
                PlayerRetryAttempts[state.player] = 1
                PlayerCooldowns[state.player] = true
                
                hook.Run("PlayerDisconnected", state.player)
                
                expect(PlayerRetryAttempts[state.player]).to.equal(nil)
                expect(PlayerCooldowns[state.player]).to.equal(nil)
            end
        },
        {
            name = "Should cleanup on entity removed",
            func = function(state)
                RadioManager:add(state.entity, "Test", "url", 0.5)
                
                hook.Run("EntityRemoved", state.entity)
                
                expect(RadioManager.active[1]).to.equal(nil)
            end
        }
    }
}
