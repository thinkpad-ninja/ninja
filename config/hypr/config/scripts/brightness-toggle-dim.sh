
#!/bin/bash

MONITOR="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')"
STATE_FILE="/tmp/brightness-toggle-dim-state"

current="$(cat "$STATE_FILE" 2>/dev/null || echo "0")"

if [[ "$current" == "26" ]]; then
    swayosd-client --monitor "$MONITOR" --brightness 0
    echo "0" > "$STATE_FILE"
else
    swayosd-client --monitor "$MONITOR" --brightness 26
    echo "26" > "$STATE_FILE"
fi
