# Dotfiles Arch + Sway

Replica o ambiente atual (Sway, Waybar, Foot, Zsh, Starship) **depois** do `archinstall` (profile minimal, Pipewire, NetworkManager).

## Uso

```bash
git clone git@github.com:gsgabrielsouza/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh scripts/setup-dev-env.sh
./bootstrap.sh          # maquina fisica
./bootstrap.sh --vm     # VirtualBox (cursores, pixman, guest utils, output Virtual-1)
./scripts/setup-dev-env.sh
```

O bootstrap deixa o desktop e o Docker prontos. O `setup-dev-env.sh` e o segundo passo: toolchain .NET/Angular, SQL Server, lab isolado e hardening. Confirme cada bloco.

Arquivos atuais em `~` e `~/.config` sao copiados para `*.bak.<timestamp>` antes do symlink, se nao forem links.

## O que o bootstrap faz

- instala pacotes oficiais e AUR (`cursor-bin`, `enpass-bin`, `fnm-bin`)
- liga configs e wallpapers
- ativa Docker (grupo `docker`), UFW e power-profiles-daemon
- com `--vm`: `virtualbox-guest-utils` + `vboxservice`
- define zsh como shell e Firefox como navegador padrao

## O que o setup-dev-env faz

Inventario em [`packages/dev.txt`](packages/dev.txt) (o script instala os pacotes; `fnm-bin` e AUR e ja entra no bootstrap).

1. **.NET + Angular + Docker + SQL Server** — `dotnet-sdk` / runtimes, `dotnet-ef`, Node LTS via fnm, `@angular/cli`, container `sqlserver-dev`
2. **Diagnostico + lab isolado** — `nmap` e Wireshark no host; Kali e alvos vulneraveis na rede `pentest-isolated` (veja [`scripts/pentest/README.md`](scripts/pentest/README.md))
3. **Hardening** — UFW (deny incoming) + fail2ban

Ferramentas ofensivas ficam no container Kali. Nao compartilhe `pentest-isolated` com o SQL Server de desenvolvimento.

No host, em projetos: `dotnet list package --vulnerable` e `npm audit`.

## Fora dos scripts

- particao/disco, usuario, locale e bootloader no `archinstall`
- `git config --global user.name` / `user.email`
- Shared Folder do VirtualBox (`vboxsf`), se precisar
