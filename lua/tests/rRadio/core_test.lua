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
        SendToServer = function() end,
        ReadEntity = function() return Entity(1) end,
        ReadString = function() return "TestStation" end,
        ReadFloat = function() return 0.5 end,
        ReadBool = function() return true end,
    }
    _G.net = netMock
    return netMock
end

local function mockSound()
    local soundMock = {
        PlayURL = function(url, flags, callback)
            local station = {
                SetPos = function() end,
                SetVolume = function() end,
                Play = function() end,
                Set3DFadeDistance = function() end,
                GetState = function() return GMOD_CHANNEL_PLAYING end,
            }
            callback(station)
        end
    }
    _G.sound = soundMock
    return soundMock
end

local function mockLanguageManager()
    local langMock = {
        GetCountryTranslation = function(_, _, country) return "Translated " .. country end,
        GetAvailableLanguages = function() return {en = "English", es = "Spanish"} end,
        GetLanguageName = function() return "English" end,
        SetLanguage = function() end,
    }
    _G.LanguageManager = langMock
    return langMock
end

local function mockMisc()
    local miscMock = {
        Themes = {list = {default = {}, dark = {}}},
        ErrorHandler = {
            TrackAttempt = function() end,
            StartTimeout = function() end,
            StopTimeout = function() end,
            ClearEntity = function() end,
            HandleError = function() end,
            ErrorTypes = {
                CONNECTION_FAILED = 1,
                INVALID_URL = 2,
                UNKNOWN = 3,
                STREAM_ERROR = 4,
            },
        },
        UIPerformance = {
            GetScale = function(value) return value end,
            OptimizePaintFunction = function(_, func) return func end,
            frameUpdateThreshold = 0.016,
        },
        MemoryManager = {
            TrackSound = function() end,
            TrackTimer = function() end,
            TrackHook = function() end,
            CleanupEntity = function() end,
        },
        KeyNames = {
            mapping = {[KEY_K] = "K"},
            GetKeyName = function() return "K" end,
        },
    }
    _G.Misc = miscMock
    return miscMock
end

local function mockUtils()
    local utilsMock = {
        getEntityConfig = function() return {Volume = 0.5, MinVolumeDistance = 100, MaxHearingDistance = 1000} end,
        isValidRadioEntity = function() return true end,
        canInteractWithBoombox = function() return true end,
        getVehicleEntity = function(ent) return ent end,
    }
    _G.utils = utilsMock
    return utilsMock
end

