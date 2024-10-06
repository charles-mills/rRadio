--[[
    rRadio Addon for Garry's Mod - Friends Menu
    Description: Manages the friends list for boombox permissions.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

local PANEL = {}

-- Ensure Config and Config.Lang are initialized
Config = Config or {}
Config.Lang = Config.Lang or {}

-- Cache frequently used functions
local IsValid = IsValid
local pairs = pairs
local table_insert = table.insert
local table_remove = table.remove
local string_format = string.format

-- Localization
local function L(key, default)
    return Config.Lang[key] or default
end

-- Debounce function for search
local debounceTimer = nil
local function debounceSearch(func, delay)
    if debounceTimer then timer.Remove(debounceTimer) end
    debounceTimer = "FriendsMenuSearch_" .. tostring({}):sub(10)
    timer.Create(debounceTimer, delay, 1, func)
end

-- Improved error handling for file operations
local function safeFileWrite(filename, content)
    local success, err = pcall(function()
        file.Write(filename, content)
    end)
    if not success then
        utils.PrintError("Failed to write file: " .. filename .. ". Error: " .. tostring(err), 2)
    end
end

-- Enhanced UI creation with tooltips
local function createStyledButton(parent, text, x, y, w, h, tooltip)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(text)
    button:SetTextColor(Colors.Text)
    button:SetFont("FriendsMenu18")
    
    if tooltip then
        button:SetTooltip(tooltip)
    end
    
    function button:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Colors.ButtonHover or Colors.Button)
    end
    
    return button
end

-- Cache for authorized friends
local cachedFriends = nil
local lastCacheTime = 0
local CACHE_LIFETIME = 300 -- Cache lifetime in seconds (5 minutes)

-- Fixed color scheme
local Colors = {
    Background = Color(44, 62, 80),
    Header = Color(52, 73, 94),
    Text = Color(236, 240, 241),
    ButtonText = Color(255, 255, 255),
    Button = Color(41, 128, 185),
    ButtonHover = Color(52, 152, 219),
    ListBackground = Color(36, 50, 64),
    ListText = Color(236, 240, 241),  -- New color for list text
    ListHover = Color(52, 73, 94),
    TableHeader = Color(30, 45, 62),
    Remove = Color(192, 57, 43),
    RemoveHover = Color(231, 76, 60)
}

-- Utility function to create a styled button
local function CreateStyledButton(parent, text, x, y, w, h)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(text)
    button:SetTextColor(Colors.Text)
    button:SetFont("FriendsMenu18")
    
    function button:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Colors.ButtonHover or Colors.Button)
    end
    
    return button
end

include("misc/utils.lua")

-- Function to load authorized friends with caching
local function LoadAuthorizedFriends()
    local currentTime = SysTime()
    if cachedFriends and (currentTime - lastCacheTime) < CACHE_LIFETIME then
        return cachedFriends
    end

    local savedFriends = util.JSONToTable(file.Read("rradio_authorized_friends.txt", "DATA") or "[]")
    cachedFriends = savedFriends
    lastCacheTime = currentTime
    return savedFriends
end

-- Function to save authorized friends
local function SaveAuthorizedFriends(friends)
    local friendsJson = util.TableToJSON(friends)
    safeFileWrite("rradio_authorized_friends.txt", friendsJson)
    
    -- Update cache
    cachedFriends = friends
    lastCacheTime = SysTime()
    
    -- Send the updated list to the server
    net.Start("rRadio_UpdateAuthorizedFriends")
    net.WriteString(friendsJson)
    net.SendToServer()
    
    utils.DebugPrint("[rRadio] Sent updated friends list to server")
end

-- Save authorized friends to persistent storage
function PANEL:SaveAuthorizedFriends()
    local friends = {}
    for _, line in pairs(self.AuthorizedList:GetLines()) do
        table_insert(friends, {name = line:GetColumnText(1), steamid = line:GetColumnText(2)})
    end
    SaveAuthorizedFriends(friends)
end

-- Add a friend to the authorized list
function PANEL:AddFriendToList(name, steamid)
    local line = self.AuthorizedList:AddLine(name, steamid)
    line.Paint = function(self, w, h)
        if self:IsSelected() then
            draw.RoundedBox(0, 0, 0, w, h, Colors.ButtonHover)
        elseif self:IsHovered() then
            draw.RoundedBox(0, 0, 0, w, h, Colors.ListHover)
        end
    end

    -- Set text color for the new line
    for _, column in pairs(line.Columns) do
        column:SetTextColor(Colors.ListText)
    end

    self:SaveAuthorizedFriends()
