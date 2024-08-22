util.AddNetworkString("PlayerFirstJoin")

hook.Add("PlayerInitialSpawn", "CheckFirstJoin", function(ply)
    -- Check if this is the player's first time joining the server
    -- This could be a database check or something similar
    -- For simplicity, we'll just send a network message to open the menu
    net.Start("PlayerFirstJoin")
    net.Send(ply)
end)
