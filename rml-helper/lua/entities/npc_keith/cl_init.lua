include("shared.lua")
include("cl_chatbox.lua")

function ENT:Draw()
    self:DrawModel()

    local playerPos = LocalPlayer():GetPos()
    local npcPos = self:GetPos()

    -- Calculate the distance between the player and the NPC
    local distance = playerPos:Distance(npcPos)
    local alpha = math.Clamp(255 * (1 - distance / 500), 0, 255)

    -- Use screen scale to ensure consistent size across resolutions
    local scrW, scrH = ScrW(), ScrH()
    local scale = math.Clamp(1 / (distance / 300), 0.05, 0.2)
    local screenScale = math.min(scrW / 1920, scrH / 1080)

    -- Position above the NPC's head
    local pos = npcPos + Vector(0, 0, 85)
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, scale)
        local rectW, rectH = 125 * screenScale, 35 * screenScale
        local rectX, rectY = -rectW / 2, -rectH + 45 * screenScale
        draw.RoundedBox(8, rectX, rectY, rectW, rectH, Color(18, 18, 18, alpha))
        draw.SimpleText("Keith", "Trebuchet24", 0, 10 * screenScale, Color(240, 240, 240, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Tour Guide", "Trebuchet18", 0, 30 * screenScale, Color(150, 150, 150, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end