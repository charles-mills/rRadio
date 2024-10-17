# rRadio

rRadio is a feature-rich radio addon for Garry's Mod that allows players to listen to various online radio stations through in-game boomboxes.

## Features

- Extensive list of radio stations from various countries
- Intuitive and sleek user interface with dark mode support
- Favorites system for quick access to preferred stations
- Search functionality to easily find stations
- Volume control with 3D audio falloff
- Recent stations list
- Customizable configuration

## Installation

1. Clone this repository or download the ZIP file.
2. Place the `rradio` folder in your server's `addons` directory.
3. Upload the models and materials directories to the workshop, or use your own model, to allow clients to download the boombox model (Optional - Multiplayer Only)
5. Restart your server or change the map to load the addon.

## Usage

1. Spawn a rRadio boombox using the spawn menu (under the "rRadio" category).
2. Use the boombox to open the radio menu.
3. Browse or search for stations, and click on a station to start playing.
4. Use the controls at the bottom of the menu to adjust volume or stop playback.

## Configuration

You can customize various aspects of rRadio by editing the `lua/rradio/sh_rradio_config.lua` file. This includes:

- Menu dimensions
- Default volume
- Audio distance settings
- Maximum number of favorites
- Cache settings

## Adding Custom Stations

To add custom stations:

1. Create a new Lua file in the `lua/rradio/stations/` directory.
2. Follow the format of existing station files to add your stations.
3. Restart the server or change the map to load the new stations.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](https://github.com/charles-mills/rRadio/blob/main/LICENSE) file for details.

## Credits

- Created by Charles Mills
- UI Icons by [Flaticon](https://www.flaticon.com/uicons/")
- Default stations list sourced from [Radio-Browser.info](https://www.radio-browser.info/)

## Support

If you encounter any issues or have any questions, please open an issue on this GitHub repository.
