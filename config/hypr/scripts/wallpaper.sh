#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wallpapers}"
HYPRLAND_WALLPAPER_DIR="${HYPRLAND_WALLPAPER_DIR:-/usr/share/hypr}"
INTERVAL="${INTERVAL:-300}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-index"
FIT_MODE="cover"

collect_wallpapers() {
    local dir file base resolved
    local -A seen=()
    local -a dirs=("$WALLPAPER_DIR" "$HOME/wallpaper" "$HYPRLAND_WALLPAPER_DIR")

    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        resolved="$(readlink -f "$dir")"
        [[ -n "${seen[$resolved]:-}" ]] && continue
        seen[$resolved]=1

        while IFS= read -r file; do
            base="${file##*/}"
            case "$base" in
                lockdead*) continue ;;
            esac
            printf '%s\n' "$file"
        done < <(find -L "$dir" -maxdepth 1 -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o \
            -iname '*.png' -o -iname '*.webp' -o \
            -iname '*.jxl' \
        \))
    done | sort
}

apply_wallpaper() {
    local wallpaper="$1"
    hyprctl hyprpaper wallpaper ",$wallpaper,$FIT_MODE" >/dev/null 2>&1
}

current_wallpaper() {
    hyprctl hyprpaper listactive 2>/dev/null | head -n1 | cut -d: -f2- | sed 's/^ *//'
}

next_wallpaper() {
    mapfile -t wallpapers < <(collect_wallpapers)
    if ((${#wallpapers[@]} == 0)); then
        exit 1
    fi

    local current
    current="$(current_wallpaper)"
    local candidates=()

    if ((${#wallpapers[@]} == 1)); then
        candidates=("${wallpapers[0]}")
    else
        for wallpaper in "${wallpapers[@]}"; do
            if [[ "$wallpaper" != "$current" ]]; then
                candidates+=("$wallpaper")
            fi
        done
        if ((${#candidates[@]} == 0)); then
            candidates=("${wallpapers[@]}")
        fi
    fi

    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    apply_wallpaper "$pick"
}

prev_wallpaper() {
    mapfile -t wallpapers < <(collect_wallpapers)
    if ((${#wallpapers[@]} == 0)); then
        exit 1
    fi

    local index=0
    if [[ -f "$STATE_FILE" ]]; then
        index="$(<"$STATE_FILE")"
    fi

    local current
    current="$(current_wallpaper)"
    if [[ -n "$current" ]]; then
        for i in "${!wallpapers[@]}"; do
            if [[ "${wallpapers[$i]}" == "$current" ]]; then
                index="$i"
                break
            fi
        done
    fi

    index=$(( (index - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]} ))
    echo "$index" >"$STATE_FILE"
    apply_wallpaper "${wallpapers[$index]}"
}

sync_index() {
    mapfile -t wallpapers < <(collect_wallpapers)
    local current
    current="$(current_wallpaper)"
    local index=0

    for i in "${!wallpapers[@]}"; do
        if [[ "${wallpapers[$i]}" == "$current" ]]; then
            index="$i"
            break
        fi
    done

    echo "$index" >"$STATE_FILE"
}

daemon() {
    local pidfile="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-daemon.pid"
    if [[ -f "$pidfile" ]]; then
        local old
        old="$(<"$pidfile")"
        if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
            exit 0
        fi
    fi
    echo $$ >"$pidfile"

    until pgrep -x hyprpaper >/dev/null; do
        sleep 0.5
    done

    while pgrep -x Hyprland >/dev/null; do
        next_wallpaper
        sync_index
        sleep "$INTERVAL"
    done
}

case "${1:-next}" in
    next)
        next_wallpaper
        sync_index
        ;;
    prev)
        prev_wallpaper
        ;;
    daemon)
        daemon
        ;;
    *)
        exit 1
        ;;
esac
