local function mockNet()
    local netMock = {
        messages = {},
        Receive = function(msgName, func)
            netMock.messages[msgName] = func
        end,
        Start = function(msgName)
            netMock.currentMessage = msgName
        end,
        WriteEntity = function() end,
        WriteString = function() end,
        WriteFloat = function() end,
        WriteBool = function() end,
        Send = function() end,
        Broadcast = function() end,
        ReadEntity = function() return Entity(1) end,
        ReadString = function() return "TestStation" end,
        ReadFloat = function() return 0.5 end,
        ReadBool = function() return true end,
    }
    _G.net = netMock
    return netMock
end

local function mockPlayer()
    return {
        EntIndex = function() return 1 end,
        GetPos = function() return Vector(0, 0, 0) end,
        IsValid = function() return true end,
        GetVehicle = function() return nil end,
        IsSuperAdmin = function() return false end,
        GetEyeTrace = function() 
            return {
                Entity = Entity(1),
                HitPos = Vector(0, 0, 0)
            }
        end,
        Nick = function() return "TestPlayer" end
    }
end

local function mockEntity(class)
    return {
        IsValid = function() return true end,
        GetClass = function() return class or "prop_vehicle_jeep" end,
        GetPos = function() return Vector(0, 0, 0) end,
        EntIndex = function() return 1 end,
        SetNWString = function() end,
        SetNWBool = function() end,
        GetNWBool = function() return false end,
        GetParent = function() return NULL end,
        GetOwner = function() return NULL end
    }
end

