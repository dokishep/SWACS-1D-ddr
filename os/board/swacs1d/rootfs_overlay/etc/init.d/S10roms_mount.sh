#!/bin/sh

# S10roms_mount.sh — Boot init script (Swacs 1D • RootDDR v2.0)
# Mounts the ROMS (exFAT) partition and creates /mnt/roms.
#
# This partition holds DDR System 573 ROM CHD files placed on the USB drive
# by the end-user.  The exFAT driver is tried first (kernel driver, fast);
# if unavailable the script falls back to fuse-exfat.
#
# PARTUUID for the ROMS partition (see genimage.cfg):
#   d1e879a3-2c5b-4f6a-8d9e-1c2b3a4f5e6d
# GPT label: ROMS

ROM_DEV="/dev/disk/by-partlabel/ROMS"
ROM_MP="/mnt/roms"
SYMLINK="/mnt/roms"   # top-level symlink (exec perms for MAME path traversal)
LOCK_DIR="/var/run/ddr"

log() { echo "[S10roms] $*"; }

wait_for_dev() {
    DEV="$1"; TIMEOUT="${2:-10}"
    i=0
    while [ $i -lt "$TIMEOUT" ]; do
        [ -b "$DEV" ] && return 0
        sleep 1; i=$((i + 1))
    done
    return 1
}

mkdir -p "${LOCK_DIR}" "${ROM_MP}"

if ! wait_for_dev "$ROM_DEV" 15; then
    log "ROMS partition not found at ${ROM_DEV} — skipping (may be mounted later)."
    exit 0
fi

# Try kernel exfat driver first, then fuse-exfat fallback
FORCE=0
if mount -t exfat -o rw,noatime,exec "$ROM_DEV" "${ROM_MP}" 2>/dev/null; then
    FORCE=1
    log "Mounted ROMS (exfat kernel driver)."
elif mount -t exfat-fuse -o rw,noatime,exec "$ROM_DEV" "${ROM_MP}" 2>/dev/null; then
    FORCE=1
    log "Mounted ROMS (fuse-exfat)."
else
    log "WARNING: Failed to mount ROMS partition. Check filesystem."
fi

# Create the top-level /mnt/roms symlink with exec flag so
# MAME can descend into the directory tree when launching CHDs.
# If /mnt/roms already exists (genimage created it), just apply perms.
if [ -d "$SYMLINK" ]; then
    chmod 0755 "$SYMLINK"
else
    ln -s "$ROM_MP" "$SYMLINK"
    chmod 0755 "$SYMLINK"
fi

[ "$FORCE" -eq 1 ] && log "S10roms_mount done."
