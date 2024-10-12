function rRadio.RegisterModule(name, module)
    rRadio.Modules[name] = module
end

function rRadio.GetModule(name)
    return rRadio.Modules[name]
end

function rRadio.AddHook(hookName, functionName, func)
    hook.Add(hookName, "rRadio_" .. functionName, func)
end
