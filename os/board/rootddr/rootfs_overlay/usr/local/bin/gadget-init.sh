#!/bin/sh
# USB Gadget Initialization for PS1 Memory Card Emulation
# Creates a composite USB gadget: HID keyboard + Mass Storage (memory card)
#
# Usage:
#   gadget-init.sh [ -f /path/to/memcard.bin ] [ -p player_num ]
#
#   -f  Override the memory card backing file (default: /var/data/memcard.bin).
#       Usually this is a symlink managed by S10memory_card.sh pointing to
#       DDR.mc / DDRMAX.mc / DDREXTREME.mc in /var/data/.
#   -p  Player number (1 or 2) for dual-gadget setups — appends player ID to
#       the gadget and function names so two gadgets can coexist on separate
#       physical UDCs (e.g. two USB host ports on the cabinet board).

set -e

CONFIGFS="/sys/kernel/config"
DEFAULT_MEMCARD="/var/data/memcard.bin"
MEMCARD_FILE="$DEFAULT_MEMCARD"
PLAYER_SUFFIX=""
GADGET_NAME="ps1-memcard"
UDC_DRIVER=""

# ── argument parsing ─────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--file)
            MEMCARD_FILE="$2"
            shift 2
            ;;
        -p|--player)
            PLAYER_NUM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            shift
            ;;
    esac
done

if [ -n "$PLAYER_NUM" ]; then
    PLAYER_SUFFIX=".p${PLAYER_NUM}"
    GADGET_NAME="${GADGET_NAME}${PLAYER_SUFFIX}"
fi

# ── resolve active card via S10memory_card.sh symlink ─────────────────────────
#
# When S10memory_card.sh has set /var/data/memcard.bin → DDR.mc (or
# DDRMAX.mc / DDREXTREME.mc) via symlink, follow that link so the gadget
# always reflects the currently running game — no explicit -f argument needed.

if [ "$MEMCARD_FILE" = "$DEFAULT_MEMCARD" ] && [ -L "$DEFAULT_MEMCARD" ]; then
    # Symlink: follow to actual file in /var/data/
    _resolved=$(readlink "$DEFAULT_MEMCARD")
    # Guard against absolute paths
    case "$_resolved" in
        /*)  MEMCARD_FILE="$_resolved" ;;
        *)   MEMCARD_FILE="${MEMCARD_DIR:-/var/data}/$_resolved" ;;
    esac
    echo "Active memory card from S10 selection: $(basename "$MEMCARD_FILE")"
fi

# ── UDC selection ─────────────────────────────────────────────────────────────
# For single-player (-p not set) or IEEE-1722 / single-UDC systems, use the
# first available UDC. For dual-player (-p 1 / -p 2) we select a distinct
# UDC by index so both gadgets can coexist.

UDC_INDEX=0   # index among enumerated UDCs
if [ -n "$PLAYER_SUFFIX" ]; then
    UDC_INDEX=$((PLAYER_NUM - 1))
fi

if [ -d "/sys/class/udc" ]; then
    UDC_LIST=$(ls -1 /sys/class/udc/ | grep -v "^$" | sort)
    i=0
    for udc in $UDC_LIST; do
        if [ "$i" -eq "$UDC_INDEX" ]; then
            UDC_DRIVER="$udc"
            break
        fi
        i=$((i + 1))
    done
    [ -z "$UDC_DRIVER" ] && UDC_DRIVER=$(echo "$UDC_LIST" | head -1)
else
    UDC_DRIVER=$(find /sys/class/udc -maxdepth 1 -type d -mindepth 1 -printf '%f\n' 2>/dev/null | head -1 || true)
fi

if [ -z "$UDC_DRIVER" ]; then
    echo "No UDC found, exiting"
    exit 0
fi

if [ -n "$PLAYER_SUFFIX" ]; then
    echo "Using UDC: $UDC_DRIVER (player $PLAYER_NUM)"
else
    echo "Using UDC: $UDC_DRIVER"
fi

# ── memory card image provision ───────────────────────────────────────────────

MEMCARD_DIR=$(dirname "$MEMCARD_FILE")

if [ ! -f "$MEMCARD_FILE" ]; then
    echo "Creating empty memory card image: $MEMCARD_FILE"
    truncate -s 131072 "$MEMCARD_FILE" 2>/dev/null || \
        dd if=/dev/zero of="$MEMCARD_FILE" bs=128K count=1 2>/dev/null
fi

# Clean up existing gadget
rm -rf "$CONFIGFS/usb_gadget/$GADGET_NAME"

# Create gadget directory
mkdir -p "$CONFIGFS/usb_gadget/$GADGET_NAME"
cd "$CONFIGFS/usb_gadget/$GADGET_NAME"

# Basic USB device descriptors
echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "RootDDR" > strings/0x409/manufacturer
echo "PS1 Memory Card" > strings/0x409/product

# Configuration
mkdir -p configs/c.1
echo 120 > configs/c.1/MaxPower
echo "Memory Card + HID" > configs/c.1/strings/0x409/configuration

# HID function (keyboard for button input if needed)
mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
# Standard keyboard HID report descriptor (no xxd needed)
printf '\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x03\x05\x08\x19\x01\x29\x05\x91\x02\x95\x03\x75\x08\x91\x03\xc0' > functions/hid.usb0/report_desc

# Mass Storage function (memory card)
mkdir -p functions/mass_storage.0
echo "$MEMCARD_FILE" > functions/mass_storage.0/lun.0/file
echo 0 > functions/mass_storage.0/stall
echo 1 > functions/mass_storage.0/lun.0/removable
echo 0 > functions/mass_storage.0/lun.0/cdrom
echo 0 > functions/mass_storage.0/lun.0/ro
echo 0 > functions/mass_storage.0/lun.0/nofua

# Link functions to configuration
ln -s functions/hid.usb0 configs/c.1/
ln -s functions/mass_storage.0 configs/c.1/

# Enable gadget
echo "$UDC_DRIVER" > UDC

echo "PS1 Memory Card gadget enabled"

exit 0