include("telepanel/config.lua")

function TeleportPanel_Open()
    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW() * 0.6, ScrH() * 0.4)
    frame:Center()
    frame:SetTitle("Choose Your Destination")
    frame:MakePopup()

    local scrollPanel = vgui.Create("DScrollPanel", frame)
    scrollPanel:Dock(FILL)

    local iconLayout = vgui.Create("DIconLayout", scrollPanel)
    iconLayout:Dock(FILL)
    iconLayout:SetSpaceY(10)
    iconLayout:SetSpaceX(10)

    for i, loc in ipairs(TeleportConfig.locations) do
        local icon = vgui.Create("DImageButton", iconLayout)
        icon:SetImage(TeleportConfig.images[i])
        icon:SetSize(ScrW() * 0.1, ScrH() * 0.1)
        icon.DoClick = function()
            print("Requesting teleport to:", loc.name)  -- Debugging print statement

            -- Send a network message to the server to teleport the player
            net.Start("TeleportPlayer")
            net.WriteInt(i, 4)  -- Send the index of the location
            net.SendToServer()

            frame:Close()
        end

        local label = vgui.Create("DLabel", icon)
        label:SetPos(0, ScrH() * 0.1)
        label:SetSize(ScrW() * 0.1, 20)
        label:SetText(loc.name)
        label:SetContentAlignment(5)
    end
end
