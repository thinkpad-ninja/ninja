#!/bin/bash
# Toggle ThinkPad trackpoint (nub) between default and low sensitivity (-0.4).

DEVICE="tpps/2-synaptics-trackpoint"
STATE_FILE="$HOME/.config/hypr/.trackpoint-low"

if [ -f "$STATE_FILE" ]; then
  hyprctl keyword "device[$DEVICE]:sensitivity" 0 >/dev/null
  rm -f "$STATE_FILE"
  notify-send -i input-mouse "Trackpoint" "sensitivity 0 (default)" --expire-time=1500 --urgency=low --transient
else
  hyprctl keyword "device[$DEVICE]:sensitivity" -0.4 >/dev/null
  hyprctl keyword "device[$DEVICE]:accel_profile" adaptive >/dev/null
  touch "$STATE_FILE"
  notify-send -i input-mouse "Trackpoint" "sensitivity -0.4 (low)" --expire-time=1500 --urgency=low --transient
fi
