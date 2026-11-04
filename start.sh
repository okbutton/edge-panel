#!/bin/sh
# Starts the panel, unless it's already running.
dir="$(dirname "$(readlink -f "$0")")"
qs -p "$dir" ipc call panel plugin >/dev/null 2>&1 && exit 0
exec qs -p "$dir"
