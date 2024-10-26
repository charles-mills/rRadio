return {
    groupName = "rRadio Initialization",
    cases = {
        {
            name = "Should load core files",
            func = function()
                print("[DEBUG] Running initialization test")
                
                if SERVER then
                    include("radio/server/sv_core.lua")
                    print("[DEBUG] Server core included")
                end
                
                if CLIENT then
                    include("radio/client/cl_core.lua")
                    print("[DEBUG] Client core included")
                end
                
                include("radio/shared/sh_utils.lua")
                print("[DEBUG] Utils included")
                
                expect(utils).to.exist()
                print("[DEBUG] Initialization test complete")
            end
        }
    }
}
