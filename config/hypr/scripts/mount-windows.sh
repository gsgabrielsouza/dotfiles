#!/usr/bin/env bash
set -euo pipefail

uuid=7A8E5C018E5BB3FB
dev=/dev/disk/by-uuid/$uuid
fstab_mp=/mnt/windows

notify() {
  command -v hyprctl >/dev/null || return 0
  hyprctl notify 3 7000 "rgb(ed8796)" "$1" >/dev/null 2>&1 || true
}

mountpoint_of() {
  findmnt -n -o TARGET -S UUID="$uuid" 2>/dev/null | head -n1
}

if [[ -z $(mountpoint_of) ]]; then
  if [[ -d $fstab_mp ]] && grep -Fq "$uuid" /etc/fstab 2>/dev/null; then
    if ! mount "$fstab_mp" >/dev/null; then
      notify "Não foi possível montar o Windows. Desative a Inicialização Rápida e desligue o Windows por completo."
      exit 1
    fi
  elif command -v udisksctl >/dev/null; then
    if ! udisksctl mount -b "$dev" >/dev/null; then
      notify "Não foi possível montar o Windows. Desative a Inicialização Rápida e desligue o Windows por completo."
      exit 1
    fi
  else
    notify "Partição Windows não montada. Configure o fstab no terminal."
    exit 1
  fi
fi

root=$(mountpoint_of)
if [[ -z $root ]]; then
  notify "Partição Windows não montada. Configure o fstab no terminal."
  exit 1
fi

ln -sfn "$root" "$HOME/windows"
