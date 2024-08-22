if SERVER then
    util.AddNetworkString("OpenTokenBuyerMenu")
    util.AddNetworkString("BuyWeaponWithTokens")
    util.AddNetworkString("UpdateTokens")

    -- Define the file path for the token configuration
    local configFilePath = "skidnetworks/token_config.txt"

    -- Default token configuration settings
    local tokenConfig = {
        amount = 10,        -- Number of tokens given per interval
        interval = 300      -- Interval in seconds for token distribution
    }

    -- Function to save the token configuration to a file
    local function SaveTokenConfig()
        if not file.Exists("skidnetworks", "DATA") then
            file.CreateDir("skidnetworks")
        end
        file.Write(configFilePath, util.TableToJSON(tokenConfig))
    end

    -- Function to load the token configuration from a file
    local function LoadTokenConfig()
        if file.Exists(configFilePath, "DATA") then
            local data = file.Read(configFilePath, "DATA")
            local loadedConfig = util.JSONToTable(data)
            if loadedConfig then
                tokenConfig = loadedConfig
            end
        else
            -- If the config file doesn't exist, save the default config
            SaveTokenConfig()
        end
    end

    -- Load the token configuration on server start
    LoadTokenConfig()

    -- Load player's tokens from disk
    local function LoadPlayerTokens(ply)
        local steamID64 = ply:SteamID64()
        local data = file.Read("skidnetworks/tokens/" .. steamID64 .. ".txt", "DATA")
        
        if data then
            ply.tokens = tonumber(data) or 0
        else
            ply.tokens = 0
        end

        print("Loaded tokens for player " .. ply:Nick() .. ": " .. ply.tokens)
    end

    -- Save player's tokens to disk
    local function SavePlayerTokens(ply)
        local steamID64 = ply:SteamID64()
        if not file.Exists("skidnetworks/tokens", "DATA") then
            file.CreateDir("skidnetworks/tokens")
        end
        file.Write("skidnetworks/tokens/" .. steamID64 .. ".txt", tostring(ply.tokens))
    end

    -- Load player's purchased weapons from disk
    local function LoadPlayerWeapons(ply)
        local steamID64 = ply:SteamID64()
        local data = file.Read("skidnetworks/weapons/" .. steamID64 .. ".txt", "DATA")
        
        if data then
            ply.purchasedWeapons = util.JSONToTable(data) or {}
        else
            ply.purchasedWeapons = {}
        end
    end

    -- Save player's purchased weapons to disk
    local function SavePlayerWeapons(ply)
        local steamID64 = ply:SteamID64()
        if not file.Exists("skidnetworks/weapons", "DATA") then
            file.CreateDir("skidnetworks/weapons")
        end
        file.Write("skidnetworks/weapons/" .. steamID64 .. ".txt", util.TableToJSON(ply.purchasedWeapons))
    end

    -- Give purchased weapons to player on spawn
    local function GivePlayerWeapons(ply)
        if ply.purchasedWeapons then
            for _, weapon in ipairs(ply.purchasedWeapons) do
                if not ply:HasWeapon(weapon) then
                    ply:Give(weapon)
                end
            end
        end
    end

    -- Handle player spawn and token/weapon initialization
    hook.Add("PlayerInitialSpawn", "LoadPlayerData", function(ply)
        LoadPlayerTokens(ply)
        LoadPlayerWeapons(ply)
        GivePlayerWeapons(ply)

        -- Send the current token count to the player
        net.Start("UpdateTokens")
        net.WriteInt(ply.tokens, 32)
        net.Send(ply)
    end)

    hook.Add("PlayerSpawn", "GivePersistedWeapons", function(ply)
        GivePlayerWeapons(ply)
    end)

    -- Handle weapon purchases via tokens
    net.Receive("BuyWeaponWithTokens", function(len, ply)
        local weaponClass = net.ReadString()
        local cost = net.ReadInt(32)

        if ply.tokens >= cost then
            if not table.HasValue(ply.purchasedWeapons, weaponClass) then
                ply.tokens = ply.tokens - cost
                table.insert(ply.purchasedWeapons, weaponClass)
                SavePlayerWeapons(ply)
                SavePlayerTokens(ply)

                -- Update the player's token count
                net.Start("UpdateTokens")
                net.WriteInt(ply.tokens, 32)
                net.Send(ply)

                ply:Give(weaponClass)

                ply:ChatPrint("You have purchased " .. weaponClass .. " for " .. cost .. " tokens!")
            else
                ply:ChatPrint("You already own this weapon!")
            end
        else
            ply:ChatPrint("You don't have enough tokens!")
        end
    end)

    local function GiveTokensToAllPlayers()
        quantityOfPlayersRecievedTokens = 0

        for _, ply in ipairs(player.GetAll()) do
            if ply.tokens then
                ply.tokens = ply.tokens + tokenConfig.amount
                SavePlayerTokens(ply)
                net.Start("UpdateTokens")
                net.WriteInt(ply.tokens, 32)
                net.Send(ply)
                quantityOfPlayersRecievedTokens = quantityOfPlayersRecievedTokens + 1
            end
        end

        playersOrPlayer = quantityOfPlayersRecievedTokens == 1 and "player" or "players"

        if quantityOfPlayersRecievedTokens > 0 then
            print(tokenConfig.amount .. " tokens have been given to " .. quantityOfPlayersRecievedTokens .. " " .. playersOrPlayer)
        end
    end
    
    -- Start the token distribution timer
    timer.Create("TokenTimer", tokenConfig.interval, 0, GiveTokensToAllPlayers)

    -- Handle player disconnect to save data
    hook.Add("PlayerDisconnected", "SavePlayerData", function(ply)
        SavePlayerTokens(ply)
        SavePlayerWeapons(ply)
    end)

    concommand.Add("give_tokens", function(ply, cmd, args)
        if ply:IsSuperAdmin() then
            local target = args[1] and player.GetByID(tonumber(args[1])) or ply
            local amount = tonumber(args[2]) or 10

            if IsValid(target) then
                target.tokens = (target.tokens or 0) + amount
                SavePlayerTokens(target)

                -- Update the player's token count
                net.Start("UpdateTokens")
                net.WriteInt(target.tokens, 32)
                net.Send(target)

                ply:ChatPrint("Gave " .. amount .. " tokens to " .. target:Nick())
            else
                ply:ChatPrint("Invalid player!")
            end
        else
            ply:ChatPrint("You do not have permission to use this command!")
        end
    end)
    
    -- Commands for admins to set the token amount and interval
    concommand.Add("set_token_amount", function(ply, cmd, args)
        if ply:IsSuperAdmin() then
            local amount = tonumber(args[1])
            if amount then
                tokenConfig.amount = amount
                SaveTokenConfig()  -- Save the updated config
                ply:ChatPrint("Token amount set to " .. amount)
                ply:ChatPrint("Configuration saved to " .. configFilePath)
            else
                ply:ChatPrint("Invalid amount")
            end
        end
    end)

    concommand.Add("set_token_interval", function(ply, cmd, args)
        if ply:IsSuperAdmin() then
            local interval = tonumber(args[1])
            if interval then
                tokenConfig.interval = interval
                timer.Adjust("TokenTimer", tokenConfig.interval, 0, GiveTokensToAllPlayers)
                SaveTokenConfig()  -- Save the updated config
                ply:ChatPrint("Token interval set to " .. interval .. " seconds")
                ply:ChatPrint("Configuration saved to " .. configFilePath)
            else
                ply:ChatPrint("Invalid interval")
            end
        end
    end)

    concommand.Add("sell_all_weapons", function(ply, cmd, args)
        local weaponPrices = {
            ["cw_makarov"] = 10000,
            ["cw_mr96"] = 15000,
        }
    
        local refundAmount = 0
    
        for _, weapon in ipairs(ply.purchasedWeapons) do
            refundAmount = refundAmount + (weaponPrices[weapon] or 0)
            ply:StripWeapon(weapon)
        end
    
        ply.tokens = ply.tokens + refundAmount
        ply.purchasedWeapons = {}
        SavePlayerWeapons(ply)
        SavePlayerTokens(ply)
    
        -- Update the player's token count
        net.Start("UpdateTokens")
        net.WriteInt(ply.tokens, 32)
        net.Send(ply)
    
        if refundAmount > 0 then
            ply:ChatPrint("[" .. TokenNPCName .. "] You have sold all your permanent weapons for " .. refundAmount .. " tokens!")
        else
            ply:ChatPrint("[" .. TokenNPCName .. "] You don't have any permanent weapons to sell!")
        end
    end)

    concommand.Add("check_tokens", function(ply, cmd, args)
        ply:ChatPrint("You have " .. (ply.tokens or 0) .. " tokens!")
    end)

    concommand.Add("help_rammel", function(ply, cmd, args)
        ply:ChatPrint("[SKID-NET] Rammel's Help Menu!")
        ply:ChatPrint("sell_all_weapons - Sell all your permanent weapons for tokens")
        ply:ChatPrint("give_tokens <player> <amount> - Give tokens to a player")
        ply:ChatPrint("set_token_amount <amount> - Set the amount of tokens given to players")
        ply:ChatPrint("set_token_interval <seconds> - Set the interval at which tokens are given")
    end)
end