include("skidnetworks_training/config.lua")

-- Function to calculate the direction from the player to the PD
local function CalculateArrowPosition()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local plyPos = ply:GetPos()
    local direction = (AutoTrainingConfig.PDLocation - plyPos):GetNormalized()
    local screenPos = direction:ToScreen()

    return screenPos.x, screenPos.y
end

-- Function to draw the arrow on the player's screen
local function DrawArrow()
    if not AutoTrainingConfig.ArrowVisible then return end

    local x, y = CalculateArrowPosition()

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(Material(AutoTrainingConfig.ArrowMaterial))
    surface.DrawTexturedRectRotated(x, y, AutoTrainingConfig.ArrowSize, AutoTrainingConfig.ArrowSize, 0)
end

hook.Add("HUDPaint", "DrawTrainingArrow", DrawArrow)
