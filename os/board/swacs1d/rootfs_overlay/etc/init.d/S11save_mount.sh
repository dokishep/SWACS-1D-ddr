#!/bin/sh
# S11save_mount.sh - Mount SAVE partition (exFAT) for game saves/state
#
# Probes attached drives for GPT partition labeled "SAVE" and mounts it
# at /mnt/save. Creates symlink for state.json.

MOUNT_POINT="/mnt/save"
LABEL="SAVE"
DDR_DIR="/mnt/save/ddr"

mkdir -p "$MOUNT_POINT"
mkdir -p /var/lib/ddr

# Find partition by GPT label
SAVE_DEV=$(ls -l /dev/disk/by-partlabel/"$LABEL" 2>/dev/null | awk -F'/' '{print $NF}')
if [ -z "$SAVE_DEV" ]; then
    for dev in /dev/sd* /dev/mmcblk*; do
        [ -b "$dev" ] || continue
        PARTLABEL=$(blkid -o value -s PARTLABEL "$dev"* 2>/dev/null | grep -x "$LABEL" | head -n 1)
        if [ "$PARTLABEL" = "$LABEL" ]; then
            SAVE_DEV=$(basename "$dev")
            break
        fi
    done
fi

if [ -z "$SAVE_DEV" ]; then
    echo "WARNING: SAVE partition not found"
    exit 0
fi

# Try mounting with exfat, fallback to vfat
if mount -t exfat "/dev/$SAVE_DEV" "$MOUNT_POINT" -o uid=0,gid=0 2>/dev/null; then
    echo "Mounted SAVE partition ($SAVE_DEV) as exfat"
elif mount -t vfat "/dev/$SAVE_DEV" "$MOUNT_POINT" -o uid=0,gid=0 2>/dev/null; then
    echo "Mounted SAVE partition ($SAVE_DEV) as vfat (fallback)"
else
    echo "ERROR: Failed to mount SAVE partition"
    exit 1
fi

mkdir -p "$DDR_DIR"

# Symlink state.json to SAVE partition if it exists there
if [ -f "$DDR_DIR/state.json" ]; then
    ln -sf "$DDR_DIR/state.json" /var/lib/ddr/state.json
fi