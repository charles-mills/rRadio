--[[
    Radio Addon Client-Side Admin Panel
    Author: Charles Mills
    Description: This file implements the client-side admin panel interface for the Radio Addon.
    Date: November 01, 2024
]]--

local PANEL = {}
local adminPanel

function PANEL:Init()
    self:SetTitle("Radio Admin Panel")
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