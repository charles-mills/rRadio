local function setupTestEnv()
    -- Mock file system
    file = file or {
        Exists = function() return true end,
        Read = function() return util.TableToJSON({test = true}) end,
        Write = function() end,
        CreateDir = function() end,
        IsDir = function() return false end
    }
    
    util = util or {
        JSONToTable = function(json) return {test = true} end,
        TableToJSON = function(tbl) return "{\"test\":true}" end
    }
end

return {
    groupName = "rRadio Favorites",
    
    beforeEach = function(state)
        setupTestEnv()
        include("radio/client/cl_core.lua")
        
        state.oldFileExists = file.Exists
        state.oldFileRead = file.Read
        state.oldFileWrite = file.Write
    end,
    
    afterEach = function(state)
        -- Restore file system
        file.Exists = state.oldFileExists
        file.Read = state.oldFileRead
        file.Write = state.oldFileWrite
    end,

    cases = {
        {
            name = "Should load favorites from file",
            func = function()
                loadFavorites()
                expect(favoriteCountries.test).to.equal(true)
            end
        },
        {
            name = "Should save favorites to file",
            func = function()
                local savedData
                file.Write = function(_, data) savedData = data end
                
                favoriteCountries = {test = true}
                saveFavorites()
                
                expect(savedData).to.exist()
                expect(util.JSONToTable(savedData).test).to.equal(true)
            end
        }
    }
}
