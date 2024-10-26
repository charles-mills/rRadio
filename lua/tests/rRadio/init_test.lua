return {
    groupName = "rRadio Initialization",
    cases = {
        {
            name = "Should initialize required components",
            func = function()
                -- Include initialization files
                include("autorun/server/sv_radio_init.lua")
                if CLIENT then
                    include("autorun/client/cl_radio_init.lua")
                end

                -- Test core components exist
                expect(RadioManager).to.exist()
                expect(StationQueue).to.exist()
                expect(utils).to.exist()
            end
        }
    }
}
