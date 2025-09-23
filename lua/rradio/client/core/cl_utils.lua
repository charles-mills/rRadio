local Radio = rRadio

Radio.interface = Radio.interface or {}
Radio.cl = Radio.cl or {}

local Utils = Radio.utils
local Interface = Radio.interface
local Config = Radio.config
local DevPrint = Radio.DevPrint

local ICON_VOL_MUTE = Material("hud/vol_mute.png", "smooth")
local ICON_VOL_DOWN = Material("hud/vol_down.png", "smooth")
local ICON_VOL_UP   = Material("hud/vol_up.png", "smooth")

local stringLower = string.lower
local stringSub   = string.sub
local stringFind  = string.find
local stringUpper = string.upper
local languageGetPhrase = language.GetPhrase
local inputGetKeyName = input.GetKeyName
local utf8Len = string.utf8Len or function(s) return #s end
local utf8Sub = string.utf8Sub or function(s, i, j) return stringSub(s, i, j) end

local IsValid = IsValid

local BASE_WIDTH = 2560
local scaleRatio = ScrW() / BASE_WIDTH

function Radio.cl.getEntityVolume(entity)
    if not IsValid(entity) then return 0.5 end
    
    local vol = Radio.cl.entityVolumes[entity]
    if vol then return vol end
    
    local cfg = Interface.getEntityConfig(entity)
    return (cfg and cfg.Volume) or 0.5
end

function Radio.cl.updateVolumeIcon(volumeIcon, value)
    if not IsValid(volumeIcon) then return end
    local v = (type(value) == "function") and value() or value
    volumeIcon:SetMaterial(Interface.GetVolumeIcon(v))
end

function Radio.cl.sendPendingVolume()
    if not IsValid(Radio.cl.pendingEntity) then return end
    net.Start("rRadio.SetRadioVolume")
    net.WriteEntity(Radio.cl.pendingEntity)
    net.WriteFloat(Radio.cl.pendingVolume)
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
    if not positions then
      return false
    end
    lastPos = binarySearch(positions, lastPos)
    if not lastPos then
      return false
    end
  end
  return true
end

Interface.buildCharMap     = buildCharMap
Interface.subsequenceTest = subsequenceTest

Interface.favoriteCountries = Interface.favoriteCountries or {}
Interface.favoriteStations = Interface.favoriteStations or {}
local DATA_DIR = "rradio"

Interface.favoriteCountriesFile = DATA_DIR .. "/favorite_countries.json"
Interface.favoriteStationsFile = DATA_DIR .. "/favorite_stations.json"

local SAVE_FAVORITES_TIMER = "rRadio.SaveFavorites"
local SAVE_FAVORITES_DELAY = 0.25

local function readJSON(path)
  if not file.Exists(path, "DATA") then return nil end
  local success, data = pcall(function()
    return util.JSONToTable(file.Read(path, "DATA"))
  end)
  return success and data or nil
end

local function writeJSON(path, tbl)
  local json = util.TableToJSON(tbl, true)
  if not json then
    print("[rRADIO] Error converting table to JSON")
    return
  end
  if file.Exists(path, "DATA") then
    file.Write(path .. ".bak", file.Read(path, "DATA"))
  end
  file.Write(path, json)
end

local enabledCvar = GetConVar("rammel_rradio_enabled")
local function radioEnabled()
  return enabledCvar:GetBool()
end

if not file.IsDir(DATA_DIR, "DATA") then
    file.CreateDir(DATA_DIR)
end

local scaledFontCache = {}
local keyNameCache = {}
hook.Add("LanguageUpdated", "rRadio.ClearScaledFontCache", function()
    scaledFontCache = {}
    keyNameCache = {}
end)

local KEY_NAME_FALLBACK = "the Open Key"

local function resolveKeyName(keyCode)
    local token = keyCode and inputGetKeyName(keyCode) or nil
    if token and token ~= "" then
        local translated = languageGetPhrase(token)
        if translated and translated ~= "" then
            return translated
        end
    end

    local fallback = languageGetPhrase(KEY_NAME_FALLBACK)
    if not fallback or fallback == "" then
        fallback = KEY_NAME_FALLBACK
    end

    return fallback
end

function Radio.cl.getKeyName(keyCode)
    if keyCode ~= nil then
        local cached = keyNameCache[keyCode]
        if cached then return cached end
    end

    local resolved = resolveKeyName(keyCode)
    local upper = stringUpper(resolved)

    if keyCode ~= nil then
        keyNameCache[keyCode] = upper
    end

    return upper
