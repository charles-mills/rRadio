-- rRadio Interface Utilities
-- Enhanced logic, optimized performance, and accurate volume handling

rRadio.interface = rRadio.interface or {}

-- State management
rRadio.interface.state = rRadio.interface.state or {
    isMessageAnimating = false,
    lastMessageTime = 0,
    entityVolumes = {}
}

-- File paths
local dataDir = "rradio"
rRadio.interface.favoriteCountriesFile = dataDir .. "/favorite_countries.json"
rRadio.interface.favoriteStationsFile = dataDir .. "/favorite_stations.json"
rRadio.interface.entityVolumesFile = dataDir .. "/entity_volumes.json"

-- Favorites
rRadio.interface.favoriteCountries = rRadio.interface.favoriteCountries or {}
rRadio.interface.favoriteStations = rRadio.interface.favoriteStations or {}

-- Utility function
local function Scale(value)
    return value * (ScrW() / 2560)
end

-- Initialize data directory
if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

-- Font setup (one-time creation)
local function setupFonts()
    surface.CreateFont("DynamicStopButtonFont", {
        font = "Roboto",
        size = Scale(20),
        weight = 700
    })
    surface.CreateFont("HeaderFont", {
        font = "Roboto",
        size = ScreenScale(8),
        weight = 700
    })
    surface.CreateFont("Roboto18", {
        font = "Roboto",
        size = ScreenScale(6),
        weight = 500
    })
end
setupFonts()

