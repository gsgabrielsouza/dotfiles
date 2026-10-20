#!/usr/bin/env bash
# Passos com root que faltam depois do bootstrap: tela de login (SDDM), driver NVIDIA,
# hardening e SQL Server com restore do backup. Rode como usuario normal (pede sudo).
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  printf '%s\n' "Rode sem sudo: $0" >&2
  exit 1
fi

dotfiles=$(cd "$(dirname "$0")/.." && pwd)
backup_dir=${1:-/run/media/${USER}/SAMSUNG/backup-linux/2026-10-19/docker/sqlserver_data}
container=sqlserver-dev
sqlcmd=/opt/mssql-tools18/bin/sqlcmd

log() {
  printf '\n== %s\n' "$*"
}

sudo -v

log "Pacotes: SDDM, Xorg (greeter), NVIDIA, fail2ban"
sudo pacman -S --needed --noconfirm sddm xorg-server nvidia-open nvidia-utils fail2ban dbeaver

log "Tela de login (SDDM) e nvidia-drm"
sudo bash "$dotfiles/config/hypr/scripts/fix-sddm-boot.sh"

log "Rede: wait-online aceita qualquer interface (Ethernet sem cabo travava o boot por 2 min)"
sudo install -d -m 755 /etc/systemd/system/systemd-networkd-wait-online.service.d
printf '%s\n' '[Service]' 'ExecStart=' 'ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any --timeout=15' |
  sudo tee /etc/systemd/system/systemd-networkd-wait-online.service.d/any.conf >/dev/null
sudo systemctl daemon-reload

log "Hardening: UFW deny incoming + fail2ban"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo systemctl enable --now ufw.service fail2ban.service

log "SQL Server (${container})"
sudo systemctl enable --now docker.service
if sudo docker ps -a --format '{{.Names}}' | grep -Fxq "$container"; then
  printf '%s\n' "Container ${container} ja existe"
  sudo docker start "$container" >/dev/null
  read -r -s -p "Senha do SA do container existente: " pass
  printf '\n'
else
  while true; do
    read -r -s -p "Nova senha do SA (8+ chars, maiuscula, minuscula, numero e simbolo): " pass
    printf '\n'
    read -r -s -p "Confirme: " pass2
    printf '\n'
    if [[ ${pass} == "${pass2}" && ${#pass} -ge 8 && ${pass} =~ [A-Z] && ${pass} =~ [a-z] && ${pass} =~ [0-9] && ${pass} =~ [^A-Za-z0-9] ]]; then
      break
    fi
    printf '%s\n' "Senha invalida ou nao confere"
  done
  unset pass2
  sudo docker run -d \
    --name "$container" \
    -e ACCEPT_EULA=Y \
    -e "MSSQL_SA_PASSWORD=${pass}" \
    -p 1433:1433 \
    -v sqlserver-dev-data:/var/opt/mssql \
    --restart unless-stopped \
    mcr.microsoft.com/mssql/server:2022-latest
fi

run_sql() {
  sudo docker exec -e "SQLCMDPASSWORD=${pass}" "$container" "$sqlcmd" -S localhost -U sa -C -b "$@"
}

printf '%s' "Aguardando o SQL Server subir"
for _ in $(seq 1 60); do
  if run_sql -Q 'SELECT 1' >/dev/null 2>&1; then
    break
  fi
  printf '.'
  sleep 2
done
printf '\n'
run_sql -Q 'SELECT 1' >/dev/null

bak="${backup_dir}/cronosLocal.bak"
if [[ ! -f ${bak} ]]; then
  printf '%s\n' "Backup ${bak} nao encontrado; pulando restore (monte o HD e rode de novo)"
elif [[ -n $(run_sql -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name = 'cronosLocal'") ]]; then
  printf '%s\n' "Banco cronosLocal ja existe; restore pulado"
else
  log "Restaurando cronosLocal"
  sudo docker exec "$container" mkdir -p /var/opt/mssql/backup
  sudo docker cp "$bak" "${container}:/var/opt/mssql/backup/cronosLocal.bak"
  moves=$(run_sql -h -1 -W -s '|' -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/cronosLocal.bak'" |
    awk -F'|' 'NF > 3 {
      ext = ($3 == "L") ? "ldf" : "mdf"
      if ($3 == "D" && seen++) ext = "ndf" seen
      printf ", MOVE N'\''%s'\'' TO N'\''/var/opt/mssql/data/cronosLocal_%s.%s'\''", $1, $1, ext
    }')
  run_sql -Q "RESTORE DATABASE [cronosLocal] FROM DISK = N'/var/opt/mssql/backup/cronosLocal.bak' WITH RECOVERY${moves}"
fi
unset pass

log "Pronto. Reinicie (reboot) para subir a tela de login e o driver NVIDIA."
