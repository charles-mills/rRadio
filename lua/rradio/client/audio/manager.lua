rRadio = rRadio or {}
rRadio.Audio = rRadio.Audio or {}

local Audio = rRadio.Audio
local activeStreams = {}      -- entIndex -> BASS handle
local targetVolumes = {}      -- entIndex -> volume (0-1)
local lastSpatialUpdate = {}  -- entIndex -> CurTime

local SPATIAL_TICK = 0.12     -- was way too aggressive before
local MAX_DISTANCE = 1200
local FALL_OFF = 1.4

local function IsValidStream(ent)
    return IsValid(ent) and activeStreams[ent:EntIndex()]
end

local function StopStream(ent)
    local idx = ent:EntIndex()
    local stream = activeStreams[idx]
    
    if IsValid(stream) then
        stream:Stop()
        stream = nil
    end
    
    activeStreams[idx] = nil
    targetVolumes[idx] = nil
    lastSpatialUpdate[idx] = nil
end

local function Update3DSound(ent)
    local idx = ent:EntIndex()
    local stream = activeStreams[idx]
    if not IsValid(stream) then return end

    local now = CurTime()
    if (lastSpatialUpdate[idx] or 0) + SPATIAL_TICK > now then return end
    lastSpatialUpdate[idx] = now

    local pos = ent:GetPos()
    stream:SetPos(pos)

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local dist = pos:Distance(ply:EyePos())
    local vol = math.max(0, 1 - (dist / MAX_DISTANCE)) ^ FALL_OFF

    -- Quick and dirty occlusion
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = pos + Vector(0, 0, 35),
        filter = {ply, ent},
        mask = MASK_SOLID
    })

    if tr.Hit then
        vol = vol * 0.4
    end

    stream:SetVolume(vol * (targetVolumes[idx] or 1))
end

-- Public API (kept simple)
function Audio.Play(ent, url, volume)
    if not IsValid(ent) then return end
    
    -- Kill old one first
    StopStream(ent)

    volume = math.Clamp(volume or 0.7, 0, 1)
    targetVolumes[ent:EntIndex()] = volume

    sound.PlayURL(url, "3d mono noplay", function(snd, errCode, err)
        if not IsValid(snd) then
            -- TODO: better error feedback to player
            print("[rRadio] Failed to play: " .. (err or "unknown"))
            return
        end

        activeStreams[ent:EntIndex()] = snd
        snd:Play()
    end)
end

function Audio.Stop(ent)
    if IsValid(ent) then
        StopStream(ent)
    end
end

function Audio.SetVolume(ent, vol)
    if IsValid(ent) then
        targetVolumes[ent:EntIndex()] = math.Clamp(vol, 0, 1)
    end
end

-- Main loop - much lighter now
hook.Add("Think", "rRadio.AudioThink", function()
    for idx, stream in pairs(activeStreams) do
        local ent = Entity(idx)
        if IsValid(ent) and IsValid(stream) then
            Update3DSound(ent)
        else
            StopStream(ent or {EntIndex = function() return idx end})
        end
    end
end)

-- Cleanup on removal
hook.Add("EntityRemoved", "rRadio.CleanStreams", function(ent)
    if IsValid(ent) then
        StopStream(ent)
    end
end)
