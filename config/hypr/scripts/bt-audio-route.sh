#!/usr/bin/env bash
set -euo pipefail

EE_OUT="ee_soe_output_level"
speaker_sink() {
  pactl list short sinks 2>/dev/null | awk '/HiFi__Speaker__sink/ { print $2; exit }'
}

bt_sink() {
  pactl list short sinks 2>/dev/null | awk '/bluez_output\./ { print $2; exit }'
}

laptop_mic() {
  pactl list short sources 2>/dev/null | awk '/HiFi__Mic1__source$/ { print $2; exit }'
}

unlink_port() {
  local port="$1"
  local target
  while read -r target; do
    [[ -n "$target" ]] || continue
    pw-link -d "$port" "$target" 2>/dev/null || true
  done < <(pw-link -l 2>/dev/null | awk -v p="$port" '
    $0 == p { found=1; next }
    found && $1 == "|->" { print $2; next }
    found && $0 != "" && $1 != "|<-" && $1 != "|->" { exit }
  ')
}

link_ee_to_sink() {
  local sink="$1"
  command -v pw-link >/dev/null 2>&1 || return 0
  pw-link -io 2>/dev/null | grep -qx "${EE_OUT}:output_FL" || return 0
  pw-link -io 2>/dev/null | grep -qx "${sink}:playback_FL" || return 0
  unlink_port "${EE_OUT}:output_FL"
  unlink_port "${EE_OUT}:output_FR"
  pw-link "${EE_OUT}:output_FL" "${sink}:playback_FL" 2>/dev/null || true
  pw-link "${EE_OUT}:output_FR" "${sink}:playback_FR" 2>/dev/null || true
}

bt="$(bt_sink || true)"
speaker="$(speaker_sink || true)"

if [[ -n "$bt" ]]; then
  hardware="$bt"
else
  hardware="$speaker"
fi

[[ -n "$hardware" ]] || exit 0

link_ee_to_sink "$hardware"
pactl set-sink-mute "$hardware" 0 >/dev/null 2>&1 || true
pactl set-default-sink "$hardware" >/dev/null 2>&1 || true

if [[ -n "$bt" && -n "$speaker" ]]; then
  pactl set-sink-mute "$speaker" 1 >/dev/null 2>&1 || true
elif [[ -n "$speaker" ]]; then
  pactl set-sink-mute "$speaker" 0 >/dev/null 2>&1 || true
fi

mic="$(laptop_mic || true)"
if [[ -n "$mic" ]]; then
  pactl set-source-mute "$mic" 0 >/dev/null 2>&1 || true
  pactl set-default-source "$mic" >/dev/null 2>&1 || true
fi
