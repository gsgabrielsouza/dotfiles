#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  printf '%s\n' "Execute como usuario comum, com sudo disponivel." >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
compose_file="${script_dir}/pentest/docker-compose.yml"
zshrc_local="${HOME}/.zshrc.local"
dotnet_path_line='export PATH="$HOME/.dotnet/tools:$PATH"'
fnm_eval_line='eval "$(fnm env --use-on-cd --shell zsh)"'

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ ${reply} == [yY] ]]
}

pkg_installed() {
  pacman -Qi "$1" &>/dev/null
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_pacman() {
  local pkg=$1
  local bin=${2:-}
  if pkg_installed "$pkg"; then
    log "Pulando ${pkg}: pacote ja instalado"
    return
  fi
  if [[ -n ${bin} ]] && cmd_exists "$bin"; then
    log "Pulando ${pkg}: comando ${bin} ja existe no PATH"
    return
  fi
  log "Instalando ${pkg}"
  sudo pacman -S --needed --noconfirm "$pkg"
}

aur_helper() {
  if command -v paru >/dev/null 2>&1; then
    printf '%s\n' paru
    return
  fi
  if command -v yay >/dev/null 2>&1; then
    printf '%s\n' yay
    return
  fi
  return 1
}

ensure_aur() {
  local pkg=$1
  local bin=${2:-}
  local helper
  if pkg_installed "$pkg"; then
    log "Pulando ${pkg}: pacote AUR ja instalado"
    return
  fi
  if [[ -n ${bin} ]] && cmd_exists "$bin"; then
    log "Pulando ${pkg}: comando ${bin} ja existe no PATH"
    return
  fi
  if ! helper=$(aur_helper); then
    log "paru/yay nao encontrado"
    return 1
  fi
  log "Instalando ${pkg} via ${helper}"
  "$helper" -S --needed --noconfirm "$pkg"
}

user_in_group() {
  local group=$1
  id -nG "$USER" | tr ' ' '\n' | grep -Fxq "$group"
}

ensure_group() {
  local group=$1
  if user_in_group "$group"; then
    log "Usuario ${USER} ja esta no grupo ${group}"
    return
  fi
  if ! getent group "$group" >/dev/null; then
    log "Grupo ${group} ainda nao existe; pulando"
    return
  fi
  log "Adicionando ${USER} ao grupo ${group}"
  sudo usermod -aG "$group" "$USER"
  log "Grupo ${group} aplicado. Logout/login para valer na sessao atual"
}

ensure_zshrc_local_line() {
  local line=$1
  # Apenas ~/.zshrc.local (toolchain). Nunca le, grava ou faz source de .env de projetos.
  if [[ -f ${zshrc_local} ]] && grep -Fqx "$line" "$zshrc_local"; then
    log "Pulando ~/.zshrc.local: trecho de toolchain ja presente"
    return
  fi
  mkdir -p "$(dirname "$zshrc_local")"
  touch "$zshrc_local"
  printf '%s\n' "$line" >>"$zshrc_local"
  log "Trecho de toolchain adicionado em ~/.zshrc.local (nao altera .env de projetos)"
}

docker_exec() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

compose_exec() {
  if docker_exec compose version &>/dev/null; then
    docker_exec compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    if docker info &>/dev/null; then
      docker-compose "$@"
    else
      sudo docker-compose "$@"
    fi
  else
    log "docker compose / docker-compose nao encontrado"
    return 1
  fi
}

valid_sa_password() {
  local pass=$1
  [[ ${#pass} -ge 8 ]] || return 1
  [[ ${pass} =~ [A-Z] ]] || return 1
  [[ ${pass} =~ [a-z] ]] || return 1
  [[ ${pass} =~ [0-9] ]] || return 1
  [[ ${pass} =~ [^A-Za-z0-9] ]] || return 1
}

list_sql_containers() {
  docker_exec ps -a --format '{{.Names}} | {{.Image}} | {{.Ports}}' | grep -iE 'mssql|sqlserver' || true
}

ensure_service() {
  local unit=$1
  if systemctl is-enabled --quiet "$unit" && systemctl is-active --quiet "$unit"; then
    log "Pulando ${unit}: servico ja ativo e habilitado"
    return
  fi
  log "Habilitando e iniciando ${unit}"
  sudo systemctl enable --now "$unit"
}

ensure_docker_compose() {
  if pkg_installed docker-compose; then
    log "Pulando docker-compose: pacote ja instalado"
    return
  fi
  if cmd_exists docker-compose; then
    log "Pulando docker-compose: comando ja existe no PATH"
    return
  fi
  if cmd_exists docker && docker compose version &>/dev/null; then
    log "Pulando docker-compose: plugin compose ja disponivel"
    return
  fi
  ensure_pacman docker-compose
}

ufw_defaults_ok() {
  sudo ufw status verbose 2>/dev/null | grep -qiE 'Default: deny \(incoming\), allow \(outgoing\)'
}

install_dotnet() {
  log "Iniciando install_dotnet"
  ensure_pacman dotnet-sdk dotnet
  ensure_pacman dotnet-runtime
  ensure_pacman aspnet-runtime

  ensure_zshrc_local_line "$dotnet_path_line"
  export PATH="${HOME}/.dotnet/tools:${PATH}"

  if cmd_exists dotnet-ef || { cmd_exists dotnet && dotnet tool list -g | awk 'NR > 2 { print $1 }' | grep -Fxq dotnet-ef; }; then
    log "Pulando dotnet-ef: ferramenta global ja instalada"
  else
    log "Instalando dotnet-ef (global tool)"
    dotnet tool install -g dotnet-ef
  fi
  log "install_dotnet concluido"
}

install_node_angular() {
  local current
  log "Iniciando install_node_angular"
  if pkg_installed fnm-bin || pkg_installed fnm || cmd_exists fnm; then
    log "Pulando fnm: ja instalado"
  else
    ensure_aur fnm-bin fnm
  fi
  ensure_zshrc_local_line "$fnm_eval_line"

  eval "$(fnm env --shell bash)"

  if fnm list 2>/dev/null | grep -qi lts; then
    log "Pulando fnm install --lts: Node LTS ja presente"
  else
    log "Instalando Node LTS via fnm"
    fnm install --lts
  fi

  current=$(fnm current 2>/dev/null || true)
  if [[ -n ${current} && ${current} != none ]] && fnm list 2>/dev/null | grep -i lts | grep -q "${current}"; then
    log "Pulando fnm use --lts: LTS ja ativo (${current})"
  else
    fnm use --lts
  fi

  if cmd_exists ng || npm list -g --depth=0 @angular/cli &>/dev/null; then
    log "Pulando @angular/cli: ja instalado"
  else
    log "Instalando @angular/cli no npm global da versao fnm (nao em projetos)"
    npm install -g @angular/cli
  fi
  log "install_node_angular concluido"
}

run_sqlserver_container() {
  local existing pass pass2
  existing=$(list_sql_containers)
  if [[ -n ${existing} ]]; then
    log "Pulando SQL Server: container ja existe no sistema"
    printf '%s\n' "$existing"
    return
  fi

  while true; do
    read -r -s -p "Senha do usuario SA (nao e gravada em disco): " pass
    printf '\n'
    read -r -s -p "Confirme a senha: " pass2
    printf '\n'
    if [[ ${pass} != "${pass2}" ]]; then
      log "Senhas nao conferem"
      continue
    fi
    if ! valid_sa_password "$pass"; then
      log "Senha deve ter 8+ caracteres, maiuscula, minuscula, numero e simbolo"
      continue
    fi
    break
  done

  # Bridge default do daemon: nao usa host network nem redes nomeadas de outros compose.
  log "Criando container sqlserver-dev na bridge default (sem host network e sem redes de outros projetos)"
  docker_exec run -d \
    --name sqlserver-dev \
    -e ACCEPT_EULA=Y \
    -e "MSSQL_SA_PASSWORD=${pass}" \
    -p 1433:1433 \
    -v sqlserver-dev-data:/var/opt/mssql \
    --restart unless-stopped \
    mcr.microsoft.com/mssql/server:2022-latest
  unset pass pass2
  log "sqlserver-dev criado"
}

install_docker() {
  log "Iniciando install_docker"
  ensure_pacman docker docker
  ensure_docker_compose
  ensure_service docker.service
  ensure_group docker
  run_sqlserver_container
  log "install_docker concluido"
}

install_pentest_isolated() {
  log "Iniciando install_pentest_isolated"
  # Host: so diagnostico de rede. Ferramentas ofensivas ficam no container Kali isolado.
  ensure_pacman nmap nmap
  ensure_pacman wireshark-qt wireshark
  ensure_group wireshark

  if [[ -f ${compose_file} ]]; then
    log "docker-compose de pentest ja existe; nao sobrescrevendo ${compose_file}"
  else
    log "Arquivo ${compose_file} ausente"
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    log "Docker nao encontrado. Rode o bloco 1 ou o bootstrap antes do lab isolado"
    return 1
  fi

  if docker_exec ps -a --format '{{.Names}}' | grep -Fxq pentest-kali; then
    log "Pulando lab Kali: container pentest-kali ja existe"
  else
    log "Subindo lab Kali na rede pentest-isolated (sem publicar portas no host)"
    compose_exec -f "$compose_file" up -d
  fi
  log "install_pentest_isolated concluido"
}

ufw_allows_ssh() {
  sudo ufw status | grep -qE '22/tcp'
}

install_hardening() {
  log "Iniciando install_hardening"
  ensure_pacman ufw ufw
  ensure_pacman fail2ban fail2ban-client

  # Sem ufw reset: defaults novos nao apagam regras ja existentes no host.
  if ufw_defaults_ok; then
    log "Pulando defaults UFW: ja estao deny incoming / allow outgoing"
  else
    log "Aplicando defaults do UFW sem reset (regras existentes sao preservadas)"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
  fi

  if systemctl is-active --quiet sshd.service || systemctl is-active --quiet ssh.service; then
    if ufw_allows_ssh; then
      log "sshd ativo e 22/tcp ja liberado no UFW"
    elif confirm "sshd ativo. Liberar 22/tcp no UFW para evitar corte de SSH?"; then
      sudo ufw allow 22/tcp
      log "22/tcp liberado"
    else
      log "22/tcp nao liberado; deny incoming pode cortar SSH remoto"
    fi
  fi

  if sudo ufw status | grep -qi 'Status: active'; then
    log "UFW ja ativo"
  else
    log "Ativando UFW"
    sudo ufw --force enable
  fi
  ensure_service ufw.service

  if [[ -f /etc/fail2ban/jail.local ]]; then
    log "jail.local ja existe; nao sera criado nem sobrescrito"
  else
    log "Nenhum jail.local presente; fail2ban usara o default do pacote"
  fi
  ensure_service fail2ban.service
  log "install_hardening concluido"
}

main() {
  sudo -v
  log "Inicio do setup (idempotente; confirmação por bloco)"

  if confirm "Bloco 1 — .NET + Angular + Docker + SQL Server?"; then
    install_dotnet
    install_node_angular
    install_docker
  else
    log "Bloco 1 ignorado"
  fi

  if confirm "Bloco 2 — diagnostico de rede no host + lab Kali isolado?"; then
    install_pentest_isolated
  else
    log "Bloco 2 ignorado"
  fi

  if confirm "Bloco 3 — hardening do host (UFW + fail2ban)?"; then
    install_hardening
  else
    log "Bloco 3 ignorado"
  fi

  log "Setup concluido"
}

main "$@"
