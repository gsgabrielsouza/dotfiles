#!/usr/bin/env bash
set -euo pipefail

bluetoothctl power on >/dev/null
sleep 1

while read -r _ mac _; do
  [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || continue
  connected=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/^\tConnected:/{print $2; exit}')
  [[ $connected == yes ]] && continue
  bluetoothctl connect "$mac" >/dev/null 2>&1 || true
done < <(bluetoothctl devices Paired 2>/dev/null || true)
