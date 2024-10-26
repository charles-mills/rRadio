local NetworkRateLimiter = include("radio/server/sv_rate_limiter.lua") or {
    players = {},
    check = function() return true end
}

return {
    groupName = "rRadio Rate Limiter",
    
    beforeEach = function(state)
        NetworkRateLimiter.players = {}
    end,

    cases = {
        {
            name = "Should allow messages within rate limit",
            func = function()
                local player = {
                    SteamID = function() return "STEAM_0:1:123456" end
                }
                
                for i = 1, RATE_LIMIT.MESSAGES_PER_SECOND do
                    expect(NetworkRateLimiter:check(player)).to.equal(true)
                end
            end
        },
        {
            name = "Should block messages exceeding rate limit",
            func = function()
                local player = {
                    SteamID = function() return "STEAM_0:1:123456" end
                }
                
                -- Fill up rate limit
                for i = 1, RATE_LIMIT.MESSAGES_PER_SECOND do
                    NetworkRateLimiter:check(player)
                end
                
                expect(NetworkRateLimiter:check(player)).to.equal(false)
            end
        },
        {
            name = "Should allow burst messages within allowance",
            func = function()
                local player = {
                    SteamID = function() return "STEAM_0:1:123456" end
                }
                
                -- Fill normal rate limit
                for i = 1, RATE_LIMIT.MESSAGES_PER_SECOND do
                    NetworkRateLimiter:check(player)
                end
                
                -- Should still allow burst messages
                expect(NetworkRateLimiter:check(player)).to.equal(true)
            end
        }
    }
}
