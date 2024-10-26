return {
    groupName = "rRadio Validator",
    cases = {
        {
            name = "Volume validator should enforce limits",
            func = function()
                expect(Validator.volume(-0.1)).to.equal(false)
                expect(Validator.volume(0)).to.equal(true)
                expect(Validator.volume(0.5)).to.equal(true)
                expect(Validator.volume(1)).to.equal(true)
                expect(Validator.volume(1.1)).to.equal(false)
            end
        },
        {
            name = "URL validator should check format",
            func = function()
                expect(Validator.url("")).to.equal(false)
                expect(Validator.url(string.rep("a", 501))).to.equal(false)
                expect(Validator.url("http://valid.com/stream")).to.equal(true)
            end
        },
        {
            name = "Station name validator should check length",
            func = function()
                expect(Validator.stationName("")).to.equal(false)
                expect(Validator.stationName(string.rep("a", 101))).to.equal(false)
                expect(Validator.stationName("Test Station")).to.equal(true)
            end
        }
    }
}
