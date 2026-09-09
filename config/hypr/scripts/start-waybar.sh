#!/usr/bin/env bash
set -euo pipefail

waybar_bin="${HOME}/.local/bin/waybar"
if [[ ! -x "$waybar_bin" ]]; then
    waybar_bin="$(command -v waybar)"
fi

if [[ -z "${waybar_bin}" || ! -x "$waybar_bin" ]]; then
    notify-send -u critical "Waybar" "Binário não encontrado."
    exit 1
fi

if ! ldd "$waybar_bin" 2>/dev/null | grep -q "not found"; then
    exec "$waybar_bin" "$@"
fi

missing="$(ldd "$waybar_bin" 2>/dev/null | awk '/not found/{print $1}' | paste -sd' ' -)"
notify-send -u critical "Waybar" "Biblioteca ausente: ${missing}. Instale com: sudo pacman -S gpsd"
exit 1
