#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  printf '%s\n' "Execute como usuario comum, com sudo disponivel." >&2
  exit 1
fi

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

sudo pacman -Syu --noconfirm
mapfile -t packages < <(read_packages "$dotfiles/packages/pacman.txt")
sudo pacman -S --needed --noconfirm "${packages[@]}"

if (( vm )); then
  mapfile -t vm_packages < <(read_packages "$dotfiles/packages/pacman-vm.txt")
  sudo pacman -S --needed --noconfirm "${vm_packages[@]}"
fi

if ! command -v yay >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

mapfile -t aur < <(read_packages "$dotfiles/packages/aur.txt")
yay -S --needed --noconfirm "${aur[@]}"

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

sudo systemctl enable --now docker.service
sudo systemctl enable --now ufw.service
sudo systemctl enable --now power-profiles-daemon.service
sudo usermod -aG docker "$USER"

if (( vm )); then
  sudo systemctl enable --now vboxservice.service
fi

if [[ ${SHELL} != /usr/bin/zsh ]]; then
  chsh -s /usr/bin/zsh
fi

xdg-settings set default-web-browser firefox.desktop || true

printf '%s\n' "Bootstrap concluido. Faca logout/login para aplicar grupo docker e o zsh."
