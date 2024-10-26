local Validator = include("radio/server/sv_validator.lua")

return {
    groupName = "rRadio Validator",
    cases = {
        {
            name = "Should validate volume correctly",
            func = function()
                expect(Validator.volume(-0.1)).to.equal(false)
                expect(Validator.volume(0)).to.equal(true)
                expect(Validator.volume(0.5)).to.equal(true)
                expect(Validator.volume(1)).to.equal(true)
                expect(Validator.volume(1.1)).to.equal(false)
            end
        },
        {
            name = "Should validate URLs correctly",
            func = function()
                expect(Validator.url("")).to.equal(false)
                expect(Validator.url(string.rep("a", 501))).to.equal(false)
                expect(Validator.url("http://valid.url/stream")).to.equal(true)
            end
        },
        {
            name = "Should validate station names correctly",
            func = function()
                expect(Validator.stationName("")).to.equal(false)
                expect(Validator.stationName(string.rep("a", 101))).to.equal(false)
                expect(Validator.stationName("Valid Station")).to.equal(true)
            end
        }
    }
}
