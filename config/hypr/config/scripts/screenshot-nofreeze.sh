#!/bin/bash
# Screenshot without wayfreeze. Replaces omarchy-cmd-screenshot's smart mode.
# Region select with slurp -> annotate in satty -> save to ~/Pictures.

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

pkill slurp && exit 0

get_rectangles() {
  local ws
  ws=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
  hyprctl monitors -j | jq -r --arg ws "$ws" '.[] | select(.activeWorkspace.id == ($ws | tonumber)) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"'
  hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

RECTS=$(get_rectangles)
SELECTION=$(echo "$RECTS" | slurp 2>/dev/null)

if [[ "$SELECTION" =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]]; then
  if (( BASH_REMATCH[3] * BASH_REMATCH[4] < 20 )); then
    cx="${BASH_REMATCH[1]}"; cy="${BASH_REMATCH[2]}"
    while IFS= read -r rect; do
      if [[ "$rect" =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+) ]]; then
        rx="${BASH_REMATCH[1]}"; ry="${BASH_REMATCH[2]}"
        rw="${BASH_REMATCH[3]}"; rh="${BASH_REMATCH[4]}"
        if (( cx >= rx && cx < rx+rw && cy >= ry && cy < ry+rh )); then
          SELECTION="${rx},${ry} ${rw}x${rh}"
          break
        fi
      fi
    done <<< "$RECTS"
  fi
fi

[ -z "$SELECTION" ] && exit 0

grim -g "$SELECTION" - |
  satty --filename - \
    --output-filename "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy' \
    --disable-notifications
