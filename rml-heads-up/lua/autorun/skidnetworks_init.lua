-- Server-Side Initialization
if SERVER then
    print("[Skid Networks] Initializing server-side...")

    -- Add client-side files so they are sent to the client
    AddCSLuaFile("skidnetworks_hud/cl_hud.lua")
    AddCSLuaFile("skidnetworks_hud/cl_utilities.lua")
    AddCSLuaFile("skidnetworks_hud/cl_speedo.lua")

    -- Ensure directory exists
    if not file.Exists("skidnetworks/tokens", "DATA") then
        file.CreateDir("skidnetworks/tokens")
    end

    if not file.Exists("skidnetworks/weapons", "DATA") then
        file.CreateDir("skidnetworks/weapons")
    end

    -- Include server-side files
    include("autorun/server/tokensystem_init.lua")

    print("[Skid Networks] Server-side initialization complete.")
end

-- Client-Side Initialization
if CLIENT then
    print("[Skid Networks] Initializing client-side...")

    -- Include client-side files
    include("skidnetworks_hud/cl_hud.lua")
    include("skidnetworks_hud/cl_utilities.lua")
    include("skidnetworks_hud/cl_speedo.lua")

    print("[Skid Networks] Client-side initialization complete.")
end
