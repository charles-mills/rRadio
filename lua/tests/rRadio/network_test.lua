return {
    groupName = "rRadio Network",
    cases = {
        {
            name = "NetworkRateLimiter should allow initial messages",
            func = function()
                local player = mockPlayer()
                local limiter = NetworkRateLimiter
                
                for i = 1, RATE_LIMIT.MESSAGES_PER_SECOND do
                    expect(limiter:check(player)).to.equal(true)
                end
            end
        },
        {
            name = "NetworkRateLimiter should block after limit",
            func = function()
                local player = mockPlayer()
                local limiter = NetworkRateLimiter
                
                -- Fill up the rate limit
                for i = 1, RATE_LIMIT.MESSAGES_PER_SECOND do
                    limiter:check(player)
                end
                
                expect(limiter:check(player)).to.equal(false)
            end
        }
    }
}
