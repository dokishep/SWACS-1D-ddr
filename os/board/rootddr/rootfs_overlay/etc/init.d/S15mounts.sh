#!/bin/sh
# First boot partition creation for ROMS and SAVE partitions
# Creates partitions only if they don't exist (no TPM dependency)

DRIVE=$(mount | grep "on / " | cut -d' ' -f1 | sed 's/[0-9]*$//')

# Check if ROMS partition already exists
if ! blkid -L ROMS >/dev/null 2>&1 || ! blkid -L SAVE >/dev/null 2>&1; then
    echo "Creating ROMS and SAVE partitions on first boot..."

    # Create ROMS partition (exFAT, 2-4GB)
    sgdisk -n 3:0:+2G -c 3:"ROMS" -t 3:0700 "$DRIVE"

    # Create SAVE partition (exFAT, remaining space)
    sgdisk -n 4:0:0 -c 4:"SAVE" -t 4:0700 "$DRIVE"

    partprobe "$DRIVE" && udevadm settle

    # Format as exFAT
    mkfs.exfat -n "ROMS" "${DRIVE}3"
    mkfs.exfat -n "SAVE" "${DRIVE}4"

    # Create ddr directory structure on SAVE
    mkdir -p /mnt/save
    mount -t exfat "${DRIVE}4" /mnt/save
    mkdir -p /mnt/save/ddr
    umount /mnt/save

    echo "Partitions created. Rebooting..."
    reboot
fi