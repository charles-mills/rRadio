surface.CreateFont("DigitalFont", {
    font = "Digital-7",
    size = 48, 
    weight = 500,
    antialias = true,
    additive = false,
})

local currentRPM = 2000  -- Initialize current RPM to 2000

hook.Add("HUDPaint", "DrawSpeedometer", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:InVehicle() or ply ~= ply:GetVehicle():GetDriver() then return end

    -- Get the vehicle name
    local vehicleName = "Unknown Vehicle"
    if VC and ply:GetVehicle().VC_getName then
        vehicleName = ply:GetVehicle():VC_getName()
    elseif ply:GetVehicle().GetVehicleClass then
        vehicleName = ply:GetVehicle():GetVehicleClass()  -- fallback to vehicle class name
    end

    if vehicleName == nil then
        return -- Hacky little workaround to not draw speedo for passengers
    end

    local scrW, scrH = ScrW(), ScrH()
    local scaleW = scrW / 1920
    local scaleH = scrH / 1080

    -- Dimensions and positioning for the main HUD elements
    local boxW, boxH = 225 * scaleW, 130 * scaleH
    local borderThickness = 4 * scaleW
    local padding = 8 * scaleW
    local x = 10 * scaleW
    local y = scrH - boxH - 10 * scaleH

    -- Dimensions and positioning for the speedometer
    local speedoBoxW, speedoBoxH = 300 * scaleW, 65 * scaleH  -- Half the height of the main HUD
    local speedoX = (scrW - speedoBoxW) / 2  -- Centered horizontally
    local speedoY = scrH - speedoBoxH - 10 * scaleH  -- Bottom-aligned with the main HUD

    -- Vehicle Name Box Dimensions and Positioning
    local nameBoxW, nameBoxH = speedoBoxW, 20 * scaleH  -- Same width as the speedo box
    local nameBoxX = speedoX  -- Align with speedo box horizontally
    local nameBoxY = speedoY - nameBoxH + 0.5 * scaleH  -- Positioned on top of the speedo box

    -- Draw the vehicle name box
    draw.RoundedBox(0, nameBoxX, nameBoxY, nameBoxW, nameBoxH, Color(18, 18, 18))
    draw.SimpleText(vehicleName, "Trebuchet18", nameBoxX + nameBoxW / 2, nameBoxY + nameBoxH / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Draw the speedometer box
    draw.RoundedBox(0, speedoX, speedoY, speedoBoxW, speedoBoxH, Color(18, 18, 18))

    -- Speed Calculation
    local speed = math.Round(ply:GetVehicle():GetVelocity():Length() * 0.0568182) -- Convert units/s to MPH

    -- Speed Display using the digital font
    draw.SimpleText(speed .. " MPH", "DigitalFont", speedoX + speedoBoxW / 2, speedoY + padding, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- Target RPM Calculation
    local targetRPM
    if speed < 5 then  -- Simulate idling behavior when speed is low
        targetRPM = 3000 + math.random(-50, 50)  -- Idle RPM fluctuates between 2950 and 3050
    else
        targetRPM = math.Clamp(math.Round(speed * 45) + 2000, 2000, 11000)  -- RPM based on speed, minimum 2000
    end

    -- Smoothly interpolate currentRPM towards targetRPM with a slower transition
    currentRPM = Lerp(FrameTime() * 2, currentRPM, targetRPM)

    -- Ensure the currentRPM is clamped to a minimum of 2000 at all times
    currentRPM = math.max(currentRPM, 2000)

    -- Determine the color of the RPM bar
    local rpmColor
    if currentRPM <= 7000 then
        rpmColor = Color(0, 255, 0)  -- Green
    elseif currentRPM <= 9000 then
        rpmColor = Color(255, 165, 0)  -- Orange
    else
        rpmColor = Color(255, 0, 0)  -- Red
    end

    -- Calculate the width of the RPM bar based on the current RPM value
    local rpmBarWidth = ((currentRPM - 2000) / 9000) * (speedoBoxW - 2 * padding)  -- Adjusted for 2000-11000 range

    -- Draw the RPM bar
    draw.RoundedBox(0, speedoX + padding, speedoY + speedoBoxH / 2 + padding, rpmBarWidth, 10 * scaleH, rpmColor)
end)
