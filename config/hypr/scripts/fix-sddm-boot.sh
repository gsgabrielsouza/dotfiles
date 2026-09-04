#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

install -d -m 755 /etc/sddm.conf.d /etc/modprobe.d /etc/systemd/system/sddm.service.d /usr/local/libexec

cat >/etc/sddm.conf.d/10-autologin.conf <<'EOF'
[Autologin]
Session=hyprland.desktop
Relogin=false

[General]
DisplayServer=x11
GreeterEnvironment=QT_XCB_GL_INTEGRATION=none,QT_QUICK_BACKEND=software,QSG_RENDER_LOOP=basic,LIBGL_ALWAYS_SOFTWARE=1

[Theme]
CursorTheme=Adwaita
CursorSize=24
EOF

cat >/etc/modprobe.d/nvidia-drm.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
EOF

cat >/usr/local/libexec/sddm-wait-drm.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

deadline=$((SECONDS + 20))

while (( SECONDS < deadline )); do
  if [[ -e /sys/module/nvidia_drm ]] && [[ -e /dev/dri/card0 ]] && [[ -e /dev/dri/card1 ]]; then
    sleep 0.5
    exit 0
  fi
  sleep 0.2
done

exit 0
EOF

cat >/etc/systemd/system/sddm.service.d/wait-drm.conf <<'EOF'
[Unit]
After=systemd-modules-load.service
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
ExecStartPre=/usr/local/libexec/sddm-wait-drm.sh
EOF

chmod 755 /usr/local/libexec/sddm-wait-drm.sh
chmod 644 /etc/sddm.conf.d/10-autologin.conf /etc/modprobe.d/nvidia-drm.conf /etc/systemd/system/sddm.service.d/wait-drm.conf

systemctl daemon-reload
systemctl enable sddm.service

echo "SDDM: greeter em software GL, espera nvidia-drm e modeset aplicados."
echo "Reinicie para validar o boot. Nao reinicie o sddm agora (encerra a sessao)."
