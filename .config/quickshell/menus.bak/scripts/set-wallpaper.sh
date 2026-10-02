#!/bin/sh
# Usage:
#   set-wallpaper.sh /path/to/image.jpg    apply + remember
#   set-wallpaper.sh --restore             re-apply the remembered one (use at login)
#
# Uses swaybg (sway). To use swww/awww or something else, only edit the
# "apply" block at the bottom.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-menus"
STATE="$CACHE/wallpaper"
mkdir -p "$CACHE"

if [ "$1" = "--restore" ]; then
    [ -f "$STATE" ] || exit 0
    IMG="$(cat "$STATE")"
else
    IMG="$1"
fi

[ -f "$IMG" ] || exit 1
[ "$1" = "--restore" ] || printf '%s\n' "$IMG" > "$STATE"

# ---- apply ----
OLD="$(pgrep -x swaybg)"
setsid -f swaybg -i "$IMG" -m fill >/dev/null 2>&1
sleep 0.3
[ -n "$OLD" ] && kill $OLD 2>/dev/null
exit 0
