#!/bin/sh
# Run this at login: brings back the live wallpaper if one was active, otherwise the static one.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-menus"
DIR="$(dirname "$0")"
if [ -f "$CACHE/live-wallpaper" ]; then
    exec sh "$DIR/set-live-wallpaper.sh" --restore
else
    exec sh "$DIR/set-wallpaper.sh" --restore
fi
