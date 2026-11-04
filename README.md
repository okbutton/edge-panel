# Edge panel

Controls for a Corsair Xeneon Edge (2560x720, 14.5", 5-point touch) that follow the
focused app. Built with Quickshell on Hyprland.

    ./start.sh                                 # run, unless already running; plugin edits reload live
    qs -p ~/Work/edge-panel                    # run another copy
    EDGE_SCREEN=DP-2 qs -p ~/Work/edge-panel   # another monitor instead of the Edge

Pull down from the header for workspaces and media. Swipe sideways to change page.

## Settings

`config.json` applies as soon as it is saved:

| Key | Default | Does |
|---|---|---|
| `aboveFullscreen` | `false` | `true` keeps the panel above fullscreen windows, including the screensaver |
| `screen` | `""` | a monitor name such as `DP-1`; empty finds the Edge. `EDGE_SCREEN` overrides it |

Until the Edge arrives this runs along the bottom of a normal monitor at the same pixel
size. Text and buttons appear about 1.7 times larger there than on the Edge: 27" at
1440p is about 109 pixels per inch, the Edge about 184.

## Plugins

An integration is one JSON file in `plugins/`. Drop one in and it is detected
automatically; there is nothing to register. Every plugin gets a Window page at the end,
unless it sets `"windowPage": false`.

    {
      "name": "My App",
      "icon": "",
      "match": { "app": "myapp" },
      "pages": [
        { "name": "Main", "actions": [
          { "icon": "", "label": "Play", "keys": "space" }
        ] }
      ]
    }

`match` decides when the plugin applies. If several match, the most specific wins, so
file order doesn't matter. A plugin with no `match` is the fallback.

| Key | Matches | Score |
|---|---|---|
| `process` | exact name of a process running inside the focused window | 4 |
| `title` | regular expression on the window title | 2 |
| `app` | case-insensitive regular expression on the window class | 1 |

An action does one of these, and may add `"danger": true` for red styling or
`"confirm": true` to need a second tap:

| Key | Does |
|---|---|
| `keys` | sends a chord such as `ctrl+t` to the focused window |
| `run` | runs a command, as an array of arguments |
| `hypr` | runs a Hyprland dispatcher, such as `hl.dsp.window.close()` |

A page can be live instead of fixed: `"live": { "command": [...], "interval": 2000 }`
runs a command that prints a JSON array of actions, while that page is showing. Those
actions can also have `detail`, `status` (`working`, `blocked`, `done`) and `active`.
See `plugins/herdr.json`.
