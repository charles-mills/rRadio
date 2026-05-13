rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.commands = rRadio.radio.commands or {}

local commands = rRadio.radio.commands
local customStations = rRadio.radio.customStations
local permissions = rRadio.radio.permissions
local stateStore = rRadio.radio.stateStore


local function sendChat( player, message )
    if IsValid( player ) then player:ChatPrint( "[rRadio] " .. message ) end
end


local function printCommandLine( player, ... )
    local parts = {}
    for index = 1, select( "#", ... ) do
        parts[index] = tostring( select( index, ... ) )
    end

    local line = table.concat( parts, " " )
    if IsValid( player ) then
        player:PrintMessage( HUD_PRINTCONSOLE, line )
    else
        print( line )
    end
end


local function registerListCustomCommand()
    concommand.Remove( "rammel_rradio_list_custom" )
    concommand.Add( "rammel_rradio_list_custom", function( player )
        if IsValid( player ) and not permissions.CanManageCustomStations( player ) then
            sendChat( player, "You do not have permission to manage custom stations." )
            return
        end

        local stations = customStations.List()
        if #stations == 0 then
            printCommandLine( player, "[rRadio] No custom stations found." )
            return
        end

        for _, station in ipairs( stations ) do
            printCommandLine( player, "[rRadio]", station.id, station.name )
        end
    end )
end


local function registerActiveRadioCommand()
    concommand.Remove( "rammel_rradio_list_active" )
    concommand.Add( "rammel_rradio_list_active", function( player )
        if IsValid( player ) and not player:IsAdmin() then
            sendChat( player, "You do not have permission to list active radios." )
            return
        end

        if stateStore.CountActive() == 0 then
            printCommandLine( player, "[rRadio] No active server radios." )
            return
        end

        stateStore.ForEach( function( state )
            printCommandLine(
                player,
                "[rRadio]",
                state.entityIndex,
                state.stationID,
                state.stationName,
                state.volume
            )
        end )
    end )
end


local function isRadioEntity( entity )
    if not IsValid( entity ) then return false end
    if rRadio.util.IsBoomboxClass( entity:GetClass() ) then return true end

    return rRadio.vehicle.IsRadioHost( entity )
end


local function registerEntityStateCommand()
    concommand.Remove( "rammel_rradio_list_entities" )
    concommand.Add( "rammel_rradio_list_entities", function( player )
        if IsValid( player ) and not player:IsAdmin() then
            sendChat( player, "You do not have permission to list radio entities." )
            return
        end

        local count = 0
        for _, entity in ents.Iterator() do
            if isRadioEntity( entity ) then
                count = count + 1
                local hadRuntimeState = type( entity.rRadioState ) == "table"
                local indexed = stateStore.Get( entity ) ~= nil
                local state = stateStore.GetEntityState( entity )
                local settings = state and state.settings or {}
                local assignment = state and state.assignment
                printCommandLine(
                    player,
                    "[rRadio]",
                    entity:EntIndex(),
                    entity:GetClass(),
                    "state=" .. tostring( hadRuntimeState ),
                    "assignment=" .. tostring( assignment ~= nil ),
                    "indexed=" .. tostring( indexed ),
                    "permanent=" .. tostring( settings.permanent == true ),
                    "public=" .. tostring( settings.public == true ),
                    "volume=" .. tostring( settings.defaultVolume or 0 ),
                    "station=" .. tostring( assignment and assignment.stationID or "" )
                )
            end
        end

        if count == 0 then printCommandLine( player, "[rRadio] No radio-capable entities found." ) end
    end )
end


function commands.Register()
    registerListCustomCommand()
    registerActiveRadioCommand()
    registerEntityStateCommand()
end


return commands
