rRadio.interface = rRadio.interface or {}
local ICON_VOL_MUTE = Material("hud/vol_mute.png", "smooth")
local ICON_VOL_DOWN = Material("hud/vol_down.png", "smooth")
local ICON_VOL_UP = Material("hud/vol_up.png", "smooth")
local stringLower = string.lower
local stringSub = string.sub
local stringFind = string.find
local utf8Len = string.utf8Len or function(s) return #s end
local utf8Sub = string.utf8Sub or function(s, i, j) return stringSub(s, i, j) end
local IsValid = IsValid
local BASE_WIDTH = 2560
local scaleRatio = ScrW() / BASE_WIDTH
function rRadio.cl.getEntityVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local vol = rRadio.cl.entityVolumes[entity]
    if vol then return vol end
    local cfg = rRadio.interface.getEntityConfig(entity)
    return (cfg and cfg.Volume) or 0.5
end

function rRadio.cl.updateVolumeIcon(volumeIcon, value)
    if not IsValid(volumeIcon) then return end
    local v = (type(value) == "function") and value() or value
    volumeIcon:SetMaterial(rRadio.interface.GetVolumeIcon(v))
end

function rRadio.cl.sendPendingVolume()
    if not IsValid(rRadio.cl.pendingEntity) then return end
    net.Start("rRadio.SetRadioVolume")
    net.WriteEntity(rRadio.cl.pendingEntity)
    net.WriteFloat(rRadio.cl.pendingVolume)
    net.SendToServer()
end

