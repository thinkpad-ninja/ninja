#!/bin/bash

MONITOR="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')"
STATE_FILE="/tmp/brightness-toggle-high-state"

current="$(cat "$STATE_FILE" 2>/dev/null || echo "100")"

if [ "$current" = "5" ]; then
    next=100
else
    next=5
fi

swayosd-client --monitor "$MONITOR" --brightness "$next"
echo "$next" > "$STATE_FILE"
