--[[
    Radio Addon Server-Side Admin Panel
    Author: Charles Mills
    Description: This file implements the admin panel functionality for the Radio Addon,
                 allowing server administrators to monitor and manage active radio streams.
    Date: November 01, 2024
]]--

local COMMAND_PREFIX = "!radioviewer"
local ADMIN_PANEL_WIDTH = 800
local ADMIN_PANEL_HEIGHT = 600
local COLUMN_PADDING = 10

-- Temporary ban system
local TempBans = {
    bans = {},
    
    AddBan = function(self, steamID, duration, adminName)
        self.bans[steamID] = {
            startTime = CurTime(),
            duration = duration,
            admin = adminName,
            expires = CurTime() + duration
        }
        self:SaveBans()
    end,
    
    RemoveBan = function(self, steamID)
        self.bans[steamID] = nil
        self:SaveBans()
    end,
    
    IsBanned = function(self, steamID)
        local ban = self.bans[steamID]
        if not ban then return false end
        
        local timeLeft = ban.expires - CurTime()
        if timeLeft <= 0 then
            self:RemoveBan(steamID)
            return false
        end
        
        return true, ban, timeLeft
    end,
    
    SaveBans = function(self)
        -- Convert CurTime to relative durations for storage
        local storageData = {}
        local currentTime = CurTime()
        
        for steamID, banData in pairs(self.bans) do
            -- Only save bans that haven't expired
            if currentTime < banData.expires then
                storageData[steamID] = {
                    remainingTime = banData.expires - currentTime,
                    admin = banData.admin,
                    duration = banData.duration
                }
            end
        end
        
        local data = util.TableToJSON(storageData)
        file.Write("rradio/tempbans.txt", data)
    end,
    
    LoadBans = function(self)
        if not file.Exists("rradio/tempbans.txt", "DATA") then return end
        
        local data = file.Read("rradio/tempbans.txt", "DATA")
        local storageData = util.JSONToTable(data) or {}
        
        -- Convert stored relative times to current CurTime values
        local currentTime = CurTime()
        self.bans = {}
        
        for steamID, banData in pairs(storageData) do
            -- Only restore bans that still have time remaining
            if banData.remainingTime > 0 then
                self.bans[steamID] = {
                    startTime = currentTime,
                    duration = banData.duration,
                    admin = banData.admin,
                    expires = currentTime + banData.remainingTime
                }
            end
        end
        
        self:SaveBans() -- Clean up storage by removing expired bans
    end,
    
    GetActiveBans = function(self)
        local bans = {}
        local currentTime = CurTime()
        
        for steamID, banData in pairs(self.bans) do
            -- Only include active bans
            if currentTime < banData.expires then
                local timeLeft = banData.expires - currentTime
                table.insert(bans, {
                    steamID = steamID,
                    admin = banData.admin,
                    duration = banData.duration,
                    timeLeft = timeLeft,
                    expires = banData.expires,
                    startTime = banData.startTime
                })
            end
        end
        
        -- Sort by time remaining (ascending)
        table.sort(bans, function(a, b)
            return a.timeLeft < b.timeLeft
        end)
        
        return bans
    end,
    
    RevokeBan = function(self, steamID, adminName)
        if not self.bans[steamID] then return false end
        
        -- Get player name before removing ban
        local targetName = "Unknown"
        local targetPly = player.GetBySteamID(steamID)
        if IsValid(targetPly) then
            targetName = targetPly:Nick()
        end
        
        self:RemoveBan(steamID)
        
        -- Notify online admins
        for _, ply in ipairs(player.GetAll()) do
            if Config.AdminPanel.CanAccess(ply) then
                SendAdminNotification(ply, string.format("Admin %s revoked ban for %s (%s)", 
                    adminName, targetName, steamID), Color(0, 255, 0))
            end
        end
        
        -- Notify unbanned player if online
        if IsValid(targetPly) then
            targetPly:ChatPrint("[Radio] Your radio ban has been revoked by " .. adminName)
        end
        
        return true
    end
}

-- Load bans on server start
hook.Add("Initialize", "LoadRadioTempBans", function()
    if not file.Exists("radio", "DATA") then
        file.CreateDir("radio")
    end
    TempBans:LoadBans()
end)

