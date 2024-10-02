--[[ 
    rRadio Addon for Garry's Mod - Client Boombox Script
    Description: Manages client-side boombox functionalities and UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

include("shared.lua")
include("misc/config.lua")

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

    if GetConVar("boombox_show_text"):GetBool() then
        local pos = self:GetPos() + Vector(0, 0, 30)
        local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

        -- Default text for unauthorized users
        local text = Config.Lang and Config.Lang["PAUSED"] or "PAUSED"
        local color = Color(255, 255, 255, 255)

        local interact = Config.Lang and Config.Lang["Interact"] or "Press E to Interact"

        -- Check if the LocalPlayer is the owner or a superadmin
        local owner = self:GetNWEntity("Owner")
        if LocalPlayer() == owner or LocalPlayer():IsSuperAdmin() then
            text = interact
        end

        -- If the station name is not empty, show it to all players
        if self:GetStationName() ~= "" then
            text = self:GetStationName()
            color = GetRainbowColor(2)

            rotationAngle = rotationAngle + 2
            if rotationAngle >= 360 then rotationAngle = 0 end
        end

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleText(text, "BoomboxFont", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

surface.CreateFont("BoomboxFont", {
    font = "Roboto",
    size = 100,
    weight = 700,
})

net.Receive("UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()

    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
        entity:SetStationName(stationName)
    end
end)
