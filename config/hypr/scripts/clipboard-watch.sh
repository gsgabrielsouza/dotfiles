#!/usr/bin/env bash

kill_old_watchers() {
    local pid cmdline
    for pid in $(pgrep -f 'wl-paste --type .+ --watch' || true); do
        cmdline=$(ps -p "$pid" -o args= 2>/dev/null) || continue
        case "$cmdline" in
            *cliphist*) continue ;;
        esac
        kill "$pid" 2>/dev/null || true
    done
}

kill_old_watchers

if pgrep -f 'wl-paste --type text --watch cliphist store' >/dev/null; then
    exit 0
fi

wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
