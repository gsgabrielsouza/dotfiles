# Dotfiles Arch + Sway

Replica o ambiente atual (Sway, Waybar, Foot, Zsh, Starship) **depois** do `archinstall` (profile minimal, Pipewire, NetworkManager).

## Uso

```bash
git clone git@github.com:gsgabrielsouza/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh
./bootstrap.sh          # maquina fisica
./bootstrap.sh --vm     # VirtualBox (cursores, pixman, guest utils, output Virtual-1)
```

Arquivos atuais em `~` e `~/.config` sao copiados para `*.bak.<timestamp>` antes do symlink, se nao forem links.

## O que o script faz

- instala pacotes oficiais e AUR (`cursor-bin`, `enpass-bin`)
- liga configs e wallpapers
- ativa Docker (grupo `docker`), UFW e power-profiles-daemon
- com `--vm`: `virtualbox-guest-utils` + `vboxservice`
- define zsh como shell e Firefox como navegador padrao

## Fora do script

- particao/disco, usuario, locale e bootloader no `archinstall`
- `git config --global user.name` / `user.email`
- Shared Folder do VirtualBox (`vboxsf`), se precisar
