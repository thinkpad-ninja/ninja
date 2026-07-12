#!/usr/bin/env bash
if pgrep -x espanso >/dev/null; then
  espanso stop
  notify-send "off" --expire-time=1500 --urgency=low
else
  espanso start 2>/dev/null || { espanso service register >/dev/null 2>&1 && espanso start; }
  notify-send "on" --expire-time=1500 --urgency=low
fi
