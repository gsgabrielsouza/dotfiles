#!/usr/bin/env bash
set -euo pipefail

id="${1:?}"
icon="${2:?}"
output="${WAYBAR_OUTPUT_NAME:-}"
cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-ws-cache.json"
lock="${cache}.lock"

refresh_cache() {
  local now mtime
  now="$(date +%s)"
  if [[ -f "$cache" ]]; then
    mtime="$(stat -c %Y "$cache" 2>/dev/null || echo 0)"
    if (( now - mtime < 1 )) && [[ -s "$cache" ]]; then
      return 0
    fi
  fi
  (
    flock -n 9 || exit 0
    local active workspaces
    active="$(hyprctl activeworkspace -j 2>/dev/null)"
    workspaces="$(hyprctl workspaces -j 2>/dev/null)"
    jq -nc --argjson active "$active" --argjson workspaces "$workspaces" \
      '{active:{id:$active.id,monitor:$active.monitor}, workspaces: ($workspaces | map({id, monitor, windows}))}' \
      >"${cache}.tmp"
    mv -f "${cache}.tmp" "$cache"
  ) 9>"$lock"
}

refresh_cache

if [[ ! -s "$cache" ]]; then
  printf '%s\n' '{"text":"","class":"hidden","tooltip":""}'
  exit 0
fi

jq -nc --argjson id "$id" --arg icon "$icon" --arg output "$output" --slurpfile c "$cache" '
  ($c[0].workspaces | map(select(.id == $id)) | .[0]) as $ws
  | if $ws == null then
      {text:"", class:"hidden", tooltip:""}
    elif ($output != "" and $ws.monitor != $output) then
      {text:"", class:"hidden", tooltip:""}
    else
      (if ($c[0].active.id == $id) then "active"
       elif ($ws.windows > 0) then "occupied"
       else "empty" end) as $class
      | {
          text: $icon,
          class: $class,
          tooltip: (
            if $class == "active" then "Workspace \($id) · ativo"
            elif $class == "occupied" then "Workspace \($id) · \($ws.windows) janela(s)"
            else "Workspace \($id) · vazio" end
          )
        }
    end
'