end


local _lastVolumes = {}
local _volThreshold = 0.01

function Interface.scale(val)
    return val * scaleRatio
end

function Interface.playSound(sound)
    if not Config.EnableSoundEffects then return end
    if not Config.Sounds[sound] then return end
    surface.PlaySound(Config.Sounds[sound])
end

function Interface.refreshVolume(ent)
    local src = Radio.cl.radioSources[ent]
    if not (IsValid(ent) and IsValid(src)) then return end

    local ply = LocalPlayer()
    local dist = ply:GetPos():DistToSqr(ent:GetPos())
    local inCar = (Utils.GetVehicle(ply:GetVehicle()) == ent)
    Interface.updateRadioVolume(src, dist, inCar, ent)
end

function Interface.fuzzyMatch(needle, haystack, alreadyLowered)
    if not alreadyLowered then
        needle = stringLower(needle or "")
        haystack = stringLower(haystack or "")
    else
        needle = needle or ""
        haystack = haystack or ""
    end
    local nLen = #needle
    if nLen == 0 then return 1 end
    local hLen = #haystack
    local scoreSum = 0
    local lastPos = 1
    for i = 1, nLen do
        local c = stringSub(needle, i, i)
        local found = stringFind(haystack, c, lastPos, true)
        if not found then return 0 end
        scoreSum = scoreSum + (1 - (found - lastPos) / hLen)
        lastPos = found + 1
    end
    return scoreSum / nLen
end

local DEFAULT_MAX_FUZZY_RESULTS = 150

local function getFuzzyResultLimit()
    local cl = Radio.cl
    return (cl and cl.MAX_SEARCH_RESULTS) or DEFAULT_MAX_FUZZY_RESULTS
end

local function prepareFuzzyItem(item, keyFn)
    local text = keyFn(item) or ""
    if type(item) == "table" then
        if item.__fuzzyKey ~= text then
            item.__fuzzyKey = text
            item.__fuzzyLower = stringLower(text)
            item.__fuzzyCharMap = nil
        end
        return item.__fuzzyKey, item.__fuzzyLower or ""
    end

    return text, stringLower(text)
end

local function ensureCharMap(item, text)
    if type(item) == "table" then
        if not item.__fuzzyCharMap then
            item.__fuzzyCharMap = item.charMap or buildCharMap(text)
        end
        return item.__fuzzyCharMap
    end

    return buildCharMap(text)
end

