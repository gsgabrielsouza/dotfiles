#!/usr/bin/env bash
# Mostra um menu (wofi) com os dispositivos USB/removiveis e desmonta/desliga o escolhido.
set -uo pipefail

ALL_LABEL="⏏ Todos os dispositivos"

notify() {
    dunstify -a usb-eject -h "string:x-dunst-stack-tag:usb-eject" "$@"
}

# Discos inteiros conectados via USB ou marcados como removiveis
mapfile -t disks < <(lsblk -dnpo NAME,TRAN,RM,TYPE | awk '$4=="disk" && ($2=="usb" || $3=="1") {print $1}')

if (( ${#disks[@]} == 0 )); then
    notify -u low "Nenhum dispositivo USB conectado"
    exit 0
fi

disk_label() {
    local label
    label="$(lsblk -dno MODEL "$1" | xargs)"
    [[ -z "$label" ]] && label="$1"
    printf '%s' "$label"
}

# Monta as linhas do menu: "/dev/sdX  Modelo  Tamanho  (pontos de montagem)"
entries=()
for disk in "${disks[@]}"; do
    size="$(lsblk -dno SIZE "$disk" | xargs)"
    mnts="$(lsblk -lno MOUNTPOINT "$disk" | sed '/^$/d' | paste -sd ', ')"
    [[ -z "$mnts" ]] && mnts="nao montado"
    entries+=("$disk  $(disk_label "$disk")  $size  ($mnts)")
done
(( ${#disks[@]} > 1 )) && entries+=("$ALL_LABEL")

choice="$(printf '%s\n' "${entries[@]}" | wofi --dmenu --insensitive --prompt "Ejetar dispositivo" \
    --lines "$(( ${#entries[@]} + 1 ))")" || exit 0
[[ -z "$choice" ]] && exit 0

if [[ "$choice" == "$ALL_LABEL" ]]; then
    targets=("${disks[@]}")
else
    targets=("${choice%%  *}")
fi

sync

ok=()
fail=()
for disk in "${targets[@]}"; do
    [[ -b "$disk" ]] || continue
    label="$(disk_label "$disk")"
    busy=0
    # Desmonta cada particao montada do disco (inclui o proprio disco sem tabela de particoes)
    while read -r part mnt; do
        [[ -z "$mnt" ]] && continue
        if ! udisksctl unmount -b "$part" --no-user-interaction >/dev/null 2>&1; then
            busy=1
            fail+=("$label: $mnt em uso")
        fi
    done < <(lsblk -lnpo NAME,MOUNTPOINT "$disk")

    if (( busy == 0 )); then
        udisksctl power-off -b "$disk" --no-user-interaction >/dev/null 2>&1 || true
        ok+=("$label")
    fi
done

if (( ${#ok[@]} > 0 )); then
    notify -u normal "Pode remover com seguranca" "$(printf '%s\n' "${ok[@]}")"
fi
if (( ${#fail[@]} > 0 )); then
    notify -u critical "Nao foi possivel desmontar" "$(printf '%s\n' "${fail[@]}")
Feche os arquivos/terminais abertos nele e tente de novo."
fi
