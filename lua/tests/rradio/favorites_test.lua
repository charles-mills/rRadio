return {
    groupName = "rRadio Favorites",
    
    beforeEach = function(state)
        -- Mock file system
        state.oldFileExists = file.Exists
        state.oldFileRead = file.Read
        state.oldFileWrite = file.Write
        
        file.Exists = function() return true end
        file.Read = function() return util.TableToJSON({test = true}) end
        file.Write = function() end
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
