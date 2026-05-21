#!/bin/sh
# S91shutdown.sh - Clean shutdown handler for MAME and partitions
#
# Ensures MAME shuts down cleanly, memory cards are synced, and
# SAVE partition is unmounted properly.

SAVE_MOUNT="/mnt/save"
ROMS_MOUNT="/mnt/roms"

# Signal MAME to exit cleanly (SIGINT waits for clean exit)
if pgrep mame > /dev/null 2>&1; then
    echo "Stopping MAME..."
    killall -SIGINT mame 2>/dev/null
    sleep 2
fi

# Force kill if still running
if pgrep mame > /dev/null 2>&1; then
    killall -9 mame 2>/dev/null
fi

# Sync all filesystems
sync

# Unmount SAVE partition if mounted
if mountpoint -q "$SAVE_MOUNT"; then
    echo "Unmounting SAVE partition..."
    fuser -k -m "$SAVE_MOUNT" 2>/dev/null
    umount "$SAVE_MOUNT" 2>/dev/null
fi

# Unmount ROMS partition if mounted
if mountpoint -q "$ROMS_MOUNT"; then
    echo "Unmounting ROMS partition..."
    fuser -k -m "$ROMS_MOUNT" 2>/dev/null
    umount "$ROMS_MOUNT" 2>/dev/null
fi