if SERVER then
    util.AddNetworkString("OpenCarDealerMenu")
    util.AddNetworkString("BuyCar")

if CLIENT then
    net.Receive("OpenCarDealerMenu", function()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Car Dealer")
        frame:SetSize(ScrW() * 0.5, ScrH() * 0.7) -- Responsive width and height
        frame:Center()
        frame:SetDraggable(true)
        frame:MakePopup()
        frame:ShowCloseButton(true)
        frame:SetDeleteOnClose(true)

        -- Apply a modern background color
        frame:SetBackgroundBlur(true)
        frame.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(30, 30, 30, 230)) -- Dark semi-transparent background
        end

        local carList = vgui.Create("DListView", frame)
        carList:Dock(LEFT)
        carList:SetWidth(frame:GetWide() * 0.3) -- 30% width of the frame
        carList:AddColumn("Car").Header:SetTextColor(Color(255, 255, 255))
        carList:AddColumn("Price").Header:SetTextColor(Color(255, 255, 255))

        carList.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(50, 50, 50, 200))
        end

        -- Populate the car list from the config
        local cars = CarDealerConfig.Cars
        for _, car in ipairs(cars) do
            carList:AddLine(car.name, car.price)
        end

        -- Define the previewPanel after the car list is created and populated
        local previewPanel = vgui.Create("DModelPanel", frame)
        previewPanel:Dock(FILL)
        previewPanel:SetModel("models/props_c17/oildrum001.mdl") -- Default model
        previewPanel:SetFOV(70)
        previewPanel:SetCamPos(Vector(250, 250, 150))
        previewPanel:SetLookAt(Vector(0, 0, 40))

        previewPanel.LayoutEntity = function(ent) return end -- Disable automatic rotation
        previewPanel.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(50, 50, 50, 200))
            if self.Entity then
                local x, y = self:LocalToScreen(0, 0)
                local camPos = self.CamPos or Vector(0, 0, 0)
                local lookAt = self.LookAt or Vector(0, 0, 0)

                cam.Start3D(camPos, lookAt, self.fFOV, x, y, w, h, 5, 4096)
                render.SuppressEngineLighting(true)
                render.SetLightingOrigin(self.Entity:GetPos())
                render.ResetModelLighting(1, 1, 1)
                render.SetColorModulation(1, 1, 1)
                render.SetBlend(1)
                self.Entity:DrawModel()
                render.SuppressEngineLighting(false)
                cam.End3D()
            end
        end

        -- Now that previewPanel is properly defined, it can be accessed here
        carList.OnRowSelected = function(_, _, line)
            local carName = line:GetColumnText(1)
            local carPrice = tonumber(line:GetColumnText(2))
            local carModel = cars[line:GetID()].model

            -- Update preview panel
            if IsValid(previewPanel) then
                previewPanel:SetModel(carModel)
            end
            frame.SelectedCarName = carName
            frame.SelectedCarPrice = carPrice
        end

        local buyButton = vgui.Create("DButton", frame)
        buyButton:SetText("Buy Selected Car")
        buyButton:Dock(BOTTOM)
        buyButton:SetHeight(50)
        buyButton:SetTextColor(Color(255, 255, 255))
        buyButton:SetFont("DermaLarge")
        buyButton.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(10, 0, 0, w, h, Color(40, 150, 200)) -- Hover color
            else
                draw.RoundedBox(10, 0, 0, w, h, Color(30, 130, 170)) -- Normal color
            end
        end

        buyButton.DoClick = function()
            local selectedLine = carList:GetSelectedLine()
            if selectedLine then
                local carName = carList:GetLine(selectedLine):GetColumnText(1)
                local carPrice = tonumber(carList:GetLine(selectedLine):GetColumnText(2))

                -- Send purchase request to server
                net.Start("BuyCar")
                net.WriteString(carName)
                net.WriteInt(carPrice, 32)
                net.SendToServer()

                -- Provide feedback
                LocalPlayer():ChatPrint("Attempting to buy " .. carName .. " for $" .. carPrice .. ".")
            else
                LocalPlayer():ChatPrint("Please select a car first!")
            end
        end
    end)
end
