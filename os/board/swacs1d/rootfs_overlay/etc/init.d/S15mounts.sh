#!/bin/sh
# S15mounts.sh - Detect and auto-create partitions if missing (first boot only)
#
# For RootDDR: PART 1 = EFI (FAT32), PART 2 = ROOT_SYSTEM (squashfs),
# PART 3 = ROMS (exFAT), PART 4 = SAVE (exFAT)
#
# Only creates partitions if the drive has NO existing partitions.

ROMS_LABEL="ROMS"
SAVE_LABEL="SAVE"

# Check if partitions already exist
ls /dev/disk/by-partlabel/"$ROMS_LABEL" 2>/dev/null && exit 0
ls /dev/disk/by-partlabel/"$SAVE_LABEL" 2>/dev/null && exit 0

# Find the target drive (not the rootfs drive)
ROOT_DEV=$(awk '$5 == "/" {print $3}' /proc/self/mountinfo)
if [ -n "$ROOT_DEV" ] && [ -d "/sys/dev/block/$ROOT_DEV" ]; then
    if [ -f "/sys/dev/block/$ROOT_DEV/partition" ]; then
        TARGET_DRIVE="/dev/$(basename $(readlink -f /sys/dev/block/$ROOT_DEV/..))"
    else
        TARGET_DRIVE="/dev/$(basename $(readlink -f /sys/dev/block/$ROOT_DEV))"
    fi
else
    TARGET_DRIVE=$(mount | grep "on / " | cut -d' ' -f1 | sed 's/[0-9]*$//')
fi

# Count existing partitions on target drive
PART_COUNT=$(lsblk -ln -o NAME "$TARGET_DRIVE" 2>/dev/null | wc -l)

# Only proceed if there are no partitions yet (fresh drive)
[ "$PART_COUNT" -gt 1 ] && exit 0

echo "Creating partitions on $TARGET_DRIVE..."

# Create GPT with 4 partitions: EFI, ROOT_SYSTEM, ROMS, SAVE
sgdisk -o "$TARGET_DRIVE" || exit 1
sgdisk -n 1:1M:+512M -c 1:"EFI" -t 1:EF00 "$TARGET_DRIVE"
sgdisk -n 2:0:+4G -c 2:"ROOT_SYSTEM" -t 2:8300 "$TARGET_DRIVE"
sgdisk -n 3:0:+2G -c 3:"ROMS" -t 3:0700 "$TARGET_DRIVE"
sgdisk -n 4:0:0 -c 4:"SAVE" -t 4:0700 "$TARGET_DRIVE"

partprobe "$TARGET_DRIVE"

# Format exFAT partitions
ROOT_PART=$(lsblk -ln -o NAME "$TARGET_DRIVE" | grep -E "^[a-z]+[0-9]+$" | head -n 3 | tail -n 1 | sed 's/^/dev\//')
ROMS_PART=$(lsblk -ln -o NAME "$TARGET_DRIVE" | grep -E "^[a-z]+[0-9]+$" | tail -n 2 | head -n 1 | sed 's/^/dev\//')
SAVE_PART=$(lsblk -ln -o NAME "$TARGET_DRIVE" | grep -E "^[a-z]+[0-9]+$" | tail -n 1 | sed 's/^/dev\//')

# Format ROMS partition
mkfs.exfat -n "$ROMS_LABEL" "$ROMS_PART" 2>/dev/null || mkfs.vfat -n "$ROMS_LABEL" "$ROMS_PART"

# Format SAVE partition
mkfs.exfat -n "$SAVE_LABEL" "$SAVE_PART" 2>/dev/null || mkfs.vfat -n "$SAVE_LABEL" "$SAVE_PART"

echo "Partition creation complete. Reboot to mount."