local function buildCharMap(s)
    local map = {}
    if not s then return map end
    s = stringLower(s)
    for i = 1, #s do
        local c = stringSub(s, i, i)
        map[c] = map[c] or {}
        map[c][#map[c] + 1] = i
    end
    return map
end

local function binarySearch(arr, last)
    local lo, hi = 1, #arr
    local result
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if arr[mid] > last then
            result, hi = arr[mid], mid - 1
        else
            lo = mid + 1
        end
    end
    return result
end

local function subsequenceTest(needle, haystackMap)
    if #needle == 0 then return true end
    local lastPos = 0
    for i = 1, #needle do
        local c = stringSub(needle, i, i)
        local positions = haystackMap[c]
        if not positions then return false end
        lastPos = binarySearch(positions, lastPos)
        if not lastPos then return false end
    end
    return true
end

rRadio.interface.buildCharMap = buildCharMap
rRadio.interface.subsequenceTest = subsequenceTest
rRadio.interface.favoriteCountries = rRadio.interface.favoriteCountries or {}
rRadio.interface.favoriteStations = rRadio.interface.favoriteStations or {}
local DATA_DIR = "rradio"
rRadio.interface.favoriteCountriesFile = DATA_DIR .. "/favorite_countries.json"
rRadio.interface.favoriteStationsFile = DATA_DIR .. "/favorite_stations.json"
local SAVE_FAVORITES_TIMER = "rRadio.SaveFavorites"
local SAVE_FAVORITES_DELAY = 0.25
local function readJSON(path)
    if not file.Exists(path, "DATA") then return nil end
    local success, data = pcall(function() return util.JSONToTable(file.Read(path, "DATA")) end)
    return success and data or nil
end

local function writeJSON(path, tbl)
    local json = util.TableToJSON(tbl, true)
    if not json then
        rRadio.logger.ErrorScope("favorites", "Error converting table to JSON for", path)
        return
    end

    if file.Exists(path, "DATA") then file.Write(path .. ".bak", file.Read(path, "DATA")) end
    file.Write(path, json)
end

local enabledCvar = GetConVar("rammel_rradio_enabled")
local function radioEnabled()
    return enabledCvar:GetBool()
end

if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
local scaledFontCache = {}
hook.Add("LanguageUpdated", "rRadio.ClearScaledFontCache", function() scaledFontCache = {} end)
local _lastVolumes = {}
local _volThreshold = 0.01
function rRadio.interface.scale(val)
    return val * scaleRatio
end

function rRadio.interface.playSound(sound)
    if not rRadio.config.EnableSoundEffects then return end
    if not rRadio.config.Sounds[sound] then return end
    surface.PlaySound(rRadio.config.Sounds[sound])
end

function rRadio.interface.refreshVolume(ent)
    local src = rRadio.cl.radioSources[ent]
    if not (IsValid(ent) and IsValid(src)) then return end
    local ply = LocalPlayer()
    local dist = ply:GetPos():DistToSqr(ent:GetPos())
    local inCar = rRadio.utils.GetVehicle(ply:GetVehicle()) == ent
    rRadio.interface.updateRadioVolume(src, dist, inCar, ent)
end

function rRadio.interface.fuzzyMatch(needle, haystack)
    local lowerNeedle = stringLower(needle or "")
    local lowerHaystack = stringLower(haystack or "")
    local nLen = #lowerNeedle
    if nLen == 0 then return 1 end
    local hLen = #lowerHaystack
    local scoreSum = 0
    local lastPos = 1
    for i = 1, nLen do
        local c = stringSub(lowerNeedle, i, i)
        local found = stringFind(lowerHaystack, c, lastPos, true)
        if not found then return 0 end
        scoreSum = scoreSum + (1 - (found - lastPos) / hLen)
        lastPos = found + 1
    end
    return scoreSum / nLen
end

local function fuzzyMatchLowered(lowerNeedle, lowerHaystack)
    local nLen = #lowerNeedle
    if nLen == 0 then return 1 end
    local hLen = #lowerHaystack
    local scoreSum = 0
    local lastPos = 1
    for i = 1, nLen do
        local c = stringSub(lowerNeedle, i, i)
        local found = stringFind(lowerHaystack, c, lastPos, true)
        if not found then return 0 end
        scoreSum = scoreSum + (1 - (found - lastPos) / hLen)
        lastPos = found + 1
    end
    return scoreSum / nLen
end

local function ensureSearchMetadata(item, keyFn)
    local text = item.searchText
    if text == nil then
        text = keyFn(item) or ""
        item.searchText = text
    end

    local lower = item.searchTextLower
    if lower == nil then
        lower = stringLower(text)
        item.searchTextLower = lower
    end

    local map = item.charMap
    if map == nil then
        map = buildCharMap(lower)
        item.charMap = map
    end
    return text, lower, map
end

local function fuzzyFilterCore(needle, items, keyFn, minScore, boostFn)
    local lowerNeedle = stringLower(needle or "")
    local hasNeedle = #lowerNeedle > 0
    local matches = {}
    for _, item in ipairs(items) do
        local _, lowerText, map = ensureSearchMetadata(item, keyFn)
        if (not hasNeedle) or (map and rRadio.interface.subsequenceTest(lowerNeedle, map)) then
            local score = hasNeedle and fuzzyMatchLowered(lowerNeedle, lowerText) or 1
            if boostFn then score = score + (boostFn(item) or 0) end
            if score >= (minScore or 0) then
                matches[#matches + 1] = {
                    item = item,
                    score = score,
                    sortKey = lowerText
                }
            end
        end
    end

    if #matches == 0 then
        for _, item in ipairs(items) do
            local _, lowerText = ensureSearchMetadata(item, keyFn)
            matches[#matches + 1] = {
                item = item,
                score = 0,
                sortKey = lowerText
            }
        end
    end

    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.sortKey < b.sortKey
    end)

    local results, seen = {}, {}
    for _, v in ipairs(matches) do
        if not seen[v.sortKey] then
            seen[v.sortKey] = true
            results[#results + 1] = v.item
        end
    end
    return results
end

rRadio.interface.fuzzyFilter = function(needle, items, keyFn, minScore, boostFn) return fuzzyFilterCore(needle, items, keyFn, minScore, boostFn) end
function rRadio.interface.MakeIconButton(parent, materialPath, url, xOffset)
    local icon = vgui.Create("rRadioIconButton", parent)
    local size = rRadio.interface.scale(32)
    icon:SetSize(size, size)
    icon:SetPos(xOffset, (parent:GetTall() - size) / 2)
    icon:SetIcon(materialPath)
    icon:SetURL(url)
    return icon
end

function rRadio.interface.TruncateText(text, font, maxWidth)
    surface.SetFont(font)
    local textW = surface.GetTextSize(text)
    if textW <= maxWidth then return text end
    local ellipsis = "..."
    local suffixW = surface.GetTextSize(ellipsis)
    local len = utf8Len(text)
    local low, high, best = 1, len, 0
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local substr = utf8Sub(text, 1, mid)
        local w = surface.GetTextSize(substr)
        if w + suffixW <= maxWidth then
            best = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return utf8Sub(text, 1, best) .. ellipsis
end

function rRadio.interface.TruncateChars(text, maxChars)
    if utf8Len(text) <= maxChars then return text end
    return utf8Sub(text, 1, maxChars)
end

function rRadio.interface.StyleVBar(vbar)
    if not IsValid(vbar) then return end
    vbar:SetWide(rRadio.interface.scale(8))
    if vbar.DockMargin then vbar:DockMargin(0, rRadio.interface.scale(2), rRadio.interface.scale(2), rRadio.interface.scale(2)) end
    vbar.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ScrollbarColor) end
    vbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ScrollbarGripColor) end
    vbar.btnUp.Paint = function(self, w, h) end
    vbar.btnDown.Paint = function(self, w, h) end
