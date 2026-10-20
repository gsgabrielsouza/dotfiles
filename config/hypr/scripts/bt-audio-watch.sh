#!/usr/bin/env bash
set -euo pipefail

ROUTE="${HOME}/.config/hypr/scripts/bt-audio-route.sh"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/bt-audio-watch.lock"
PENDING="${XDG_RUNTIME_DIR:-/tmp}/bt-audio-watch.pending"

if [[ "${1:-}" != "--run" ]]; then
  pkill -f '/hypr/scripts/bt-audio-watch.sh --run' >/dev/null 2>&1 || true
  sleep 0.2
  nohup "$0" --run >/dev/null 2>&1 &
  exit 0
fi

if [[ -e "$LOCK" ]]; then
  fuser -k "$LOCK" >/dev/null 2>&1 || true
  sleep 0.1
fi

exec 9>"$LOCK"
flock -n 9 || exit 0

[[ -x "$ROUTE" ]] || exit 0

route_now() {
  "$ROUTE" || true
}

request_route() {
  date +%s > "$PENDING"
}

debounce_loop() {
  while true; do
    if [[ -f "$PENDING" ]]; then
      rm -f "$PENDING"
      sleep 0.6
      if [[ -f "$PENDING" ]]; then
        rm -f "$PENDING"
        sleep 0.5
      fi
      route_now
      sleep 1.2
      route_now
    else
      sleep 0.2
    fi
  done
}

watch_pactl() {
  while true; do
    pactl subscribe 2>/dev/null | while IFS= read -r event; do
      case "$event" in
        Event\ \'new\'\ on\ sink*|Event\ \'remove\'\ on\ sink*|Event\ \'new\'\ on\ card*|Event\ \'remove\'\ on\ card*)
          request_route
          ;;
      esac
    done
    sleep 1
  done
}

watch_bt() {
  while true; do
    bluetoothctl --monitor 2>/dev/null | while IFS= read -r line; do
      case "$line" in
        *"Connected: yes"*|*"Connected: no"*)
          request_route
          ;;
      esac
    done
    sleep 1
  done
}

trap 'trap - EXIT; kill $(jobs -p) 2>/dev/null || true' EXIT

rm -f "$PENDING"
route_now
debounce_loop 9>&- &
watch_pactl 9>&- &
watch_bt 9>&- &
wait
