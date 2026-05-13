rRadio = rRadio or {}
rRadio.privileges = rRadio.privileges or {}

local privileges = rRadio.privileges
local registerHookName = "rRadio_Privileges_RegisterCAMI"

privileges.ID = {
    UseAll = "rradio.UseAll",
    ManageConfig = "rradio.ManageConfig",
    ManageCustom = "rradio.ManageCustom"
}

privileges.Definitions = {
    {
        Name = privileges.ID.UseAll,
        Description = "Allows a usergroup to use all rRadio boomboxes regardless of owner.",
        MinAccess = "superadmin"
    },
    {
        Name = privileges.ID.ManageConfig,
        Description = "Allows a usergroup to manage rRadio server config and persistent boombox settings.",
        MinAccess = "superadmin"
    },
    {
        Name = privileges.ID.ManageCustom,
        Description = "Allows a usergroup to add, edit, and remove custom rRadio stations.",
        MinAccess = "superadmin"
    }
}

local function copyPrivilege( privilege )
    return {
        Name = privilege.Name,
        Description = privilege.Description,
        MinAccess = privilege.MinAccess
    }
end

function privileges.Register()
    if not CAMI or not CAMI.RegisterPrivilege then return false end

    for _, privilege in ipairs( privileges.Definitions ) do
        CAMI.RegisterPrivilege( copyPrivilege( privilege ) )
    end

    return true
end

function privileges.RegisterWhenAvailable()
    if privileges.Register() then return true end

    hook.Add( "Initialize", registerHookName, function()
        privileges.Register()
        hook.Remove( "Initialize", registerHookName )
    end )

    return false
end

return privileges
