#!/bin/sh
# S10roms_mount.sh - Mount ROMS partition (exFAT) for DDR game ROMs
#
# Probes attached drives for GPT partition labeled "ROMS" and mounts it
# at /mnt/roms. Falls back to vfat if exfat driver is unavailable.

MOUNT_POINT="/mnt/roms"
LABEL="ROMS"

mkdir -p "$MOUNT_POINT"

# Find partition by GPT label
ROMS_DEV=$(ls -l /dev/disk/by-partlabel/"$LABEL" 2>/dev/null | awk -F'/' '{print $NF}')
if [ -z "$ROMS_DEV" ]; then
    # Try to find by scanning partitions
    for dev in /dev/sd* /dev/mmcblk*; do
        [ -b "$dev" ] || continue
        PARTLABEL=$(blkid -o value -s PARTLABEL "$dev"* 2>/dev/null | grep -x "$LABEL" | head -n 1)
        if [ "$PARTLABEL" = "$LABEL" ]; then
            ROMS_DEV=$(basename "$dev")
            break
        fi
    done
fi

if [ -z "$ROMS_DEV" ]; then
    echo "WARNING: ROMS partition not found"
    exit 0
fi

# Try mounting with exfat, fallback to vfat
if mount -t exfat "/dev/$ROMS_DEV" "$MOUNT_POINT" -o uid=0,gid=0,exec 2>/dev/null; then
    echo "Mounted ROMS partition ($ROMS_DEV) as exfat"
elif mount -t vfat "/dev/$ROMS_DEV" "$MOUNT_POINT" -o uid=0,gid=0,exec 2>/dev/null; then
    echo "Mounted ROMS partition ($ROMS_DEV) as vfat (fallback)"
else
    echo "ERROR: Failed to mount ROMS partition"
    exit 1
fi

# Create symlink for games path
ln -sf "$MOUNT_POINT" /mnt/roms