--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Shared API functions for the rRadio addon, providing interfaces
    for module registration and hook management.
]]

function rRadio.RegisterModule(name, module)
    rRadio.Modules[name] = module
end

function rRadio.GetModule(name)
    return rRadio.Modules[name]
end

function rRadio.AddHook(hookName, functionName, func)
    hook.Add(hookName, "rRadio_" .. functionName, func)
end
