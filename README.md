# Dotfiles Arch + Hyprland

Replica o ambiente atual (Hyprland, Waybar, Foot, Kitty, Zsh, Starship) **depois** do `archinstall` (profile minimal, Pipewire, NetworkManager). Sway continua instalado como sessao alternativa.

Monitores, particao Windows e VPN neste repo sao da maquina atual. Ajuste `config/hypr/hyprland.lua`, `config/hypr/scripts/mount-windows.sh` e `scripts/home/vpn-techne` antes de usar em outro hardware.

## Uso

```bash
git clone git@github.com:gsgabrielsouza/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh scripts/setup-dev-env.sh
./bootstrap.sh          # maquina fisica
./bootstrap.sh --vm     # VirtualBox (guest utils, output Virtual-1)
./scripts/setup-dev-env.sh
```

O bootstrap deixa o desktop e o Docker prontos. O `setup-dev-env.sh` e o segundo passo: toolchain .NET/Angular, pentest no host, lab isolado e hardening. Confirme cada bloco.

Arquivos existentes em `~` e `~/.config` sao movidos para `*.bak.<timestamp>` antes da copia.

## Desktop

- **Hyprland** (Lua) + **UWSM**, lock/idle/wallpaper via hyprlock, hypridle e hyprpaper
- **Waybar**: workspaces, janela, clima, CPU/RAM, rede (menu Wi-Fi), audio, brilho, bateria, relogio e powermenu
- Terminais **Foot** (Super+Return) e **Kitty**; launcher **Wofi**; arquivos **Nemo**
- Tema Catppuccin Macchiato, teclado `br-abnt2`
- Notebook `eDP-1` @ 120 Hz; HDMI em cima; DP a direita. Workspaces 1–5 no laptop; 6–10 no HDMI quando conectado
- Browser da sessao: Edge (`Super+B`). O bootstrap ainda define Firefox como padrao xdg
- Scripts em [`config/hypr/scripts`](config/hypr/scripts): wallpaper, OSD, clipboard, Bluetooth, Wi-Fi, calendario, montagem do Windows, Waybar

## O que o bootstrap faz

- instala pacotes oficiais ([`packages/pacman.txt`](packages/pacman.txt)) e AUR (`cursor-bin`, `enpass-bin`, `fnm-bin`, `microsoft-edge-stable-bin`)
- copia configs (Hyprland, Sway, Waybar, Foot, Kitty, UWSM, dunst, btop, htop, EasyEffects, Cursor, openfortivpn) e wallpapers
- instala `~/scripts/vpn-techne` (`connect` / `disconnect` / `status`, SAML no navegador)
- habilita Docker (grupo `docker`), UFW, power-profiles-daemon e `mount-windows.service`
- com `--vm`: `virtualbox-guest-utils` + `vboxservice` e overlays em `vm/`
- define zsh como shell e Firefox como navegador xdg padrao

## O que o setup-dev-env faz

O inventario geral fica em [`packages/dev.txt`](packages/dev.txt). O inventario de pentest no host fica em [`packages/pentest-host.txt`](packages/pentest-host.txt), e o script exige que o repositorio oficial do BlackArch esteja configurado no pacman antes de instalar essa lista.

1. **.NET + Angular + Docker + SQL Server** — `dotnet-sdk` / runtimes, `dotnet-ef`, Node LTS via fnm, `@angular/cli`, container `sqlserver-dev`
2. **Pentest no host** — reconhecimento, web/API, enumeracao de servicos, credenciais, hashes e wireless conforme [`packages/pentest-host.txt`](packages/pentest-host.txt)
3. **Lab web isolado** — Kali e alvos vulneraveis na rede `pentest-isolated` (veja [`scripts/pentest/README.md`](scripts/pentest/README.md))
4. **Hardening** — UFW (deny incoming) + fail2ban

O container Kali continua disponivel para o lab web, mas as ferramentas do inventario de pentest sao instaladas diretamente no host. Nao compartilhe `pentest-isolated` com o SQL Server de desenvolvimento.

No host, em projetos: `dotnet list package --vulnerable` e `npm audit`.

## Preparar o BlackArch

O setup nao instala nem altera automaticamente o repositorio BlackArch. Siga a documentacao oficial para configurar o repositorio assinado no Arch:

<https://blackarch.org/downloads.html>

Baixe o `strap.sh` somente da pagina oficial, valide o checksum publicado nessa pagina e execute-o com `sudo`. Depois sincronize os repositorios:

```bash
sudo pacman -Syyu
```

Confirme que o repositorio esta habilitado e que os pacotes foram encontrados:

```bash
pacman-conf --repo-list | grep -Fx blackarch
pacman -Si burpsuite metasploit aircrack-ng
```

Se o primeiro comando nao retornar `blackarch`, o bloco de pentest sera interrompido sem instalar nada. A lista e intencionalmente selecionada; nao use o grupo completo `blackarch` sem avaliar o impacto de manutencao e armazenamento.

## Requisitos para wireless

As ferramentas wireless precisam de um adaptador compativel com modo monitor e injecao de pacotes, suporte do driver e permissao para controlar a interface. Verifique o hardware antes do teste:

```bash
rfkill list
iw list
airmon-ng
```

Use uma interface dedicada e alvos sob seu controle. A instalacao dos pacotes nao habilita automaticamente modo monitor nem garante compatibilidade do chipset.

Testes de rede devem usar uma rede de laboratorio separada da rede domestica ou corporativa. Nao use `network_mode: host` no compose e nao aponte scanners para terceiros.

Para desativar o repositorio, remova ou desabilite a secao `[blackarch]` e seu servidor em `/etc/pacman.conf`, depois valide com:

```bash
pacman-conf --repo-list
```

## Atalhos (Hyprland)

| Atalho | Acao |
|--------|------|
| Super+Return | Foot |
| Super+B | Edge |
| Super+E | Nemo |
| Super+P | Wofi |
| Super+O | proximo wallpaper |
| Super+V | clipboard (cliphist) |
| Super+W | lista de janelas |
| Super+L | hyprlock |
| Super+Q | fecha janela |
| Super+F | fullscreen |
| Super+Shift+E | sai da sessao |

## Fora dos scripts

- particao/disco, usuario, locale, bootloader e display manager no `archinstall`
- entrada da particao Windows no `/etc/fstab` (UUID da maquina atual) e Inicializacao Rapida desligada no Windows
- Shared Folder do VirtualBox (`vboxsf`), se precisar