end

-- Create fonts
surface.CreateFont("FriendsMenu18", {
    font = "Roboto",
    size = 18,
    weight = 500,
})

surface.CreateFont("FriendsMenu24", {
    font = "Roboto",
    size = 24,
    weight = 700,
})

-- Main panel initialization
function PANEL:Init()
    self:SetSize(700, 500)
    self:Center()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:MakePopup()

    self.AuthorizedList = vgui.Create("DListView", self)
    self.AuthorizedList:Dock(FILL)
    self.AuthorizedList:DockMargin(10, 50, 10, 50)
    self.AuthorizedList:SetMultiSelect(false)
    self.AuthorizedList:AddColumn(utils.L("Name", "Name")):SetWidth(350)
    self.AuthorizedList:AddColumn(utils.L("SteamID", "SteamID")):SetWidth(350)

    self.AuthorizedList.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Colors.ListBackground)
    end

    -- Style the table headers
    for _, column in pairs(self.AuthorizedList.Columns) do
        column.Header:SetTextColor(Colors.Text)
        column.Header:SetFont("FriendsMenu18")
        column.Header.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Colors.TableHeader)
            -- Left-align the header text
            draw.SimpleText(self:GetText(), "FriendsMenu18", 5, h/2, Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end
    end

    -- Set text color for list items
    self.AuthorizedList.OnRowAdded = function(_, _, line)
        for _, column in pairs(line.Columns) do
            column:SetTextColor(Colors.ListText)
        end
    end

    self.AuthorizedList.OnRowSelected = function(_, _, row)
        self.RemoveButton:SetEnabled(true)
    end

    -- Add Remove Friend button
    self.RemoveButton = CreateStyledButton(self, utils.L("RemoveFriend", "Remove Friend"), 10, self:GetTall() - 40, 120, 30)
    self.RemoveButton:SetEnabled(false)
    self.RemoveButton.DoClick = function()
        local selectedLine = self.AuthorizedList:GetSelectedLine()
        if selectedLine then
            self:RemoveFriend(selectedLine)
        end
    end

    self.AddButton = CreateStyledButton(self, utils.L("AddFriend", "Add Friend"), 140, self:GetTall() - 40, 120, 30)
    self.AddButton.DoClick = function()
        self:OpenPlayerSelector()
    end

    self.CloseButton = CreateStyledButton(self, utils.L("Close", "Close"), self:GetWide() - 130, self:GetTall() - 40, 120, 30)
    self.CloseButton.DoClick = function()
        self:Close()
    end

    self:LoadAuthorizedFriends()
end

-- Load authorized friends from persistent storage
function PANEL:LoadAuthorizedFriends()
    local savedFriends = LoadAuthorizedFriends()
    for _, friend in pairs(savedFriends) do
        self:AddFriendToList(friend.name, friend.steamid)
    end
end

-- Remove a friend from the list
function PANEL:RemoveFriend(lineID)
    self.AuthorizedList:RemoveLine(lineID)
    self:SaveAuthorizedFriends()
    self.RemoveButton:SetEnabled(false)
end

-- Open the player selector panel
function PANEL:OpenPlayerSelector()
    if IsValid(self.PlayerSelector) then
        self.PlayerSelector:Remove()
    end

    -- Create a background panel for blur and shadow
    local backgroundPanel = vgui.Create("DPanel")
    backgroundPanel:SetSize(ScrW(), ScrH())
    backgroundPanel:Center()
    backgroundPanel:MakePopup()
    backgroundPanel.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, 0)
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(0, 0, w, h)
    end

    self.PlayerSelector = vgui.Create("DFrame", backgroundPanel)
    self.PlayerSelector:SetSize(400, 500)
    self.PlayerSelector:SetTitle("")
    self.PlayerSelector:Center()
    self.PlayerSelector:MakePopup()
    self.PlayerSelector:ShowCloseButton(false)
    self.PlayerSelector:SetDraggable(true)

    self.PlayerSelector.Paint = function(self, w, h)
        -- Shadow
        local shadowSize = 5
        local shadowColor = Color(0, 0, 0, 100)
        for i = 1, shadowSize do
            draw.RoundedBox(8, -i, -i, w + i * 2, h + i * 2, shadowColor)
        end

        -- Main background
        draw.RoundedBox(8, 0, 0, w, h, Colors.Background)
        
        -- Header
        draw.RoundedBoxEx(8, 0, 0, w, 30, Colors.Header, true, true, false, false)
        
        -- Border
        surface.SetDrawColor(Colors.Button)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        -- Title (white text for sub-menu)
        draw.SimpleText(utils.L("SelectFriend", "Select a Friend"), "FriendsMenu24", 10, 15, Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local playerList = vgui.Create("DListView", self.PlayerSelector)
    playerList:Dock(FILL)
    playerList:DockMargin(10, 40, 10, 50)
    playerList:SetMultiSelect(false)
    playerList:AddColumn(utils.L("Name", "Name")):SetWidth(200)
    playerList:AddColumn(utils.L("SteamID", "SteamID")):SetWidth(200)

    -- Style the table headers for player list
    for _, column in pairs(playerList.Columns) do
        column.Header:SetTextColor(Colors.Text)
        column.Header:SetFont("FriendsMenu18")
        column.Header.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Colors.TableHeader)
            -- Left-align the header text
            draw.SimpleText(self:GetText(), "FriendsMenu18", 5, h/2, Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return true
        end
    end

    for _, ply in pairs(player.GetAll()) do
        if ply ~= LocalPlayer() then
            playerList:AddLine(ply:Nick(), ply:SteamID())
        end
    end

    playerList.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Colors.ListBackground)
    end

    -- Set text color for player list items
    playerList.OnRowAdded = function(_, _, line)
        for _, column in pairs(line.Columns) do
            column:SetTextColor(Colors.ListText)
        end
    end

    local addButton = CreateStyledButton(self.PlayerSelector, utils.L("AddSelectedFriend", "Add Selected Friend"), 10, self.PlayerSelector:GetTall() - 40, 180, 30)
    addButton:SetEnabled(false)

    playerList.OnRowSelected = function(_, _, row)
        addButton:SetEnabled(true)
    end

    addButton.DoClick = function()
        local selectedLine = playerList:GetSelectedLine()
        if selectedLine then
            local name = playerList:GetLine(selectedLine):GetColumnText(1)
            local steamid = playerList:GetLine(selectedLine):GetColumnText(2)
            self:AddFriendToList(name, steamid)
            backgroundPanel:Remove()  -- Remove both the selector and background
        end
    end

    local cancelButton = CreateStyledButton(self.PlayerSelector, utils.L("Cancel", "Cancel"), self.PlayerSelector:GetWide() - 130, self.PlayerSelector:GetTall() - 40, 120, 30)
    cancelButton.DoClick = function()
        backgroundPanel:Remove()  -- Remove both the selector and background
    end

    -- Apply custom paint to list rows
    for _, line in pairs(playerList:GetLines()) do
        line.Paint = function(self, w, h)
            if self:IsSelected() then
                draw.RoundedBox(0, 0, 0, w, h, Colors.ButtonHover)
            elseif self:IsHovered() then
                draw.RoundedBox(0, 0, 0, w, h, Colors.ListHover)
            end
        end
    end
