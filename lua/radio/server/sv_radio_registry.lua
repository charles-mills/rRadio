--[[
    Radio Addon Server-Side Registry
    Author: Charles Mills
    Description: This file contains the ActiveRadioRegistry implementation used by both
                 the core radio system and permanent boombox management.
    Date: November 01, 2024
]]--

local POSITION_SAVE_INTERVAL = 30 -- Save position every 30 seconds
local STATION_SAVE_DEBOUNCE = 2 -- Debounce station saves by 2 seconds
local pendingSaves = {}
local lastPositionSaves = {}

local ActiveRadioRegistry = {
    entities = {},
    
    Add = function(self, entity, stationName, url, volume, isPermanent)
        print("[rRadio Debug] Registry Add called")
        print("  - Entity:", entity)
        print("  - Station:", stationName or "none")
        print("  - URL:", url or "none")
        print("  - IsPermanent:", isPermanent or entity.IsPermanent)
        
        if not IsValid(entity) then 
            print("[rRadio Debug] Invalid entity in Registry Add")
            return false 
        end
        
        local entIndex = entity:EntIndex()
        print("  - EntIndex:", entIndex)
        
        -- Store essential data
        self.entities[entIndex] = {
            entity = entity,
            stationName = stationName or "",
            url = url or "",
            volume = volume or 1.0,
            lastUpdate = CurTime(),
            isPermanent = isPermanent or entity.IsPermanent or false,
            inRangePlayers = {},
            class = entity:GetClass(),
            status = "playing"
        }
        
        -- Set initial radio status
        if utils.IsBoombox(entity) then
            utils.setRadioStatus(entity, "playing", stationName, true)
        end
        
        -- Update networked variables
        entity:SetNWString("StationName", stationName or "")
        entity:SetNWString("StationURL", url or "")
        entity:SetNWFloat("Volume", volume or 1.0)
        
        -- Update in-range players
        self:UpdateInRangePlayers(entity)
        
        -- Queue save if permanent
        if (isPermanent or entity.IsPermanent) and QueueBoomboxSave then
            QueueBoomboxSave(entity, "registry_add")
        end
        
        -- If there's a station, broadcast to clients
        if stationName and stationName ~= "" and url and url ~= "" then
            -- Broadcast to all players in range
            local inRangePlayers = self:GetInRangePlayers(entity)
            if #inRangePlayers > 0 then
                print("[rRadio Debug] Broadcasting station to", #inRangePlayers, "players in range")
                net.Start("PlayCarRadioStation")
                    net.WriteEntity(entity)
                    net.WriteString(stationName)
                    net.WriteString(url)
                    net.WriteFloat(volume)
                net.Send(inRangePlayers)
            end
        end
        
        -- Broadcast registry update to all clients
        net.Start("UpdateRadioRegistry")
            net.WriteString("add")
            net.WriteEntity(entity)
            net.WriteString(stationName or "")
            net.WriteString(url or "")
            net.WriteFloat(volume or 1.0)
        net.Broadcast()
        
        return true
    end,
    
    Remove = function(self, entity)
        if not IsValid(entity) then return false end
        local entIndex = entity:EntIndex()
        
        -- Clear radio status
        if utils.IsBoombox(entity) then
            utils.setRadioStatus(entity, "stopped", "", false)
        end
        
        -- Clear networked variables
        entity:SetNWString("StationName", "")
        entity:SetNWString("StationURL", "")
        
        -- Remove from registry
        self.entities[entIndex] = nil
        
        -- Notify clients
        net.Start("UpdateRadioRegistry")
            net.WriteString("remove")
            net.WriteEntity(entity)
        net.Broadcast()
        
        -- Notify clients to stop playback
        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()
        
        return true
    end,
    
    Get = function(self, entity)
        if not IsValid(entity) then return nil end
        return self.entities[entity:EntIndex()]
    end,
    
    UpdateInRangePlayers = function(self, entity)
        if not IsValid(entity) then return {} end
        local entIndex = entity:EntIndex()
        local data = self.entities[entIndex]
        if not data then return {} end
        
        -- Get fresh list of in-range players
        data.inRangePlayers = utils.getPlayersInRange(entity)
        return data.inRangePlayers
    end,
    
    GetInRangePlayers = function(self, entity)
        if not IsValid(entity) then return {} end
        local data = self.entities[entity:EntIndex()]
        return data and data.inRangePlayers or {}
    end,
    
    LoadPermanentBoombox = function(self, entity, stationName, url, volume)
        print("[rRadio Debug] LoadPermanentBoombox called")
        print("  - Entity:", entity)
        print("  - Station:", stationName)
        print("  - URL:", url)
        print("  - Volume:", volume)
        print("  - IsPermanent:", entity:GetNWBool("IsPermanent"))
        print("  - PermanentID:", entity:GetNWString("PermanentID"))
        
        -- Add to registry with permanent flag
        if not self:Add(entity, stationName, url, volume, true) then 
            print("[rRadio Debug] Failed to add permanent boombox to registry")
            return false 
        end
        
        -- Broadcast to all current players in range
        local inRangePlayers = self:GetInRangePlayers(entity)
        print("[rRadio Debug] Players in range:", #inRangePlayers)
        
        if #inRangePlayers > 0 then
            print("[rRadio Debug] Broadcasting station to in-range players")
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(stationName)
                net.WriteString(url)
                net.WriteFloat(volume)
            net.Send(inRangePlayers)
        end
        
        return true
    end,
    
    -- Periodic cleanup of invalid entities
    Cleanup = function(self)
        local removed = 0
        for entIndex, data in pairs(self.entities) do
            if not IsValid(data.entity) then
                self.entities[entIndex] = nil
                removed = removed + 1
            end
        end
        return removed
    end,
    
    QueueSave = function(self, entity, reason)
        if not IsValid(entity) or not entity.IsPermanent then 
            print("[rRadio Debug] QueueSave rejected:", not IsValid(entity) and "Invalid entity" or "Not permanent")
            return 
        end
        
        local entIndex = entity:EntIndex()
        local radioData = self.entities[entIndex]
        local currentTime = CurTime()
        
        print("[rRadio Debug] QueueSave called")
        print("  - Entity:", entIndex)
        print("  - Reason:", reason)
        print("  - Has RadioData:", radioData ~= nil)
        print("  - Registry Data:", self.entities[entIndex] and "exists" or "nil")
        if radioData then
            print("  - Current Station:", radioData.stationName)
            print("  - Current URL:", radioData.url)
        end
        
        -- Initialize or update pending save
        if not pendingSaves[entIndex] then
            pendingSaves[entIndex] = {
                entity = entity,
                lastSave = 0,
                nextSave = currentTime + STATION_SAVE_DEBOUNCE,
                position = entity:GetPos(),
                angles = entity:GetAngles(),
                lastPositionSave = lastPositionSaves[entIndex] or 0,
                stationName = radioData and radioData.stationName or entity:GetNWString("StationName", ""),
                url = radioData and radioData.url or entity:GetNWString("StationURL", ""),
                volume = entity:GetNWFloat("Volume", 1.0),
                lastSavedState = nil
            }
        else
            -- Update existing pending save with latest data
            local newState = {
                position = entity:GetPos(),
                angles = entity:GetAngles(),
                stationName = radioData and radioData.stationName or entity:GetNWString("StationName", ""),
                url = radioData and radioData.url or entity:GetNWString("StationURL", ""),
                volume = entity:GetNWFloat("Volume", 1.0)
            }
            
            -- Only update if data has actually changed
            if not pendingSaves[entIndex].lastSavedState or 
               hasDataChanged(pendingSaves[entIndex].lastSavedState, newState) then
                pendingSaves[entIndex].position = newState.position
                pendingSaves[entIndex].angles = newState.angles
                pendingSaves[entIndex].stationName = newState.stationName
                pendingSaves[entIndex].url = newState.url
                pendingSaves[entIndex].volume = newState.volume
                pendingSaves[entIndex].nextSave = currentTime + STATION_SAVE_DEBOUNCE
                pendingSaves[entIndex].lastSavedState = table.Copy(newState)
                
                print("[rRadio Debug] Updated pending save data:")
                print("  - Station:", newState.stationName)
                print("  - URL:", newState.url)
                print("  - Volume:", newState.volume)
            end
        end
    end
}

timer.Create("ProcessPermanentBoomboxSaves", 1, 0, function()
    local currentTime = CurTime()
    
    for entIndex, saveData in pairs(pendingSaves) do
        if not IsValid(saveData.entity) then
            pendingSaves[entIndex] = nil
            continue
        end
        
        local shouldSave = false
        local reasons = {}
        
        -- Check if position needs saving
        if currentTime - saveData.lastPositionSave >= POSITION_SAVE_INTERVAL then
            shouldSave = true
            table.insert(reasons, "position_update")
            lastPositionSaves[entIndex] = currentTime
        end
        
        -- Check if station data needs saving
        if currentTime >= saveData.nextSave then
            shouldSave = true
            table.insert(reasons, "station_update")
        end
        
        if shouldSave then
            print(string.format("[rRadio Debug] Processing save for boombox %d (Reasons: %s)", 
                entIndex, table.concat(reasons, ", ")))
            
            if SavePermanentBoombox then
                SavePermanentBoombox(saveData.entity)
            end
            pendingSaves[entIndex].lastSave = currentTime
        end
    end
end)

return ActiveRadioRegistry 