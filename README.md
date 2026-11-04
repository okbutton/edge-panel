# Edge Panel

App-aware touch controls for the **Corsair Xeneon Edge** (14.5", 2560x720, 5-point touch)
on **Hyprland**, built with [Quickshell](https://quickshell.org).

The panel follows whichever window has focus and shows controls for that app: transport
buttons for Spotify or YouTube, the command palette and debugger for VS Code, live agent
status for [herdr](https://herdr.dev), and so on. Each app integration is a small JSON
plugin, picked up automatically.

## Features

- **Follows focus.** Switches to the focused app's controls instantly, matching on the
  window class, the window title, or a program running inside the window (herdr inside
  a terminal, for example).
- **Swipeable pages.** Swipe sideways through each app's pages. Every app also gets a
  Window page: fullscreen, maximise, float, split and close.
- **Pull-down.** Swipe down from the header for workspaces 1–6, system controls and media.
  - **System controls:** the Omarchy menu, stay awake, night light, do not disturb, mic
    mute, audio output, screenshot and lock.
  - **Media:** now playing, previous, play/pause, next, and a volume bar you drag.
- **The Omarchy menu on the Edge.** Opens the menu on the panel itself, where it works by
  touch, then returns focus to your window when it closes.
- **Nothing hides behind the panel.** A window that opens on the Edge is moved to the
  workspace you were last using.
- **Touch-safe.** The panel never takes keyboard focus, so pressing a button doesn't
  disturb the app it controls. Destructive actions can require a second tap.
- **Live reload.** Plugins and settings apply as soon as they're saved.

## Requirements

- Hyprland 0.56 or later, with its Lua configuration
- Quickshell 0.3 or later
- `wtype`, `jq` and `wpctl` (PipeWire)
- JetBrainsMono Nerd Font, for the icons
- [Omarchy](https://omarchy.org), for the menu and the system controls. The rest of the
  panel works on any Hyprland setup.

## Installation

```sh
git clone https://github.com/okbutton/edge-panel.git ~/edge-panel
~/edge-panel/start.sh
```

`start.sh` starts the panel unless it's already running. The panel finds the Edge by its
model name.

To start the panel at login on Omarchy, add this to `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("/home/you/edge-panel/start.sh")
```

To start it from the app launcher, create
`~/.local/share/applications/edge-panel.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Edge Panel
Exec=/home/you/edge-panel/start.sh
Icon=input-tablet
```

## Setting up the Edge in Hyprland

The Edge connects over HDMI, usually as `HDMI-A-1`. Give each monitor a fixed position in
`~/.config/hypr/monitors.lua`. Otherwise, adding the Edge can reorder your other monitors.
For example, to put the Edge below a 2560x1440 monitor at scale 1.25:

```lua
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x1152", scale = 1.25 })
```

Keep touches on the Edge by mapping the touchscreen to it in
`~/.config/hypr/input.lua`:

```lua
hl.config({ input = { touchdevice = { output = "HDMI-A-1" } } })
```

If the Edge is mounted upside down, for example to route its cable, rotate both its
display and its touch input. Add `transform = 2` to the Edge's `hl.monitor` line, and
`transform = 2` to `touchdevice`.

The panel compensates for any scale, so one layout pixel is always one screen pixel.

## Settings

`config.json` applies as soon as it is saved:

| Key | Default | Does |
|---|---|---|
| `aboveFullscreen` | `false` | `true` keeps the panel above fullscreen windows, including the screensaver |
| `buttonColumns` | `6` | Columns of buttons on fixed pages. Live pages, such as herdr's, fill the page |
| `buttonRows` | `3` | Rows of buttons on fixed pages. A page shows at most columns × rows buttons |
| `screen` | `""` | A monitor name such as `DP-1`. Leave empty to find the Edge |

The `EDGE_SCREEN` environment variable overrides `screen`, which is handy for trying the
panel on an ordinary monitor:

```sh
EDGE_SCREEN=DP-1 qs -p ~/edge-panel
```

There, the panel runs along the bottom of that monitor at the Edge's pixel size. It looks
larger than on the Edge, because the Edge has a higher pixel density (about 184 pixels
per inch, against 109 for a 27" 1440p monitor).

## Included plugins

| Plugin | Matches |
|---|---|
| herdr | herdr running in the focused terminal. Live agent and workspace tiles, panes, Claude Code keys |
| Terminal | foot, Alacritty, kitty, Ghostty |
| Chrome | Google Chrome and Chromium |
| YouTube | YouTube in Chrome or as a web app |
| Netflix, Disney+ | Their players in Chrome or as web apps |
| Spotify | Spotify |
| mpv | mpv |
| Image Viewer | imv |
| VS Code | Visual Studio Code |
| Obsidian | Obsidian |
| Discord | Discord, desktop or web app |
| Files | GNOME Files (Nautilus) |
| LibreOffice | All LibreOffice apps |
| Documents | GNOME Papers and Evince |
| Desktop | Everything else |

## Writing a plugin

A plugin is one JSON file in `plugins/`. Add one and it's detected automatically, with
nothing to register.

```json
{
  "name": "My App",
  "icon": "",
  "match": { "app": "^myapp$" },
  "pages": [
    {
      "name": "Main",
      "actions": [
        { "icon": "", "label": "Play", "keys": "space" },
        { "icon": "", "label": "Quit", "keys": "ctrl+q", "danger": true, "confirm": true }
      ]
    }
  ]
}
```

Icons are Nerd Font characters, written as `\uXXXX` escapes. Every plugin gets the Window
page last, unless it sets `"windowPage": false`.

### Matching

`match` decides when a plugin applies. If several plugins match, the most specific wins,
so file order doesn't matter. A plugin with no `match` is the fallback.

| Key | Matches | Score |
|---|---|---|
| `process` | The exact name of a process running inside the focused window | 4 |
| `title` | A regular expression on the window title | 2 |
| `app` | A case-insensitive regular expression on the window class | 1 |

Run `hyprctl activewindow` to find a window's class and title.

### Actions

Each action does one of these:

| Key | Does |
|---|---|
| `keys` | Sends a key chord such as `ctrl+shift+t` to the focused window. Key names are XKB names: `Left`, `Return`, `F5`, `space`, `slash` |
| `run` | Runs a command, given as an array of arguments |
| `hypr` | Runs a Hyprland dispatcher, such as `hl.dsp.window.close()` |

An action can also set `"danger": true` for red styling, or `"confirm": true` to need a
second tap.

### Live pages

A page can be filled by a command instead of a fixed list:

```json
{ "name": "Agents", "live": { "command": ["sh", "-c", "..."], "interval": 2000 } }
```

The command must print a JSON array of actions, and runs only while its page is showing.
Live actions can also set `detail` (a second line of text), `status` (`working`,
`blocked` or `done`, which colours the button) and `active` (an outline). See
`plugins/herdr.json` for an example.

Plugins can run any command, so only install plugins you trust, as you would any script.

## Limitations

- **Shifted symbols:** keys are sent with `wtype`, whose keymap has no Shift level. The
  panel handles Shift with a letter, but a chord like `shift+slash` may not produce `?`.
- **Process matching:** this looks at every program under the focused window. A plugin
  that matches a program run in one herdr pane therefore applies whichever pane has
  focus.