end

-- Override Paint function for custom background (this is for the opened menu)
function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Colors.Background)
    draw.RoundedBoxEx(8, 0, 0, w, 30, Colors.Header, true, true, false, false)
    draw.SimpleText(utils.L("FriendsMenuTitle", "Boombox Friends"), "FriendsMenu24", 10, 15, Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("rRadioFriendsMenu", PANEL, "DFrame")

-- Create the friends menu in the tools tab
hook.Add("PopulateToolMenu", "rRadioFriendsMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "rRadio", "FriendsMenu", utils.L("BoomboxFriends", "Boombox Friends"), "", "", function(panel)
        panel:ClearControls()
        
        -- Add title
        local titleLabel = vgui.Create("DLabel", panel)
        titleLabel:SetFont("DermaDefaultBold")
        titleLabel:SetText(utils.L("BoomboxFriendsTitle", "rRadio Boombox Friends"))
        titleLabel:SetTextColor(Color(0, 0, 0))  -- Set text color to black
        titleLabel:SizeToContents()
        titleLabel:Dock(TOP)
        titleLabel:DockMargin(0, 0, 0, 5)
        
        -- Add description
        local descLabel = vgui.Create("DLabel", panel)
        descLabel:SetFont("DermaDefault")
        descLabel:SetText(utils.L("BoomboxFriendsDescription", "Open the menu to allow your friends to use your boombox"))
        descLabel:SetTextColor(Color(0, 0, 0))  -- Set text color to black
        descLabel:SetWrap(true)
        descLabel:SetAutoStretchVertical(true)
        descLabel:SetContentAlignment(7)  -- Top-left alignment
        descLabel:Dock(TOP)
        descLabel:DockMargin(0, 0, 0, 10)
        
        -- Add button
        local openButton = panel:Button(utils.L("OpenFriendsMenu", "Open Friends Menu"), "rradio_open_friends_menu")
        openButton:SetTextColor(Color(0, 0, 0))  -- Set button text color to black
    end)
end)

