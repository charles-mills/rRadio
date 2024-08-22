if CLIENT then
    hook.Add("HUDPaint", "DisplayPlayerInfo", function()
        local ply = LocalPlayer()
        local maxDistance = 200  -- Maximum distance at which the text is fully visible
        local minAlphaDistance = 300  -- Distance at which the text is fully invisible

        -- Screen resolution scaling
        local scrW, scrH = ScrW(), ScrH()
        local scaleH = scrH / 1080  -- Scale factor based on vertical resolution

        -- Iterate through all players
        for _, target in ipairs(player.GetAll()) do
            -- Skip if the target is not valid or is the local player
            if not IsValid(target) or target == ply then continue end

            -- Calculate the distance between the local player and the target
            local distance = ply:GetPos():Distance(target:GetPos())
            if distance > minAlphaDistance then continue end  -- Skip if too far away

            -- Calculate the target's screen position with a dynamic height offset
            local heightOffset = 55 * scaleH  -- Adjusted height offset
            local targetPos = target:GetPos() + Vector(0, 0, heightOffset)
            local screenPos = targetPos:ToScreen()

            -- Get the player's name and job
            local playerName = target:Nick()
            local playerJob = target:getDarkRPVar("job") or "Unknown"

            -- Get the color of the player's job
            local jobColor = team.GetColor(target:Team())

            -- Determine the alpha value based on distance
            local alpha = 255
            if distance > maxDistance then
                alpha = math.Clamp(255 - ((distance - maxDistance) / (minAlphaDistance - maxDistance)) * 255, 0, 255)
            end

            -- Set the font and colors with alpha applied
            local textColor = Color(240, 240, 240, alpha)
            jobColor = Color(jobColor.r, jobColor.g, jobColor.b, alpha)  -- Apply alpha to the job color

            -- Calculate text height for offset
            surface.SetFont("Trebuchet18")
            local _, jobTextHeight = surface.GetTextSize(playerJob)  -- Get the height of the job text

            -- Position the job text so it's always just above the player's head
            local jobY = screenPos.y  -- Keep the Y position as calculated

            -- Draw the player's job
            draw.SimpleTextOutlined(playerJob, "Trebuchet18", screenPos.x, jobY, jobColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, alpha))

            -- Draw the player's name above the job
            draw.SimpleTextOutlined(playerName, "Trebuchet18", screenPos.x, jobY - jobTextHeight, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, alpha))
        end
    end)
end