return {
    groupName = "rRadio Core",
    cases = {
        {
            name = "RadioManager should exist",
            func = function()
                expect(RadioManager).to.exist()
            end
        },
        {
            name = "StationQueue should exist",
            func = function()
                expect(StationQueue).to.exist()
            end
        },
        {
            name = "CountryNameCache functionality",
            func = function()
                local cache = CountryNameCache
                cache:set("USA", "en", "United States")
                expect(cache:get("USA", "en")).to.equal("United States")
                cache:clear("USA", "en")
                expect(cache:get("USA", "en")).to.equal(nil)
            end
        },
        {
            name = "formatCountryName functionality",
            func = function()
                mockLanguageManager()
                expect(formatCountryName("USA")).to.equal("Translated USA")
            end
        },
        {
            name = "RadioSourceManager functionality",
            func = function()
                local netMock = mockNet()
                local soundMock = mockSound()
                mockMisc()
                mockUtils()

                local entity = Entity(1)
                local station = {
                    SetPos = function() end,
                    SetVolume = function() end,
                    Play = function() end,
                    Stop = function() end,
                }

                RadioSourceManager:addSource(entity, station, "TestStation")
                expect(RadioSourceManager.activeSources[1]).to.exist()
                expect(RadioSourceManager.sourceStatuses[1].stationStatus).to.equal("playing")

                RadioSourceManager:removeSource(entity)
                expect(RadioSourceManager.activeSources[1]).to.equal(nil)
                expect(RadioSourceManager.sourceStatuses[1].stationStatus).to.equal("stopped")
            end
        },
        {
            name = "PlayCarRadioStation net message",
            func = function()
                local netMock = mockNet()
                local soundMock = mockSound()
                mockMisc()
                mockUtils()

                netMock.messages["PlayCarRadioStation"]()
                expect(RadioSourceManager.activeSources[1]).to.exist()
                expect(RadioSourceManager.sourceStatuses[1].stationStatus).to.equal("playing")
            end
        },
        {
            name = "StopCarRadioStation net message",
            func = function()
                local netMock = mockNet()
                mockMisc()
                mockUtils()

                RadioSourceManager:addSource(Entity(1), {Stop = function() end}, "TestStation")
                netMock.messages["StopCarRadioStation"]()
                expect(RadioSourceManager.activeSources[1]).to.equal(nil)
                expect(RadioSourceManager.sourceStatuses[1].stationStatus).to.equal("stopped")
            end
        },
        {
            name = "UpdateRadioVolume net message",
            func = function()
                local netMock = mockNet()
                mockMisc()
                mockUtils()

                entityVolumes = {}
                netMock.messages["UpdateRadioVolume"]()
                expect(entityVolumes[Entity(1)]).to.equal(0.5)
            end
        },
        {
            name = "OpenRadioMenu net message",
            func = function()
                local netMock = mockNet()
                mockMisc()
                mockUtils()

                local openRadioMenuCalled = false
                _G.openRadioMenu = function() openRadioMenuCalled = true end
                netMock.messages["OpenRadioMenu"]()
                expect(openRadioMenuCalled).to.equal(true)
            end
        },
        {
            name = "loadFavorites functionality",
            func = function()
                -- Mock file.Exists and file.Read
                local oldFileExists = file.Exists
                local oldFileRead = file.Read
                file.Exists = function(_, _) return true end
                file.Read = function(_, _) return util.TableToJSON({country1 = true, country2 = true}) end

                loadFavorites()
                expect(favoriteCountries.country1).to.equal(true)
                expect(favoriteCountries.country2).to.equal(true)

                -- Restore original functions
                file.Exists = oldFileExists
                file.Read = oldFileRead
            end
        },
        {
            name = "saveFavorites functionality",
            func = function()
                -- Mock file.Write
                local oldFileWrite = file.Write
                local writtenData = {}
                file.Write = function(path, content)
                    writtenData[path] = content
                end

                favoriteCountries = {country1 = true, country2 = true}
                favoriteStations = {country1 = {station1 = true, station2 = true}}
                saveFavorites()

                expect(writtenData[favoriteCountriesFile]).to.exist()
                expect(writtenData[favoriteStationsFile]).to.exist()

                -- Restore original function
                file.Write = oldFileWrite
            end
        },
        {
            name = "createFonts functionality",
            func = function()
                -- Mock surface.CreateFont
                local oldCreateFont = surface.CreateFont
                local createdFonts = {}
                surface.CreateFont = function(name, data)
                    createdFonts[name] = data
                end

                createFonts()
                expect(createdFonts["Roboto18"]).to.exist()
                expect(createdFonts["HeaderFont"]).to.exist()

                -- Restore original function
                surface.CreateFont = oldCreateFont
            end
        },
        {
            name = "updateRadioVolume functionality",
            func = function()
                local station = {
                    SetVolume = function(self, vol) self.volume = vol end,
                    volume = 0
                }
                local entity = Entity(1)
                entityVolumes[entity] = 0.8

                -- Test in-car scenario
                updateRadioVolume(station, 100, true, entity)
                expect(station.volume).to.equal(0.8)

                -- Test out-of-car scenario within min distance
                updateRadioVolume(station, 50*50, false, entity)
                expect(station.volume).to.equal(0.8)

                -- Test out-of-car scenario beyond min distance
                updateRadioVolume(station, 500*500, false, entity)
                expect(station.volume).to.be.below(0.8)
                expect(station.volume).to.be.above(0)

                -- Test out-of-car scenario beyond max distance
                updateRadioVolume(station, 2000*2000, false, entity)
                expect(station.volume).to.equal(0)
            end
        },
        {
            name = "PrintCarRadioMessage functionality",
            func = function()
                -- Mock chat.AddText and GetConVar
                local oldAddText = chat.AddText
                local messageAdded = false
                chat.AddText = function() messageAdded = true end

                local oldGetConVar = GetConVar
                GetConVar = function(name)
                    if name == "car_radio_show_messages" then
                        return {GetBool = function() return true end}
                    elseif name == "car_radio_open_key" then
                        return {GetInt = function() return KEY_K end}
                    end
                end

                -- Mock LocalPlayer
                local oldLocalPlayer = LocalPlayer
                LocalPlayer = function()
                    return {
                        GetVehicle = function() return Entity(1) end
                    }
                end

                PrintCarRadioMessage()
                expect(messageAdded).to.equal(true)

                -- Restore original functions
                chat.AddText = oldAddText
                GetConVar = oldGetConVar
                LocalPlayer = oldLocalPlayer
            end
        },
        {
            name = "calculateFontSizeForStopButton functionality",
            func = function()
                -- Mock surface functions
                local oldCreateFont = surface.CreateFont
                local oldSetFont = surface.SetFont
                local oldGetTextSize = surface.GetTextSize

                surface.CreateFont = function() end
                surface.SetFont = function() end
                surface.GetTextSize = function() return 50 end

                local fontName = calculateFontSizeForStopButton("STOP", 100, 50)
                expect(fontName).to.equal("DynamicStopButtonFont")

                -- Restore original functions
                surface.CreateFont = oldCreateFont
                surface.SetFont = oldSetFont
                surface.GetTextSize = oldGetTextSize
            end
        },
        {
            name = "createStarIcon functionality",
            func = function()
                -- Mock vgui.Create
                local oldVguiCreate = vgui.Create
                local createdButton
                vgui.Create = function(type, parent)
                    if type == "DImageButton" then
                        createdButton = {
                            SetSize = function() end,
                            SetPos = function() end,
                            SetImage = function() end,
                            DoClick = function() end
                        }
                        return createdButton
                    end
                end

                local parent = {}
                local starIcon = createStarIcon(parent, "TestCountry", function() end)
                expect(starIcon).to.equal(createdButton)

                -- Restore original function
                vgui.Create = oldVguiCreate
            end
        },
    }
}
