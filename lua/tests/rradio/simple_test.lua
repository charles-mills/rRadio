--[[
    Simple test to check if the test environment is working
]]

return {
    groupName = "Simple Test",
    cases = {
        {
            name = "Should pass basic equality check",
            func = function()
                expect(true).to.equal(true)
            end
        }
    }
}
