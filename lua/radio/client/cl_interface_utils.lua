rRadio.interface = rRadio.interface or {}

local dataDir = "rradio"
rRadio.interface.favoriteCountries = rRadio.interface.favoriteCountries or {}
rRadio.interface.favoriteStations = rRadio.interface.favoriteStations or {}
rRadio.interface.favoriteCountriesFile = dataDir .. "/favorite_countries.json"
rRadio.interface.favoriteStationsFile = dataDir .. "/favorite_stations.json"

if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

local function Scale(value)
    return value * (ScrW() / 2560)
end

function rRadio.interface.DisplayVehicleEnterAnimation(argVehicle, isDriverOverride)
    if not GetConVar("rammel_rradio_enabled"):GetBool() or not GetConVar("rammel_rradio_vehicle_animation"):GetBool() then
        return
    end

    local ply = LocalPlayer()
    local vehicle = argVehicle or ply:GetVehicle()
    if not IsValid(vehicle) then return end

    local mainVehicle = rRadio.utils.GetVehicle(vehicle)
    if not IsValid(mainVehicle) or rRadio.utils.isSitAnywhereSeat(mainVehicle) then return end

    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then return end
    if rRadio.config.DriverPlayOnly and not (isDriverOverride or mainVehicle:GetDriver() == ply) then return end

    ply.currentRadioEntity = mainVehicle

    local currentTime = CurTime()
    if rRadio.interface.isAnimating or (rRadio.interface.lastAnimationTime and currentTime - rRadio.interface.lastAnimationTime < rRadio.config.MessageCooldown()) then
        return
    end

    rRadio.interface.lastAnimationTime = currentTime
    rRadio.interface.isAnimating = true

    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local keyName = rRadio.GetKeyName(openKey) or "UNKNOWN"
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth, panelHeight = Scale(300), Scale(70)
    local panel = vgui.Create("DButton")
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPos(scrW, scrH * 0.2)
    panel:SetText("")
    panel:MoveToFront()

    local animDuration, showDuration = 1, 2
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
        local bgColor = rRadio.config.UI.HeaderColor or Color(50, 50, 50)
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(
            math.min(bgColor.r * hoverBrightness, 255),
            math.min(bgColor.g * hoverBrightness, 255),
            math.min(bgColor.b * hoverBrightness, 255),
            alpha * 255
        )
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)

        local keyWidth, keyHeight = Scale(40), Scale(30)
        local keyX, keyY = Scale(20), h / 2 - keyHeight / 2
        local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
        local adjustedKeyWidth, adjustedKeyHeight = keyWidth * pulseScale, keyHeight * pulseScale
        local adjustedKeyX, adjustedKeyY = keyX - (adjustedKeyWidth - keyWidth) / 2, keyY - (adjustedKeyHeight - keyHeight) / 2

        draw.RoundedBox(6, adjustedKeyX, adjustedKeyY, adjustedKeyWidth, adjustedKeyHeight, ColorAlpha(rRadio.config.UI.ButtonColor or Color(100, 100, 100), alpha * 255))
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
            alpha = math.ease.InOutQuad(time / animDuration)
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos(scrW - panelWidth, scrH * 0.2)
        else
            local progress = math.ease.InOutQuint((time - (animDuration + showDuration)) / animDuration)
            self:SetPos(Lerp(progress, scrW - panelWidth, scrW), scrH * 0.2)
            alpha = 1 - math.ease.InOutQuad(progress)
            if progress >= 1 then
                rRadio.interface.isAnimating = false
                self:Remove()
            end
        end
    end

    panel.OnRemove = function()
        rRadio.interface.isAnimating = false
    end
end

function rRadio.interface.applyTheme(themeName)
    local theme = rRadio.themes and rRadio.themes[themeName]
    if theme then
        rRadio.config.UI = theme
        hook.Run("ThemeChanged", themeName)
    else
        rRadio.FormattedOutput("[rRadio] Invalid theme: " .. tostring(themeName))
    end
end

function rRadio.interface.loadSavedSettings()
    local themeName = GetConVar("rammel_rradio_menu_theme"):GetString()
    rRadio.interface.applyTheme(themeName)
end

function rRadio.interface.updateStationCount()
    local count = 0
    currentRadioSources = currentRadioSources or {}
    for ent, source in pairs(currentRadioSources) do
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
    return math.Clamp(tonumber(volume) or 0, 0, rRadio.config.MaxVolume() or 1)
