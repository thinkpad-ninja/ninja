#!/usr/bin/env bash
# Hard thermal guard: pauses (SIGSTOP) the fuzzer processes when the CPU gets
# too hot and resumes (SIGCONT) them once it cools. Hysteresis avoids rapid
# stop/start flapping.
#
# Unlike a package-only reading (which on this Ultra 9 285H lags the real
# hotspots), this watches the MAX temperature across every coretemp input
# (all cores + package), so the true hottest core drives the decision. Tjmax
# on this part is 105C; the defaults keep it hot but with a safe margin.

set -u

HOT_C=${HOT_C:-92}      # pause fuzzers at/above this max-core temp (deg C)
COOL_C=${COOL_C:-85}    # resume fuzzers once back at/below this temp (deg C)
POLL_S=${POLL_S:-0.3}   # seconds between checks (fractional ok)
MATCH=${MATCH:-build-fuzz/fuzz/}   # pgrep pattern selecting the workload
LOG=${LOG:-/home/x/.local/state/fuzz-thermal-guard.log}

mkdir -p "$(dirname "$LOG")"

# Collect the temperature input files that represent CPU die temperatures:
# every temp*_input under the coretemp hwmon. Falls back to the x86_pkg_temp
# thermal zone if coretemp is unavailable.
declare -a TEMP_INPUTS=()
discover_inputs() {
  local d f
  for d in /sys/class/hwmon/hwmon*; do
    [ -r "$d/name" ] || continue
    if [ "$(cat "$d/name" 2>/dev/null)" = "coretemp" ]; then
      for f in "$d"/temp*_input; do
        [ -r "$f" ] && TEMP_INPUTS+=("$f")
      done
    fi
  done
  if [ "${#TEMP_INPUTS[@]}" -eq 0 ]; then
    for d in /sys/class/thermal/thermal_zone*; do
      if [ "$(cat "$d/type" 2>/dev/null)" = "x86_pkg_temp" ]; then
        TEMP_INPUTS+=("$d/temp")
      fi
    done
  fi
  [ "${#TEMP_INPUTS[@]}" -gt 0 ]
}

# Echo the hottest reading (deg C) across all inputs.
read_max_c() {
  local f raw max=0
  for f in "${TEMP_INPUTS[@]}"; do
    raw=$(cat "$f" 2>/dev/null) || continue
    raw=$(( raw / 1000 ))
    [ "$raw" -gt "$max" ] && max=$raw
  done
  [ "$max" -gt 0 ] || return 1
  echo "$max"
}

signal_fuzzers() {
  local sig=$1 pids
  pids=$(pgrep -f "$MATCH")
  [ -n "$pids" ] || return 1
  kill -"$sig" $pids 2>/dev/null
  return 0
}

log() { echo "$(date -Is) $*" >>"$LOG"; }

# Always resume the fuzzers if the guard itself is terminated, so a killed
# guard never leaves the workload stuck in SIGSTOP.
cleanup() { signal_fuzzers CONT; log "guard exiting, resumed fuzzers"; }
trap cleanup EXIT
trap 'exit 0' INT TERM

discover_inputs || { log "FATAL: no CPU temp sensor found"; exit 1; }
log "guard started (HOT=${HOT_C} COOL=${COOL_C} inputs=${#TEMP_INPUTS[@]} match=${MATCH})"

paused=0
while true; do
  t=$(read_max_c) || { sleep "$POLL_S"; continue; }
  if [ "$paused" -eq 1 ]; then
    if [ "$t" -le "$COOL_C" ]; then
      signal_fuzzers CONT
      paused=0
      log "RESUMED fuzzers at ${t}C (<= ${COOL_C})"
    else
      # Re-assert STOP every poll so libFuzzer workers respawned while paused
      # cannot leak CPU and keep the package hot.
      signal_fuzzers STOP
    fi
  elif [ "$t" -ge "$HOT_C" ]; then
    if signal_fuzzers STOP; then
      paused=1
      log "PAUSED fuzzers at ${t}C (>= ${HOT_C})"
    fi
  fi
  sleep "$POLL_S"
done
