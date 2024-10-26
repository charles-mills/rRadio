return {
    groupName = "rRadio Permanent Boomboxes",
    
    beforeEach = function(state)
        -- Mock SQL
        state.queries = {}
        sql.Query = function(query)
            table.insert(state.queries, query)
            return {}
        end
        sql.TableExists = function() return true end
        sql.SQLStr = function(str) return "'" .. str .. "'" end
        
        -- Mock entity
        state.boombox = {
            IsValid = function() return true end,
            GetModel = function() return "models/props/test.mdl" end,
            GetPos = function() return Vector(0, 0, 0) end,
            GetAngles = function() return Angle(0, 0, 0) end,
            GetNWString = function(_, key)
                if key == "StationName" then return "Test Station"
                elseif key == "StationURL" then return "http://test.url"
                elseif key == "PermanentID" then return "test_123"
                end
            end,
            GetNWFloat = function() return 0.5 end,
            SetNWString = function() end,
            SetNWBool = function() end,
            EntIndex = function() return 1 end
        }
    end,

    cases = {
        {
            name = "Should initialize database correctly",
            func = function(state)
                InitializeDatabase()
                local lastQuery = state.queries[#state.queries]
                expect(lastQuery).to.include("CREATE TABLE")
                expect(lastQuery).to.include("permanent_boomboxes")
            end
        },
        
        {
            name = "Should save permanent boombox",
            func = function(state)
                SavePermanentBoombox(state.boombox)
                local lastQuery = state.queries[#state.queries]
                expect(lastQuery).to.include("INSERT INTO")
                expect(lastQuery).to.include("Test Station")
            end
        },
        
        {
            name = "Should remove permanent boombox",
            func = function(state)
                RemovePermanentBoombox(state.boombox)
                local lastQuery = state.queries[#state.queries]
                expect(lastQuery).to.include("DELETE FROM")
                expect(lastQuery).to.include("test_123")
            end
        },
        
        {
            name = "Should load permanent boomboxes",
            func = function(state)
                -- Mock SQL result
                sql.Query = function()
                    return {{
                        permanent_id = "test_123",
                        model = "models/props/test.mdl",
                        pos_x = 0,
                        pos_y = 0,
                        pos_z = 0,
                        angle_pitch = 0,
                        angle_yaw = 0,
                        angle_roll = 0,
                        station_name = "Test Station",
                        station_url = "http://test.url",
                        volume = 0.5
                    }}
                end
                
                -- Mock ents.Create
                local createdEnt = state.boombox
                ents.Create = function() return createdEnt end
                
                LoadPermanentBoomboxes(false)
                
                expect(spawnedBoomboxes["test_123"]).to.equal(true)
            end
        }
    }
}
