#!/bin/sh
# Starts the panel, unless it's already running.
dir="$(dirname "$(readlink -f "$0")")"
qs -p "$dir" ipc call panel plugin >/dev/null 2>&1 && exit 0

# Omarchy sometimes comes up at login without the wallpaper drawn on the Edge, leaving
# flat grey behind a see-through panel. Loading the current wallpaper again a little
# later fixes it.
if command -v omarchy-shell >/dev/null 2>&1; then
  (
    sleep 5
    background="$(readlink -f "$HOME/.local/state/omarchy/current/background")"
    [ -e "$background" ] && timeout 3 omarchy-shell background setInstant "$background" >/dev/null 2>&1
  ) &
fi

exec qs -p "$dir"
