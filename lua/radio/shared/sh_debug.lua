local Debug = {
    enabled = CreateConVar("radio_debug", "0", FCVAR_ARCHIVE, "Enable debug logging for radio system"),
    
    Log = function(self, ...)
        if not self.enabled:GetBool() then return end
        print("[Radio Debug]", ...)
    end,
    
    Error = function(self, ...)
        ErrorNoHalt("[Radio Error]", ...)
    end,
    
    Warning = function(self, ...)
        print("[Radio Warning]", ...)
    end,
    
    Trace = function(self, ...)
        if not self.enabled:GetBool() then return end
        local info = debug.getinfo(2, "Sl")
        print(string.format("[Radio Trace] %s:%d", info.short_src, info.currentline), ...)
    end
}

-- Initialize the module
_G.RadioDebug = Debug

return Debug 