local function pushLimitedMatch(matches, limit, entry)
    local size = #matches
    if size >= limit then
        local worst = matches[size]
        if worst.score > entry.score then return end
        if worst.score == entry.score and worst.sortKey <= entry.sortKey then return end
    end

    matches[size + 1] = entry
    local idx = size + 1
    while idx > 1 do
        local prev = matches[idx - 1]
        if prev.score > entry.score then break end
        if prev.score == entry.score and prev.sortKey <= entry.sortKey then break end
        matches[idx], matches[idx - 1] = prev, entry
        idx = idx - 1
    end

    if #matches > limit then
        matches[#matches] = nil
    end
end

local function fuzzySort(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.sortKey < b.sortKey
end

local function buildResults(matches)
    local results, seen = {}, {}
    for i = 1, #matches do
        local entry = matches[i]
        local key = entry.sortKey or ""
        if not seen[key] then
            seen[key] = true
            results[#results + 1] = entry.item
        end
    end
    return results
end

local function fuzzyFilterCore(needle, items, keyFn, minScore, boostFn)
    local lowerNeedle = stringLower(needle or "")
    local hasNeedle = lowerNeedle ~= ""
    local minAccept = minScore or 0
    local limit = hasNeedle and getFuzzyResultLimit() or nil
    local matches = {}

    if hasNeedle then
        for i = 1, #items do
            local item = items[i]
            local text, lowered = prepareFuzzyItem(item, keyFn)
            local map = ensureCharMap(item, text)
            if map and Interface.subsequenceTest(lowerNeedle, map) then
                local score = Interface.fuzzyMatch(lowerNeedle, lowered, true)
                if boostFn then score = score + (boostFn(item) or 0) end
                if score >= minAccept then
                    local entry = { item = item, score = score, sortKey = lowered or "" }
                    if limit then
                        pushLimitedMatch(matches, limit, entry)
                    else
                        matches[#matches + 1] = entry
                    end
                end
            end
        end

        if not limit then
            table.sort(matches, fuzzySort)
        end
    else
        for i = 1, #items do
            local item = items[i]
            local _, lowered = prepareFuzzyItem(item, keyFn)
            local score = Interface.fuzzyMatch(lowerNeedle, lowered, true)
            if boostFn then score = score + (boostFn(item) or 0) end
            matches[#matches + 1] = { item = item, score = score, sortKey = lowered or "" }
        end

        table.sort(matches, fuzzySort)
    end

    if #matches == 0 then return {} end

    return buildResults(matches)
end

Interface.fuzzyFilter = function(needle, items, keyFn, minScore, boostFn)
    local out = fuzzyFilterCore(needle, items, keyFn, minScore, boostFn)
    if needle and needle ~= "" and #out == 0 then
        return fuzzyFilterCore("", items, keyFn, minScore, boostFn)
    end
    return out
end

function Interface.MakeIconButton(parent, materialPath, url, xOffset)
    local icon = vgui.Create("rRadioIconButton", parent)
    local size = Interface.scale(32)
    icon:SetSize(size, size)
    icon:SetPos(xOffset, (parent:GetTall() - size) / 2)
    icon:SetIcon(materialPath)
    icon:SetURL(url)
    return icon
end

function Interface.TruncateText(text, font, maxWidth)
    surface.SetFont(font)
    local textW = surface.GetTextSize(text)
    if textW <= maxWidth then
        return text
    end
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

function Interface.TruncateChars(text, maxChars)
    if utf8Len(text) <= maxChars then
        return text
    end
    return utf8Sub(text, 1, maxChars)
end

function Interface.StyleVBar(vbar)
    if not IsValid(vbar) then return end
    vbar:SetWide(Interface.scale(8))
    if vbar.DockMargin then vbar:DockMargin(0, Interface.scale(2), Interface.scale(2), Interface.scale(2)) end
    vbar.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor)
    end
    vbar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor)
    end
    vbar.btnUp.Paint = function(self, w, h) end
    vbar.btnDown.Paint = function(self, w, h) end
end

function Interface.DisplayVehicleEnterAnimation(argVehicle, isDriverOverride)
    DevPrint("Displaying vehicle enter animation")

    if not radioEnabled() then
        DevPrint("Radio disabled")
        return
    end

    if not GetConVar("rammel_rradio_vehicle_animation"):GetBool() then
        DevPrint("Vehicle animation disabled")
        return
    end

    local ply = LocalPlayer()
    DevPrint("argVehicle: " .. tostring(argVehicle) .. ", ply:GetVehicle(): " .. tostring(ply:GetVehicle()))
    local vehicle = argVehicle or ply:GetVehicle()
    if IsValid(vehicle) then DevPrint("vehicle class: " .. vehicle:GetClass() .. ", entIndex: " .. vehicle:EntIndex()) else DevPrint("vehicle is invalid") end
    if not IsValid(vehicle) then
        DevPrint("Player is not in a vehicle")
        return end
    local mainVehicle = Utils.GetVehicle(vehicle)
    DevPrint("mainVehicle: " .. tostring(mainVehicle) .. (IsValid(mainVehicle) and (", class: " .. mainVehicle:GetClass() .. ", entIndex: " .. mainVehicle:EntIndex()) or ""))
    if not IsValid(mainVehicle) then
        DevPrint("Vehicle is not valid")
        return 
    end

    if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then
        DevPrint("Hook disallowed")
        return 
    end

    if Config.DriverPlayOnly then
        local ok = (isDriverOverride ~= nil and isDriverOverride) or (mainVehicle:GetDriver() == ply)
        if not ok then
            DevPrint("Player is not the driver")
            return
        end
    end

    if Utils.IsSitAnywhereSeat(mainVehicle) then
        DevPrint("Player is in a sit anywhere seat")
        return 
    end

    ply.currentRadioEntity = mainVehicle

    DevPrint("Vehicle animation conditions met")

    local currentTime = CurTime()
    local cooldownTime = Config.MessageCooldown

    if isMessageAnimating or (lastMessageTime and currentTime - lastMessageTime < cooldownTime) then
        DevPrint("Animation is already playing or cooldown not met")
        return
    end

    DevPrint("Animation cooldown met")
    lastMessageTime = currentTime
    isMessageAnimating = true
    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local keyName = Radio.cl.getKeyName(openKey)
    local scrW, scrH = ScrW(), ScrH()
    local panelWidth = Interface.scale(300)
    local panelHeight = Interface.scale(70)
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
        Interface.playSound("ButtonPressMain")
        openRadioMenu()
        isDismissed = true
    end

    panel.Paint = function(self, w, h)
        local bgColor = Config.UI.HeaderColor
        local hoverBrightness = self:IsHovered() and 1.2 or 1
        bgColor =
            Color(
            math.min(bgColor.r * hoverBrightness, 255),
            math.min(bgColor.g * hoverBrightness, 255),
            math.min(bgColor.b * hoverBrightness, 255),
            alpha * 255
        )
        draw.RoundedBoxEx(12, 0, 0, w, h, bgColor, true, false, true, false)
        local keyWidth = Interface.scale(40)
        local keyHeight = Interface.scale(30)
        local keyX = Interface.scale(20)
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
            ColorAlpha(Config.UI.ButtonColor, alpha * 255)
        )
        surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, alpha * 50))
        surface.DrawLine(keyX + keyWidth + Interface.scale(7), h * 0.3, keyX + keyWidth + Interface.scale(7), h * 0.7)
        draw.SimpleText(
            keyName,
            "rRadio.Roboto5",
            keyX + keyWidth / 2,
            h / 2,
            ColorAlpha(Config.UI.TextColor, alpha * 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        local messageX = keyX + keyWidth + Interface.scale(15)
        draw.SimpleText(
            Config.Lang["ToOpenRadio"] or "to open radio",
            "rRadio.Roboto5",
            messageX,
            h / 2,
            ColorAlpha(Config.UI.TextColor, alpha * 255),
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

function Interface.applyTheme(themeName)
    if Radio.themes[themeName] then
        Config.UI = Radio.themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        Radio.FormattedOutput("[rRadio] Invalid theme name: " .. themeName)
    end
end

function Interface.loadSavedSettings()
    local themeName = GetConVar("rammel_rradio_menu_theme"):GetString()
    Interface.applyTheme(themeName)
end

function Interface.updateStationCount()
    local count = 0
    for ent, source in pairs(Radio.cl.radioSources or {}) do
        if IsValid(ent) and IsValid(source) then
            count = count + 1
        else
            if IsValid(source) then
                source:Stop()
            end
            if Radio.cl.radioSources then
                Radio.cl.radioSources[ent] = nil
            end
        end
    end
    activeStationCount = count
    return count
end

function Interface.LerpColor(t, col1, col2)
    return Color(
        Lerp(t, col1.r, col2.r),
        Lerp(t, col1.g, col2.g),
        Lerp(t, col1.b, col2.b),
        Lerp(t, col1.a or 255, col2.a or 255)
    )
end

function Interface.ClampVolume(volume)
    local serverMax = Config.MaxVolume
    local clientMax = GetConVar("rammel_rradio_max_volume"):GetFloat()
    local limit = math.min(serverMax, clientMax)
    return math.Clamp(volume, 0, limit)
end

function Interface.loadFavorites()
    local favoriteCountries = {}
    local favoriteStations = {}
    local data = readJSON(Interface.favoriteCountriesFile)
    if data then
        for _, country in ipairs(data) do
            if type(country) == "string" then
                favoriteCountries[country] = true
            end
        end
    elseif file.Exists(Interface.favoriteCountriesFile, "DATA") then
        print("[rRADIO] Error loading favorite countries, resetting file")
        favoriteCountries = {}
        Interface.saveFavorites()
    end

    local dataStations = readJSON(Interface.favoriteStationsFile)
    if dataStations then
        for country, stations in pairs(dataStations) do
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
    elseif file.Exists(Interface.favoriteStationsFile, "DATA") then
        print("[rRADIO] Error loading favorite stations, resetting file")
        favoriteStations = {}
        Interface.saveFavorites()
    end

    Interface.favoriteCountries = favoriteCountries
    Interface.favoriteStations = favoriteStations
end

local function writeFavorites()
    local favoriteCountries = Interface.favoriteCountries or {}
    local favoriteStations = Interface.favoriteStations or {}
    local favCountriesList = {}
    for country, _ in pairs(favoriteCountries) do
        if type(country) == "string" then
            table.insert(favCountriesList, country)
        end
    end
    writeJSON(Interface.favoriteCountriesFile, favCountriesList)
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
    writeJSON(Interface.favoriteStationsFile, favStationsTable)
end

function Interface.saveFavorites()
    timer.Remove(SAVE_FAVORITES_TIMER)
    timer.Create(SAVE_FAVORITES_TIMER, SAVE_FAVORITES_DELAY, 1, writeFavorites)
end

function Interface.toggleFavorite(list, key, subkey)
    if subkey then
        list[key] = list[key] or {}
        if list[key][subkey] then
            list[key][subkey] = nil
            if not next(list[key]) then
                list[key] = nil
            end
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
    Interface.saveFavorites()
end

function Interface.GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

function Interface.getEntityConfig(entity)
    return Utils.GetEntityConfig(entity)
end

function Interface.CalculateVolume(entity, player, distanceSqr)
    if not IsValid(entity) or not IsValid(player) then return 0 end
    local entityConfig = Utils.GetEntityConfig(entity)
    if not entityConfig then return 0 end
    local baseVolume =
        (Radio.cl.entityVolumes[entity] ~= nil and Radio.cl.entityVolumes[entity])
        or entity:GetNWFloat("Volume", entityConfig.Volume)
    if player:GetVehicle() == entity or distanceSqr <= entityConfig.MinVolumeDistance ^ 2 then
        return baseVolume
    end
    local maxDist = entityConfig.MaxHearingDistance
    local distance = math.sqrt(distanceSqr)
    if distance >= maxDist then return 0 end
    local falloff = 1 - math.Clamp((distance - entityConfig.MinVolumeDistance) /
    (maxDist - entityConfig.MinVolumeDistance), 0, 1)
    return baseVolume * falloff
end

function Interface.updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
    if not radioEnabled() then
        local prev = _lastVolumes[entity] or -1
        if prev ~= 0 then
            station:SetVolume(0)
            _lastVolumes[entity] = 0
        end
        return
    end

    if Radio.cl.mutedBoomboxes and Radio.cl.mutedBoomboxes[entity] then
        local prev = _lastVolumes[entity] or -1
        if prev ~= 0 then
            station:SetVolume(0)
            _lastVolumes[entity] = 0
        end
        return
    end

    local entityConfig = Interface.getEntityConfig(entity)
    if not entityConfig then
        return
    end

    local userVolume = Interface.ClampVolume(
        Radio.cl.entityVolumes[entity]
        or entity:GetNWFloat("Volume", entityConfig.Volume)
    )

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
    local finalVolume = Interface.CalculateVolume(entity, LocalPlayer(), distanceSqr)

    finalVolume = Interface.ClampVolume(finalVolume)
    local prev = _lastVolumes[entity] or -1
    
    if math.abs(finalVolume - prev) >= _volThreshold then
        station:SetVolume(finalVolume)
        _lastVolumes[entity] = finalVolume
    end
end

local function getScaledFont(prefix, text, buttonWidth, buttonHeight)
    local key = prefix .. "_" .. text .. "_" .. math.floor(buttonHeight)
    if scaledFontCache[key] then
        return scaledFontCache[key]
    end

    local maxFontSize = math.floor(buttonHeight * 0.7)
    local fontName = prefix .. "Font_" .. key
    surface.CreateFont(fontName, {
        font   = "Roboto",
        size   = maxFontSize,
        weight = 700,
    })
    surface.SetFont(fontName)
    local textWidth = surface.GetTextSize(text)

    while textWidth > buttonWidth * 0.9 and maxFontSize > 10 do
        maxFontSize = maxFontSize - 1
        surface.CreateFont(fontName, {
            font   = "Roboto",
            size   = maxFontSize,
            weight = 700,
        })
        surface.SetFont(fontName)
        textWidth = surface.GetTextSize(text)
    end

    scaledFontCache[key] = fontName
    return fontName
end

function Interface.calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
    return getScaledFont("Stop", text, buttonWidth, buttonHeight)
end

function Interface.calculateFontSizeForGlobalButton(text, buttonWidth, buttonHeight)
    return getScaledFont("Global", text, buttonWidth, buttonHeight)
end

function Interface.GetVolumeIcon(vol)
    local maxVol = Config.MaxVolume or 1.0
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
    Radio.LanguageManager:UpdateCurrentLanguage()
    hook.Run("LanguageUpdated")
end

loadLanguage()
cvars.AddChangeCallback("gmod_language", function()
    loadLanguage()
end)

hook.Add("OnScreenSizeChanged", "rRadio.RecalcScale", function()
    scaleRatio = ScrW() / BASE_WIDTH
end)
