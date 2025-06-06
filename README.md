# rRadio - Stream Live Internet Radio in Garry's Mod

rRadio is an internet-radio add-on for Garry's Mod. Stream thousands of live stations straight to in-game boomboxes or in your vehicle. Built for playing alone, with friends, or large public servers.

[![Steam](https://img.shields.io/badge/steam-%23000000.svg?style=for-the-badge&logo=steam&logoColor=white)](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) [![Lua](https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white)](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) [![Downloads](https://img.shields.io/steam/downloads/3318060741?style=for-the-badge&color=00adb5)](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) [![Size](https://img.shields.io/steam/size/3318060741?style=for-the-badge&color=2ea043)](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) [![Update Date](https://img.shields.io/steam/update-date/3318060741?style=for-the-badge&color=515de9)](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741)

## Key Features

- **Global Stations:** Tune in to stations from 100+ countries.
- **Favourites:** Bookmark your go-to stations for quick access.
- **Modern UI with Themes:** Pick from 6+ clientside themes.
- **Persistent Boomboxes:** Optionally make your boombox respawn after a restart.

## Getting Started

It is recommended to install via the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3318060741) for automatic updates. 

### Vehicle Radio
1. Spawn a vehicle via the spawn menu or a third-party car dealer.
2. Press the **Menu Open** key (default K) to bring up the menu.
3. Browse or search for a station and click to start playback.
4. Use the menu controls to adjust volume or stop the stream.

### Boombox
1. Spawn a boombox from the spawn menu (**rRadio** category) or via the DarkRP F4 menu.
2. Interact with the boombox to open the radio menu.
3. Choose a station to start listening.
4. Adjust volume or stop playback via the menu controls.

### Changing Your Theme
1. Open the radio menu via a boombox *or* vehicle.
2. Open **Settings** (cog icon).
3. Select the theme drop-down.
4. Choose a theme.

### Persistent Boomboxes (Superadmins)
1. Spawn and interact with a boombox.
2. Open **Settings** (cog icon).
3. Enable **Make Boombox Permanent**
4. The boombox will now respawn after a server restart and resume the last station.
5. Disable the setting to revert to normal behaviour, then delete the boombox as needed.

## Configuration

### Clientside Settings

Clientside settings are configurable via the Garry's Mod console and rRadio Settings menu. Press ``` ` ``` (left of 1) to open console.

```lua
rammel_rradio_boombox_hud <boolean>    -- Toggle visibility of boombox HUDs (1 - Enabled / 0 - Disabled)
rammel_rradio_enabled <boolean>        -- Toggle all functionality of rRadio (1 - Enabled / 0 - Disabled)
```
```lua
rammel_rradio_menu_key <integer>       -- The key used to open the menu. Modify this via the Settings menu.
rammel_rradio_menu_theme <string>      -- The theme applied to the rRadio UI. Modify this via the Settings menu.
```

### Global (Serverside) Settings

Global settings must be locally configured in [sh_config.lua](lua/rradio/shared/sh_config.lua).

```lua
rRadio.config.SecureStationLoad = false  -- block playing stations not in the client's list
rRadio.config.DriverPlayOnly = false     -- only allow driver to control radio
rRadio.config.AnimationDefaultOn = true  -- enable animations by default
rRadio.config.ClientHardDisable = false  -- disables file loading when client's rradio_enabled convar is set to 0
rRadio.config.DisablePushDamage = true  -- disable push damage
rRadio.config.PrioritiseCustom  = true -- the custom / server added station category will appear at the top of the menu
rRadio.config.AllowCreatePermanentBoombox = true -- allow new permanent boomboxes to be created by superadmins
```
```lua
rRadio.config.CustomStationCategory = "Custom"
rRadio.config.CommandAddStation = "!rradioadd"
rRadio.config.CommandRemoveStation = "!rradiorem"
```

## Screenshots

![The rRadio boombox next to a vehicle](https://github.com/user-attachments/assets/6461ae96-7deb-4da8-8c82-398e0adff39a)
![The rRadio main interface, listing available countries](https://github.com/user-attachments/assets/371abaf1-a5ee-4863-b3e2-bf46d510f848)

## Support

If you encounter any issues or have any questions, please open an issue on this GitHub repository. Alternatively, contact me on [Steam](https://steamcommunity.com/id/rammel/).

## General Credits

- UI Icons by [Flaticon](https://www.flaticon.com/uicons/)
- Boombox Model by [Lemoin890](https://sketchfab.com/3d-models/90s-style-boombox-radio-low-poly-ripped-db9105533ca54470b74c48d3e3a62b49)
- Default stations list sourced from [Radio-Browser.info](https://www.radio-browser.info/)

## Translation Credits

- Turkish Translation by [NovaDiablox](https://github.com/NovaDiablox)
