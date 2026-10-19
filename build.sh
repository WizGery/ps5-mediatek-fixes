#!/usr/bin/env bash
# Recompila los drivers con los arreglos para la PS5 con chip MediaTek:
#   mt7921e.ko   - WiFi MT7921 (el kernel de ps5-linux se compila sin él)
#   btusb.ko     - Bluetooth: parches de ps5-linux + envío ACL por el bulk OUT 0x02
#   bluetooth.ko - Bluetooth: parche de ps5-linux + L2CAP espera al cifrado
#
# Uso:
#   ./build.sh                 compila para el kernel en uso
#   ./build.sh 7.1.8           compila para otra versión instalada
#   sudo ./build.sh --install  compila e instala en /lib/modules/<versión>/updates

set -euo pipefail

INSTALL=0
KVER=$(uname -r)
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) KVER=$arg ;;
    esac
done

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KBUILD=/lib/modules/$KVER/build
WORK=${WORK:-$HOME/.cache/ps5-mediatek-fixes/$KVER}

if [[ ! -f $KBUILD/Makefile ]]; then
    echo "No hay cabeceras del kernel en $KBUILD" >&2
    exit 1
fi

# Versión base del kernel (7.1.7-algo -> 7.1.7) para descargar el código de kernel.org
BASE=${KVER%%[-+]*}
MAJOR=${BASE%%.*}
SRC=$WORK/linux-$BASE

# Usar la misma versión de gcc con la que se compiló el kernel
CC_MAJOR=$(grep -oP 'CONFIG_CC_VERSION_TEXT=".*gcc.*?\) \K[0-9]+' "$KBUILD/.config" || true)
CC=gcc
if [[ -n $CC_MAJOR ]] && command -v "gcc-$CC_MAJOR" >/dev/null; then
    CC=gcc-$CC_MAJOR
elif [[ -n $CC_MAJOR ]]; then
    echo "Aviso: el kernel se compiló con gcc $CC_MAJOR; instala gcc-$CC_MAJOR (usando gcc)" >&2
fi

mkdir -p "$WORK"
if [[ ! -d $SRC ]]; then
    echo "Descargando linux-$BASE..."
    curl -fL -o "$WORK/linux.tar.xz" \
        "https://cdn.kernel.org/pub/linux/kernel/v$MAJOR.x/linux-$BASE.tar.xz"
    tar -xJf "$WORK/linux.tar.xz" -C "$WORK" \
        "linux-$BASE/drivers/net/wireless/mediatek/mt76" \
        "linux-$BASE/drivers/bluetooth" \
        "linux-$BASE/net/bluetooth"
    rm "$WORK/linux.tar.xz"
    echo "Aplicando parches..."
    for p in "$REPO"/patches/*.patch; do
        echo "  $(basename "$p")"
        patch -s -d "$SRC" -p1 < "$p"
    done
fi

build() {
    local dir=$1; shift
    echo "Compilando $dir..."
    make -s -C "$KBUILD" M="$SRC/$dir" CC="$CC" "$@" modules
}

build drivers/net/wireless/mediatek/mt76/mt7921 CONFIG_MT7921E=m
build drivers/bluetooth CONFIG_BT_HCIBTUSB=m
build net/bluetooth

MODS=(
    "$SRC/drivers/net/wireless/mediatek/mt76/mt7921/mt7921e.ko"
    "$SRC/drivers/bluetooth/btusb.ko"
    "$SRC/net/bluetooth/bluetooth.ko"
)

if (( INSTALL )); then
    if [[ $EUID -ne 0 ]]; then
        echo "Para instalar ejecuta: sudo $0 --install" >&2
        exit 1
    fi
    install -Dm644 -t "/lib/modules/$KVER/updates" "${MODS[@]}"
    install -Dm644 "$REPO/system/99-ps5-bt-fantasma.rules" /etc/udev/rules.d/99-ps5-bt-fantasma.rules
    install -Dm644 "$REPO/system/btusb-ps5.conf" /etc/modprobe.d/btusb-ps5.conf
    depmod -a "$KVER"
    udevadm control --reload
    echo "Instalado en /lib/modules/$KVER/updates. Reinicia para cargarlos."
else
    printf 'Módulos compilados:\n'; printf '  %s\n' "${MODS[@]}"
fi
