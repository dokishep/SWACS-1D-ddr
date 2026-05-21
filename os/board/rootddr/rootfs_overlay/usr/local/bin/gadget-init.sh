#!/bin/sh
# USB Gadget Initialization for PS1 Memory Card Emulation
# Creates a composite USB gadget: HID keyboard + Mass Storage (memory card)

set -e

CONFIGFS="/sys/kernel/config"
GADGET_NAME="ps1-memcard"
MEMCARD_FILE="/var/data/memcard.bin"
UDC_DRIVER=""

# Find UDC (USB Device Controller)
if [ -d "/sys/class/udc" ]; then
    for udc in /sys/class/udc/*; do
        if [ -e "$udc" ]; then
            UDC_DRIVER=$(basename "$udc")
            break
        fi
    done
fi

if [ -z "$UDC_DRIVER" ]; then
    echo "No UDC found, exiting"
    exit 0
fi

echo "Using UDC: $UDC_DRIVER"

# Create empty memory card image if it doesn't exist (128KB PS1 card)
if [ ! -f "$MEMCARD_FILE" ]; then
    echo "Creating empty memory card image..."
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