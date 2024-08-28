include("shared.lua")

-- Function to generate a rainbow color effect
local function GetRainbowColor(frequency)
    local time = CurTime() * frequency
    return Color(
        math.sin(time) * 127 + 128,
        math.sin(time + 2) * 127 + 128,
        math.sin(time + 4) * 127 + 128
    )
end

local radioStatus = ""
local rotationAngle = 0

function ENT:Draw()
    self:DrawModel()

    -- Add 3D2D text rendering
    local pos = self:GetPos() + Vector(0, 0, 30)  -- Position the text above the boombox
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)  -- Face the text towards the player

    cam.Start3D2D(pos, ang, 0.1)  -- The scale of the text (0.1 can be adjusted)
        local text = radioStatus == "" and "E to Interact" or radioStatus

        if radioStatus ~= "" then
            local rainbowColor = GetRainbowColor(2)

            -- Apply spinning effect to the text
            rotationAngle = rotationAngle + 2
            if rotationAngle >= 360 then rotationAngle = 0 end

            draw.SimpleText(text, "BoomboxFont", 0, 0, rainbowColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            -- Draw default white text for "E to Interact"
            draw.SimpleText(text, "BoomboxFont", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

-- Create a font for the boombox HUD
surface.CreateFont("BoomboxFont", {
    font = "Roboto",
    size = 100,  -- Set a fixed size for your text
    weight = 700,
})

-- Receive the station status update from the server
net.Receive("UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()

    if IsValid(entity) and entity:GetClass() == "boombox" then
        radioStatus = stationName
    end
end)
