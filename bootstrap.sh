#!/usr/bin/env bash
set -euo pipefail

run_privileged() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

aur_user=
aur_sudoers=

cleanup_aur_builder() {
  if [[ -n ${aur_sudoers} ]]; then
    rm -f "$aur_sudoers"
  fi
  if [[ -n ${aur_user} ]] && id "$aur_user" >/dev/null 2>&1; then
    userdel -r "$aur_user" >/dev/null 2>&1 || true
  fi
}

prepare_aur_builder() {
  if [[ ${EUID} -ne 0 ]]; then
    return
  fi
  if ! command -v runuser >/dev/null 2>&1; then
    printf '%s\n' "O comando runuser e necessario para instalar pacotes AUR como root." >&2
    exit 1
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    run_privileged pacman -S --needed --noconfirm sudo
  fi
  aur_user="dotfiles-aur-${BASHPID}"
  trap cleanup_aur_builder EXIT
  useradd --create-home --shell /bin/bash "$aur_user"
  aur_sudoers=$(mktemp /etc/sudoers.d/dotfiles-bootstrap.XXXXXX)
  printf '%s\n' "${aur_user} ALL=(root) NOPASSWD: /usr/bin/pacman" >"$aur_sudoers"
  chmod 440 "$aur_sudoers"
  if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$aur_sudoers" >/dev/null
  fi
}

run_aur() {
  if [[ ${EUID} -eq 0 ]]; then
    runuser -u "$aur_user" -- "$@"
  else
    "$@"
  fi
}

vm=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm) vm=1 ;;
    -h|--help)
      printf '%s\n' "Uso: $0 [--vm]"
      exit 0
      ;;
    *)
      printf '%s\n' "Uso: $0 [--vm]" >&2
      exit 1
      ;;
  esac
  shift
done

dotfiles=$(cd "$(dirname "$0")" && pwd)

read_packages() {
  grep -vE '^(#|[[:space:]]*$)' "$1"
}

link() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [[ -L $dest ]]; then
    rm -f "$dest"
  elif [[ -e $dest ]]; then
    mv "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  ln -sfn "$src" "$dest"
}

run_privileged pacman -Syu --noconfirm
mapfile -t packages < <(read_packages "$dotfiles/packages/pacman.txt")
run_privileged pacman -S --needed --noconfirm "${packages[@]}"

if (( vm )); then
  mapfile -t vm_packages < <(read_packages "$dotfiles/packages/pacman-vm.txt")
  run_privileged pacman -S --needed --noconfirm "${vm_packages[@]}"
fi

prepare_aur_builder
if ! command -v yay >/dev/null 2>&1; then
  tmp=$(run_aur mktemp -d)
  run_aur git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  run_aur bash -c 'cd "$1" && makepkg -si --noconfirm' bash "$tmp/yay"
  rm -rf "$tmp"
fi

mapfile -t aur < <(read_packages "$dotfiles/packages/aur.txt")
run_aur yay -S --needed --noconfirm "${aur[@]}"

mkdir -p "$HOME/.config/sway/config.d"

link "$dotfiles/config/sway/config" "$HOME/.config/sway/config"
link "$dotfiles/config/waybar" "$HOME/.config/waybar"
link "$dotfiles/config/foot" "$HOME/.config/foot"
link "$dotfiles/config/starship.toml" "$HOME/.config/starship.toml"
link "$dotfiles/home/.zshrc" "$HOME/.zshrc"
link "$dotfiles/wallpapers" "$HOME/wallpapers"

if (( vm )); then
  link "$dotfiles/vm/home/.zshenv" "$HOME/.zshenv"
  link "$dotfiles/vm/home/.zprofile" "$HOME/.zprofile"
  link "$dotfiles/vm/home/.zshrc.local" "$HOME/.zshrc.local"
  mkdir -p "$HOME/.config/environment.d"
  link "$dotfiles/vm/config/environment.d/sway-vbox.conf" "$HOME/.config/environment.d/sway-vbox.conf"
  link "$dotfiles/vm/config/sway/config.d/output.conf" "$HOME/.config/sway/config.d/output.conf"
fi

run_privileged systemctl enable --now docker.service
run_privileged systemctl enable --now ufw.service
run_privileged systemctl enable --now power-profiles-daemon.service
run_privileged usermod -aG docker "$USER"

if (( vm )); then
  run_privileged systemctl enable --now vboxservice.service
fi

if [[ ${SHELL} != /usr/bin/zsh ]]; then
  chsh -s /usr/bin/zsh
fi

xdg-settings set default-web-browser firefox.desktop || true

printf '%s\n' "Bootstrap concluido. Faca logout/login para aplicar grupo docker e o zsh."
