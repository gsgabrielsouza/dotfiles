#!/usr/bin/env bash
set -euo pipefail
id="${1:?}"
hyprctl dispatch "hl.dsp.focus({ workspace = ${id} })" >/dev/null
