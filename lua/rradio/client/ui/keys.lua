rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.keys = rRadio.client.ui.keys or {}

local keys = rRadio.client.ui.keys

local function addKey( set, keyCode )
    if keyCode then set[keyCode] = true end
end

keys.Menu = {
    MoveUp = KEY_UP,
    MoveDown = KEY_DOWN,
    PageUp = KEY_PAGEUP,
    PageDown = KEY_PAGEDOWN,
    Home = KEY_HOME,
    End = KEY_END,
    Activate = KEY_ENTER,
    ActivatePad = KEY_PAD_ENTER,
    ActivateSpace = KEY_SPACE,
    Search = KEY_SLASH,
    Favourite = KEY_F,
    Global = KEY_G,
    Settings = KEY_S,
    Back = KEY_BACKSPACE,
    VolumeDown = KEY_LEFT,
    VolumeUp = KEY_RIGHT,
    LeftShift = KEY_LSHIFT,
    RightShift = KEY_RSHIFT,
    LeftControl = KEY_LCONTROL,
    RightControl = KEY_RCONTROL,
    LeftAlt = KEY_LALT,
    RightAlt = KEY_RALT
}

local function buildMenuControlKeySet()
    local set = {}

    addKey( set, keys.Menu.MoveUp )
    addKey( set, keys.Menu.MoveDown )
    addKey( set, keys.Menu.PageUp )
    addKey( set, keys.Menu.PageDown )
    addKey( set, keys.Menu.Home )
    addKey( set, keys.Menu.End )
    addKey( set, keys.Menu.Activate )
    addKey( set, keys.Menu.ActivatePad )
    addKey( set, keys.Menu.ActivateSpace )
    addKey( set, keys.Menu.Search )
    addKey( set, keys.Menu.Favourite )
    addKey( set, keys.Menu.Global )
    addKey( set, keys.Menu.Settings )
    addKey( set, keys.Menu.Back )
    addKey( set, keys.Menu.VolumeDown )
    addKey( set, keys.Menu.VolumeUp )
    addKey( set, keys.Menu.LeftShift )
    addKey( set, keys.Menu.RightShift )
    addKey( set, keys.Menu.LeftControl )
    addKey( set, keys.Menu.RightControl )
    addKey( set, keys.Menu.LeftAlt )
    addKey( set, keys.Menu.RightAlt )

    return set
end

local menuControlKeySet = buildMenuControlKeySet()

local function copySet( set )
    local copy = {}
    for keyCode in pairs( set ) do
        copy[keyCode] = true
    end

    return copy
end

function keys.GetMenuKeyBlockedKeys()
    local blockedKeys = copySet( menuControlKeySet )

    addKey( blockedKeys, MOUSE_LEFT )
    addKey( blockedKeys, KEY_NONE )

    return blockedKeys
end

return keys
