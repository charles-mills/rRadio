rRadio.interface = rRadio.interface or {}

rRadio.interface.favoriteCountries = rRadio.interface.favoriteCountries or {}
rRadio.interface.favoriteStations = rRadio.interface.favoriteStations or {}
local dataDir = "rradio"

rRadio.interface.favoriteCountriesFile = dataDir .. "/favorite_countries.json"
rRadio.interface.favoriteStationsFile = dataDir .. "/favorite_stations.json"

rRadio.DevPrint("Loading interface utils")

if not file.IsDir(dataDir, "DATA") then
    file.CreateDir(dataDir)
end

local function Scale(value)
    return value * (ScrW() / 2560)
end

function rRadio.interface.DisplayVehicleEnterAnimation(argVehicle, isDriverOverride)
    rRadio.DevPrint("Displaying vehicle enter animation")

    if not GetConVar("rammel_rradio_enabled"):GetBool() then
        rRadio.DevPrint("Radio disabled")
        return
    end

    if not GetConVar("rammel_rradio_vehicle_animation"):GetBool() then
        rRadio.DevPrint("Vehicle animation disabled")
        return
    end

    local ply = LocalPlayer()
    rRadio.DevPrint("argVehicle: " .. tostring(argVehicle) .. ", ply:GetVehicle(): " .. tostring(ply:GetVehicle()))
    local vehicle = argVehicle or ply:GetVehicle()
    if IsValid(vehicle) then rRadio.DevPrint("vehicle class: " .. vehicle:GetClass() .. ", entIndex: " .. vehicle:EntIndex()) else rRadio.DevPrint("vehicle is invalid") end
    if not IsValid(vehicle) then
        rRadio.DevPrint("Player is not in a vehicle")
        return end
    local mainVehicle = rRadio.utils.GetVehicle(vehicle)
    rRadio.DevPrint("mainVehicle: " .. tostring(mainVehicle) .. (IsValid(mainVehicle) and (", class: " .. mainVehicle:GetClass() .. ", entIndex: " .. mainVehicle:EntIndex()) or ""))
    if not IsValid(mainVehicle) then
        rRadio.DevPrint("Vehicle is not valid")
        return 
    end

    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then
        rRadio.DevPrint("Hook disallowed")
        return 
    end

    if rRadio.config.DriverPlayOnly then
        local ok = (isDriverOverride ~= nil and isDriverOverride) or (mainVehicle:GetDriver() == ply)
        if not ok then
            rRadio.DevPrint("Player is not the driver")
            return
        end
    end

    if rRadio.utils.isSitAnywhereSeat(mainVehicle) then
        rRadio.DevPrint("Player is in a sit anywhere seat")
        return 
    end

    ply.currentRadioEntity = mainVehicle

    rRadio.DevPrint("Vehicle animation conditions met")

    local currentTime = CurTime()
    local cooldownTime = rRadio.config.MessageCooldown()

    if isMessageAnimating or (lastMessageTime and currentTime - lastMessageTime < cooldownTime) then
        rRadio.DevPrint("Animation is already playing or cooldown not met")
        return
    end

    rRadio.DevPrint("Animation cooldown met")
    lastMessageTime = currentTime
    isMessageAnimating = true
    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local keyName = rRadio.GetKeyName(openKey)
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
    local startTime = CurTime()
    local alpha = 0
    local pulseValue = 0
    local isDismissed = false

    panel.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function(self, w, h)
        local bgColor = rRadio.config.UI.HeaderColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor =
            Color(
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
            ColorAlpha(rRadio.config.UI.ButtonColor, alpha * 255)
        )
        surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor, alpha * 50))
        surface.DrawLine(keyX + keyWidth + Scale(7), h * 0.3, keyX + keyWidth + Scale(7), h * 0.7)
        draw.SimpleText(
            keyName,
            "Roboto18",
            keyX + keyWidth / 2,
            h / 2,
            ColorAlpha(rRadio.config.UI.TextColor, alpha * 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        local messageX = keyX + keyWidth + Scale(15)
        draw.SimpleText(
            rRadio.config.Lang["ToOpenRadio"] or "to open radio",
            "Roboto18",
            messageX,
            h / 2,
            ColorAlpha(rRadio.config.UI.TextColor, alpha * 255),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    panel.Think = function(self)
        local time = CurTime() - startTime
        pulseValue = (pulseValue + FrameTime() * 1.5) % 1
        if time < animDuration then
            local progress = time / animDuration
            local easedProgress = math.ease.OutQuint(progress)
            self:SetPos(Lerp(easedProgress, scrW, scrW - panelWidth), scrH * 0.2)
            alpha = math.ease.InOutQuad(progress)
        elseif time < animDuration + showDuration and not isDismissed then
            alpha = 1
            self:SetPos(scrW - panelWidth, scrH * 0.2)
        elseif not isDismissed or time >= animDuration + showDuration then
            local progress = (time - (animDuration + showDuration)) / animDuration
            local easedProgress = math.ease.InOutQuint(progress)
            self:SetPos(Lerp(easedProgress, scrW - panelWidth, scrW), scrH * 0.2)
            alpha = 1 - math.ease.InOutQuad(progress)
            if progress >= 1 then
                isMessageAnimating = false
                self:Remove()
            end
        end
    end
    
    panel.OnRemove = function()
        isMessageAnimating = false
    end
end

function rRadio.interface.applyTheme(themeName)
    if rRadio.themes[themeName] then
        rRadio.config.UI = rRadio.themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        rRadio.FormattedOutput("[rRadio] Invalid theme name: " .. themeName)
    end
end

function rRadio.interface.loadSavedSettings()
    local themeName = GetConVar("rammel_rradio_menu_theme"):GetString()
    rRadio.interface.applyTheme(themeName)
end

function rRadio.interface.updateStationCount()
    local count = 0
    for ent, source in pairs(currentRadioSources or {}) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            if IsValid(source) then
                source:Stop()
            end
            if currentRadioSources then
                currentRadioSources[ent] = nil
            end
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
    local maxVolume = rRadio.config.MaxVolume()
    return math.Clamp(volume, 0, maxVolume)
end

function rRadio.interface.loadFavorites()
    local favoriteCountries = {}
    local favoriteStations = {}
    if file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
        local success, data =
            pcall(
            function()
                return util.JSONToTable(file.Read(rRadio.interface.favoriteCountriesFile, "DATA"))
            end
        )
        if success and data then
            for _, country in ipairs(data) do
                if type(country) == "string" then
                    favoriteCountries[country] = true
                end
            end
        else
            print("[rRADIO] Error loading favorite countries, resetting file")
            favoriteCountries = {}
            rRadio.interface.saveFavorites()
        end
    end
    if file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
        local success, data =
            pcall(
            function()
                return util.JSONToTable(file.Read(rRadio.interface.favoriteStationsFile, "DATA"))
            end
        )
        if success and data then
            for country, stations in pairs(data) do
                if type(country) == "string" and type(stations) == "table" then
                    favoriteStations[country] = {}
                    for stationName, isFavorite in pairs(stations) do
                        if type(stationName) == "string" and type(isFavorite) == "boolean" then
                            favoriteStations[country][stationName] = isFavorite
                        end
                    end
                    if next(favoriteStations[country]) == nil then
                        favoriteStations[country] = nil
                    end
                end
            end
        else
            print("[rRADIO] Error loading favorite stations, resetting file")
            favoriteStations = {}
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
        if type(country) == "string" then
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
        print("[rRADIO] Error converting favorite countries to JSON")
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
            if next(favStationsTable[country]) == nil then
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
        print("[rRADIO] Error converting favorite stations to JSON")
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
    if not GetConVar("rammel_rradio_enabled"):GetBool() then
        station:SetVolume(0)
        return
    end

    local entityConfig = rRadio.interface.getEntityConfig(entity)
    if not entityConfig then
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
        return
    end
    station:Set3DEnabled(true)
    local minDist = entityConfig.MinVolumeDistance()
    local maxDist = entityConfig.MaxHearingDistance()
    station:Set3DFadeDistance(minDist, maxDist)
    local finalVolume = rRadio.config.CalculateVolume(entity, LocalPlayer(), distanceSqr)
    station:SetVolume(finalVolume)
end

function rRadio.interface.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    local maxFontSize = buttonHeight * 0.7
    local fontName = "DynamicStopButtonFont"
    surface.CreateFont(
        fontName,
        {
            font = "Roboto",
            size = maxFontSize,
            weight = 700
        }
    )
    surface.CreateFont(
        "HeaderFont",
        {
            font = "Roboto",
            size = ScreenScale(8),
            weight = 700
        }
    )
    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)
    while textWidth > buttonWidth * 0.9 and maxFontSize > 10 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(
            fontName,
            {
                font = "Roboto",
                size = maxFontSize,
                weight = 700
            }
        )
        surface.SetFont(fontName)
        textWidth = surface.GetTextSize(text)
    end
    return fontName
end