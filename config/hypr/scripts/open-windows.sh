#!/usr/bin/env bash
set -euo pipefail

uuid=7A8E5C018E5BB3FB
file_manager=nemo

notify() {
  command -v hyprctl >/dev/null || return 0
  hyprctl notify 3 7000 "rgb(ed8796)" "$1" >/dev/null 2>&1 || true
}

mountpoint_of() {
  findmnt -n -o TARGET -S UUID="$uuid" 2>/dev/null | head -n1
}

skip_user() {
  case $1 in
    Public|Default|'Default User'|'All Users') return 0 ;;
  esac
  return 1
}

find_source() {
  local root=$1
  local preferred=$root/Users/gabri/source
  if [[ -d $preferred ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local d user
  for d in "$root"/Users/*/source; do
    [[ -d $d ]] || continue
    user=$(basename "$(dirname "$d")")
    skip_user "$user" && continue
    printf '%s\n' "$d"
    return 0
  done
  return 1
}

"${BASH_SOURCE[0]%/*}/mount-windows.sh"

root=$(mountpoint_of)
if [[ -z $root ]]; then
  notify "Partição Windows não montada. Configure o fstab no terminal."
  exit 1
fi

target=$(find_source "$root" || true)
if [[ -z ${target:-} ]]; then
  if [[ -d $root/Users ]]; then
    target=$root/Users
  else
    target=$root
  fi
  notify "Pasta source não encontrada. Abrindo ${target}"
fi

exec "$file_manager" "$target"
