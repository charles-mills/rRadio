include("radio/shared/sh_config.lua")
local LanguageManager = include("radio/client/lang/cl_language_manager.lua")
local themes = include("radio/client/cl_themes.lua") or {}
local keyCodeMapping = include("radio/client/cl_key_names.lua")
local utils = include("radio/shared/sh_utils.lua")
BoomboxStatuses = BoomboxStatuses or {}
local favoriteCountries = {}
local favoriteStations = {}
local dataDir = "rradio"
local favoriteCountriesFile = dataDir .. "/favorite_countries.json"
local favoriteStationsFile = dataDir .. "/favorite_stations.json"
if not file.IsDir(dataDir, "DATA") then
file.CreateDir(dataDir)
end
local currentFrame = nil
local settingsMenuOpen = false
local entityVolumes = {}
local openRadioMenu
local lastIconUpdate = 0
local iconUpdateDelay = 0.1
local pendingIconUpdate = nil
local isUpdatingIcon = false
local isMessageAnimating = false
local lastKeyPress = 0
local keyPressDelay = 0.2
local favoritesMenuOpen = false
local VOLUME_ICONS = {
MUTE = Material("hud/vol_mute.png", "smooth"),
LOW = Material("hud/vol_down.png", "smooth"),
HIGH = Material("hud/vol_up.png", "smooth")
}
local lastPermissionMessage = 0
local PERMISSION_MESSAGE_COOLDOWN = 3
local MAX_CLIENT_STATIONS = 10
local activeStationCount = 0
local function updateStationCount()
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
currentRadioSources = currentRadioSources or {}
local function LerpColor(t, col1, col2)
return Color(
Lerp(t, col1.r, col2.r),
Lerp(t, col1.g, col2.g),
Lerp(t, col1.b, col2.b),
Lerp(t, col1.a or 255, col2.a or 255)
)
end
local function reopenRadioMenu(openSettingsMenuFlag)
if openRadioMenu then
if IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
timer.Simple(0.1, function()
openRadioMenu(openSettingsMenuFlag)
end)
end
else
print("Error: openRadioMenu function not found")
end
end
local function ClampVolume(volume)
local maxVolume = Config.MaxVolume()
return math.Clamp(volume, 0, maxVolume)
end
local function loadFavorites()
if file.Exists(favoriteCountriesFile, "DATA") then
local success, data = pcall(function()
return util.JSONToTable(file.Read(favoriteCountriesFile, "DATA"))
end)
if success and data then
favoriteCountries = {}
for _, country in ipairs(data) do
if type(country) == "string" then
favoriteCountries[country] = true
end
end
else
print("[Radio] Error loading favorite countries, resetting file")
favoriteCountries = {}
saveFavorites()
end
end
if file.Exists(favoriteStationsFile, "DATA") then
local success, data = pcall(function()
return util.JSONToTable(file.Read(favoriteStationsFile, "DATA"))
end)
if success and data then
favoriteStations = {}
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
print("[Radio] Error loading favorite stations, resetting file")
favoriteStations = {}
saveFavorites()
end
end
end
local function saveFavorites()
local favCountriesList = {}
for country, _ in pairs(favoriteCountries) do
if type(country) == "string" then
table.insert(favCountriesList, country)
end
end
local countriesJson = util.TableToJSON(favCountriesList, true)
if countriesJson then
if file.Exists(favoriteCountriesFile, "DATA") then
file.Write(favoriteCountriesFile .. ".bak", file.Read(favoriteCountriesFile, "DATA"))
end
file.Write(favoriteCountriesFile, countriesJson)
else
print("[Radio] Error converting favorite countries to JSON")
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
if file.Exists(favoriteStationsFile, "DATA") then
file.Write(favoriteStationsFile .. ".bak", file.Read(favoriteStationsFile, "DATA"))
end
file.Write(favoriteStationsFile, stationsJson)
else
print("[Radio] Error converting favorite stations to JSON")
end
end
local function createFonts()
surface.CreateFont("Roboto18", {
font = "Roboto",
size = ScreenScale(5),
weight = 500,
})
surface.CreateFont("HeaderFont", {
font = "Roboto",
size = ScreenScale(8),
weight = 700,
})
end
createFonts()
local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil
local currentRadioSources = {}
local lastMessageTime = -math.huge
local lastStationSelectTime = 0
local currentlyPlayingStations = {}
local settingsMenuOpen = false
local formattedCountryNames = {}
local stationDataLoaded = false
local isSearching = false
local function GetVehicleEntity(entity)
if IsValid(entity) and entity:IsVehicle() then
local parent = entity:GetParent()
return IsValid(parent) and parent or entity
end
return entity
end
local function Scale(value)
return value * (ScrW() / 2560)
end
local function getEntityConfig(entity)
return utils.GetEntityConfig(entity)
end
local function formatCountryName(name)
local lang = GetConVar("radio_language"):GetString() or "en"
local cacheKey = name .. "_" .. lang
if formattedCountryNames[cacheKey] then
return formattedCountryNames[cacheKey]
end
local translatedName = LanguageManager:GetCountryTranslation(lang, name)
formattedCountryNames[cacheKey] = translatedName
return translatedName
end
local function updateRadioVolume(station, distanceSqr, isPlayerInCar, entity)
local entityConfig = getEntityConfig(entity)
if not entityConfig then return end
local userVolume = ClampVolume(entity:GetNWFloat("Volume", entityConfig.Volume()))
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
local finalVolume = Config.CalculateVolume(entity, LocalPlayer(), distanceSqr)
station:SetVolume(finalVolume)
end
local function PrintCarRadioMessage()
if not GetConVar("car_radio_show_messages"):GetBool() then return end
local currentTime = CurTime()
local cooldownTime = Config.MessageCooldown()
if isMessageAnimating or (lastMessageTime and currentTime - lastMessageTime < cooldownTime) then
return
end
lastMessageTime = currentTime
isMessageAnimating = true
local openKey = GetConVar("car_radio_open_key"):GetInt()
local keyName = GetKeyName(openKey)
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
local bgColor = Config.UI.HeaderColor
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
local keyY = h/2 - keyHeight/2
local pulseScale = 1 + math.sin(pulseValue * math.pi * 2) * 0.05
local adjustedKeyWidth = keyWidth * pulseScale
local adjustedKeyHeight = keyHeight * pulseScale
local adjustedKeyX = keyX - (adjustedKeyWidth - keyWidth) / 2
local adjustedKeyY = keyY - (adjustedKeyHeight - keyHeight) / 2
draw.RoundedBox(6, adjustedKeyX, adjustedKeyY, adjustedKeyWidth, adjustedKeyHeight,
ColorAlpha(Config.UI.ButtonColor, alpha * 255))
surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, alpha * 50))
surface.DrawLine(keyX + keyWidth + Scale(7), h * 0.3,
keyX + keyWidth + Scale(7), h * 0.7)
draw.SimpleText(keyName, "Roboto18", keyX + keyWidth/2, h/2,
ColorAlpha(Config.UI.TextColor, alpha * 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
local messageX = keyX + keyWidth + Scale(15)
draw.SimpleText(Config.Lang["ToOpenRadio"] or "to open radio", "Roboto18",
messageX, h/2, ColorAlpha(Config.UI.TextColor, alpha * 255),
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
local function calculateFontSizeForStopButton(text, buttonWidth, buttonHeight)
local maxFontSize = buttonHeight * 0.7
local fontName = "DynamicStopButtonFont"
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
return fontName
end
local function createStarIcon(parent, country, station, updateList)
local starIcon = vgui.Create("DImageButton", parent)
starIcon:SetSize(Scale(24), Scale(24))
starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
local isFavorite = station and
(favoriteStations[country] and favoriteStations[country][station.name]) or
(not station and favoriteCountries[country])
starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
starIcon.DoClick = function()
if station then
if not favoriteStations[country] then
favoriteStations[country] = {}
end
if favoriteStations[country][station.name] then
favoriteStations[country][station.name] = nil
if next(favoriteStations[country]) == nil then
favoriteStations[country] = nil
end
else
favoriteStations[country][station.name] = true
end
else
if favoriteCountries[country] then
favoriteCountries[country] = nil
else
favoriteCountries[country] = true
end
end
saveFavorites()
local newIsFavorite = station and
(favoriteStations[country] and favoriteStations[country][station.name]) or
(not station and favoriteCountries[country])
starIcon:SetImage(newIsFavorite and "hud/star_full.png" or "hud/star.png")
if updateList then
updateList()
end
end
return starIcon
end
local StationData = {}
local function LoadStationData()
if stationDataLoaded then return end
StationData = {}
local dataFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
for _, filename in ipairs(dataFiles) do
local data = include("radio/client/stations/" .. filename)
for country, stations in pairs(data) do
local baseCountry = country:gsub("_(%d+)$", "")
if not StationData[baseCountry] then
StationData[baseCountry] = {}
end
for _, station in ipairs(stations) do
table.insert(StationData[baseCountry], { name = station.n, url = station.u })
end
end
end
stationDataLoaded = true
end
LoadStationData()
local function populateList(stationListPanel, backButton, searchBox, resetSearch)
if not stationListPanel then
return
end
stationListPanel:Clear()
if resetSearch then
searchBox:SetText("")
end
local filterText = searchBox:GetText():lower()
local lang = GetConVar("radio_language"):GetString() or "en"
local function updateList()
populateList(stationListPanel, backButton, searchBox, false)
end
if selectedCountry == nil then
local hasFavorites = false
for country, stations in pairs(favoriteStations) do
for stationName, isFavorite in pairs(stations) do
if isFavorite then
hasFavorites = true
break
end
end
if hasFavorites then break end
end
if hasFavorites then
local topSeparator = vgui.Create("DPanel", stationListPanel)
topSeparator:Dock(TOP)
topSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
topSeparator:SetTall(Scale(2))
topSeparator.Paint = function(self, w, h)
draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonColor)
end
local favoritesButton = vgui.Create("DButton", stationListPanel)
favoritesButton:Dock(TOP)
favoritesButton:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
favoritesButton:SetTall(Scale(40))
favoritesButton:SetText(Config.Lang["FavoriteStations"] or "Favorite Stations")
favoritesButton:SetFont("Roboto18")
favoritesButton:SetTextColor(Config.UI.TextColor)
favoritesButton.Paint = function(self, w, h)
local bgColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.ButtonColor
draw.RoundedBox(8, 0, 0, w, h, bgColor)
surface.SetMaterial(Material("hud/star_full.png"))
surface.SetDrawColor(Config.UI.TextColor)
surface.DrawTexturedRect(Scale(10), h/2 - Scale(12), Scale(24), Scale(24))
end
favoritesButton.DoClick = function()
surface.PlaySound("buttons/button3.wav")
selectedCountry = "favorites"
favoritesMenuOpen = true
if backButton then
backButton:SetVisible(true)
backButton:SetEnabled(true)
end
populateList(stationListPanel, backButton, searchBox, true)
end
local bottomSeparator = vgui.Create("DPanel", stationListPanel)
bottomSeparator:Dock(TOP)
bottomSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
bottomSeparator:SetTall(Scale(2))
bottomSeparator.Paint = function(self, w, h)
draw.RoundedBox(0, 0, 0, w, h, Config.UI.ButtonColor)
end
end
local countries = {}
for country, _ in pairs(StationData) do
local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
return first:upper() .. rest:lower()
end)
local translatedCountry = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry
if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
table.insert(countries, {
original = country,
translated = translatedCountry,
isPrioritized = favoriteCountries[country]
})
end
end
table.sort(countries, function(a, b)
if a.isPrioritized ~= b.isPrioritized then
return a.isPrioritized
end
return a.translated < b.translated
end)
for _, country in ipairs(countries) do
local countryButton = vgui.Create("DButton", stationListPanel)
countryButton:Dock(TOP)
countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
countryButton:SetTall(Scale(40))
countryButton:SetText(country.translated)
countryButton:SetFont("Roboto18")
countryButton:SetTextColor(Config.UI.TextColor)
countryButton.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
if self:IsHovered() then
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
end
end
createStarIcon(countryButton, country.original, nil, updateList)
countryButton.DoClick = function()
surface.PlaySound("buttons/button3.wav")
selectedCountry = country.original
if backButton then backButton:SetVisible(true) end
populateList(stationListPanel, backButton, searchBox, true)
end
end
if backButton then
backButton:SetVisible(false)
backButton:SetEnabled(false)
end
elseif selectedCountry == "favorites" then
local favoritesList = {}
for country, stations in pairs(favoriteStations) do
if StationData[country] then
for _, station in ipairs(StationData[country]) do
if stations[station.name] and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
local formattedCountry = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
return first:upper() .. rest:lower()
end)
local translatedName = LanguageManager:GetCountryTranslation(lang, formattedCountry) or formattedCountry
table.insert(favoritesList, {
station = station,
country = country,
countryName = translatedName
})
end
end
end
end
table.sort(favoritesList, function(a, b)
if a.countryName == b.countryName then
return a.station.name < b.station.name
end
return a.countryName < b.countryName
end)
for _, favorite in ipairs(favoritesList) do
local stationButton = vgui.Create("DButton", stationListPanel)
stationButton:Dock(TOP)
stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
stationButton:SetTall(Scale(40))
stationButton:SetText(favorite.countryName .. " - " .. favorite.station.name)
stationButton:SetFont("Roboto18")
stationButton:SetTextColor(Config.UI.TextColor)
stationButton.Paint = function(self, w, h)
local entity = LocalPlayer().currentRadioEntity
if IsValid(entity) and currentlyPlayingStations[entity] and
currentlyPlayingStations[entity].name == favorite.station.name then
draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
else
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
if self:IsHovered() then
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
end
end
end
createStarIcon(stationButton, favorite.country, favorite.station, updateList)
stationButton.DoClick = function()
local currentTime = CurTime()
if currentTime - lastStationSelectTime < 2 then
return
end
surface.PlaySound("buttons/button17.wav")
local entity = LocalPlayer().currentRadioEntity
if not IsValid(entity) then
return
end
if currentlyPlayingStations[entity] then
net.Start("StopCarRadioStation")
net.WriteEntity(entity)
net.SendToServer()
end
local entityConfig = getEntityConfig(entity)
local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
timer.Simple(0, function()
if not IsValid(entity) then return end
net.Start("PlayCarRadioStation")
net.WriteEntity(entity)
net.WriteString(favorite.station.name)
net.WriteString(favorite.station.url)
net.WriteFloat(volume)
net.SendToServer()
currentlyPlayingStations[entity] = favorite.station
lastStationSelectTime = currentTime
populateList(stationListPanel, backButton, searchBox, false)
end)
end
end
else
local stations = StationData[selectedCountry] or {}
local favoriteStationsList = {}
for _, station in ipairs(stations) do
if station and station.name and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
local isFavorite = favoriteStations[selectedCountry] and favoriteStations[selectedCountry][station.name]
table.insert(favoriteStationsList, { station = station, favorite = isFavorite })
end
end
table.sort(favoriteStationsList, function(a, b)
if a.favorite ~= b.favorite then
return a.favorite
end
return (a.station.name or "") < (b.station.name or "")
end)
for _, stationData in ipairs(favoriteStationsList) do
local station = stationData.station
local stationButton = vgui.Create("DButton", stationListPanel)
stationButton:Dock(TOP)
stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
stationButton:SetTall(Scale(40))
stationButton:SetText(station.name)
stationButton:SetFont("Roboto18")
stationButton:SetTextColor(Config.UI.TextColor)
stationButton.Paint = function(self, w, h)
local entity = LocalPlayer().currentRadioEntity
if IsValid(entity) and station == currentlyPlayingStations[entity] then
draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
else
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
if self:IsHovered() then
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
end
end
end
createStarIcon(stationButton, selectedCountry, station, updateList)
stationButton.DoClick = function()
local currentTime = CurTime()
if currentTime - lastStationSelectTime < 2 then
return
end
surface.PlaySound("buttons/button17.wav")
local entity = LocalPlayer().currentRadioEntity
if not IsValid(entity) then
return
end
if currentlyPlayingStations[entity] then
net.Start("StopCarRadioStation")
net.WriteEntity(entity)
net.SendToServer()
end
local entityConfig = getEntityConfig(entity)
local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
timer.Simple(0, function()
if not IsValid(entity) then return end
net.Start("PlayCarRadioStation")
net.WriteEntity(entity)
net.WriteString(station.name)
net.WriteString(station.url)
net.WriteFloat(volume)
net.SendToServer()
currentlyPlayingStations[entity] = station
lastStationSelectTime = currentTime
populateList(stationListPanel, backButton, searchBox, false)
end)
end
end
if backButton then
backButton:SetVisible(true)
backButton:SetEnabled(true)
end
end
end
local function openSettingsMenu(parentFrame, backButton)
settingsFrame = vgui.Create("DPanel", parentFrame)
settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50) - Scale(10))
settingsFrame:SetPos(Scale(10), Scale(50))
settingsFrame.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
end
local scrollPanel = vgui.Create("DScrollPanel", settingsFrame)
scrollPanel:Dock(FILL)
scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
local function addHeader(text, isFirst)
local header = vgui.Create("DLabel", scrollPanel)
header:SetText(text)
header:SetFont("Roboto18")
header:SetTextColor(Config.UI.TextColor)
header:Dock(TOP)
if isFirst then
header:DockMargin(0, Scale(5), 0, Scale(0))
else
header:DockMargin(0, Scale(10), 0, Scale(5))
end
header:SetContentAlignment(4)
end
local function addDropdown(text, choices, currentValue, onSelect)
local container = vgui.Create("DPanel", scrollPanel)
container:Dock(TOP)
container:SetTall(Scale(50))
container:DockMargin(0, 0, 0, Scale(5))
container.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
end
local label = vgui.Create("DLabel", container)
label:SetText(text)
label:SetFont("Roboto18")
label:SetTextColor(Config.UI.TextColor)
label:Dock(LEFT)
label:DockMargin(Scale(10), 0, 0, 0)
label:SetContentAlignment(4)
label:SizeToContents()
local dropdown = vgui.Create("DComboBox", container)
dropdown:Dock(RIGHT)
dropdown:SetWide(Scale(150))
dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
dropdown:SetValue(currentValue)
dropdown:SetTextColor(Config.UI.TextColor)
dropdown:SetFont("Roboto18")
dropdown.Paint = function(self, w, h)
draw.RoundedBox(6, 0, 0, w, h, Config.UI.SearchBoxColor)
self:DrawTextEntryText(Config.UI.TextColor, Config.UI.ButtonHoverColor, Config.UI.TextColor)
end
for _, choice in ipairs(choices) do
dropdown:AddChoice(choice.name, choice.data)
end
dropdown.OnSelect = onSelect
return dropdown
end
local function addCheckbox(text, convar)
local container = vgui.Create("DPanel", scrollPanel)
container:Dock(TOP)
container:SetTall(Scale(40))
container:DockMargin(0, 0, 0, Scale(5))
container.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
end
local checkbox = vgui.Create("DCheckBox", container)
checkbox:SetPos(Scale(10), (container:GetTall() - Scale(20)) / 2)
checkbox:SetSize(Scale(20), Scale(20))
checkbox:SetConVar(convar)
checkbox.Paint = function(self, w, h)
draw.RoundedBox(4, 0, 0, w, h, Config.UI.SearchBoxColor)
if self:GetChecked() then
surface.SetDrawColor(Config.UI.TextColor)
surface.DrawRect(Scale(4), Scale(4), w - Scale(8), h - Scale(8))
end
end
local label = vgui.Create("DLabel", container)
label:SetText(text)
label:SetTextColor(Config.UI.TextColor)
label:SetFont("Roboto18")
label:SizeToContents()
label:SetPos(Scale(40), (container:GetTall() - label:GetTall()) / 2)
checkbox.OnChange = function(self, value)
RunConsoleCommand(convar, value and "1" or "0")
end
return checkbox
end
addHeader(Config.Lang["ThemeSelection"] or "Theme Selection", true)
local themeChoices = {}
if themes then
for themeName, _ in pairs(themes) do
table.insert(themeChoices, {name = themeName:gsub("^%l", string.upper), data = themeName})
end
end
local currentTheme = GetConVar("radio_theme"):GetString()
local currentThemeName = currentTheme:gsub("^%l", string.upper)
addDropdown(Config.Lang["SelectTheme"] or "Select Theme", themeChoices, currentThemeName, function(_, _, value)
local lowerValue = value:lower()
if themes and themes[lowerValue] then
RunConsoleCommand("radio_theme", lowerValue)
Config.UI = themes[lowerValue]
parentFrame:Close()
reopenRadioMenu(true)
end
end)
addHeader(Config.Lang["LanguageSelection"] or "Language Selection")
local languageChoices = {}
for code, name in pairs(LanguageManager:GetAvailableLanguages()) do
table.insert(languageChoices, {name = name, data = code})
end
local currentLanguage = GetConVar("radio_language"):GetString()
local currentLanguageName = LanguageManager:GetLanguageName(currentLanguage)
addDropdown(Config.Lang["SelectLanguage"] or "Select Language", languageChoices, currentLanguageName, function(_, _, _, data)
RunConsoleCommand("radio_language", data)
LanguageManager:SetLanguage(data)
Config.Lang = LanguageManager.translations[data]
formattedCountryNames = {}
stationDataLoaded = false
LoadStationData()
if IsValid(currentFrame) then
currentFrame:Close()
timer.Simple(0.1, function()
if openRadioMenu then
radioMenuOpen = false
selectedCountry = nil
settingsMenuOpen = false
favoritesMenuOpen = false
openRadioMenu(true)
end
end)
end
end)
addHeader(Config.Lang["SelectKeyToOpenRadioMenu"] or "Select Key to Open Radio Menu")
local keyChoices = {}
if keyCodeMapping then
for keyCode, keyName in pairs(keyCodeMapping) do
table.insert(keyChoices, {name = keyName, data = keyCode})
end
table.sort(keyChoices, function(a, b) return a.name < b.name end)
else
table.insert(keyChoices, {name = "K", data = KEY_K})
end
local currentKey = GetConVar("car_radio_open_key"):GetInt()
local currentKeyName = (keyCodeMapping and keyCodeMapping[currentKey]) or "K"
addDropdown(Config.Lang["SelectKey"] or "Select Key", keyChoices, currentKeyName, function(_, _, _, data)
RunConsoleCommand("car_radio_open_key", data)
end)
addHeader(Config.Lang["GeneralOptions"] or "General Options")
addCheckbox(Config.Lang["ShowCarMessages"] or "Show Car Radio Messages", "car_radio_show_messages")
addCheckbox(Config.Lang["ShowBoomboxHUD"] or "Show Boombox Hover Text", "boombox_show_text")
if LocalPlayer():IsSuperAdmin() then
local currentEntity = LocalPlayer().currentRadioEntity
local isBoombox = IsValid(currentEntity) and (currentEntity:GetClass() == "boombox" or currentEntity:GetClass() == "golden_boombox")
if isBoombox then
addHeader(Config.Lang["SuperadminSettings"] or "Superadmin Settings")
local permanentCheckbox = addCheckbox(Config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent", "")
permanentCheckbox:SetChecked(currentEntity:GetNWBool("IsPermanent", false))
permanentCheckbox.OnChange = function(self, value)
if not IsValid(currentEntity) then
self:SetChecked(false)
return
end
if value then
net.Start("MakeBoomboxPermanent")
net.WriteEntity(currentEntity)
net.SendToServer()
else
net.Start("RemoveBoomboxPermanent")
net.WriteEntity(currentEntity)
net.SendToServer()
end
end
net.Receive("BoomboxPermanentConfirmation", function()
local message = net.ReadString()
chat.AddText(Color(0, 255, 0), "[Boombox] ", Color(255, 255, 255), message)
if string.find(message, "marked as permanent") then
permanentCheckbox:SetChecked(true)
elseif string.find(message, "permanence has been removed") then
permanentCheckbox:SetChecked(false)
end
end)
end
end
local footerHeight = Scale(60)
local footer = vgui.Create("DButton", settingsFrame)
footer:SetSize(settingsFrame:GetWide(), footerHeight)
footer:SetPos(0, settingsFrame:GetTall() - footerHeight)
footer:SetText("")
footer.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Config.UI.BackgroundColor or Config.UI.BackgroundColor)
end
footer.DoClick = function()
gui.OpenURL("https://github.com/charles-mills/rRadio")
end
local githubIcon = vgui.Create("DImage", footer)
githubIcon:SetSize(Scale(32), Scale(32))
githubIcon:SetPos(Scale(10), (footerHeight - Scale(32)) / 2)
githubIcon:SetImage("hud/github.png")
githubIcon.Paint = function(self, w, h)
surface.SetDrawColor(Config.UI.TextColor)
surface.SetMaterial(Material("hud/github.png"))
surface.DrawTexturedRect(0, 0, w, h)
end
local contributeTitleLabel = vgui.Create("DLabel", footer)
contributeTitleLabel:SetText(Config.Lang["Contribute"] or "Want to contribute?")
contributeTitleLabel:SetFont("Roboto18")
contributeTitleLabel:SetTextColor(Config.UI.TextColor)
contributeTitleLabel:SizeToContents()
contributeTitleLabel:SetPos(Scale(50), footerHeight / 2 - contributeTitleLabel:GetTall() + Scale(2))
local contributeSubLabel = vgui.Create("DLabel", footer)
contributeSubLabel:SetText(Config.Lang["SubmitPullRequest"] or "Submit a pull request :)")
contributeSubLabel:SetFont("Roboto18")
contributeSubLabel:SetTextColor(Config.UI.TextColor)
contributeSubLabel:SizeToContents()
contributeSubLabel:SetPos(Scale(50), footerHeight / 2 + Scale(2))
end
openRadioMenu = function(openSettings)
if radioMenuOpen then return end
local ply = LocalPlayer()
local entity = ply.currentRadioEntity
if not IsValid(entity) then return end
if not utils.canUseRadio(entity) then
chat.AddText(Color(255, 0, 0), "[Radio] This seat cannot use the radio.")
return
end
if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
if not utils.canInteractWithBoombox(ply, entity) then
chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
return
end
end
radioMenuOpen = true
local backButton
local frame = vgui.Create("DFrame")
currentFrame = frame
frame:SetTitle("")
frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
frame:Center()
frame:SetDraggable(false)
frame:ShowCloseButton(false)
frame:MakePopup()
frame.OnClose = function()
radioMenuOpen = false
end
frame.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
draw.RoundedBoxEx(8, 0, 0, w, Scale(40), Config.UI.HeaderColor, true, true, false, false)
local headerHeight = Scale(40)
local iconSize = Scale(25)
local iconOffsetX = Scale(10)
local iconOffsetY = headerHeight/2 - iconSize/2
surface.SetMaterial(Material("hud/radio.png"))
surface.SetDrawColor(Config.UI.TextColor)
surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
local headerText
if settingsMenuOpen then
headerText = Config.Lang["Settings"] or "Settings"
elseif selectedCountry then
if selectedCountry == "favorites" then
headerText = Config.Lang["FavoriteStations"] or "Favorite Stations"
else
local formattedCountry = selectedCountry:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b)
return string.upper(a) .. string.lower(b)
end)
local lang = GetConVar("radio_language"):GetString() or "en"
headerText = LanguageManager:GetCountryTranslation(lang, formattedCountry)
end
else
headerText = Config.Lang["SelectCountry"] or "Select Country"
end
draw.SimpleText(headerText, "HeaderFont", iconOffsetX + iconSize + Scale(5),
headerHeight/2, Config.UI.TextColor,
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end
local searchBox = vgui.Create("DTextEntry", frame)
searchBox:SetPos(Scale(10), Scale(50))
searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
searchBox:SetFont("Roboto18")
searchBox:SetPlaceholderText(Config.Lang and Config.Lang["SearchPlaceholder"] or "Search")
searchBox:SetTextColor(Config.UI.TextColor)
searchBox:SetDrawBackground(false)
searchBox.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)
if self:GetText() == "" then
draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end
end
searchBox:SetVisible(not settingsMenuOpen)
searchBox.OnGetFocus = function()
isSearching = true
end
searchBox.OnLoseFocus = function()
isSearching = false
end
local stationListPanel = vgui.Create("DScrollPanel", frame)
stationListPanel:SetPos(Scale(5), Scale(90))
stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(200))
stationListPanel:SetVisible(not settingsMenuOpen)
local stopButtonHeight = Scale(Config.UI.FrameSize.width) / 8
local stopButtonWidth = Scale(Config.UI.FrameSize.width) / 4
local stopButtonText = Config.Lang["StopRadio"] or "STOP"
local stopButtonFont = calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)
local function createAnimatedButton(parent, x, y, w, h, text, textColor, bgColor, hoverColor, clickFunc)
local button = vgui.Create("DButton", parent)
button:SetPos(x, y)
button:SetSize(w, h)
button:SetText(text)
button:SetTextColor(textColor)
button.bgColor = bgColor
button.hoverColor = hoverColor
button.lerp = 0
button.Paint = function(self, w, h)
local color = LerpColor(self.lerp, self.bgColor, self.hoverColor)
draw.RoundedBox(8, 0, 0, w, h, color)
end
button.Think = function(self)
if self:IsHovered() then
self.lerp = math.Approach(self.lerp, 1, FrameTime() * 5)
else
self.lerp = math.Approach(self.lerp, 0, FrameTime() * 5)
end
end
button.DoClick = clickFunc
return button
end
local stopButton = createAnimatedButton(
frame,
Scale(10),
Scale(Config.UI.FrameSize.height) - Scale(90),
stopButtonWidth,
stopButtonHeight,
stopButtonText,
Config.UI.TextColor,
Config.UI.CloseButtonColor,
Config.UI.CloseButtonHoverColor,
function()
surface.PlaySound("buttons/button6.wav")
local entity = LocalPlayer().currentRadioEntity
if IsValid(entity) then
net.Start("StopCarRadioStation")
net.WriteEntity(entity)
net.SendToServer()
currentlyPlayingStation = nil
currentlyPlayingStations[entity] = nil
populateList(stationListPanel, backButton, searchBox, false)
if backButton then
backButton:SetVisible(selectedCountry ~= nil or settingsMenuOpen)
backButton:SetEnabled(selectedCountry ~= nil or settingsMenuOpen)
end
end
end
)
stopButton:SetFont(stopButtonFont)
local volumePanel = vgui.Create("DPanel", frame)
volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(Config.UI.FrameSize.height) - Scale(90))
volumePanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
volumePanel.Paint = function(self, w, h)
draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
end
local volumeIconSize = Scale(50)
local volumeIcon = vgui.Create("DImage", volumePanel)
volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
volumeIcon:SetSize(volumeIconSize, volumeIconSize)
volumeIcon:SetMaterial(VOLUME_ICONS.HIGH)
local function updateVolumeIcon(volumeIcon, value)
if not IsValid(volumeIcon) then return end
local iconMat
if type(value) == "function" then
value = value()
end
if value < 0.01 then
iconMat = VOLUME_ICONS.MUTE
elseif value <= 0.65 then
iconMat = VOLUME_ICONS.LOW
else
iconMat = VOLUME_ICONS.HIGH
end
if iconMat then
volumeIcon:SetMaterial(iconMat)
end
end
volumeIcon.Paint = function(self, w, h)
surface.SetDrawColor(Config.UI.TextColor)
local mat = self:GetMaterial()
if mat then
surface.SetMaterial(mat)
surface.DrawTexturedRect(0, 0, w, h)
end
end
local entity = LocalPlayer().currentRadioEntity
local currentVolume = 0.5
if IsValid(entity) then
if entityVolumes[entity] then
currentVolume = entityVolumes[entity]
else
local entityConfig = getEntityConfig(entity)
if entityConfig and entityConfig.Volume then
currentVolume = type(entityConfig.Volume) == "function"
and entityConfig.Volume()
or entityConfig.Volume
end
end
currentVolume = math.min(currentVolume, Config.MaxVolume())
end
updateVolumeIcon(volumeIcon, currentVolume)
local volumeSlider = vgui.Create("DNumSlider", volumePanel)
volumeSlider:SetPos(-Scale(170), Scale(5))
volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) + Scale(120) - stopButtonWidth, volumePanel:GetTall() - Scale(20))
volumeSlider:SetText("")
volumeSlider:SetMin(0)
volumeSlider:SetMax(Config.MaxVolume())
volumeSlider:SetDecimals(2)
volumeSlider:SetValue(currentVolume)
volumeSlider.Slider.Paint = function(self, w, h)
draw.RoundedBox(8, 0, h / 2 - 4, w, 16, Config.UI.TextColor)
end
volumeSlider.Slider.Knob.Paint = function(self, w, h)
draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, Config.UI.BackgroundColor)
end
volumeSlider.TextArea:SetVisible(false)
local lastServerUpdate = 0
volumeSlider.OnValueChanged = function(_, value)
local entity = LocalPlayer().currentRadioEntity
if not IsValid(entity) then return end
entity = utils.GetVehicle(entity) or entity
value = math.min(value, Config.MaxVolume())
entityVolumes[entity] = value
if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
currentRadioSources[entity]:SetVolume(value)
end
updateVolumeIcon(volumeIcon, value)
local currentTime = CurTime()
if currentTime - lastServerUpdate >= 0.1 then
lastServerUpdate = currentTime
net.Start("UpdateRadioVolume")
net.WriteEntity(entity)
net.WriteFloat(value)
net.SendToServer()
end
end
local sbar = stationListPanel:GetVBar()
sbar:SetWide(Scale(8))
function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end
local buttonSize = Scale(25)
local topMargin = Scale(7)
local buttonPadding = Scale(5)
local closeButton = createAnimatedButton(
frame,
frame:GetWide() - buttonSize - Scale(10),
topMargin,
buttonSize,
buttonSize,
"",
Config.UI.TextColor,
Color(0, 0, 0, 0),
Config.UI.ButtonHoverColor,
function()
surface.PlaySound("buttons/lightswitch2.wav")
frame:Close()
end
)
closeButton.Paint = function(self, w, h)
surface.SetMaterial(Material("hud/close.png"))
surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
surface.DrawTexturedRect(0, 0, w, h)
end
local settingsButton = createAnimatedButton(
frame,
closeButton:GetX() - buttonSize - buttonPadding,
topMargin,
buttonSize,
buttonSize,
"",
Config.UI.TextColor,
Color(0, 0, 0, 0),
Config.UI.ButtonHoverColor,
function()
surface.PlaySound("buttons/lightswitch2.wav")
settingsMenuOpen = true
openSettingsMenu(currentFrame, backButton)
backButton:SetVisible(true)
backButton:SetEnabled(true)
searchBox:SetVisible(false)
stationListPanel:SetVisible(false)
end
)
settingsButton.Paint = function(self, w, h)
surface.SetMaterial(Material("hud/settings.png"))
surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
surface.DrawTexturedRect(0, 0, w, h)
end
backButton = createAnimatedButton(
frame,
settingsButton:GetX() - buttonSize - buttonPadding,
topMargin,
buttonSize,
buttonSize,
"",
Config.UI.TextColor,
Color(0, 0, 0, 0),
Config.UI.ButtonHoverColor,
function()
surface.PlaySound("buttons/lightswitch2.wav")
if settingsMenuOpen then
settingsMenuOpen = false
if IsValid(settingsFrame) then
settingsFrame:Remove()
settingsFrame = nil
end
searchBox:SetVisible(true)
stationListPanel:SetVisible(true)
stationDataLoaded = false
LoadStationData()
timer.Simple(0, function()
populateList(stationListPanel, backButton, searchBox, true)
end)
backButton:SetVisible(selectedCountry ~= nil or favoritesMenuOpen)
backButton:SetEnabled(selectedCountry ~= nil or favoritesMenuOpen)
elseif selectedCountry or favoritesMenuOpen then
selectedCountry = nil
favoritesMenuOpen = false
backButton:SetVisible(false)
backButton:SetEnabled(false)
populateList(stationListPanel, backButton, searchBox, true)
end
end
)
backButton.Paint = function(self, w, h)
if self:IsVisible() then
surface.SetMaterial(Material("hud/return.png"))
surface.SetDrawColor(ColorAlpha(Config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
surface.DrawTexturedRect(0, 0, w, h)
end
end
backButton:SetVisible((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
backButton:SetEnabled((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
if not settingsMenuOpen then
populateList(stationListPanel, backButton, searchBox, true)
else
openSettingsMenu(currentFrame, backButton)
end
searchBox.OnChange = function(self)
populateList(stationListPanel, backButton, searchBox, false)
end
_G.openRadioMenu = openRadioMenu
end
hook.Add("Think", "OpenCarRadioMenu", function()
local openKey = GetConVar("car_radio_open_key"):GetInt()
local ply = LocalPlayer()
local currentTime = CurTime()
if not (input.IsKeyDown(openKey) and not ply:IsTyping() and currentTime - lastKeyPress > keyPressDelay) then
return
end
lastKeyPress = currentTime
if radioMenuOpen and not isSearching then
surface.PlaySound("buttons/lightswitch2.wav")
currentFrame:Close()
radioMenuOpen = false
selectedCountry = nil
settingsMenuOpen = false
favoritesMenuOpen = false
return
end
local vehicle = ply:GetVehicle()
if IsValid(vehicle) and not utils.isSitAnywhereSeat(vehicle) then
ply.currentRadioEntity = vehicle
openRadioMenu()
end
end)
net.Receive("UpdateRadioStatus", function()
local entity = net.ReadEntity()
local stationName = net.ReadString()
local isPlaying = net.ReadBool()
local status = net.ReadString()
if IsValid(entity) then
BoomboxStatuses[entity:EntIndex()] = {
stationStatus = status,
stationName = stationName
}
entity:SetNWString("Status", status)
entity:SetNWString("StationName", stationName)
entity:SetNWBool("IsPlaying", isPlaying)
if status == "playing" then
currentlyPlayingStations[entity] = { name = stationName }
elseif status == "stopped" then
currentlyPlayingStations[entity] = nil
end
end
end)
net.Receive("PlayCarRadioStation", function()
local entity = net.ReadEntity()
entity = GetVehicleEntity(entity)
local stationName = net.ReadString()
local url = net.ReadString()
local volume = net.ReadFloat()
local currentCount = updateStationCount()
if not currentRadioSources[entity] and currentCount >= MAX_CLIENT_STATIONS then
return
end
if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
currentRadioSources[entity]:Stop()
currentRadioSources[entity] = nil
activeStationCount = math.max(0, activeStationCount - 1)
end
sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
if IsValid(station) and IsValid(entity) then
station:SetPos(entity:GetPos())
station:SetVolume(volume)
station:Play()
currentRadioSources[entity] = station
activeStationCount = updateStationCount()
local entityConfig = getEntityConfig(entity)
if entityConfig then
local minDist = entityConfig.MinVolumeDistance()
local maxDist = entityConfig.MaxHearingDistance()
station:Set3DFadeDistance(minDist, maxDist)
end
local hookName = "UpdateRadioPosition_" .. entity:EntIndex()
hook.Add("Think", hookName, function()
if not IsValid(entity) or not IsValid(station) then
hook.Remove("Think", hookName)
if IsValid(station) then
station:Stop()
end
currentRadioSources[entity] = nil
activeStationCount = updateStationCount()
return
end
local actualEntity = entity
if entity:IsVehicle() then
local parent = entity:GetParent()
if IsValid(parent) then
actualEntity = parent
end
end
station:SetPos(actualEntity:GetPos())
local playerPos = LocalPlayer():GetPos()
local entityPos = actualEntity:GetPos()
local distanceSqr = playerPos:DistToSqr(entityPos)
local isPlayerInCar = false
if actualEntity:IsVehicle() then
if LocalPlayer():GetVehicle() == entity then
isPlayerInCar = true
else
for _, seat in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
if IsValid(seat) and seat:GetParent() == actualEntity and seat:GetDriver() == LocalPlayer() then
isPlayerInCar = true
break
end
end
end
end
updateRadioVolume(station, distanceSqr, isPlayerInCar, actualEntity)
end)
else
if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
utils.clearRadioStatus(entity)
end
end
end)
end)
net.Receive("StopCarRadioStation", function()
local entity = net.ReadEntity()
if not IsValid(entity) then return end
entity = GetVehicleEntity(entity)
if currentRadioSources[entity] then
if IsValid(currentRadioSources[entity]) then
currentRadioSources[entity]:Stop()
end
currentRadioSources[entity] = nil
activeStationCount = updateStationCount()
end
if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
utils.clearRadioStatus(entity)
end
hook.Remove("Think", "UpdateRadioPosition_" .. entity:EntIndex())
end)
hook.Add("EntityRemoved", "CleanupRadioStationCount", function(entity)
if currentRadioSources[entity] then
if IsValid(currentRadioSources[entity]) then
currentRadioSources[entity]:Stop()
end
currentRadioSources[entity] = nil
activeStationCount = updateStationCount()
end
end)
timer.Create("ValidateStationCount", 30, 0, function()
updateStationCount()
end)
net.Receive("OpenRadioMenu", function()
local ent = net.ReadEntity()
if not IsValid(ent) then return end
local ply = LocalPlayer()
if ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox" then
if utils.canInteractWithBoombox(ply, ent) then
ply.currentRadioEntity = ent
if not radioMenuOpen then
openRadioMenu()
end
else
local currentTime = CurTime()
if currentTime - lastPermissionMessage >= PERMISSION_MESSAGE_COOLDOWN then
chat.AddText(Color(255, 0, 0), "You don't have permission to interact with this boombox.")
lastPermissionMessage = currentTime
end
end
end
end)
net.Receive("CarRadioMessage", function()
PrintCarRadioMessage()
end)
net.Receive("RadioConfigUpdate", function()
for entity, source in pairs(currentRadioSources) do
if IsValid(entity) and IsValid(source) then
local volume = ClampVolume(entityVolumes[entity] or getEntityConfig(entity).Volume())
source:SetVolume(volume)
end
end
end)
hook.Add("EntityRemoved", "CleanupRadioStationCount", function(entity)
if currentRadioSources[entity] then
if IsValid(currentRadioSources[entity]) then
currentRadioSources[entity]:Stop()
end
currentRadioSources[entity] = nil
activeStationCount = updateStationCount()
end
end)
timer.Create("ValidateStationCount", 30, 0, function()
local actualCount = 0
for ent, source in pairs(currentRadioSources) do
if IsValid(ent) and IsValid(source) then
actualCount = actualCount + 1
else
currentRadioSources[ent] = nil
end
end
activeStationCount = actualCount
end)
loadFavorites()
hook.Add("EntityRemoved", "BoomboxCleanup", function(ent)
if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
BoomboxStatuses[ent:EntIndex()] = nil
end
end)
hook.Add("VehicleChanged", "ClearRadioEntity", function(ply, old, new)
if ply ~= LocalPlayer() then return end
if not new then
ply.currentRadioEntity = nil
end
end)
hook.Add("EntityRemoved", "ClearRadioEntity", function(ent)
local ply = LocalPlayer()
if ent == ply.currentRadioEntity then
ply.currentRadioEntity = nil
end
end)