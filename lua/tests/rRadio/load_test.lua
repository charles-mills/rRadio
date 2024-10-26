return {
    groupName = "rRadio Load Test",
    cases = {
        {
            name = "Test environment should load",
            func = function()
                print("[DEBUG] Running load test")
                
                -- Test file system
                expect(file).to.exist()
                expect(file.Find).to.exist()
                
                -- Test basic GMod functions
                expect(SERVER).to.exist()
                expect(CLIENT).to.exist()
                
                print("[DEBUG] Load test complete")
            end
        }
    }
}
