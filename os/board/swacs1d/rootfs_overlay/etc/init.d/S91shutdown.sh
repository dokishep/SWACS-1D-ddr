#!/bin/sh

# S91shutdown.sh — Shutdown / reboot handler (Swacs 1D • RootDDR v2.0)
#
# Runs on reboot / poweroff.  It is ordered after S90mame_launcher.sh (90 → 91)
# so it can kill MAME before the save partition is unmounted.
#
# Steps:
#   1. Send SIGINT to MAME if running — allows MAME to write NVRAM / savestate.
#   2. Wait up to 5 s for MAME to die; fall back to SIGTERM then SIGKILL.
#   3. Sync memory card files on the SAVE partition (exFAT writes are delayed).
#   4. Umount ROMS and SAVE partitions so data is flushed before power-off.

SAVE_MP="/mnt/save"
ROMS_MP="/mnt/roms"
LOCK_DIR="/var/run/ddr"
SAVE_DEV="/dev/disk/by-partlabel/SAVE"
ROMS_DEV="/dev/disk/by-partlabel/ROMS"

# ─── HELPER ───────────────────────────────────────────────────────────────────
sync_and_wait() {
    # call sync() in the running init process, then wait for the kernel to
    # flush all dirty pages.  If the SAVE partition is busy (exFAT), retry.
    sync 2>/dev/null
    # Give the kernel 3 s to flush the exFAT journal
    sleep 3
}

# ─── 1. KILL MAME CLEANLY ─────────────────────────────────────────────────────
if killall -0 mame 2>/dev/null; then
    echo "[S91shutdown] MAME running — sending SIGINT for clean exit..."

    # SIGINT → MAME exits and writes NVRAM/savestate
    killall -SIGINT mame 2>/dev/null

    # Wait up to 5 s for it to die
    for i in $(seq 1 5); do
        killall -0 mame 2>/dev/null || break
        sleep 1
    done

    # Fall back to SIGTERM then SIGKILL if still running
    if killall -0 mame 2>/dev/null; then
        echo "[S91shutdown] MAME did not respond to SIGINT — sending SIGTERM."
        killall -SIGTERM mame 2>/dev/null
        sleep 2
    fi
    if killall -0 mame 2>/dev/null; then
        echo "[S91shutdown] MAME still alive — sending SIGKILL."
        killall -SIGKILL mame 2>/dev/null
    fi
fi

# ─── 2. SYNC SAVE PARTITION ───────────────────────────────────────────────────
# exFAT (especially fuse-exfat) buffers writes; force a full sync before
#拆卸 the partition so no game cfg / nvram / sav data is lost.
if [ -b "$SAVE_DEV" ] && mountpoint -q "$SAVE_MP" 2>/dev/null; then
    echo "[S91shutdown] Syncing SAVE partition..."
    sync_and_wait
fi

# ─── 3. UMOUNT ────────────────────────────────────────────────────────────────
if [ -b "$SAVE_DEV" ] && mountpoint -q "$SAVE_MP" 2>/dev/null; then
    umount "$SAVE_MP" 2>/dev/null || umount -lf "$SAVE_MP" 2>/dev/null
    echo "[S91shutdown] SAVE partition unmounted."
fi

if [ -b "$ROMS_DEV" ] && mountpoint -q "$ROMS_MP" 2>/dev/null; then
    umount "$ROMS_MP" 2>/dev/null || umount -lf "$ROMS_MP" 2>/dev/null
    echo "[S91shutdown] ROMS partition unmounted."
fi

echo "[S91shutdown] Done."
