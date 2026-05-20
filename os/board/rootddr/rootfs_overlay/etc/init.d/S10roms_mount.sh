#!/bin/sh
# Mount ROMS partition (exFAT) to /mnt/roms

mkdir -p /mnt/roms

# Find partition labeled ROMS
ROMS_PART=$(blkid -L ROMS 2>/dev/null)

if [ -n "$ROMS_PART" ]; then
    echo "Mounting ROMS partition $ROMS_PART to /mnt/roms"
    if mount -t exfat "$ROMS_PART" /mnt/roms 2>/dev/null; then
        echo "ROMS mounted successfully"
    elif mount -t vfat "$ROMS_PART" /mnt/roms 2>/dev/null; then
        echo "ROMS mounted with vfat fallback"
    else
        echo "Warning: Failed to mount ROMS partition"
    fi
else
    echo "ROMS partition not found - will be created on first boot"
fi