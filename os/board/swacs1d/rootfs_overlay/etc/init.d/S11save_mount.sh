#!/bin/sh

# S11save_mount.sh — Boot init script (Swacs 1D • RootDDR v2.0)
# Mounts the SAVE (exFAT) partition and persists /var/lib/ddr/state.json to it.
#
# The SAVE partition holds user-writable data: game configs, NVRAM, high scores,
# memory card images, and the DDR state file (state.json) that records the last-played
# game for auto-resume.
#
# PARTUUID for the SAVE partition (see genimage.cfg):
#   e2f890b4-3d6c-5g7b-9e0f-2d3c4b5a6c7e
# GPT label: SAVE

SAVE_DEV="/dev/disk/by-partlabel/SAVE"
SAVE_MP="/mnt/save"
DDR_STATE_SRC="/var/lib/ddr/state.json"
DDR_STATE_DST="${SAVE_MP}/ddr/state.json"
INPUT_MAP_SRC="/usr/lib/ddr/input-map.json"
INPUT_MAP_DST="${SAVE_MP}/ddr/input-map.json"
LOCK_DIR="/var/run/ddr"

log() { echo "[S11save] $*"; }

wait_for_dev() {
    DEV="$1"; TIMEOUT="${2:-15}"
    i=0
    while [ $i -lt "$TIMEOUT" ]; do
        [ -b "$DEV" ] && return 0
        sleep 1; i=$((i + 1))
    done
    return 1
}

mkdir -p "${LOCK_DIR}" "${SAVE_MP}" "$(dirname "${DDR_STATE_DST}")"

if ! wait_for_dev "$SAVE_DEV" 15; then
    log "SAVE partition not found at ${SAVE_DEV} — skipping."
    # Create the ddr directory anyway so state.json won't fail.
    mkdir -p "$(dirname "${DDR_STATE_DST}")"
    echo '{}' > "${DDR_STATE_DST}"
    exit 0
fi

# Try kernel exfat driver first, then fuse-exfat fallback
if mount -t exfat -o rw,noatime,exec "$SAVE_DEV" "${SAVE_MP}" 2>/dev/null; then
    log "Mounted SAVE (exfat kernel driver)."
elif mount -t exfat-fuse -o rw,noatime,exec "$SAVE_DEV" "${SAVE_MP}" 2>/dev/null; then
    log "Mounted SAVE (fuse-exfat)."
else
    log "WARNING: Failed to mount SAVE partition. State persistence disabled."
    mkdir -p "$(dirname "${DDR_STATE_DST}")"
    echo '{}' > "${DDR_STATE_DST}"
    exit 0
fi

# Persist state.json to SAVE partition (symlink over whole partition root)
mkdir -p "${SAVE_MP}/ddr"
cp -f "${DDR_STATE_SRC}" "${DDR_STATE_DST}" 2>/dev/null || echo '{}' > "${DDR_STATE_DST}"

# If the roms symlink didn't exist yet, ensure the SAVE overlay directory is writable
chmod 0755 "${SAVE_MP}"

log "S11save_mount done."
