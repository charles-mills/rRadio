return {
    groupName = "rRadio Utils",
    
    beforeEach = function(state)
        -- Mock entities
        state.vehicle = {
            IsValid = function() return true end,
            GetNWBool = function(_, key) return key == "IsSitAnywhereSeat" and true or false end,
            IsVehicle = function() return true end,
            GetParent = function() return nil end,
            GetClass = function() return "prop_vehicle_jeep" end
        }
        
        state.boombox = {
            IsValid = function() return true end,
            GetClass = function() return "boombox" end,
            GetNWEntity = function() return state.owner end,
            GetNWString = function() return "" end,
            SetNWString = function() end,
            SetNWBool = function() end
        }
        
        state.player = {
            IsValid = function() return true end,
            IsSuperAdmin = function() return false end
        }
        
        state.owner = state.player
    end,

    cases = {
        {
            name = "Should detect SitAnywhere seats",
            func = function(state)
                expect(utils.isSitAnywhereSeat(state.vehicle)).to.equal(true)
                
                -- Test invalid vehicle
                expect(utils.isSitAnywhereSeat(nil)).to.equal(false)
            end
        },
        
        {
            name = "Should get entity owner correctly",
            func = function(state)
                local owner = utils.getOwner(state.boombox)
                expect(owner).to.equal(state.owner)
                
                -- Test invalid entity
                expect(utils.getOwner(nil)).to.equal(nil)
            end
        },
        
        {
            name = "Should validate boombox interaction permissions",
            func = function(state)
                -- Test owner permission
                expect(utils.canInteractWithBoombox(state.player, state.boombox))
                    .to.equal(true)
                
                -- Test non-owner permission
                state.owner = nil
                expect(utils.canInteractWithBoombox(state.player, state.boombox))
                    .to.equal(false)
                
                -- Test superadmin override
                state.player.IsSuperAdmin = function() return true end
                expect(utils.canInteractWithBoombox(state.player, state.boombox))
                    .to.equal(true)
            end
        },
        
        {
            name = "Should get correct vehicle entity",
            func = function(state)
                local result = utils.getVehicleEntity(state.vehicle)
                expect(result).to.equal(state.vehicle)
                
                -- Test parented vehicle
                local parent = { IsValid = function() return true end }
                state.vehicle.GetParent = function() return parent end
                result = utils.getVehicleEntity(state.vehicle)
                expect(result).to.equal(parent)
            end
        },
        
        {
            name = "Should validate radio entities",
            func = function(state)
                -- Test valid vehicle
                state.vehicle.GetNWBool = function() return false end
                expect(utils.isValidRadioEntity(state.vehicle)).to.equal(true)
                
                -- Test SitAnywhere seat
                state.vehicle.GetNWBool = function() return true end
                expect(utils.isValidRadioEntity(state.vehicle)).to.equal(false)
                
                -- Test boombox with permissions
                expect(utils.isValidRadioEntity(state.boombox, state.player))
                    .to.equal(true)
            end
        },
        
        {
            name = "Should get correct entity config",
            func = function(state)
                -- Mock Config
                _G.Config = {
                    Boombox = { Volume = 1 },
                    VehicleRadio = { Volume = 0.5 }
                }
                
                expect(utils.getEntityConfig(state.boombox))
                    .to.equal(Config.Boombox)
                expect(utils.getEntityConfig(state.vehicle))
                    .to.equal(Config.VehicleRadio)
            end
        },
        
        {
            name = "Should update entity status correctly",
            func = function(state)
                local statusSet, nameSet, playingSet = false, false, false
                
                state.boombox.SetNWString = function(_, key, value)
                    if key == "Status" then statusSet = true end
                    if key == "StationName" then nameSet = true end
                end
                
                state.boombox.SetNWBool = function(_, key, value)
                    if key == "IsPlaying" then playingSet = true end
                end
                
                utils.updateEntityStatus(state.boombox, "playing", "Test Station")
                
                expect(statusSet).to.equal(true)
                expect(nameSet).to.equal(true)
                expect(playingSet).to.equal(true)
            end
        }
    }
}
