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
- **Home Assistant screen.** Tap the house in the header for your smart home. It opens on an energy overview like Home Assistant's energy dashboard, then
  one page per room of lights, switches, scenes, thermostats, media players and more.
- **System screen.** Tap the chip in the header for this computer's CPU, memory, GPU,
  network and disks, with live graphs, and the processes using the most CPU.
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
- Optionally, `nethogs`, for every program's network use (see the System section)
- Python 3, for the Home Assistant screen
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
| `skin` | `"matte-black"` | The panel's look: a file in `skins/`, or `"omarchy"` (see Skins) |

The `EDGE_SCREEN` environment variable overrides `screen`, which is handy for trying the
panel on an ordinary monitor:

```sh
EDGE_SCREEN=DP-1 qs -p ~/edge-panel
```

There, the panel runs along the bottom of that monitor at the Edge's pixel size. It looks
larger than on the Edge, because the Edge has a higher pixel density (about 184 pixels
per inch, against 109 for a 27" 1440p monitor).


### Skins

A skin is a JSON file in `skins/`, named in `config.json` without its `.json`. Switching
skins, or editing the one in use, changes the panel at once. Three come with it:
`matte-black` (the default), `paper` (light) and `high-contrast`.

A skin sets any of these keys, and keys it leaves out keep Matte Black's value:

| Key | Default | Used for |
|---|---|---|
| `background` | `#090909` | Behind everything |
| `surface` | `#161616` | Buttons and cards |
| `surfacePressed` | `#2a2a2a` | A button while it's held |
| `line` | `#333333` | Button and card borders |
| `text` | `#eaeaea` | Labels and values |
| `textDim` | `#8a8a8d` | Secondary text, idle icons |
| `accent` | `#e68e0d` | Active buttons, the current tab, graphs |
| `danger` | `#D35F5F` | Buttons that need a second tap |
| `font` | `JetBrainsMono Nerd Font` | All text. Use a Nerd Font, which has the icons |
| `radius` | `20` | Corner rounding, in Edge pixels |
| `gap` | `16` | Space between buttons |
| `labelSize`, `detailSize`, `iconSize` | `32`, `26`, `72` | Text and icon sizes |

```json
{ "background": "#1e1e2e", "surface": "#313244", "accent": "#f5c2e7", "radius": 32 }
```

The skin `"omarchy"` takes its colours from your current Omarchy theme, and changes when
you switch theme.

## Home Assistant

Tap the house in the header and the home screen slides in from the right. To go back,
tap the arrow or drag from its left edge. Its
pages swipe sideways, and the tabs in its header jump straight to a page.

To connect it, create a long-lived access token in Home Assistant (your profile,
**Security**, **Long-lived access tokens**). Then copy `home.example.json` to `home.json`
and fill it in:

```json
{
  "url": "http://homeassistant.local:8123",
  "token": "eyJ...",
  "pages": []
}
```

`home.json` is ignored by git, so the token stays on your machine. Changes apply as soon
as it's saved.

### Energy

If Home Assistant's energy dashboard is set up, the home screen opens on an Energy page,
built from the same settings:

- the power in use now, from the grid's power sensor
- the cost so far today
- the electricity and gas used so far today, with what each cost
- a chart of today's use by the hour, stacked by source

The figures are Home Assistant's own long-term statistics, so they match its dashboard.
To leave the page out, add `"energy": false` to `home.json`.

### Rooms

With `pages` empty, there is one page for each of your Home Assistant areas, holding its
lights, switches, fans, covers, scenes, scripts, thermostats, media players, locks and
buttons. As in Home Assistant's own area cards, it leaves out entities that are disabled,
hidden, or settings and diagnostics, such as a camera's motion detection switch. It also
leaves out buttons that reboot, restart or shut down a machine, so a stray touch can't.

A room with a temperature or humidity sensor gets a **Room** tile showing them, preferring
a device that measures both (a room sensor over a thermostat). Only sensors named
`…_temperature` count, so a 3D printer's nozzle and bed readings stay out. A room whose
sensors aren't reporting yet has no tile.

If [Bermuda](https://github.com/agittins/bermuda) tracks phones by room, a **People** page
comes first after Energy, showing which room each phone is in.

To choose for yourself, list the pages:

```json
"pages": [
  { "name": "Living room", "entities": ["light.lamp", "climate.thermostat", "media_player.tv"] },
  { "name": "Scenes", "entities": ["scene.movie_night", "scene.bedtime"] }
]
```

Tapping a button does the obvious thing for its kind:

| Kind | Tap |
|---|---|
| Light, switch, fan, cover, input boolean | Toggles it. Lights show their brightness |
| Scene, script | Runs it |
| Media player | Play/pause, or turns it on |
| Thermostat | Shows the current and target temperatures, with − and + buttons beside it |
| Lock, button | Locks, unlocks or presses it, after a second tap |

A page that holds more buttons than the grid splits into several pages. States refresh
every two seconds while the home screen is showing, and energy statistics once a minute.
Neither refreshes while the home screen is closed.

The areas, the energy settings and the statistics come over Home Assistant's websocket
API, through `ha-ws.py`, a small helper that needs only Python's standard library.

## System

Tap the chip in the header for a screen about this computer:

- **CPU:** use overall and for each core, temperature, clock speed and load
- **Memory:** use, and swap
- **GPU:** use, temperature, power draw and video memory. NVIDIA cards are read with
  `nvidia-smi`, AMD and Intel ones from `/sys`
- **Network:** download and upload speeds, the interface and its address
- **Disks:** read and write speeds, and how full each filesystem is

CPU, memory, GPU and network each have a graph of the last two minutes. Swipe across,
or tap **Processes**, for the twelve busiest programs, with each one's memory and process
ID. Processes with the same name, such as Chrome's many, add up to one row, which shows how
many there are. As in `top`, 100% is one whole core. One more swipe gives **Network**: the
programs downloading and uploading the most, grouped the same way. The readings
come from `sysinfo.py`, which reads `/proc` and `/sys` every two seconds, and runs only
while the screen is showing.

### Network use by program

Linux doesn't keep count of network use per program, so the Network page measures it one
of two ways:

- **[nethogs](https://github.com/raboof/nethogs)**, if it's installed and allowed to watch
  traffic. It counts everything, including the UDP that QUIC (much of Chrome's traffic)
  and voice calls use.
- **`ss`** otherwise. It needs nothing installed, but counts only TCP, and only for your
  own programs. The page says when this is the case.

To set up nethogs on Arch, install it, let it watch traffic without root, and install the
pacman hook that does that again after each upgrade:

```sh
sudo pacman -S nethogs
sudo setcap cap_net_admin,cap_net_raw+ep /usr/bin/nethogs
sudo install -Dm644 extras/nethogs-setcap.hook /etc/pacman.d/hooks/nethogs-setcap.hook
```

The `setcap` step lets anyone who can log in to this computer see which programs use the
network, and how much. That's fine on a computer only you use; think twice on a shared
one.

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
