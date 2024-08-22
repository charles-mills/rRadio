if CLIENT then
    -- Define the maximum range (in units) for displaying owner information
    local maxDisplayRange = 300
    
    hook.Add("HUDPaint", "DisplayOwnerInfo", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local trace = ply:GetEyeTrace()
        local ent = trace.Entity

        -- Check if the entity is valid and ownable
        if not IsValid(ent) or not ent:isKeysOwnable() then return end

        -- Check if the door has a title set to a single space
        local doorTitle = ent:getKeysTitle()
        if doorTitle == " " then return end

        -- Calculate the distance between the player and the entity
        local distance = ply:GetPos():Distance(ent:GetPos())
        if distance > maxDisplayRange then return end

        local ownerName = nil
        local jobCategory = nil

        -- Check if the entity is owned by a player
        local owner = ent:getDoorOwner()
        if IsValid(owner) then
            ownerName = owner:Nick()
        else
            -- Check if the door belongs to a DarkRP job category
            local jobTable = ent:getKeysDoorGroup() or ent:getKeysDoorTeams()
            if jobTable then
                if istable(jobTable) then
                    -- If the jobTable is a table, extract one of the job names
                    for k, _ in pairs(jobTable) do
                        if RPExtraTeams[k] then
                            jobCategory = RPExtraTeams[k].category
                            break
                        end
                    end
                elseif isstring(jobTable) then
                    jobCategory = jobTable  -- Directly assign if it's just a string category
                end
            end

            -- If no owner and no job, it's unowned
            if not jobCategory then
                ownerName = "Unowned"
            end
        end

        -- If neither ownerName nor jobCategory is available, return (hide HUD)
        if not ownerName and not jobCategory then return end

        -- Screen resolution scaling
        local scrW, scrH = ScrW(), ScrH()
        local scaleH = scrH / 1080  -- Scaling based on height

        -- Position the display above the crosshair
        local x = scrW / 2
        local y = scrH / 2 + 30 * scaleH

        -- Display the owner name or job category
        if jobCategory then
            draw.SimpleText(jobCategory, "Trebuchet18", x, y + 5 * scaleH, Color(240, 240, 240), TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(ownerName, "Trebuchet18", x, y + 5 * scaleH, Color(240, 240, 240), TEXT_ALIGN_CENTER)
        end

        -- If the door is unowned, suggest the player purchase it
        if ownerName == "Unowned" then
            draw.SimpleText("Press F2 to purchase", "Trebuchet18", x, y + 25 * scaleH, Color(240, 240, 240), TEXT_ALIGN_CENTER)
        end
    end)
end
