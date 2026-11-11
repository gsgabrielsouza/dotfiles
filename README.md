# Dotfiles Arch + Hyprland

Replica o ambiente atual (Hyprland, tide-island, Foot, Kitty, Zsh, Starship) **depois** do `archinstall` (profile minimal, Pipewire, NetworkManager). Sway continua instalado como sessao alternativa.

Monitores e VPN neste repo sao da maquina atual. Ajuste `config/hypr/hyprland.lua` e `scripts/home/vpn-techne` antes de usar em outro hardware.

## Uso

```bash
git clone git@github.com:gsgabrielsouza/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh scripts/setup-dev-env.sh
./bootstrap.sh          # maquina fisica
./bootstrap.sh --vm     # VirtualBox (guest utils, output Virtual-1)
./scripts/setup-dev-env.sh
./scripts/finish-setup.sh   # tela de login, NVIDIA, fail2ban e restore do SQL Server
```

Rode os scripts **sem** `sudo` (eles chamam `sudo` quando precisam). Com `sudo ./bootstrap.sh` as configs vao para `/root` e o shell/grupo docker sao aplicados ao root.

O bootstrap deixa o desktop e o Docker prontos. O `setup-dev-env.sh` e o segundo passo: toolchain .NET/Angular, pentest no host, lab isolado e hardening. Confirme cada bloco.

Arquivos existentes em `~` e `~/.config` sao movidos para `*.bak.<timestamp>` antes da copia.

## Desktop

- **Hyprland** (Lua) + **UWSM**, idle/wallpaper via hypridle e hyprpaper; lock screen pelo tide-island (hyprlock continua nos configs, comentado)
- **tide-island** (Quickshell): dynamic island com player (mpris + favoritar via Spicetify), notificacoes, clipboard, launcher, Control Center (Wi-Fi, Bluetooth, brilho, volume), calendario, clima, workspaces/overview, wallpaper picker, menu de energia e lock screen. Config em [`config/tide-island`](config/tide-island) (atalhos em [`atalhos.md`](config/tide-island/atalhos.md)). O **dunst** roda pausado so como daemon de notificacoes (a ilha as exibe). Waybar nao inicia mais (config mantida no repo); sem tray, os icones de udiskie/FortiClient/Teams nao aparecem
- Terminais **Foot** (Super+Return) e **Kitty**; launcher da ilha (`Super+P`); arquivos **Nemo**
- Tema Catppuccin Macchiato, teclado `br-abnt2`
- Notebook `eDP-1` @ 120 Hz; HDMI em cima. Workspaces 1–5 no laptop; 6–10 no HDMI quando conectado
- Browser da sessao: Edge (`Super+B`). O bootstrap ainda define Firefox como padrao xdg
- Scripts em [`config/hypr/scripts`](config/hypr/scripts): wallpaper, OSD, clipboard, Bluetooth (menu e roteamento de audio), Wi-Fi, calendario, Waybar (legado)
- Plugin [hypr-autoscroll](https://github.com/estebanhiram/hypr-autoscroll) (autoscroll com botao do meio; `Super+A` liga/desliga), compilado em `~/.local/src/hypr-autoscroll`. O plugin depende da ABI do Hyprland: apos atualizar o Hyprland, rode `make -C ~/.local/src/hypr-autoscroll clean all`. O bootstrap aplica `patches/hypr-autoscroll-hyprland-0.57.patch` (suporte a API de plugins do Hyprland 0.57, ainda nao incorporado upstream)
- VPN via **FortiClient** (tray iniciado com a sessao)

## O que o bootstrap faz

- instala pacotes oficiais ([`packages/pacman.txt`](packages/pacman.txt)) e AUR ([`packages/aur.txt`](packages/aur.txt): Cursor, Enpass, fnm, Edge, Chrome, FortiClient VPN, Postman, Claude Desktop, tide-island)
- copia configs (Hyprland, tide-island, Sway, Waybar, Foot, Kitty, UWSM, dunst, btop, htop, EasyEffects, Cursor) e wallpapers
- compila o plugin hypr-autoscroll (falha nao interrompe o bootstrap)
- instala `~/scripts/vpn-techne` (`connect` / `disconnect` / `status`, SAML no FortiClient)
- habilita Docker (grupo `docker`), UFW e power-profiles-daemon
- com `--vm`: `virtualbox-guest-utils` + `vboxservice` e overlays em `vm/`
- define zsh como shell e Firefox como navegador xdg padrao

## O que o finish-setup faz

- instala SDDM + Xorg (greeter) e aplica [`config/hypr/scripts/fix-sddm-boot.sh`](config/hypr/scripts/fix-sddm-boot.sh) (sessao Hyprland, espera o `nvidia_drm`)
- instala `nvidia-open` + `nvidia-utils`: o HDMI do notebook esta ligado na RTX 3050 e com `nouveau` o Hyprland deixa a tela preta
- UFW (deny incoming) + fail2ban
- cria/inicia o container `sqlserver-dev` e restaura `cronosLocal.bak` do HD de backup (padrao: `/run/media/$USER/SAMSUNG/backup-linux/2026-10-19/docker/sqlserver_data`, ou passe o diretorio como argumento)

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
| Super+P | launcher da ilha |
| Super+S | player da ilha |
| Super+Alt+S | Spotify |
| Super+A | liga/desliga autoscroll |
| Super+O | proximo wallpaper |
| Super+V | clipboard da ilha |
| Super+L | lock screen da ilha |
| Super+I / Super+Tab | mostra/esconde a ilha |
| Super+N | central de notificacoes |
| Super+X | Control Center (Wi-Fi, Bluetooth, brilho, volume) |
| Super+W | clima |
| Super+Esc | menu de energia |
| Super+Ctrl+Tab | overview de workspaces |
| Super+Alt+C | calendario |
| Super+Alt+F | file shelf |
| Super+Alt+O | seletor de wallpaper |
| Super+Q | fecha janela |
| Super+F | fullscreen |
| Super+Shift+E | sai da sessao |

## Fora dos scripts

- particao/disco, usuario, locale, bootloader e display manager no `archinstall`
- Shared Folder do VirtualBox (`vboxsf`), se precisar
