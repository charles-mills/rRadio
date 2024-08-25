util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")


net.Receive("PlayCarRadioStation", function(len, ply)
    local status, err = pcall(function()
        local url = net.ReadString()
        local vehicle = ply:GetVehicle()
        if IsValid(vehicle) and url ~= "" then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(vehicle)
            net.WriteString(url)
            net.Broadcast()
        else
            error("Invalid vehicle or URL")
        end
    end)
    if not status then
        print("Error in PlayCarRadioStation: " .. err)
    end
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local status, err = pcall(function()
        local vehicle = ply:GetVehicle()
        if IsValid(vehicle) then
            net.Start("StopCarRadioStation")
            net.WriteEntity(vehicle)
            net.Broadcast()
        else
            error("Invalid vehicle")
        end
    end)
    if not status then
        print("Error in StopCarRadioStation: " .. err)
    end
end)

