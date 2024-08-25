-- car_dealer_purchase.lua (Server-Side)

if SERVER then
    util.AddNetworkString("BuyCar")
    util.AddNetworkString("SpawnVehicle")

    -- Function to handle buying a car
    net.Receive("BuyCar", function(len, ply)
        local carName = net.ReadString()
        local carPrice = net.ReadInt(32)

        -- Check if the player can afford the car
        if ply:canAfford(carPrice) then
            ply:addMoney(-carPrice)

            -- Prepare to spawn the car
            net.Start("SpawnVehicle")
            net.WriteString(carName)
            net.Send(ply)
        else
            ply:ChatPrint("You cannot afford this car.")
        end
    end)

    -- Function to handle vehicle spawning
    net.Receive("SpawnVehicle", function(len, ply)
        local carName = net.ReadString()
        local carData = nil
        
        -- Find the car data from the config
        for _, car in ipairs(CarDealerConfig.Cars) do
            if car.name == carName then
                carData = car
                break
            end
        end

        if carData then
            -- Debug print to confirm vehicle spawning
            print("Spawning vehicle:", carData.name, "for player:", ply:Nick())

            -- Ensure the model and script path are correct
            local car = ents.Create("prop_vehicle_jeep")
            if not IsValid(car) then 
                print("Failed to create vehicle entity!")
                return 
            end

            car:SetModel(carData.model)
            car:SetKeyValue("vehiclescript", "scripts/vehicles/jeep_test.txt") -- Ensure this script is correct
            car:SetPos(ply:GetPos() + ply:GetForward() * 100 + Vector(0, 0, 50)) -- Adjust the position
            car:Spawn()
            car:Activate()

            if IsValid(car) then
                car:SetNWString("VehicleName", carName)

                -- Set the owner of the car
                car.vowner = ply
                ply.ActiveVeh = car
                ply:ChatPrint("You have successfully bought a " .. carName .. "!")
            else
                ply:ChatPrint("Failed to spawn the vehicle.")
            end

        else
            ply:ChatPrint("Car data not found.")
        end
    end)
end
