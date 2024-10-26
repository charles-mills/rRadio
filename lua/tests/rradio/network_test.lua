return {
    groupName = "rRadio Network",
    
    beforeEach = function(state)
        -- Mock net library
        state.oldNet = net
        state.messages = {}
        net = {
            Receive = function(msg, func) state.messages[msg] = func end,
            Start = function() end,
            WriteEntity = function() end,
            WriteString = function() end,
            WriteFloat = function() end,
            ReadEntity = function() return state.entity end,
            ReadString = function() return "Test Station" end,
            ReadFloat = function() return 0.5 end
        }
    end,
    
    afterEach = function(state)
        net = state.oldNet
    end,

    cases = {
        {
            name = "Should handle PlayCarRadioStation message",
            func = function(state)
                local handled = false
                state.messages["PlayCarRadioStation"] = function()
                    handled = true
                end
                
                net.Receive("PlayCarRadioStation")
                expect(handled).to.equal(true)
            end
        }
    }
}
