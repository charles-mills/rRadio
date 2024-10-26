return {
    groupName = "rRadio Entity Pool",
    cases = {
        {
            name = "EntityPool should reuse entities",
            func = function()
                local pool = EntityPool
                pool:initialize()
                
                local ent = pool:acquire("boombox")
                expect(ent.GetClass()).to.equal("boombox")
                
                pool:release(ent)
                local reusedEnt = pool:acquire("boombox")
                expect(reusedEnt).to.equal(ent)
            end
        },
        {
            name = "EntityPool should respect size limits",
            func = function()
                local pool = EntityPool
                pool:initialize()
                
                -- Fill pool beyond limit
                for i = 1, pool.maxPoolSize + 1 do
                    local ent = mockEntity("boombox")
                    pool:release(ent)
                end
                
                expect(#pool.pool["boombox"]).to.equal(pool.maxPoolSize)
            end
        }
    }
}
