util.AddNetworkString("OpenTokenBuyerMenu")
util.AddNetworkString("BuyWeaponWithTokens")

local function LoadPlayerWeapons(ply)
    local steamID64 = ply:SteamID64()
    local data = file.Read("skidnetworks/weapons/" .. steamID64 .. ".txt", "DATA")
    if data then
        local success, weapons = pcall(util.JSONToTable, data)
        if success and istable(weapons) then
            ply.purchasedWeapons = weapons
        else
            ply.purchasedWeapons = {}
            ply:ChatPrint("Failed to load your weapons. Please contact an admin.")
        end
    else
        ply.purchasedWeapons = {}
    end
end

local function SavePlayerWeapons(ply)
    local steamID64 = ply:SteamID64()
    if not file.Exists("skidnetworks/weapons", "DATA") then
        file.CreateDir("skidnetworks/weapons")
    end
    local success = pcall(function()
        file.Write("skidnetworks/weapons/" .. steamID64 .. ".txt", util.TableToJSON(ply.purchasedWeapons))
    end)
    if not success then
        ply:ChatPrint("Failed to save your weapons. Please contact an admin.")
    end
end

local function GivePlayerWeapons(ply)
    if ply.purchasedWeapons then
        for _, weapon in ipairs(ply.purchasedWeapons) do
            if not ply:HasWeapon(weapon) then
                ply:Give(weapon)
            end
        end
    end
end

hook.Add("PlayerInitialSpawn", "LoadPlayerWeapons", function(ply)
    LoadPlayerWeapons(ply)
    GivePlayerWeapons(ply)
end)

hook.Add("PlayerSpawn", "GivePersistedWeapons", function(ply)
    GivePlayerWeapons(ply)
end)

net.Receive("BuyWeaponWithTokens", function(len, ply)
    local weaponClass = net.ReadString()
    local cost = net.ReadInt(32)

    if ply.tokens and ply.tokens >= cost then
        if not table.HasValue(ply.purchasedWeapons, weaponClass) then
            ply.tokens = ply.tokens - cost
            table.insert(ply.purchasedWeapons, weaponClass)
            SavePlayerWeapons(ply)
            ply:ChatPrint("You have purchased " .. weaponClass .. " for " .. cost .. " tokens!")
        else
            ply:ChatPrint("You already own this weapon!")
        end
    else
        ply:ChatPrint("You don't have enough tokens!")
    end
end)
