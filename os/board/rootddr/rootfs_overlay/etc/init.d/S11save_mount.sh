#!/bin/sh
# Mount SAVE partition (exFAT) to /mnt/save and link to /var/lib/ddr

mkdir -p /mnt/save
mkdir -p /var/lib/ddr

# Find partition labeled SAVE
SAVE_PART=$(blkid -L SAVE 2>/dev/null)

if [ -n "$SAVE_PART" ]; then
    echo "Mounting SAVE partition $SAVE_PART to /mnt/save"
    if mount -t exfat "$SAVE_PART" /mnt/save 2>/dev/null; then
        echo "SAVE mounted successfully"
    elif mount -t vfat "$SAVE_PART" /mnt/save 2>/dev/null; then
        echo "SAVE mounted with vfat fallback"
    else
        echo "Warning: Failed to mount SAVE partition"
    fi

    # Create symlink for state.json
    if [ -f /mnt/save/ddr/state.json ]; then
        ln -sf /mnt/save/ddr/state.json /var/lib/ddr/state.json
    fi
else
    echo "SAVE partition not found - will be created on first boot"
fi