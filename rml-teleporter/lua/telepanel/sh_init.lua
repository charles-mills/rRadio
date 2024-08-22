include("telepanel/config.lua")

if SERVER then
    resource.AddWorkshop("3314444518")

    util.AddNetworkString("OpenTeleportPanel")  -- Register the network message for opening the panel
    util.AddNetworkString("TeleportPlayer")     -- Register a new network message for teleporting the player

    hook.Add("PlayerSpawn", "OpenTeleportPanel", function(ply)
        if ply:IsPlayer() then
            net.Start("OpenTeleportPanel")
            net.Send(ply)  -- Send the message to the player who just spawned
        end
    end)

    net.Receive("TeleportPlayer", function(len, ply)
        local locationIndex = net.ReadInt(4)  -- Read the index of the location from the message
        local location = TeleportConfig.locations[locationIndex]  -- Retrieve the location from the config

        if location then
            ply:SetPos(location.pos)  -- Teleport the player to the selected location
            print(ply:Nick() .. " teleported to " .. location.name)
        else
            print("Invalid teleport location index received: " .. locationIndex)
        end
    end)
end
