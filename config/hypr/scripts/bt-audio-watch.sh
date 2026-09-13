#!/usr/bin/env bash
set -euo pipefail

ROUTE="${HOME}/.config/hypr/scripts/bt-audio-route.sh"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/bt-audio-watch.lock"

if [[ "${1:-}" != "--run" ]]; then
  nohup "$0" --run >/dev/null 2>&1 &
  exit 0
fi

exec 9>"$LOCK"
flock -n 9 || exit 0

[[ -x "$ROUTE" ]] || exit 0
"$ROUTE" || true

while true; do
  pactl subscribe 2>/dev/null | while read -r event; do
    case "$event" in
      *"new sink"*|*"remove sink"*|*"new source"*|*"remove source"*)
        "$ROUTE" || true
        ;;
    esac
  done
  sleep 1
done