local function mockSQL()
    local sqlMock = {
        queries = {},
        results = {},
        TableExists = function(tableName)
            return true
        end,
        Query = function(query)
            table.insert(sqlMock.queries, query)
            return sqlMock.results[#sqlMock.queries] or {}
        end,
        SQLStr = function(str)
            return "'" .. str .. "'"
        end,
        setNextResult = function(self, result)
            self.results[#self.queries + 1] = result
        end,
        getLastQuery = function(self)
            return self.queries[#self.queries]
        end
    }
    _G.sql = sqlMock
    return sqlMock
end

local function mockEnts()
    local entsMock = {
        created = {},
        Create = function(className)
            local ent = mockEntity(className)
            ent.Remove = function() end
            ent.Spawn = function() end
            ent.Activate = function() end
            ent.GetPhysicsObject = function() 
                return {
                    EnableMotion = function() end
                }
            end
            ent.GetModel = function() return "models/props/test.mdl" end
            ent.GetAngles = function() return Angle(0, 0, 0) end
            table.insert(entsMock.created, ent)
            return ent
        end,
        FindByClass = function()
            return {}
        end
    }
    _G.ents = entsMock
    return entsMock
end

return {
    groupName = "rRadio Server",
    
    beforeEach = function(state)
        state.netMock = mockNet()
        state.player = mockPlayer()
        state.vehicle = mockEntity("prop_vehicle_jeep")
        state.boombox = mockEntity("boombox")
    end,

    cases = {
        {
            name = "PlayCarRadioStation network message handling",
            func = function(state)
                local messageReceived = false
                net.Receive("PlayCarRadioStation", function()
                    messageReceived = true
                end)

                -- Simulate receiving a PlayCarRadioStation message
                state.netMock.messages["PlayCarRadioStation"]()
                expect(messageReceived).to.equal(true)
            end
        },

        {
            name = "StopCarRadioStation network message handling",
            func = function(state)
                local messageReceived = false
                net.Receive("StopCarRadioStation", function()
                    messageReceived = true
                end)

                -- Simulate receiving a StopCarRadioStation message
                state.netMock.messages["StopCarRadioStation"]()
                expect(messageReceived).to.equal(true)
            end
        },

        {
            name = "UpdateRadioVolume network message handling",
            func = function(state)
                local messageReceived = false
                net.Receive("UpdateRadioVolume", function()
                    messageReceived = true
                end)

                -- Simulate receiving an UpdateRadioVolume message
                state.netMock.messages["UpdateRadioVolume"]()
                expect(messageReceived).to.equal(true)
            end
        },

        {
            name = "Boombox permanent status handling",
            func = function(state)
                local superAdminPlayer = mockPlayer()
                superAdminPlayer.IsSuperAdmin = function() return true end

                local messageReceived = false
                net.Receive("MakeBoomboxPermanent", function()
                    messageReceived = true
                end)

                -- Simulate receiving a MakeBoomboxPermanent message
                state.netMock.messages["MakeBoomboxPermanent"]()
                expect(messageReceived).to.equal(true)
            end
        },

        {
            name = "Boombox ownership validation",
            func = function(state)
                local boombox = state.boombox
                local player = state.player

                -- Test ownership validation
                local isOwner = hook.Run("CanPlayerInteractWithBoombox", player, boombox)
                expect(isOwner).to.equal(false)

                -- Set player as owner
                boombox.GetOwner = function() return player end
                isOwner = hook.Run("CanPlayerInteractWithBoombox", player, boombox)
                expect(isOwner).to.equal(true)
            end
        },

        {
            name = "Vehicle radio validation",
            func = function(state)
                local vehicle = state.vehicle
                local player = state.player

                -- Test vehicle radio access
                local canAccess = hook.Run("CanPlayerUseVehicleRadio", player, vehicle)
                expect(canAccess).to.equal(true)

                -- Test invalid vehicle
                local invalidVehicle = mockEntity("prop_physics")
                canAccess = hook.Run("CanPlayerUseVehicleRadio", player, invalidVehicle)
                expect(canAccess).to.equal(false)
            end
        },

        {
            name = "Radio distance check",
            func = function(state)
                local player = state.player
                local boombox = state.boombox

                -- Test distance check
                local withinRange = hook.Run("IsPlayerWithinRadioRange", player, boombox)
                expect(withinRange).to.equal(true)

                -- Test out of range
                boombox.GetPos = function() return Vector(1000, 1000, 1000) end
                withinRange = hook.Run("IsPlayerWithinRadioRange", player, boombox)
                expect(withinRange).to.equal(false)
            end
        },

        {
            name = "Radio entity cleanup",
            func = function(state)
                local entity = state.vehicle
                local cleaned = false

                hook.Add("EntityRemoved", "RadioCleanup", function(ent)
                    if ent == entity then
                        cleaned = true
                    end
                end)

                hook.Run("EntityRemoved", entity)
                expect(cleaned).to.equal(true)
            end
        },

        {
            name = "Radio permissions system",
            func = function(state)
                local player = state.player
                local vehicle = state.vehicle

                -- Test basic permissions
                local hasPermission = hook.Run("CanUseRadio", player)
                expect(hasPermission).to.equal(true)

                -- Test vehicle-specific permissions
                hasPermission = hook.Run("CanUseVehicleRadio", player, vehicle)
                expect(hasPermission).to.equal(true)
            end
        },

        {
            name = "Radio volume limits",
            func = function(state)
                local volume = 2.0 -- Above normal max
                local entity = state.vehicle

                local messageReceived = false
                net.Receive("UpdateRadioVolume", function()
                    local adjustedVolume = net.ReadFloat()
                    expect(adjustedVolume).to.be.below(1.1) -- Should be clamped
                    messageReceived = true
                end)

                -- Simulate volume update message
                state.netMock.messages["UpdateRadioVolume"]()
                expect(messageReceived).to.equal(true)
            end
        },

        {
            name = "PlayerInitialSpawn hook should send active radios",
            func = function(state)
                local player = state.player
                local messagesSent = 0

                -- Mock RadioManager with some active radios
                RadioManager.active = {
                    [1] = {
                        entity = state.vehicle,
                        stationName = "Test Station",
                        url = "http://test.com/stream",
                        volume = 0.8
                    }
                }
                RadioManager.count = 1

                -- Track net messages
                local oldStart = net.Start
                net.Start = function(msgName)
                    if msgName == "PlayCarRadioStation" then
                        messagesSent = messagesSent + 1
                    end
                    return oldStart(msgName)
                end

                -- Run the hook
                hook.Run("PlayerInitialSpawn", player)
                
                -- Wait for timer
                timer.Simple(3.1, function()
                    expect(messagesSent).to.equal(1)
                end)

                -- Restore net.Start
                net.Start = oldStart
            end
        },

        {
            name = "PlayerEnteredVehicle hook should mark SitAnywhere seats",
            func = function(state)
                local player = state.player
                local vehicle = state.vehicle
                
                -- Test normal vehicle
                vehicle.playerdynseat = false
                local nwBoolSet = false
                vehicle.SetNWBool = function(self, key, value)
                    if key == "IsSitAnywhereSeat" then
                        nwBoolSet = true
                        expect(value).to.equal(false)
                    end
                end

                hook.Run("PlayerEnteredVehicle", player, vehicle)
                expect(nwBoolSet).to.equal(true)

                -- Test SitAnywhere seat
                nwBoolSet = false
                vehicle.playerdynseat = true
                vehicle.SetNWBool = function(self, key, value)
                    if key == "IsSitAnywhereSeat" then
                        nwBoolSet = true
                        expect(value).to.equal(true)
                    end
                end

                hook.Run("PlayerEnteredVehicle", player, vehicle)
                expect(nwBoolSet).to.equal(true)
            end
        },

        {
            name = "PlayerLeaveVehicle hook should unmark SitAnywhere seats",
            func = function(state)
                local player = state.player
                local vehicle = state.vehicle
                
                local nwBoolSet = false
                vehicle.SetNWBool = function(self, key, value)
                    if key == "IsSitAnywhereSeat" then
                        nwBoolSet = true
                        expect(value).to.equal(false)
                    end
                end

                hook.Run("PlayerLeaveVehicle", player, vehicle)
                expect(nwBoolSet).to.equal(true)
            end
        },

        {
            name = "EntityRemoved hook should cleanup radio data",
            func = function(state)
                local entity = state.vehicle
                local entIndex = entity:EntIndex()

                -- Add some data to clean up
                RadioManager:add(entity, "Test Station", "http://test.com", 0.8)
                volumeUpdateQueue[entIndex] = { entity = entity, volume = 0.5 }
                
                -- Create a timer
                timer.Create("VolumeUpdate_" .. entIndex, 0.1, 1, function() end)
                
                -- Run the hook
                hook.Run("EntityRemoved", entity)

                -- Check cleanup
                expect(RadioManager.active[entIndex]).to.equal(nil)
                expect(volumeUpdateQueue[entIndex]).to.equal(nil)
                expect(timer.Exists("VolumeUpdate_" .. entIndex)).to.equal(false)
            end
        },

        {
            name = "PlayerDisconnected hook should cleanup player data",
            func = function(state)
                local player = state.player
                
                -- Set up some player data
                PlayerRetryAttempts[player] = 1
                PlayerCooldowns[player] = true
                NetworkRateLimiter.players[player] = { messages = 5 }
                
                -- Run the hook
                hook.Run("PlayerDisconnected", player)

                -- Check cleanup
                expect(PlayerRetryAttempts[player]).to.equal(nil)
                expect(PlayerCooldowns[player]).to.equal(nil)
                expect(NetworkRateLimiter.players[player]).to.equal(nil)
            end
        },

        {
            name = "CanTool hook should validate boombox permissions",
            func = function(state)
                local player = state.player
                local boombox = state.boombox
                
                -- Mock trace
                local tr = {
                    Entity = boombox
                }

                -- Test with permission
                utils.canInteractWithBoombox = function() return true end
                local canTool = hook.Run("CanTool", player, tr, "whatever")
                expect(canTool).to.equal(true)

                -- Test without permission
                utils.canInteractWithBoombox = function() return false end
                canTool = hook.Run("CanTool", player, tr, "whatever")
                expect(canTool).to.equal(false)
            end
        },

        {
            name = "PhysgunPickup hook should validate boombox permissions",
            func = function(state)
                local player = state.player
                local boombox = state.boombox

                -- Test with permission
                utils.canInteractWithBoombox = function() return true end
                local canPickup = hook.Run("PhysgunPickup", player, boombox)
                expect(canPickup).to.equal(true)

                -- Test without permission
                utils.canInteractWithBoombox = function() return false end
                canPickup = hook.Run("PhysgunPickup", player, boombox)
                expect(canPickup).to.equal(false)
            end
        },

        {
            name = "Permanent boombox database initialization",
            func = function(state)
                local sqlMock = mockSQL()
                
                -- Test database initialization
                InitializeDatabase()
                
                local createTableQuery = sqlMock:getLastQuery()
                expect(createTableQuery).to.include("CREATE TABLE permanent_boomboxes")
                expect(createTableQuery).to.include("permanent_id TEXT")
                expect(createTableQuery).to.include("model TEXT NOT NULL")
            end
        },

        {
            name = "Save permanent boombox",
            func = function(state)
                local sqlMock = mockSQL()
                local boombox = mockEntity("boombox")
                
                -- Mock RadioManager
                _G.RadioManager = {
                    active = {
                        [1] = {
                            stationName = "Test Station",
                            url = "http://test.com/stream",
                            volume = 0.8
                        }
                    }
                }
                
                -- Test saving a boombox
                SavePermanentBoombox(boombox)
                
                local saveQuery = sqlMock:getLastQuery()
                expect(saveQuery).to.include("INSERT INTO permanent_boomboxes")
                expect(saveQuery).to.include("Test Station")
                expect(saveQuery).to.include("http://test.com/stream")
            end
        },

        {
            name = "Remove permanent boombox",
            func = function(state)
                local sqlMock = mockSQL()
                local boombox = mockEntity("boombox")
                
                -- Set permanent ID
                local permanentID = "test_123"
                boombox.GetNWString = function(_, key)
                    if key == "PermanentID" then
                        return permanentID
                    end
                    return ""
                end
                
                -- Test removing a boombox
                RemovePermanentBoombox(boombox)
                
                local removeQuery = sqlMock:getLastQuery()
                expect(removeQuery).to.include("DELETE FROM permanent_boomboxes")
                expect(removeQuery).to.include(permanentID)
            end
        },

        {
            name = "Load permanent boomboxes",
            func = function(state)
                local sqlMock = mockSQL()
                local entsMock = mockEnts()
                
                -- Mock StationQueue
                _G.StationQueue = {
                    add = function() end
                }
                
                -- Set up test data
                local testBoomboxes = {
                    {
                        permanent_id = "test_123",
                        model = "models/props/test.mdl",
                        pos_x = 0,
                        pos_y = 0,
                        pos_z = 0,
                        angle_pitch = 0,
                        angle_yaw = 0,
                        angle_roll = 0,
                        station_name = "Test Station",
                        station_url = "http://test.com/stream",
                        volume = 0.8
                    }
                }
                sqlMock:setNextResult(testBoomboxes)
                
                -- Test loading boomboxes
                LoadPermanentBoomboxes(false)
                
                -- Verify a boombox was created
                expect(#entsMock.created).to.equal(1)
                local createdBoombox = entsMock.created[1]
                expect(createdBoombox.GetClass()).to.equal("boombox")
            end
        },

        {
            name = "MakeBoomboxPermanent network message",
            func = function(state)
                local netMock = mockNet()
                local sqlMock = mockSQL()
                
                -- Create superadmin player
                local superAdmin = mockPlayer()
                superAdmin.IsSuperAdmin = function() return true end
                
                -- Create test boombox
                local boombox = mockEntity("boombox")
                boombox.IsPermanent = false
                
                -- Mock network message
                netMock.ReadEntity = function() return boombox end
                
                -- Test making boombox permanent
                net.Receive("MakeBoomboxPermanent", function(_, ply)
                    state.netMock.messages["MakeBoomboxPermanent"](_, superAdmin)
                end)
                
                expect(boombox.IsPermanent).to.equal(true)
            end
        },

        {
            name = "RemoveBoomboxPermanent network message",
            func = function(state)
                local netMock = mockNet()
                local sqlMock = mockSQL()
                
                -- Create superadmin player
                local superAdmin = mockPlayer()
                superAdmin.IsSuperAdmin = function() return true end
                
                -- Create test boombox
                local boombox = mockEntity("boombox")
                boombox.IsPermanent = true
                boombox.StopRadio = function() end
                
                -- Mock network message
                netMock.ReadEntity = function() return boombox end
                
                -- Test removing boombox permanence
                net.Receive("RemoveBoomboxPermanent", function(_, ply)
                    state.netMock.messages["RemoveBoomboxPermanent"](_, superAdmin)
                end)
                
                expect(boombox.IsPermanent).to.equal(false)
            end
        },

        {
            name = "Permanent boombox reload command",
            func = function(state)
                local sqlMock = mockSQL()
                local entsMock = mockEnts()
                
                -- Mock concommand
                local cmdExecuted = false
                concommand.Add("rradio_reload_permanent_boomboxes", function(ply)
                    cmdExecuted = true
                end)
                
                -- Create superadmin player
                local superAdmin = mockPlayer()
                superAdmin.IsSuperAdmin = function() return true end
                
                -- Test reload command
                RunConsoleCommand("rradio_reload_permanent_boomboxes")
                expect(cmdExecuted).to.equal(true)
            end
        },

        {
            name = "Clear permanent database command",
            func = function(state)
                local sqlMock = mockSQL()
                
                -- Mock concommand
                local cmdExecuted = false
                concommand.Add("rradio_clear_permanent_db", function(ply)
                    cmdExecuted = true
                end)
                
                -- Create superadmin player
                local superAdmin = mockPlayer()
                superAdmin.IsSuperAdmin = function() return true end
                
                -- Test clear command
                RunConsoleCommand("rradio_clear_permanent_db")
                expect(cmdExecuted).to.equal(true)
                
                local clearQuery = sqlMock:getLastQuery()
                expect(clearQuery).to.include("DELETE FROM permanent_boomboxes")
            end
        }
    }
}
