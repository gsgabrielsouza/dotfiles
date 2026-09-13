#!/usr/bin/env bash
set -euo pipefail

osd() {
    local tag="$1" icon="$2" value="$3"
    dunstify \
        -a "$tag" \
        -u low \
        -t 1500 \
        -h "string:x-dunst-stack-tag:${tag}" \
        -h "int:value:${value}" \
        "${icon}  ${value}%"
}

volume_id() {
    local id
    id="$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | sed -n 's/.*[^0-9]\([0-9][0-9]*\)\. EDIFIER.*/\1/p' | head -n1)"
    if [[ -z "$id" ]]; then
        id="$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | sed -n 's/.*[^0-9]\([0-9][0-9]*\)\. .*Speaker.*/\1/p' | head -n1)"
    fi
    if [[ -n "$id" ]]; then
        printf '%s\n' "$id"
    else
        printf '%s\n' '@DEFAULT_AUDIO_SINK@'
    fi
}

volume_osd() {
    local id="$1"
    local line value muted=0 icon
    line="$(wpctl get-volume "$id")"
    value="$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$line")"
    [[ "$line" == *MUTED* ]] && muted=1
    if ((muted == 1)); then
        icon="󰝟"
    elif ((value == 0)); then
        icon=""
    elif ((value < 50)); then
        icon=""
    else
        icon=""
    fi
    osd volume "$icon" "$value"
}

brightness_osd() {
    local value
    value="$(brightnessctl -m | cut -d, -f4 | tr -d '%')"
    osd brightness "󰃠" "$value"
}

case "${1:-}" in
    volume-up)
        id="$(volume_id)"
        wpctl set-volume -l 1 "$id" 5%+
        volume_osd "$id"
        ;;
    volume-down)
        id="$(volume_id)"
        wpctl set-volume "$id" 5%-
        volume_osd "$id"
        ;;
    volume-mute)
        id="$(volume_id)"
        wpctl set-mute "$id" toggle
        volume_osd "$id"
        ;;
    brightness-up)
        brightnessctl -e4 -n2 set 5%+ >/dev/null
        brightness_osd
        ;;
    brightness-down)
        brightnessctl -e4 -n2 set 5%- >/dev/null
        brightness_osd
        ;;
    *)
        exit 1
        ;;
esac
