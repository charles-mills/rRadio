rRadio.tools = rRadio.tools or {}

cvars.AddChangeCallback("rammel_rradio_menu_theme", function(_, old, new)
    rRadio.interface.applyTheme(new)
end, "rRadioThemeCallback")

hook.Add("PopulateToolMenu", "rRadio.ToolMenu", function()
    spawnmenu.AddToolMenuOption("Options", "Rammel", "rRadio", "rRadio", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Have an issue? Report it on the Steam Workshop page.")
        local reportBtn = vgui.Create("DButton", panel)
        reportBtn:Dock(TOP)
        reportBtn:DockMargin(10, 10, 10, 10)
        reportBtn:SetText("Report Issue")
        function reportBtn:DoClick()
            gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741")
        end
        local generalForm = vgui.Create("DForm", panel)
        generalForm:SetName("General Settings")
        generalForm:Dock(TOP)
        generalForm:DockMargin(0, 10, 0, 10)
        generalForm:CheckBox("Enable rRadio", "rammel_rradio_enabled")
        generalForm:Help("Toggle the rRadio addon globally on or off.")
        generalForm:CheckBox("Vehicle Animation", "rammel_rradio_vehicle_animation")
        generalForm:Help("Play an animation when you enter a vehicle.")
        generalForm:CheckBox("Boombox HUD", "rammel_rradio_boombox_hud")
        generalForm:Help("Display a HUD overlay on boomboxes when nearby.")
        panel:Help("")

        local menuForm = vgui.Create("DForm", panel)
        menuForm:SetName("Menu Settings")
        menuForm:Dock(TOP)
        menuForm:DockMargin(0, 0, 0, 10)

        local keyRow = vgui.Create("DPanel")
        keyRow.Paint = function(self, w, h) end
        keyRow:Dock(TOP)
        keyRow:DockMargin(0, 0, 0, 10)
        keyRow:SetTall(24)
        local keyLabel = vgui.Create("DLabel", keyRow)
        keyLabel:Dock(LEFT)
        keyLabel:SetText("Menu Key")
        keyLabel:SizeToContents()
        keyLabel:DockMargin(0, 4, 8, 0)
        keyLabel:SetTextColor(Color(0, 0, 0, 255))
        local keyBinder = vgui.Create("DBinder", keyRow)
        keyBinder:Dock(RIGHT)
        keyBinder:DockMargin(0, 2, 0, 0)
        keyBinder:SetWide(185)
        keyBinder:SetConVar("rammel_rradio_menu_key")
        keyBinder:SetValue(GetConVar("rammel_rradio_menu_key"):GetInt())
        keyBinder:SetText(rRadio.GetKeyName(keyBinder:GetValue()))
        function keyBinder:OnChange(newCode)
            DBinder.OnChange(self, newCode)
            self:SetText(rRadio.GetKeyName(newCode))
        end
        menuForm:AddItem(keyRow)

        local theme = menuForm:ComboBox("Menu Theme", "rammel_rradio_menu_theme")
        for name, _ in pairs(rRadio.themes) do
            theme:AddChoice(name, name)
        end
        
        local preview = vgui.Create("DPanel")
        preview:SetTall(150)
        preview:Dock(TOP)
        preview:DockMargin(0, 0, 0, 10)
        menuForm:AddItem(preview)
        preview.Paint = function(self, w, h)
            local ui = rRadio.config.UI
            surface.SetDrawColor(ui.BackgroundColor.r, ui.BackgroundColor.g, ui.BackgroundColor.b, ui.BackgroundColor.a)
            surface.DrawRect(0, 0, w, h)
            local headerColor = ui.HeaderColor or ui.BackgroundColor
            surface.SetDrawColor(headerColor.r, headerColor.g, headerColor.b, headerColor.a)
            surface.DrawRect(0, 0, w, 30)
            draw.SimpleText("rRadio Preview", "rRadio.Roboto24", w/2, 15, ui.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(ui.ButtonColor.r, ui.ButtonColor.g, ui.ButtonColor.b, ui.ButtonColor.a)
            surface.DrawRect(10, 40, w-20, 25)
            draw.SimpleText("Sample Button", "rRadio.Roboto24", w/2, 40+12, ui.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            surface.SetDrawColor(ui.Highlight.r, ui.Highlight.g, ui.Highlight.b, ui.Highlight.a)
            surface.DrawRect(0, h-6, w, 6)
        end
        theme.OnSelect = function(self, index, text, choice)
            RunConsoleCommand("rammel_rradio_menu_theme", choice)
            rRadio.interface.applyTheme(choice)
        end
    end)
end)