function rRadio.interface.DisplayVehicleEnterAnimation(argVehicle, isDriverOverride)
    if not GetConVar("rammel_rradio_enabled"):GetBool() or
       not GetConVar("rammel_rradio_vehicle_animation"):GetBool() then
        return
    end

    local ply = LocalPlayer()
    local vehicle = argVehicle or ply:GetVehicle()
    if not IsValid(vehicle) then return end

    local mainVehicle = rRadio.utils.GetVehicle(vehicle)
    if not IsValid(mainVehicle) or
       hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false or
       rRadio.utils.isSitAnywhereSeat(mainVehicle) then
        return
    end

    if rRadio.config.DriverPlayOnly and not (isDriverOverride or mainVehicle:GetDriver() == ply) then
        return
    end

    ply.currentRadioEntity = mainVehicle
    local currentTime = CurTime()
    local cooldownTime = rRadio.config.MessageCooldown and rRadio.config.MessageCooldown() or 3

    if rRadio.interface.state.isMessageAnimating or
       (rRadio.interface.state.lastMessageTime and currentTime - rRadio.interface.state.lastMessageTime < cooldownTime) then
        return
    end

    rRadio.interface.state.isMessageAnimating = true
    rRadio.interface.state.lastMessageTime = currentTime

    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local keyName = rRadio.GetKeyName(openKey) or "K"
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth = Scale(300)
    local panelHeight = Scale(70)
    local panel = vgui.Create("DButton")
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPos(scrW, scrH * 0.2)
    panel:SetText("")
    panel:MoveToFront()

    local animDuration = 1
    local showDuration = 2
    local startTime = currentTime
    local alpha = 0
    local pulseValue = 0
    local isDismissed = false

    panel.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function(self, w, h)
        local bgColor = rRadio.config.UI.HeaderColor or Color(0, 50, 100)
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(
            math.min(bgColor.r * hoverBrightness, 255),
            math.min(bgColor.g * hoverBrightness, 255),
            math.min(bgColor.b * hoverBrightness, 255),
            alpha * 255
        )
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)

        local keyWidth = Scale(40)
        local keyHeight = Scale(30)
        local keyX = Scale(20)
        local keyY = h / 2 - keyHeight / 2
        local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
        local adjustedKeyWidth = keyWidth * pulseScale
        local adjustedKeyHeight = keyHeight * pulseScale
        local adjustedKeyX = keyX - (adjustedKeyWidth - keyWidth) / 2
        local adjustedKeyY = keyY - (adjustedKeyHeight - keyHeight) / 2

        draw.RoundedBox(
            6,
            adjustedKeyX,
            adjustedKeyY,
            adjustedKeyWidth,
            adjustedKeyHeight,
            ColorAlpha(rRadio.config.UI.ButtonColor or Color(50, 50, 50), alpha * 255)
        )
        surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor or Color(255, 255, 255), alpha * 50))
        surface.DrawLine(keyX + keyWidth + Scale(7), h * 0.3, keyX + keyWidth + Scale(7), h * 0.7)
        draw.SimpleText(
            keyName,
            "Roboto18",
            keyX + keyWidth / 2,
            h / 2,
            ColorAlpha(rRadio.config.UI.TextColor or Color(255, 255, 255), alpha * 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            rRadio.config.Lang["ToOpenRadio"] or "to open radio",
            "Roboto18",
            keyX + keyWidth + Scale(15),
            h / 2,
            ColorAlpha(rRadio.config.UI.TextColor or Color(255, 255, 255), alpha * 255),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    panel.Think = function(self)
        local time = CurTime() - startTime
        pulseValue = (pulseValue + FrameTime() * 1.5) % 1

        if time < animDuration then
            local progress = math.ease.OutQuint(time / animDuration)
            self:SetPos(Lerp(progress, scrW, scrW - panelWidth), scrH * 0.2)
            alpha = math.ease.InOutQuad(progress)
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos(scrW - panelWidth, scrH * 0.2)
        else
            local progress = math.ease.InOutQuint((time - (animDuration + showDuration)) / animDuration)
            self:SetPos(Lerp(progress, scrW - panelWidth, scrW), scrH * 0.2)
            alpha = 1 - math.ease.InOutQuad(progress)
            if progress >= 1 then
                rRadio.interface.state.isMessageAnimating = false
                self:Remove()
            end
        end
    end

    panel.OnRemove = function()
        rRadio.interface.state.isMessageAnimating = false
    end
end

function rRadio.interface.applyTheme(themeName)
    if rRadio.themes and rRadio.themes[themeName] then
        rRadio.config.UI = rRadio.themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        ErrorNoHalt("[rRadio] Invalid theme name: " .. tostring(themeName) .. "\n")
    end
end

function rRadio.interface.loadSavedSettings()
    local themeName = GetConVar("rammel_rradio_menu_theme"):GetString()
    rRadio.interface.applyTheme(themeName)
    rRadio.interface.loadEntityVolumes()
end

function rRadio.interface.updateStationCount()
    local count = 0
    for ent, source in pairs(currentRadioSources or {}) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            if IsValid(source) then source:Stop() end
            currentRadioSources[ent] = nil
        end
    end
    activeStationCount = count
    return count
end

function rRadio.interface.LerpColor(t, col1, col2)
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        Lerp(t, col1.a or 255, col2.a or 255)
    )
end

function rRadio.interface.ClampVolume(volume)
    local maxVolume = rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1
    return math.Clamp(volume, 0, maxVolume)
end

function rRadio.interface.loadFavorites()
    local favoriteCountries = {}
    local favoriteStations = {}

    if file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(rRadio.interface.favoriteCountriesFile, "DATA"))
        if success and data and type(data) == "table" then
            for _, country in ipairs(data) do
                if type(country) == "string" then
                    favoriteCountries[country] = true
                end
            end
        else
            ErrorNoHalt("[rRadio] Failed to load favorite countries: " .. tostring(data) .. "\n")
            rRadio.interface.saveFavorites()
        end
    end

    if file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(rRadio.interface.favoriteStationsFile, "DATA"))
        if success and data and type(data) == "table" then
            for country, stations in pairs(data) do
                if type(country) == "string" and type(stations) == "table" then
                    favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if type(stationName) == "string" and type(isFavorite) == "boolean" then
                            favoriteStations[country][stationName] = isFavorite
                        end
                    end
                    if not next(favoriteStations[country]) then
                        favoriteStations[country] = nil
                    end
                end
            end
        else
            ErrorNoHalt("[rRadio] Failed to load favorite stations: " .. tostring(data) .. "\n")
            rRadio.interface.saveFavorites()
        end
    end

    rRadio.interface.favoriteCountries = favoriteCountries
    rRadio.interface.favoriteStations = favoriteStations
end

