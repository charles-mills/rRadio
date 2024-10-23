# rRadio

rRadio is a feature-rich radio addon for Garry's Mod that allows players to listen to various online radio stations through in-game boomboxes and in their vehicles. The addon is intended for use by public servers, with a major focus on server-side optimisation, security, and multi-client synchronisation.

![](https://github.com/charles-mills/rRadio/blob/main/helpers/boombox_playing.gif)

## Features

- Extensive list of radio stations from over 100 countries
- Intuitive user interface with multiple themes to choose from
- Favourites system for quick access to preferred stations
- Search functionality to easily find stations
- Volume control with 3D audio falloff
- Server- and client-side configuration
- Custom persistence system for boomboxes

## Installation

1. Clone this repository or download the ZIP file.
2. Place the `rradio` folder in your server's `addons` directory.
3. Upload the `models` and `materials` directories to the workshop, or use your own model, to allow clients to download the boombox model (Optional - Multiplayer Only).
4. Restart your server or change the map to load the addon.

## Vehicle Radio Usage

1. Spawn a vehicle using the spawn menu (or via a third-party "car-dealer").
2. Press the "radio open key" (default: K) to open the menu.
3. Browse or search for stations, and click on a station to start playing.
4. Use the controls at the bottom of the menu to adjust the volume or stop playback.

## Boombox Usage

1. Spawn a boombox using the spawn menu (under the "rRadio" category).
2. Use the boombox to open the radio menu.
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

You can customise various aspects of rRadio by editing the `lua/rradio/sh_rradio_config.lua` file. This includes:

- Menu dimensions
- Default volume
- Audio distance settings
- Maximum number of favourites
- Cache settings

## Adding Custom Stations

To add custom stations:

1. Create a new Lua file in the `lua/rradio/stations/` directory.
2. Follow the format of existing station files to add your stations.
3. Restart the server or change the map to load the new stations.

## Demo Video

Watch a demo of the rRadio addon in action on [YouTube](https://www.youtube.com/watch?v=ghL9JCKeZMI).

## Support

If you encounter any issues or have any questions, please open an issue on this GitHub repository.

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

## Licence

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](https://github.com/charles-mills/rRadio/blob/main/LICENSE) file for details.

## Credits

- Created by Charles Mills
- UI Icons by [Flaticon](https://www.flaticon.com/uicons/)
- Default stations list sourced from [Radio-Browser.info](https://www.radio-browser.info/)

## Support

If you encounter any issues or have any questions, please open an issue on this GitHub repository.
