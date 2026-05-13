rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.visibility = rRadio.client.hud.visibility or {}

local visibility = rRadio.client.hud.visibility
local stateModule = rRadio.client.hud.state

local REFRESH_INTERVAL = 0.1
local MAX_VISIBLE = 64
local FADE_START_SQR = 400 * 400
local FADE_END_SQR = 500 * 500
local FADE_RANGE_INV = 1 / ( FADE_END_SQR - FADE_START_SQR )

local registered = {}
local lookup = setmetatable( {}, { __mode = "k" } )
local visible = {}
local registeredCount = 0
local visibleCount = 0
local lastRefresh = 0


local function removeFromVisible( hudState )
    for index = visibleCount, 1, -1 do
        if visible[index] == hudState then
            visible[index] = visible[visibleCount]
            visible[visibleCount] = nil
            visibleCount = visibleCount - 1
            return
        end
    end
end


local function removeRegisteredState( hudState )
    local index = hudState.registerIndex
    if not index then return end

    local last = registered[registeredCount]
    registered[index] = last
    registered[registeredCount] = nil
    registeredCount = math.max( 0, registeredCount - 1 )

    if last and last ~= hudState then last.registerIndex = index end
    lookup[hudState.entity] = nil
    hudState.registerIndex = nil
    removeFromVisible( hudState )
end


local function compareDistance( left, right )
    return left.distanceSqr < right.distanceSqr
end


function visibility.Register( entity )
    local existing = lookup[entity]
    if existing then return existing end

    local hudState = stateModule.Create( entity )
    registeredCount = registeredCount + 1
    registered[registeredCount] = hudState
    hudState.registerIndex = registeredCount
    lookup[entity] = hudState

    return hudState
end


function visibility.Unregister( entity )
    local hudState = lookup[entity]
    if not hudState then return false end

    removeRegisteredState( hudState )
    return true
end


function visibility.Refresh( player, now )
    if now - lastRefresh < REFRESH_INTERVAL then return end

    lastRefresh = now
    visibleCount = 0

    local eyePos = player:EyePos()
    for index = registeredCount, 1, -1 do
        local hudState = registered[index]
        local entity = hudState.entity
        if not IsValid( entity ) then
            removeRegisteredState( hudState )
        else
            local distanceSqr = eyePos:DistToSqr( entity:GetPos() )
            if distanceSqr < FADE_END_SQR then
                local fade = 1 - ( distanceSqr - FADE_START_SQR ) * FADE_RANGE_INV
                local alpha = math.Clamp( 255 * fade, 0, 255 )
                if alpha > 0 then
                    hudState.distanceSqr = distanceSqr
                    hudState.alpha = alpha
                    visibleCount = visibleCount + 1
                    visible[visibleCount] = hudState
                end
            end
        end
    end

    visible[visibleCount + 1] = nil

    if visibleCount <= MAX_VISIBLE then return end

    table.sort( visible, compareDistance )
    for index = visibleCount, MAX_VISIBLE + 1, -1 do
        visible[index] = nil
    end
    visibleCount = MAX_VISIBLE
end


function visibility.GetVisible()
    return visible, visibleCount
end


function visibility.CountRegistered()
    return registeredCount
end


function visibility.MarkAllLayoutDirty()
    for index = 1, registeredCount do
        stateModule.MarkLayoutDirty( registered[index] )
    end
end


function visibility.GetStats()
    return {
        registered = registeredCount,
        visible = visibleCount,
        lastRefresh = lastRefresh,
        maxVisible = MAX_VISIBLE
    }
end


return visibility
