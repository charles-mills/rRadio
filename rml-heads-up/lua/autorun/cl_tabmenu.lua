if CLIENT then
    -- Custom Fonts
    surface.CreateFont("SkidFont24", {
        font = "Trebuchet24",
        size = 24,
        weight = 500,
        antialias = true,
    })

    surface.CreateFont("SkidFont18", {
        font = "Trebuchet18",
        size = 18,
        weight = 500,
        antialias = true,
    })

    -- Variable to keep track of the frame
    local frame
    local isTabMenuOpen = false

    -- Function to close the TAB menu
    local function CloseTabMenu()
        if IsValid(frame) then
            frame:Close()
            frame = nil  -- Set frame to nil to allow reopening
        end

        isTabMenuOpen = false
        gui.EnableScreenClicker(false)  -- Disable mouse control when the menu is closed
    end

    -- Custom TAB Menu Hook
    hook.Add("ScoreboardShow", "CustomScoreboardShow", function()
        if IsValid(frame) then return true end

        -- Dimensions
        local scrW, scrH = ScrW(), ScrH()
        local scaleW, scaleH = scrW / 1920, scrH / 1080

        -- Frame for the TAB menu
        local frameW, frameH = 800 * scaleW, 600 * scaleH
        frame = vgui.Create("DFrame")
        frame:SetSize(frameW, frameH)
        frame:Center()
        frame:SetTitle("")
        frame:ShowCloseButton(false)
        frame:SetDraggable(false)
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 240))
        end

        -- Server Name
        local serverNameLabel = vgui.Create("DLabel", frame)
        serverNameLabel:SetText("Skid Networks | PoliceRP")
        serverNameLabel:SetFont("SkidFont24")
        serverNameLabel:SetColor(Color(240, 240, 240))
        serverNameLabel:SizeToContents()
        serverNameLabel:SetPos((frameW - serverNameLabel:GetWide()) / 2, 10 * scaleH)

        -- Player Count
        local playerCountLabel = vgui.Create("DLabel", frame)
        playerCountLabel:SetText(player.GetCount() .. "/70 Players Online")
        playerCountLabel:SetFont("SkidFont18")
        playerCountLabel:SetColor(Color(150, 150, 150))
        playerCountLabel:SizeToContents()
        playerCountLabel:SetPos((frameW - playerCountLabel:GetWide()) / 2, 40 * scaleH)

        -- Scrollable Player List
        local playerList = vgui.Create("DScrollPanel", frame)
        playerList:SetSize(frameW - 40 * scaleW, frameH - 100 * scaleH)
        playerList:SetPos(20 * scaleW, 80 * scaleH)

        -- Hide the scrollbar
        playerList.VBar:SetWide(0)

        -- Sorted player list by job category
        local jobCategories = {}

        for _, ply in ipairs(player.GetAll()) do
            local job = ply:getDarkRPVar("job")
            local category = RPExtraTeams and RPExtraTeams[ply:Team()].category or "Unknown"

            if not jobCategories[category] then
                jobCategories[category] = {}
            end
            table.insert(jobCategories[category], ply)
        end

        -- Create a list of players sorted by job category
        for category, players in SortedPairs(jobCategories) do
            -- Job Category Header
            local categoryHeader = vgui.Create("DLabel", playerList)
            categoryHeader:SetText(category)
            categoryHeader:SetFont("SkidFont24")
            categoryHeader:SetColor(Color(240, 240, 240))
            categoryHeader:Dock(TOP)
            categoryHeader:DockMargin(5, 10, 5, 5)

            -- List each player under their job category
            for _, ply in ipairs(players) do
                local playerPanel = vgui.Create("DPanel", playerList)
                playerPanel:SetTall(50 * scaleH)
                playerPanel:Dock(TOP)
                playerPanel:DockMargin(5, 5, 5, 5)
                playerPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
                end

                -- Player Avatar
                local avatarSize = 36 * scaleH
                local avatar = vgui.Create("AvatarImage", playerPanel)
                avatar:SetSize(avatarSize, avatarSize)
                avatar:SetPlayer(ply, 64)
                avatar:Dock(LEFT)
                avatar:DockMargin(5 * scaleW, 7 * scaleH, 10 * scaleW, 7 * scaleH)

                -- RP Name
                local rpNameLabel = vgui.Create("DLabel", playerPanel)
                rpNameLabel:SetText(ply:Nick())
                rpNameLabel:SetFont("SkidFont18")
                rpNameLabel:SetColor(Color(240, 240, 240))
                rpNameLabel:Dock(LEFT)
                rpNameLabel:DockMargin(10 * scaleW, 0, 0, 0)
                rpNameLabel:SizeToContents()

                -- Job Name
                local jobNameLabel = vgui.Create("DLabel", playerPanel)
                jobNameLabel:SetText(ply:getDarkRPVar("job"))
                jobNameLabel:SetFont("SkidFont18")
                jobNameLabel:SetColor(Color(150, 150, 150))
                jobNameLabel:Dock(FILL)
                jobNameLabel:SetContentAlignment(5)
                jobNameLabel:SizeToContents()

                -- Ping
                local pingLabel = vgui.Create("DLabel", playerPanel)
                pingLabel:SetText(ply:Ping() .. " ms")
                pingLabel:SetFont("SkidFont18")
                pingLabel:SetColor(Color(240, 240, 240))
                pingLabel:Dock(RIGHT)
                pingLabel:DockMargin(0, 0, 10 * scaleW, 0)
                pingLabel:SizeToContents()

                -- Left-click menu
                playerPanel.OnMousePressed = function(self, mouseCode)
                    if mouseCode == MOUSE_LEFT then
                        local menu = DermaMenu()

                        menu:AddOption("Open Steam Profile", function()
                            ply:ShowProfile()
                            CloseTabMenu()  -- Automatically close the TAB menu after opening the Steam profile
                        end)

                        menu:AddOption("Copy Steam ID", function()
                            SetClipboardText(ply:SteamID())
                        end)

                        menu:AddOption("Copy Steam ID64", function()
                            SetClipboardText(ply:SteamID64())
                        end)

                        menu:Open()
                    end
                end
            end
        end

        isTabMenuOpen = true

        -- Enable mouse control
        gui.EnableScreenClicker(true)

        return true  -- Returning true prevents the default scoreboard from showing
    end)

    hook.Add("ScoreboardHide", "CustomScoreboardHide", function()
        if IsValid(frame) then
            frame:Close()
            frame = nil  -- Set frame to nil to allow reopening
        end

        isTabMenuOpen = false

        -- Disable mouse control when the menu is closed
        gui.EnableScreenClicker(false)
    end)

    -- Disable weapon selection and prevent other inputs while the scoreboard is open
    hook.Add("PlayerBindPress", "DisableWeaponWheelOnTab", function(ply, bind, pressed)
        if isTabMenuOpen and (bind == "invnext" or bind == "invprev" or bind == "lastinv") then
            return true  -- Block scrolling through weapons
        end
    end)

    -- Handle the mouse wheel scrolling
    hook.Add("Think", "HandleTabMenuScrolling", function()
        if isTabMenuOpen and input.IsMouseDown(MOUSE_WHEEL_UP) then
            playerList.VBar:AnimateTo(playerList.VBar:GetScroll() - 50, 0.1, 0, 0.5)
        elseif isTabMenuOpen and input.IsMouseDown(MOUSE_WHEEL_DOWN) then
            playerList.VBar:AnimateTo(playerList.VBar:GetScroll() + 50, 0.1, 0, 0.5)
        end
    end)
end
