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

volume_osd() {
    local line value muted=0 icon
    line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
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
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        volume_osd
        ;;
    volume-down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        volume_osd
        ;;
    volume-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        volume_osd
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
