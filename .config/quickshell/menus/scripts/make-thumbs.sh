#!/bin/sh
# Usage: make-thumbs.sh <video> <thumb.jpg> [<video> <thumb.jpg> ...]
# Creates a preview frame for every video that doesn't have one yet (needs ffmpeg).
while [ $# -ge 2 ]; do
    v="$1"; t="$2"; shift 2
    [ -f "$t" ] && continue
    mkdir -p "$(dirname "$t")"
    ffmpeg -nostdin -loglevel error -y -ss 2 -i "$v" -frames:v 1 -vf "scale=800:-2" "$t" 2>/dev/null \
        || ffmpeg -nostdin -loglevel error -y -i "$v" -frames:v 1 -vf "scale=800:-2" "$t" 2>/dev/null
done
exit 0
