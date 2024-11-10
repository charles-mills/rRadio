--[[
    Radio Addon Client-Side Admin Panel
    Author: Charles Mills
    Description: This file implements the client-side admin panel interface for the Radio Addon.
    Date: November 01, 2024
]]--

local PANEL = {}
local adminPanel

function PANEL:Init()
    self:SetTitle("rRadio Admin Panel")
    self:SetSize(800, 600)
    self:Center()
    self:MakePopup()
    
    -- Stop All button
    local stopAllBtn = vgui.Create("DButton", self)
    stopAllBtn:SetText("Stop All Streams")
    stopAllBtn:SetTextColor(Color(255, 255, 255))
    stopAllBtn:SetPos(10, 30)
    stopAllBtn:SetSize(120, 30)
    stopAllBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(200, 0, 0))
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(150, 0, 0))
        end
    end
    stopAllBtn.DoClick = function()
        net.Start("rRadio_AdminAction")
            net.WriteString("stop_all")
        net.SendToServer()
    end
    
    -- View Bans button
    local viewBansBtn = vgui.Create("DButton", self)
    viewBansBtn:SetText("View Active Bans")
    viewBansBtn:SetTextColor(Color(255, 255, 255))
    viewBansBtn:SetPos(140, 30)
    viewBansBtn:SetSize(120, 30)
    viewBansBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0, 100, 200))
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(0, 80, 160))
        end
    end
    viewBansBtn.DoClick = function()
        self:OpenBanList()
    end
    
    -- Stream list
    self.streamList = vgui.Create("DListView", self)
    self.streamList:Dock(FILL)
    self.streamList:DockMargin(10, 70, 10, 10)
    self.streamList:SetMultiSelect(false)
    self.streamList:AddColumn("Player"):SetWidth(150)
    self.streamList:AddColumn("SteamID"):SetWidth(150)
    self.streamList:AddColumn("Entity"):SetWidth(100)
    self.streamList:AddColumn("Station"):SetWidth(200)
    self.streamList:AddColumn("Duration"):SetWidth(80)
    self.streamList:AddColumn("Actions"):SetWidth(120)
    
    -- Right-click menu
    self.streamList.OnRowRightClick = function(panel, lineID, line)
        if not line or not line.steamID then return end
        
        local menu = DermaMenu()
        
        menu:AddOption("Stop Stream", function()
            if not line.entityIndex then return end
            
            net.Start("rRadio_AdminAction")
                net.WriteString("stop_stream")
                net.WriteUInt(line.entityIndex, 16)
            net.SendToServer()
        end)
        
        menu:AddSpacer()
        
        local banMenu, banParent = menu:AddSubMenu("Temporary Ban")
        local banTimes = {
            {name = "15 Minutes", time = 15},
            {name = "30 Minutes", time = 30},
            {name = "1 Hour", time = 60},
            {name = "2 Hours", time = 120},
            {name = "4 Hours", time = 240},
            {name = "8 Hours", time = 480},
            {name = "24 Hours", time = 1440}
        }
        
        for _, ban in ipairs(banTimes) do
            banMenu:AddOption(ban.name, function()
                if not line.steamID then return end
                
                net.Start("rRadio_AdminAction")
                    net.WriteString("temp_ban")
                    net.WriteString(line.steamID)
                    net.WriteUInt(ban.time, 32)
                net.SendToServer()
            end)
        end
        
        menu:Open()
    end
end

function PANEL:UpdateData(data)
    self.streamList:Clear()
    
    for _, stream in ipairs(data) do
        if not stream.owner or not stream.ownerSteamID then continue end
        
        local duration = math.floor((CurTime() - (stream.startTime or 0)) / 60)
        local durationStr = string.format("%dm", duration)
        
        local line = self.streamList:AddLine(
            stream.owner,
            stream.ownerSteamID,
            stream.entityClass or "Unknown",
            stream.stationName or "Unknown",
            durationStr
        )
        
        if stream.entity and IsValid(stream.entity) then
            line.entityIndex = stream.entity:EntIndex()
        end
        line.steamID = stream.ownerSteamID
    end