end

function rRadio.interface.DisplayVehicleEnterAnimation(argVehicle, isDriverOverride)
    rRadio.logger.DebugScope("cl_utils", "Displaying vehicle enter animation")
    if not radioEnabled() then
        rRadio.logger.DebugScope("cl_utils", "Radio disabled")
        return
    end

    if not GetConVar("rammel_rradio_vehicle_animation"):GetBool() then
        rRadio.logger.DebugScope("cl_utils", "Vehicle animation disabled")
        return
    end

    local ply = LocalPlayer()
    rRadio.logger.DebugScope("cl_utils", "argVehicle:", tostring(argVehicle), "ply:GetVehicle():", tostring(ply:GetVehicle()))
    local vehicle = argVehicle or ply:GetVehicle()
    if IsValid(vehicle) then
        rRadio.logger.DebugScope("cl_utils", "vehicle class:", vehicle:GetClass(), "entIndex:", vehicle:EntIndex())
    else
        rRadio.logger.DebugScope("cl_utils", "vehicle is invalid")
    end

    if not IsValid(vehicle) then
        rRadio.logger.DebugScope("cl_utils", "Player is not in a vehicle")
        return
    end

    local mainVehicle = rRadio.utils.GetVehicle(vehicle)
    rRadio.logger.DebugScope("cl_utils", "mainVehicle:", tostring(mainVehicle), IsValid(mainVehicle) and ("class: " .. mainVehicle:GetClass() .. ", entIndex: " .. mainVehicle:EntIndex()) or "")
    if not IsValid(mainVehicle) then
        rRadio.logger.DebugScope("cl_utils", "Vehicle is not valid")
        return
    end

    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then
        rRadio.logger.DebugScope("cl_utils", "Hook disallowed")
        return
    end

    if rRadio.config.DriverPlayOnly then
        local ok = (isDriverOverride ~= nil and isDriverOverride) or (mainVehicle:GetDriver() == ply)
        if not ok then
            rRadio.logger.DebugScope("cl_utils", "Player is not the driver")
            return
        end
    end

    if rRadio.utils.IsSitAnywhereSeat(mainVehicle) then
        rRadio.logger.DebugScope("cl_utils", "Player is in a sit anywhere seat")
        return
    end

    ply.currentRadioEntity = mainVehicle
    rRadio.logger.DebugScope("cl_utils", "Vehicle animation conditions met")
    local currentTime = CurTime()
    local cooldownTime = rRadio.config.MessageCooldown
    if isMessageAnimating or (lastMessageTime and currentTime - lastMessageTime < cooldownTime) then
        rRadio.logger.DebugScope("cl_utils", "Animation is already playing or cooldown not met")
        return
    end

    rRadio.logger.DebugScope("cl_utils", "Animation cooldown met")
    lastMessageTime = currentTime
    isMessageAnimating = true
    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local keyName = rRadio.GetKeyName(openKey)
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth = rRadio.interface.scale(300)
    local panelHeight = rRadio.interface.scale(70)
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
        rRadio.interface.playSound("ButtonPressMain")
        rRadio.cl.openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function(self, w, h)
        local bgColor = rRadio.config.UI.HeaderColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor = Color(math.min(bgColor.r * hoverBrightness, 255), math.min(bgColor.g * hoverBrightness, 255), math.min(bgColor.b * hoverBrightness, 255), alpha * 255)
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)
        local keyWidth = rRadio.interface.scale(40)
        local keyHeight = rRadio.interface.scale(30)
        local keyX = rRadio.interface.scale(20)
        local keyY = h / 2 - keyHeight / 2
        local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
        local adjustedKeyWidth = keyWidth * pulseScale
        local adjustedKeyHeight = keyHeight * pulseScale
        local adjustedKeyX = keyX - (adjustedKeyWidth - keyWidth) / 2
        local adjustedKeyY = keyY - (adjustedKeyHeight - keyHeight) / 2
        draw.RoundedBox(6, adjustedKeyX, adjustedKeyY, adjustedKeyWidth, adjustedKeyHeight, ColorAlpha(rRadio.config.UI.ButtonColor, alpha * 255))
        surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor, alpha * 50))
        surface.DrawLine(keyX + keyWidth + rRadio.interface.scale(7), h * 0.3, keyX + keyWidth + rRadio.interface.scale(7), h * 0.7)
        draw.SimpleText(keyName, "rRadio.Roboto5", keyX + keyWidth / 2, h / 2, ColorAlpha(rRadio.config.UI.TextColor, alpha * 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local messageX = keyX + keyWidth + rRadio.interface.scale(15)
        draw.SimpleText(rRadio.config.Lang["ToOpenRadio"] or "to open radio", "rRadio.Roboto5", messageX, h / 2, ColorAlpha(rRadio.config.UI.TextColor, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

    panel.OnRemove = function() isMessageAnimating = false end
end

function rRadio.interface.applyTheme(themeName)
    if rRadio.themes[themeName] then
        rRadio.config.UI = rRadio.themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        rRadio.logger.WarnScope("theme", "Invalid theme name:", themeName)
    end
end

function rRadio.interface.loadSavedSettings()
    local themeName = GetConVar("rammel_rradio_menu_theme"):GetString()
    rRadio.interface.applyTheme(themeName)
end

function rRadio.interface.updateStationCount()
    local count = 0
    for ent, source in pairs(rRadio.cl.radioSources or {}) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            if IsValid(source) then source:Stop() end
            if rRadio.cl.radioSources then rRadio.cl.radioSources[ent] = nil end
        end
    end

    activeStationCount = count
    return count
end

function rRadio.interface.LerpColor(t, col1, col2)
    return Color(Lerp(t, col1.r, col2.r), Lerp(t, col1.g, col2.g), Lerp(t, col1.b, col2.b), Lerp(t, col1.a or 255, col2.a or 255))
end

function rRadio.interface.ClampVolume(volume)
    local serverMax = rRadio.config.MaxVolume
    local clientMax = GetConVar("rammel_rradio_max_volume"):GetFloat()
    local limit = math.min(serverMax, clientMax)
    return math.Clamp(volume, 0, limit)
end

function rRadio.interface.loadFavorites()
    local favoriteCountries = {}
    local favoriteStations = {}
    local data = readJSON(rRadio.interface.favoriteCountriesFile)
    if data then
        for _, country in ipairs(data) do
            if type(country) == "string" then favoriteCountries[country] = true end
        end
    elseif file.Exists(rRadio.interface.favoriteCountriesFile, "DATA") then
        rRadio.logger.WarnScope("favorites", "Error loading favorite countries, resetting file")
        favoriteCountries = {}
        rRadio.interface.saveFavorites()
    end

    local dataStations = readJSON(rRadio.interface.favoriteStationsFile)
    if dataStations then
        for country, stations in pairs(dataStations) do
            if type(country) == "string" and type(stations) == "table" then
                favoriteStations[country] = {}
                for stationName, isFavorite in pairs(stations) do
                    if type(stationName) == "string" and type(isFavorite) == "boolean" then favoriteStations[country][stationName] = isFavorite end
                end

                if next(favoriteStations[country]) == nil then favoriteStations[country] = nil end
            end
        end
    elseif file.Exists(rRadio.interface.favoriteStationsFile, "DATA") then
        rRadio.logger.WarnScope("favorites", "Error loading favorite stations, resetting file")
        favoriteStations = {}
        rRadio.interface.saveFavorites()
    end

    rRadio.interface.favoriteCountries = favoriteCountries
    rRadio.interface.favoriteStations = favoriteStations
end

local function writeFavorites()
    local favoriteCountries = rRadio.interface.favoriteCountries or {}
    local favoriteStations = rRadio.interface.favoriteStations or {}
    local favCountriesList = {}
    for country, _ in pairs(favoriteCountries) do
        if type(country) == "string" then table.insert(favCountriesList, country) end
    end

    writeJSON(rRadio.interface.favoriteCountriesFile, favCountriesList)
    local favStationsTable = {}
    for country, stations in pairs(favoriteStations) do
        if type(country) == "string" and type(stations) == "table" then
            favStationsTable[country] = {}
            for stationName, isFavorite in pairs(stations) do
                if type(stationName) == "string" and type(isFavorite) == "boolean" then favStationsTable[country][stationName] = isFavorite end
            end

            if next(favStationsTable[country]) == nil then favStationsTable[country] = nil end
        end
    end

    writeJSON(rRadio.interface.favoriteStationsFile, favStationsTable)
end

function rRadio.interface.saveFavorites()
    timer.Remove(SAVE_FAVORITES_TIMER)
    timer.Create(SAVE_FAVORITES_TIMER, SAVE_FAVORITES_DELAY, 1, writeFavorites)
end

function rRadio.interface.toggleFavorite(list, key, subkey)
    if subkey then
        list[key] = list[key] or {}
        if list[key][subkey] then
            list[key][subkey] = nil
            if not next(list[key]) then list[key] = nil end
        else
            list[key][subkey] = true
        end
    else
        if list[key] then
            list[key] = nil
        else
            list[key] = true
        end
    end

    rRadio.interface.saveFavorites()
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

function rRadio.interface.CalculateVolume(entity, player, distanceSqr)
    if not IsValid(entity) or not IsValid(player) then return 0 end
    local entityConfig = rRadio.utils.GetEntityConfig(entity)
    if not entityConfig then return 0 end
    local baseVolume = (rRadio.cl.entityVolumes[entity] ~= nil and rRadio.cl.entityVolumes[entity]) or entity:GetNWFloat("Volume", entityConfig.Volume)
    if player:GetVehicle() == entity or distanceSqr <= entityConfig.MinVolumeDistance ^ 2 then return baseVolume end
    local maxDist = entityConfig.MaxHearingDistance
    local distance = math.sqrt(distanceSqr)
    if distance >= maxDist then return 0 end
    local falloff = 1 - math.Clamp((distance - entityConfig.MinVolumeDistance) / (maxDist - entityConfig.MinVolumeDistance), 0, 1)
    return baseVolume * falloff
end

function rRadio.interface.updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    if not radioEnabled() then
        local prev = _lastVolumes[entity] or -1
        if prev ~= 0 then
            station:SetVolume(0)
            _lastVolumes[entity] = 0
        end
        return
    end

    if rRadio.cl.mutedBoomboxes and rRadio.cl.mutedBoomboxes[entity] then
        local prev = _lastVolumes[entity] or -1
        if prev ~= 0 then
            station:SetVolume(0)
            _lastVolumes[entity] = 0
        end
        return
    end

    local entityConfig = rRadio.interface.getEntityConfig(entity)
    if not entityConfig then return end
    local userVolume = rRadio.interface.ClampVolume(rRadio.cl.entityVolumes[entity] or entity:GetNWFloat("Volume", entityConfig.Volume))
    if userVolume <= 0.02 then
        local prev = _lastVolumes[entity] or -1
        if prev ~= 0 then
            station:SetVolume(0)
            _lastVolumes[entity] = 0
        end
        return
    end

    if isPlayerInCar then
        station:Set3DEnabled(false)
        local prev = _lastVolumes[entity] or -1
        if math.abs(userVolume - prev) >= _volThreshold then
            station:SetVolume(userVolume)
            _lastVolumes[entity] = userVolume
        end
        return
    end

    station:Set3DEnabled(true)
    local minDist = entityConfig.MinVolumeDistance
    local maxDist = entityConfig.MaxHearingDistance
    station:Set3DFadeDistance(minDist, maxDist)
    local finalVolume = rRadio.interface.CalculateVolume(entity, LocalPlayer(), distanceSqr)
    finalVolume = rRadio.interface.ClampVolume(finalVolume)
    local prev = _lastVolumes[entity] or -1
    if math.abs(finalVolume - prev) >= _volThreshold then
        station:SetVolume(finalVolume)
        _lastVolumes[entity] = finalVolume
    end
end

local function getScaledFont(prefix, text, buttonWidth, buttonHeight)
    local key = prefix .. "_" .. text .. "_" .. math.floor(buttonHeight)
    if scaledFontCache[key] then return scaledFontCache[key] end
    local maxFontSize = math.floor(buttonHeight * 0.7)
    local fontName = prefix .. "Font_" .. key
    surface.CreateFont(fontName, {
        font = "Roboto",
        size = maxFontSize,
        weight = 700,
    })

    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)
    while textWidth > buttonWidth * 0.9 and maxFontSize > 10 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(fontName, {
            font = "Roboto",
            size = maxFontSize,
            weight = 700,
        })

        surface.SetFont(fontName)
        textWidth = surface.GetTextSize(text)
    end

    scaledFontCache[key] = fontName
    return fontName
end

function rRadio.interface.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    return getScaledFont("Stop", text, buttonWidth, buttonHeight)
end

function rRadio.interface.calculateFontSizeForGlobalButton(text, buttonWidth, buttonHeight)
    return getScaledFont("Global", text, buttonWidth, buttonHeight)
end

function rRadio.interface.GetVolumeIcon(vol)
    local maxVol = rRadio.config.MaxVolume or 1.0
    vol = math.min(vol, maxVol)
    if vol < 0.01 then
        return ICON_VOL_MUTE
    elseif vol <= 0.65 then
        return ICON_VOL_DOWN
    else
        return ICON_VOL_UP
    end
end

local function loadLanguage()
    rRadio.LanguageManager:UpdateCurrentLanguage()
    hook.Run("LanguageUpdated")
end

loadLanguage()
cvars.AddChangeCallback("gmod_language", function() loadLanguage() end)
hook.Add("OnScreenSizeChanged", "rRadio.RecalcScale", function() scaleRatio = ScrW() / BASE_WIDTH end)
function rRadio.GetKeyName(keyCode)
    local name = input.GetKeyName(keyCode)
    if not name then return "the Open Key" end
    return name:gsub("_", " "):gsub("(%a)([%w]*)", function(first, rest) return first:upper() .. rest:lower() end)
end

local BLOCKED_MENU_KEYS = {
    [MOUSE_LEFT] = true
}

function rRadio.RejectBlockedMenuKey(binder)
    if not BLOCKED_MENU_KEYS[binder:GetSelectedNumber()] then return false end
    binder:SetValue(GetConVar("rammel_rradio_menu_key"):GetInt())
    return true
end
