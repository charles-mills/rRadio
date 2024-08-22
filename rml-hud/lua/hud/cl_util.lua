-- Function to draw a uniform rainbow border around the HUD
function DrawRainbowBorder(x, y, width, height, thickness)
    local rainbowSpeed = 0.5
    local color = HSVToColor((CurTime() * 360 * rainbowSpeed) % 360, 1, 1)
    surface.SetDrawColor(color)
    
    -- Draw the border in one call
    surface.DrawOutlinedRect(x - thickness, y - thickness, width + 2 * thickness, height + 2 * thickness, thickness)
end
