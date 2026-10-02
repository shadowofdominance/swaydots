#!/bin/sh
# Usage:
#   set-live-wallpaper.sh /path/to/video.mp4   play as wallpaper + remember
#   set-live-wallpaper.sh --stop               stop it and go back to the static wallpaper
#   set-live-wallpaper.sh --restore            re-start the remembered one
#
# Needs mpvpaper. Video is muted and looped.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-menus"
LIVE="$CACHE/live-wallpaper"
DIR="$(dirname "$0")"
mkdir -p "$CACHE"

case "$1" in
    --stop)
        rm -f "$LIVE"
        pkill -x mpvpaper
        exec sh "$DIR/set-wallpaper.sh" --restore
        ;;
    --restore)
        [ -f "$LIVE" ] || exit 0
        VID="$(cat "$LIVE")"
        ;;
    *)
        VID="$1"
        [ -f "$VID" ] || exit 1
        printf '%s\n' "$VID" > "$LIVE"
        ;;
esac

[ -f "$VID" ] || exit 1

OLD="$(pgrep -x mpvpaper)"
pkill -x swaybg
setsid -f mpvpaper -o "no-audio loop-file=inf hwdec=auto panscan=1.0" '*' "$VID" >/dev/null 2>&1
sleep 0.5
[ -n "$OLD" ] && kill $OLD 2>/dev/null
exit 0
