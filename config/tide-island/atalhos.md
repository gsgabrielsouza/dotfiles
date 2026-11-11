# Atalhos do tide-island (Hyprland)

Definidos em `~/.config/hypr/hyprland.lua`. Tecla principal: SUPER.
Padrão: SUPER+tecla = acesso rápido; SUPER+ALT+tecla = extras.

| Atalho | Ação |
|---|---|
| SUPER + I / TAB | mostra/esconde a ilha |
| SUPER + P | lançador de apps (antes: wofi) |
| SUPER + V | histórico do clipboard (antes: cliphist+wofi) |
| SUPER + S | player de música (antes: abria o Spotify) |
| SUPER + N | central de notificações |
| SUPER + X | Control Center (Wi-Fi, Bluetooth, brilho, volume) |
| SUPER + W | clima |
| SUPER + ESC | menu de energia |
| SUPER + CTRL + TAB | visão geral dos workspaces |
| SUPER + L | tela de bloqueio da ilha |
| SUPER + ALT + C | calendário |
| SUPER + ALT + F | file shelf |
| SUPER + ALT + O | seletor de wallpaper |
| SUPER + ALT + S | abre o Spotify |

## Comandos manuais (IPC)

    T="quickshell ipc --any-display -p /usr/share/tide-island call"
    $T island show | hide | toggle | disableAutoHide | enableAutoHide
    $T tide toggleApplicationLauncher | toggleClipboard | toggleNotificationCenter | toggleWeather
    $T tide toggleControlCenter | togglePlayer | togglePowerMenu | toggleFileShelf | toggleWallpaperPicker
    $T tide showCalendar | showTimer | showLyrics | lockScreen | swipeLeft | swipeRight
    $T overview toggle

## Configuração

- `tide-island-config-app` — tema, clima, Spotify, tela de bloqueio, interação
- `tide-island-spotify-setup` — ponte do Spotify (spicetify)

## Notificações

O tide-island apenas escuta as notificações (dbus-monitor); precisa de um daemon dono do nome
`org.freedesktop.Notifications`. Por isso o `dunst` roda **pausado** (`dunstctl set-paused true`)
e só a ilha exibe o popup. Backups: `~/.config/hypr/hyprland.lua.bak-*`.
