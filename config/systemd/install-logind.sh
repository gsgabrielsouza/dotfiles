#!/bin/sh
set -eu

src="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/logind.conf.d/lid.conf"
dest_dir=/etc/systemd/logind.conf.d
dest="$dest_dir/lid.conf"

install -d "$dest_dir"
install -m 644 "$src" "$dest"
systemctl restart systemd-logind
systemd-analyze cat-config systemd/logind.conf | grep -E '^HandleLid'
