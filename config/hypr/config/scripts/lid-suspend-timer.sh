#!/bin/bash
# Two-stage timer triggered by lid close.
#   T+13 min: downgrade power profile to balanced if currently performance
#   T+20 min: systemctl suspend, but only if the "armed" flag file exists
# Lid open cancels everything.
#
# Usage: lid-suspend-timer.sh arm|cancel|toggle-arm|status

PIDFILE="/tmp/hypr-lid-suspend.pid"
ARM_FLAG="$HOME/.config/hypr/.suspend-armed"
PROFILE_DELAY=780   # 13 minutes
SUSPEND_DELAY=1200  # 20 minutes

lid_closed() {
  grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null
}

cancel_timer() {
  [ -f "$PIDFILE" ] || return 0
  pid=$(cat "$PIDFILE")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    # Kill children first (sleep), then the timer shell itself
    pkill -TERM -P "$pid" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null
  fi
  rm -f "$PIDFILE"
}

case "$1" in
  arm)
    cancel_timer
    (
      my_pid=$BASHPID
      # Only remove pidfile if it still belongs to this run (avoids races on re-arm)
      cleanup() { [ "$(cat "$PIDFILE" 2>/dev/null)" = "$my_pid" ] && rm -f "$PIDFILE"; }
      trap 'kill $(jobs -p) 2>/dev/null; cleanup; exit 0' TERM INT
      sleep "$PROFILE_DELAY" & wait $!
      if lid_closed && [ "$(powerprofilesctl get)" = "performance" ]; then
        powerprofilesctl set balanced
      fi
      sleep "$((SUSPEND_DELAY - PROFILE_DELAY))" & wait $!
      if lid_closed && [ -f "$ARM_FLAG" ]; then
        systemctl suspend
      fi
      cleanup
    ) </dev/null >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    ;;
  cancel)
    cancel_timer
    ;;
  toggle-arm)
    if [ -f "$ARM_FLAG" ]; then
      rm -f "$ARM_FLAG"
      notify-send -i system-suspend "off"
    else
      touch "$ARM_FLAG"
      notify-send -i system-suspend "on"
    fi
    ;;
  status)
    if [ -f "$ARM_FLAG" ]; then echo "on"; else echo "off"; fi
    ;;
esac
