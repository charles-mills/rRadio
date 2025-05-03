rRadio.sv = rRadio.sv or {}
rRadio.sv.utils = rRadio.sv.utils or {}

function rRadio.sv.utils.InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    if not rRadio.sv.EntityVolumes[entIndex] then
        rRadio.sv.EntityVolumes[entIndex] = rRadio.sv.utils.GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", rRadio.sv.EntityVolumes[entIndex])
    end
end

function rRadio.sv.utils.BroadcastStop(ent)
    net.Start("StopCarRadioStation")
    net.WriteEntity(ent)
    net.Broadcast()
end

function rRadio.sv.utils.CanControlRadio(entity, ply)
    if not IsValid(entity) or not IsValid(ply) then return false end

    if rRadio.utils.IsBoombox(entity) then
        return rRadio.utils.canInteractWithBoombox(ply, entity)
    end

    local veh = rRadio.utils.GetVehicle(entity)
    if IsValid(veh) then
        if not rRadio.config.DriverPlayOnly or veh:GetDriver() == ply then
            return true
        end
    end

    return false
end

function rRadio.sv.utils.ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

function rRadio.sv.utils.GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local class = entity:GetClass()
    if class == "golden_boombox" then
        return GetConVar("rammel_rradio_sv_gold_default_volume"):GetFloat()
    elseif class == "boombox" then
        return GetConVar("rammel_rradio_sv_boombox_default_volume"):GetFloat()
    else
        return GetConVar("rammel_rradio_sv_vehicle_default_volume"):GetFloat()
    end
end