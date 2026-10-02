#!/usr/bin/env bash
# ~/.config/waybar/scripts/window-title.sh
# Streams the focused window's title to Waybar's custom module (one JSON line per change).
# Uses `driftwm msg --json subscribe` (pushes state on change; no polling). Needs jq.

driftwm msg --json subscribe \
  | jq --unbuffered -c '
      ([.State.windows[]? | select(.is_focused and (.suspended | not))][0]) as $w
      | if $w == null
        then {text: "", class: "empty"}
        else {
          text:    ($w.title // $w.app_id // ""),
          tooltip: (($w.app_id // "") + "\n" + ($w.title // "")),
          class:   "active"
        }
        end' \
  | awk '$0 != prev { print; fflush(); prev = $0 }'   # drop repeats (state arrives every frame while panning)