end

function rRadio.interface.loadFavorites()
    local favoriteCountries, favoriteStations = {}, {}

    if file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(rRadio.interface.favoriteCountriesFile, "DATA"))
        if success and data then
            for _, country in ipairs(data) do
                if isstring(country) then favoriteCountries[country] = true end
            end
        else
            rRadio.FormattedOutput("[rRadio] Error loading favorite countries, resetting.")
            rRadio.interface.saveFavorites()
        end
    end

    if file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(rRadio.interface.favoriteStationsFile, "DATA"))
        if success and data then
            for country, stations in pairs(data) do
                if isstring(country) and istable(stations) then
                    favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if isstring(stationName) and isbool(isFavorite) then
                            favoriteStations[country][stationName] = isFavorite
                        end
                    end
                    if table.IsEmpty(favoriteStations[country]) then favoriteStations[country] = nil end
                end
            end
        else
            rRadio.FormattedOutput("[rRadio] Error loading favorite stations, resetting.")
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
    for country, _ in pairs(favoriteCountries) do
        if isstring(country) then table.insert(favCountriesList, country) end
    end
    local countriesJson = util.TableToJSON(favCountriesList, true)
    if countriesJson then
        if file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
            file.Write(rRadio.interface.favoriteCountriesFile .. ".bak", file.Read(rRadio.interface.favoriteCountriesFile, "DATA"))
        end
        file.Write(rRadio.interface.favoriteCountriesFile, countriesJson)
    else
        rRadio.FormattedOutput("[rRadio] Error saving favorite countries.")
    end

    local favStationsTable = {}
    for country, stations in pairs(favoriteStations) do
        if isstring(country) and istable(stations) then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if isstring(stationName) and isbool(isFavorite) then
                    favStationsTable[country][stationName] = isFavorite
                end
            end
            if table.IsEmpty(favStationsTable[country]) then favStationsTable[country] = nil end
        end
    end
    local stationsJson = util.TableToJSON(favStationsTable, true)
    if stationsJson then
        if file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
            file.Write(rRadio.interface.favoriteStationsFile .. ".bak", file.Read(rRadio.interface.favoriteStationsFile, "DATA"))
        end
        file.Write(rRadio.interface.favoriteStationsFile, stationsJson)
    else
        rRadio.FormattedOutput("[rRadio] Error saving favorite stations.")
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
    return rRadio.utils.GetEntityConfig(entity)
end

function rRadio.interface.updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    if not GetConVar("rammel_rradio_enabled"):GetBool() or not IsValid(station) or not IsValid(entity) then
        station:SetVolume(0)
        return
    end

    local entityConfig = rRadio.interface.getEntityConfig(entity)
    if not entityConfig then
        station:SetVolume(0)
        return
    end

    local userVolume = rRadio.interface.ClampVolume(entity:GetNWFloat("Volume", entityConfig.Volume()))
    if userVolume <= 0.02 then
        station:SetVolume(0)
        return
    end

    if isPlayerInCar then
        station:Set3DEnabled(false)
        station:SetVolume(userVolume)
    else
        station:Set3DEnabled(true)
        local minDist = entityConfig.MinVolumeDistance()
        local maxDist = entityConfig.MaxHearingDistance()
        station:Set3DFadeDistance(minDist, maxDist)
        local finalVolume = rRadio.config.CalculateVolume(entity, LocalPlayer(), distanceSqr)
        station:SetVolume(finalVolume)
    end
end

function rRadio.interface.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local fontName = "DynamicStopButtonFont"
    local maxFontSize = math.floor(buttonHeight * 0.7)
    local minFontSize = 10

    surface.CreateFont("HeaderFont", {
        font = "Roboto",
        size = ScreenScale(8),
        weight = 700
    })

    local function tryFontSize(size)
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = size,
            weight = 700
        })
        surface.SetFont(fontName)
        local textWidth = surface.GetTextSize(text)
        return textWidth <= buttonWidth * 0.9
    end

    local fontSize = maxFontSize
    while fontSize > minFontSize and not tryFontSize(fontSize) do
        fontSize = fontSize - 1
    end

    surface.CreateFont(fontName, {
        font = "Roboto",
        size = fontSize,
        weight = 700
    })

    return fontName
end