end

function PANEL:OpenBanList()
    if IsValid(self.banList) then
        self.banList:Remove()
    end
    
    self.banList = vgui.Create("DFrame")
    self.banList:SetTitle("Active Radio Bans")
    self.banList:SetSize(600, 400)
    self.banList:Center()
    self.banList:MakePopup()
    
    -- Ban list
    local listView = vgui.Create("DListView", self.banList)
    listView:Dock(FILL)
    listView:DockMargin(5, 5, 5, 5)
    listView:SetMultiSelect(false)
    listView:AddColumn("SteamID"):SetWidth(150)
    listView:AddColumn("Banned By"):SetWidth(120)
    listView:AddColumn("Duration"):SetWidth(100)
    listView:AddColumn("Time Left"):SetWidth(100)
    listView:AddColumn("Actions"):SetWidth(100)
    
    -- Right-click menu
    listView.OnRowRightClick = function(panel, lineID, line)
        local menu = DermaMenu()
        
        menu:AddOption("Revoke Ban", function()
            if not line.steamID then return end
            
            net.Start("rRadio_RevokeBan")
                net.WriteString(line.steamID)
            net.SendToServer()
            
            surface.PlaySound("buttons/button15.wav")
        end)
        
        menu:Open()
    end
    
    -- Request ban list from server
    net.Start("rRadio_RequestBanList")
    net.SendToServer()
    
    -- Update function
    function self:UpdateBanList(bans)
        if not IsValid(self.banList) then return end
        listView:Clear()
        
        for _, ban in ipairs(bans) do
            local timeLeft = math.max(0, ban.timeLeft)
            local duration = math.floor(ban.duration / 60)
            local timeLeftMinutes = math.floor(timeLeft / 60)
            
            local line = listView:AddLine(
                ban.steamID,
                ban.admin,
                string.format("%d minutes", duration),
                string.format("%d minutes", timeLeftMinutes)
            )
            
            line.steamID = ban.steamID
            
            -- Add revoke button
            local revokeBtn = vgui.Create("DButton", line)
            revokeBtn:SetText("Revoke")
            revokeBtn:SetTextColor(Color(255, 255, 255))
            revokeBtn:SizeToContents()
            revokeBtn:SetWide(60)
            revokeBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(200, 0, 0))
                if self:IsHovered() then
                    draw.RoundedBox(4, 0, 0, w, h, Color(150, 0, 0))
                end
            end
            revokeBtn.DoClick = function()
                net.Start("rRadio_RevokeBan")
                    net.WriteString(ban.steamID)
                net.SendToServer()
                
                surface.PlaySound("buttons/button15.wav")
            end
            
            line.DataLayout = function(self, w, h)
                revokeBtn:SetPos(w - 70, 2)
                revokeBtn:SetTall(h - 4)
            end
        end
    end
end

vgui.Register("RadioAdminPanel", PANEL, "DFrame")

-- Network receivers
net.Receive("rRadio_OpenAdminPanel", function()
    local data = net.ReadTable()
    
    if IsValid(adminPanel) then
        adminPanel:Remove()
    end
    
    adminPanel = vgui.Create("RadioAdminPanel")
    adminPanel:UpdateData(data)
end)

net.Receive("rRadio_UpdateAdminPanel", function()
    local data = net.ReadTable()
    
    if IsValid(adminPanel) then
        adminPanel:UpdateData(data)
    end
end)

net.Receive("rRadio_AdminNotification", function()
    local message = net.ReadString()
    local color = net.ReadColor()
    
    chat.AddText(Color(255, 165, 0), "[Radio Admin] ", color, message)
    surface.PlaySound("buttons/button15.wav")
end)

net.Receive("rRadio_SendBanList", function()
    local bans = net.ReadTable()
    
    if IsValid(adminPanel) then
        adminPanel:UpdateBanList(bans)
    end
end) 