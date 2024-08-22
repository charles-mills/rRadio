enabled = true

if enabled then
    include("telepanel/sh_init.lua")
    
    if CLIENT then
        include("telepanel/cl_panel.lua")

        net.Receive("OpenTeleportPanel", function()
            TeleportPanel_Open()
        end)
    end
end