-- Function to update menu labels
local function UpdateMenuLabels()
    local function safeUpdateLabels(menuName, labelKey)
        local menu = controlpanel.Get(menuName)
        if not IsValid(menu) then
            utils.DebugPrint("Menu not valid for key: " .. menuName)
            return
        end
        
        menu:SetLabel(utils.L(labelKey, labelKey))
        
        if not menu.GetControls then
            utils.DebugPrint("GetControls function not available for menu: " .. menuName)
            return
        end
        
        local controls = menu:GetControls()
        if not IsValid(controls) then
            utils.DebugPrint("Controls not valid for menu: " .. menuName)
            return
        end
        
        local children = controls:GetChildren()
        if not children then
            utils.DebugPrint("No children found for menu: " .. menuName)
            return
        end
        
        for _, v in pairs(children) do
            if IsValid(v) then
                if v:GetClassName() == "DLabel" then
                    if v:GetFont() == "DermaDefaultBold" then
                        v:SetText(utils.L("BoomboxFriendsTitle", "rRadio Boombox Friends"))
                    elseif v:GetFont() == "DermaDefault" then
                        v:SetText(utils.L("BoomboxFriendsDescription", "Open the menu to allow your friends to use your boombox"))
                    end
                    v:SizeToContents()
                elseif v:GetClassName() == "DButton" then
                    v:SetText(utils.L("OpenFriendsMenu", "Open Friends Menu"))
                end
            end
        end
    end

    safeUpdateLabels("rRadio", "RadioSettings")
    safeUpdateLabels("FriendsMenu", "BoomboxFriends")
end

-- Update labels when language changes
hook.Add("LanguageChanged", "UpdaterRadioMenuLabels", UpdateMenuLabels)

-- Initial update of labels
hook.Add("InitPostEntity", "InitialrRadioMenuLabelUpdate", function()
    -- Delay the initial update to ensure menus are created
    timer.Simple(1, UpdateMenuLabels)
end)

-- Invalidate cache when receiving updates from server
net.Receive("rRadio_FriendsListUpdate", function()
    cachedFriends = nil
end)

concommand.Add("rradio_open_friends_menu", function()
    if IsValid(LocalPlayer()) then
        vgui.Create("rRadioFriendsMenu")
    end
end)

-- Add this near the top of the file
local function DebugPrint(message)
    if CLIENT then
        print("[rRadio Debug] " .. message)
    end
end

-- Modify the SaveAuthorizedFriends function
local function SaveAuthorizedFriends(friends)
    local friendsJson = util.TableToJSON(friends)
    DebugPrint("Saving authorized friends: " .. friendsJson)
    safeFileWrite("rradio_authorized_friends.txt", friendsJson)
    
    -- Update cache
    cachedFriends = friends
    lastCacheTime = SysTime()
    
    -- Send the updated list to the server
    net.Start("rRadio_UpdateAuthorizedFriends")
    net.WriteString(friendsJson)
    net.SendToServer()
    
    DebugPrint("Sent updated friends list to server")
end

-- Modify the AddFriendToList function
function PANEL:AddFriendToList(name, steamid)
    DebugPrint("Adding friend to list: " .. name .. " (" .. steamid .. ")")
    local line = self.AuthorizedList:AddLine(name, steamid)
    line.Paint = function(self, w, h)
        if self:IsSelected() then
            draw.RoundedBox(0, 0, 0, w, h, Colors.ButtonHover)
        elseif self:IsHovered() then
            draw.RoundedBox(0, 0, 0, w, h, Colors.ListHover)
        end
    end

    -- Set text color for the new line
    for _, column in pairs(line.Columns) do
        column:SetTextColor(Colors.ListText)
    end

    self:SaveAuthorizedFriends()
end

-- Add debug print to the network receiver in sv_radio.lua
net.Receive("rRadio_UpdateAuthorizedFriends", function(len, ply)
    local friendsData = net.ReadString()
    local filename = "rradio_authorized_friends_" .. ply:SteamID64() .. ".txt"
    file.Write(filename, friendsData)
    DebugPrint("Updated friends list for " .. ply:Nick() .. ": " .. friendsData)
end)

return PANEL