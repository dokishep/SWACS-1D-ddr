#!/bin/sh
# USB gadget initialization for PS1-style memory card emulation
# Creates a composite gadget with mass storage (memory card) and HID (controller) functions

# Wait for configfs to be mounted
while [ ! -d /sys/kernel/config/usb_gadget ]; do
    sleep 1
done

GADGET_DIR=/sys/kernel/config/usb_gadget/g1
MEMORY_CARD_IMAGE=/var/data/memcard.bin

# Ensure /var/data exists
mkdir -p /var/data

# Create a default memory card image if it doesn't exist (128KB for PS1)
if [ ! -f "$MEMORY_CARD_IMAGE" ]; then
    dd if=/dev/zero of="$MEMORY_CARD_IMAGE" bs=1K count=128 2>/dev/null
fi

# Create gadget directory
mkdir -p "$GADGET_DIR"
cd "$GADGET_DIR"

# Set vendor/product IDs (using Linux Foundation IDs for testing)
echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct  # Multifunction Composite Gadget

# Create strings directory
mkdir -p strings/0x409
echo "ABCD1234" > strings/0x409/serialnumber
echo "RootDDR" > strings/0x409/manufacturer
echo "PS1 Memory Card Emulator" > strings/0x409/product

# Create mass storage function
mkdir -p functions/mass_storage.0
echo "$MEMORY_CARD_IMAGE" > functions/mass_storage.0/lun.0/file
echo 0 > functions/mass_storage.0/lun.0/ro  # Read-write
echo 1 > functions/mass_storage.0/lun.0/nofua

# Create HID function for PS1 controller emulation
mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
# Create HID report descriptor for PS1 controller
# This is a simplified PS1 controller report descriptor
printf "\\x05\\x01\\x09\\x05\\xA1\\x01\\x09\\x01\\x09\\x02\\x09\\x03\\x09\\x04\\x09\\x05\\x09\\x06\\x09\\x07\\x09\\x08\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\xC0" > functions/hid.usb0/report_desc

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo 120 > configs/c.1/MaxPower
echo "Composite" > configs/c.1/strings/0x409/configuration
echo "EF" > configs/c.1/bmAttributes

# Link functions to configuration
ln -s functions/mass_storage.0 configs/c.1/
ln -s functions/hid.usb0 configs/c.1/

# Enable UDC
UDC=$(ls /sys/class/udc | head -n 1)
if [ -n "$UDC" ]; then
    echo "$UDC" > UDC
else
    echo "No UDC found"
fi

echo "USB gadget g1 initialized"