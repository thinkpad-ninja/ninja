#!/bin/bash
# Toggle the built-in touchpad on/off at runtime.

DEVICE="elan0676:00-04f3:3195-touchpad"
STATE_FILE="$HOME/.config/hypr/.touchpad-disabled"

if [ -f "$STATE_FILE" ]; then
  hyprctl keyword "device[$DEVICE]:enabled" true >/dev/null
  rm -f "$STATE_FILE"
  notify-send -i input-touchpad "Touchpad" "enabled" --expire-time=1500 --urgency=low --transient
else
  hyprctl keyword "device[$DEVICE]:enabled" false >/dev/null
  touch "$STATE_FILE"
  notify-send -i input-touchpad "Touchpad" "disabled" --expire-time=1500 --urgency=low --transient
fi
