include("shared.lua")

local function GetRainbowColor(frequency)
    local time = CurTime() * frequency
    return Color(
        math.sin(time) * 127 + 128,
        math.sin(time + 2) * 127 + 128,
        math.sin(time + 4) * 127 + 128
    )
end

local rotationAngle = 0

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 30)
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    local interact = Config.Lang["Interact"]

    cam.Start3D2D(pos, ang, 0.1)
        local text = self:GetStationName() == "" and interact or self:GetStationName()

        if self:GetStationName() ~= "" then
            local rainbowColor = GetRainbowColor(2)
            rotationAngle = rotationAngle + 2
            if rotationAngle >= 360 then rotationAngle = 0 end

            draw.SimpleText(text, "BoomboxFont", 0, 0, rainbowColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(text, "BoomboxFont", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

surface.CreateFont("BoomboxFont", {
    font = "Roboto",
    size = 100,
    weight = 700,
})

net.Receive("UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()

    if IsValid(entity) and entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        entity:SetStationName(stationName)
    end
end)