-- Check for ban before allowing stream
hook.Add("RadioPreStreamStart", "CheckRadioTempBan", function(ply)
    if not IsValid(ply) then return end
    
    local steamID = ply:SteamID()
    local isBanned, banData, timeLeft = TempBans:IsBanned(steamID)
    
    if isBanned then
        local timeLeftMinutes = math.ceil(timeLeft / 60)
        ply:ChatPrint(string.format("[Radio] You are temporarily banned from using the radio system. Time remaining: %d minutes", timeLeftMinutes))
        return false
    end
end)

local function SendAdminNotification(ply, message, color)
    if not IsValid(ply) then return end
    
    net.Start("rRadio_AdminNotification")
        net.WriteString(message)
        net.WriteColor(color or Color(255, 255, 255))
    net.Send(ply)
end

local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

local function GetStreamData()
    local data = {}
    
    if not _G.ActiveRadios then
        print("[rRadio] Warning: ActiveRadios table not found")
        return data
    end
    
    for entIndex, radio in pairs(_G.ActiveRadios) do
        local entity = Entity(entIndex)
        if IsValid(entity) then
            local owner = entity.RadioStartedBy
            if IsValid(owner) then
                table.insert(data, {
                    entity = entity,
                    entityClass = entity:GetClass(),
                    owner = owner:Nick(),
                    ownerSteamID = owner:SteamID(),
                    stationName = radio.stationName,
                    startTime = radio.startTime or 0,
                    volume = radio.volume or 1
                })
            end
        end
    end
    
    return data
end

net.Receive("rRadio_AdminAction", function(len, admin)
    if not IsValid(admin) or not Config.AdminPanel.CanAccess(admin) then return end
    
    local action = net.ReadString()
    
    if action == "stop_all" then
        -- Stop all streams
        if _G.ActiveRadios then
            for entIndex, _ in pairs(_G.ActiveRadios) do
                local entity = Entity(entIndex)
                if IsValid(entity) then
                    net.Start("rRadio_StopStream")
                        net.WriteEntity(entity)
                    net.Broadcast()
                    
                    RemoveActiveRadio(entity)
                end
            end
        end
        
        SendAdminNotification(admin, "Stopped all active streams", Color(0, 255, 0))
        
    elseif action == "stop_stream" then
        local entIndex = net.ReadUInt(16)
        local entity = Entity(entIndex)
        
        if IsValid(entity) then
            net.Start("rRadio_StopStream")
                net.WriteEntity(entity)
            net.Broadcast()
            
            RemoveActiveRadio(entity)
            SendAdminNotification(admin, "Stopped stream for " .. entity:GetClass(), Color(0, 255, 0))
        end
        
    elseif action == "temp_ban" then
        local steamID = net.ReadString()
        local duration = net.ReadUInt(32) -- Duration in minutes
        
        local targetPly = player.GetBySteamID(steamID)
        if IsValid(targetPly) then
            TempBans:AddBan(steamID, duration * 60, admin:Nick())
            
            -- Stop all streams by this player
            for entIndex, radio in pairs(ActiveRadios) do
                local entity = Entity(entIndex)
                if IsValid(entity) and entity.RadioStartedBy == targetPly then
                    net.Start("rRadio_StopStream")
                        net.WriteEntity(entity)
                    net.Broadcast()
                    
                    RemoveActiveRadio(entity)
                end
            end
            
            SendAdminNotification(admin, string.format("Temporarily banned %s from using radio for %d minutes", 
                targetPly:Nick(), duration), Color(255, 165, 0))
            
            targetPly:ChatPrint(string.format("[Radio] You have been temporarily banned from using the radio system for %d minutes", 
                duration))
        end
    end
end)

hook.Add("PlayerSay", "RadioAdminPanelCommand", function(ply, text)
    if text:lower() == COMMAND_PREFIX then
        if not IsValid(ply) then return "" end
        
        if not Config.AdminPanel.CanAccess(ply) then
            ply:ChatPrint("[Radio] You don't have permission to use this command!")
            return ""
        end
        
        net.Start("rRadio_OpenAdminPanel")
            net.WriteTable(GetStreamData())
        net.Send(ply)
        
        return ""
    end
end)

timer.Create("RadioAdminPanelUpdate", 5, 0, function()
    local admins = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and Config.AdminPanel.CanAccess(ply) then
            table.insert(admins, ply)
        end
    end
    
    if #admins > 0 then
        net.Start("rRadio_UpdateAdminPanel")
            net.WriteTable(GetStreamData())
        net.Send(admins)
    end
end)

-- Export TempBans system for use in other files
return TempBans 