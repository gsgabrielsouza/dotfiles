#!/usr/bin/env bash
set -euo pipefail

deadline=$((SECONDS + 20))

while (( SECONDS < deadline )); do
  if [[ -e /sys/module/nvidia_drm ]] && [[ -e /dev/dri/card0 ]] && [[ -e /dev/dri/card1 ]]; then
    sleep 0.5
    exit 0
  fi
  sleep 0.2
done

exit 0
