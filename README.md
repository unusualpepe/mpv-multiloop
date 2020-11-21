# mpv-multiloop
Loop over multiple A-B points in mpv.

![screenshot](/img/screenshot.png)

## Installation
Place `multiloop.lua` in your scripts folder, generally `~/.config/mpv/scripts/` (GNU/Linux) or `%AppData%\mpv\scripts\` (Windows), or start mpv with `--scripts=/path/to/multiloop.lua`.

## Usage
The script is activated by the M (shift+m) key. This can be changed by editing the `keybind` variable at the beginning of the file.

Follow the on-screen instructions.
If you decide to save the A-B points for future use, a file with the same name as the file you are playing and "mab" extension will be created. The points will be restored from this file when activating the script.

~~Once looping, to exit you'll have to quit mpv.~~
