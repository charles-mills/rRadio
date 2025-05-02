# rRadio - Internet Radio for Garry's Mod

![Downloads](https://img.shields.io/steam/downloads/3318060741?style=for-the-badge&color=00adb5) ![Views](https://img.shields.io/steam/views/3318060741?style=for-the-badge&color=ff5719) ![Size](https://img.shields.io/steam/size/3318060741?style=for-the-badge&color=2ea043) ![Update Date](https://img.shields.io/steam/update-date/3318060741?style=for-the-badge&color=515de9)

rRadio is an internet radio addon for Garry's Mod that allows players to listen to thousands of live stations through in-game boomboxes, and in their vehicles. The addon is intended for use by public servers, with a major focus on server-side optimisation, security, and multi-client synchronisation, though remains fully compatible with singleplayer.

## Features

- Extensive list of radio stations from over 100 countries
- Intuitive user interface with multiple themes to choose from
- Favourites system for quick access to preferred stations
- Search functionality to easily find stations
- Volume control with 3D audio falloff
- Server and client-side configuration
- Custom persistence system for boomboxes

## Vehicle Radio Usage

1. Spawn a vehicle using the spawn menu (or via a third-party "car-dealer").
2. Press the "radio open key" (default: K) to open the menu.
3. Browse or search for stations, and click on a station to start playing.
4. Use the controls at the bottom of the menu to adjust the volume or stop playback.

## Boombox Usage

1. Spawn a boombox using the spawn menu (under the "rRadio" category).
2. Interact with the boombox to open the radio menu.
3. Browse or search for stations, and click on a station to start playing.
4. Use the controls at the bottom of the menu to adjust the volume or stop playback.

## Persistent Boomboxes Usage

1. Spawn a boombox using the spawn menu.
2. Use the boombox to open the radio menu.
3. Enter the settings menu via the cog icon.
4. Toggle the setting "Make Boombox Permanent" (Superadmins only).
5. The boombox will respawn every time the server restarts, and the last station will automatically begin playing.
6. To undo, simply uncheck the setting. You can now safely remove the boombox, or use it until the next restart.

## Configuration

You can customise various aspects of rRadio by editing the `lua/rradio/shared/sh_config.lua` file.

## Support

If you encounter any issues or have any questions, please open an issue on this GitHub repository.

## Licence

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](https://github.com/charles-mills/rRadio/blob/main/LICENSE) file for details.

## General Credits

- UI Icons by [Flaticon](https://www.flaticon.com/uicons/)
- Boombox Model by [Lemoin890](https://sketchfab.com/3d-models/90s-style-boombox-radio-low-poly-ripped-db9105533ca54470b74c48d3e3a62b49)
- Default stations list sourced from [Radio-Browser.info](https://www.radio-browser.info/)

## Translation Credits

- Turkish Translation by [NovaDiablox](https://github.com/NovaDiablox) 
