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

O bootstrap deixa o desktop e o Docker prontos. O `setup-dev-env.sh` e o segundo passo: toolchain .NET/Angular, pentest no host, lab isolado e hardening. Confirme cada bloco.

Arquivos atuais em `~` e `~/.config` sao copiados para `*.bak.<timestamp>` antes do symlink, se nao forem links.

## O que o bootstrap faz

- instala pacotes oficiais e AUR (`cursor-bin`, `enpass-bin`, `fnm-bin`)
- liga configs e wallpapers
- ativa Docker (grupo `docker`), UFW e power-profiles-daemon
- com `--vm`: `virtualbox-guest-utils` + `vboxservice`
- define zsh como shell e Firefox como navegador padrao

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

## Fora dos scripts

- particao/disco, usuario, locale e bootloader no `archinstall`
- `git config --global user.name` / `user.email`
- Shared Folder do VirtualBox (`vboxsf`), se precisar
