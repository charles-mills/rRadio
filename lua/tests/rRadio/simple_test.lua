--[[
    Simple test to check if the test environment is working
]]

return {
    groupName = "Simple Test",
    cases = {
        {
            name = "Basic test",
            func = function()
                expect(true).to.equal(true)
            end
        }
    }
}