function rRadio.interface.saveFavorites()
    local favoriteCountries = rRadio.interface.favoriteCountries or {}
    local favoriteStations = rRadio.interface.favoriteStations or {}
    local favCountriesList = {}

    for country, enabled in pairs(favoriteCountries) do
        if type(country) == "string" and enabled then
            table.insert(favCountriesList, country)
        end
    end

    local countriesJson = util.TableToJSON(favCountriesList, true)
    if countriesJson then
        if file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
            file.Write(rRadio.interface.favoriteCountriesFile .. ".bak", file.Read(rRadio.interface.favoriteCountriesFile, "DATA"))
        end
        file.Write(rRadio.interface.favoriteCountriesFile, countriesJson)
    else
        ErrorNoHalt("[rRadio] Failed to convert favorite countries to JSON\n")
    end

    local favStationsTable = {}
    for country, stations in pairs(favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and type(isFavorite) == "boolean" then
                    favStationsTable[country][stationName] = isFavorite
                end
            end
            if not next(favStationsTable[country]) then
                favStationsTable[country] = nil
            end
        end
    end

    local stationsJson = util.TableToJSON(favStationsTable, true)
    if stationsJson then
        if file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
            file.Write(rRadio.interface.favoriteStationsFile .. ".bak", file.Read(rRadio.interface.favoriteStationsFile, "DATA"))
        end
        file.Write(rRadio.interface.favoriteStationsFile, stationsJson)
    else
        ErrorNoHalt("[rRadio] Failed to convert favorite stations to JSON\n")
    end
end

function rRadio.interface.loadEntityVolumes()
    if file.Exists(rRadio.interface.entityVolumesFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(rRadio.interface.entityVolumesFile, "DATA"))
        if success and data and type(data) == "table" then
            for entIndex, volume in pairs(data) do
                if type(entIndex) == "string" and type(volume) == "number" then
                    rRadio.interface.state.entityVolumes[tonumber(entIndex)] = rRadio.interface.ClampVolume(volume)
                end
            end
        else
            ErrorNoHalt("[rRadio] Failed to load entity volumes: " .. tostring(data) .. "\n")
        end
    end
end

function rRadio.interface.saveEntityVolumes()
    local volumeTable = {}
    for entIndex, volume in pairs(rRadio.interface.state.entityVolumes) do
        if type(entIndex) == "number" and type(volume) == "number" then
            volumeTable[tostring(entIndex)] = volume
        end
    end

    local json = util.TableToJSON(volumeTable, true)
    if json then
        if file.Exists(rRadio.interface.entityVolumesFile, "DATA") then
            file.Write(rRadio.interface.entityVolumesFile .. ".bak", file.Read(rRadio.interface.entityVolumesFile, "DATA"))
        end
        file.Write(rRadio.interface.entityVolumesFile, json)
    else
        ErrorNoHalt("[rRadio] Failed to convert entity volumes to JSON\n")
    end
end

function rRadio.interface.GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

function rRadio.interface.getEntityConfig(entity)
    return rRadio.utils.GetEntityConfig(entity) or {
        Volume = function() return rRadio.config.DefaultVolume or 0.5 end,
        MinVolumeDistance = function() return 100 end,
        MaxHearingDistance = function() return 1000 end
    }
end

function rRadio.interface.updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    if not GetConVar("rammel_rradio_enabled"):GetBool() or not IsValid(station) or not IsValid(entity) then
        if IsValid(station) then station:SetVolume(0) end
        return
    end

    local entIndex = entity:EntIndex()
    local entityConfig = rRadio.interface.getEntityConfig(entity)
    local userVolume = rRadio.interface.state.entityVolumes[entIndex] or
                       entity:GetNWFloat("Volume", entityConfig.Volume())
    userVolume = rRadio.interface.ClampVolume(userVolume)

    -- Update network variable for consistency
    if entity:GetNWFloat("Volume") ~= userVolume then
        entity:SetNWFloat("Volume", userVolume)
    end

    -- Update volume icon in UI if menu is open
    if radioMenuOpen and LocalPlayer().currentRadioEntity == entity then
        hook.Run("rRadio.UpdateVolumeIcon", userVolume)
    end

    if userVolume <= 0.02 then
        station:SetVolume(0)
        return
    end

    if isPlayerInCar then
        station:Set3DEnabled(false)
        station:SetVolume(userVolume)
    else
        station:Set3DEnabled(true)
        station:Set3DFadeDistance(entityConfig.MinVolumeDistance(), entityConfig.MaxHearingDistance())
        local finalVolume = rRadio.config.CalculateVolume and
                            rRadio.config.CalculateVolume(entity, LocalPlayer(), distanceSqr) or userVolume
        station:SetVolume(finalVolume)
    end
end

function rRadio.interface.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local fontName = "DynamicStopButtonFont"
    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)
    local maxFontSize = buttonHeight * 0.7

    if textWidth <= buttonWidth * 0.9 then return fontName end

    maxFontSize = math.max(10, maxFontSize - 1)
    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700
    })
    return fontName
end
