#!/bin/sh

# S15part.sh — Boot init script (Swacs 1D • RootDDR v2.0)
# Detects and creates GPT partitions on the boot drive on first boot,
# if they don't already exist.
#
# On a fresh SD-card install only the ROOT_SYSTEM and boot ESP partitions
# (filled by genimage from the squashfs image and EFI image respectively)
# are present.  This script detects the missing ROMS and SAVE partitions
# and creates them with sgdisk so the board can boot unattended after imaging.
#
# Creates:
#   PART 3 — "ROMS"   → exFAT data partition (type 0x07), growable
#   PART 4 — "SAVE"   → exFAT data partition (type 0x07), 3 GB reserved
#
# grub.cfg boots the kernel with root=PARTUUID of the ROOT_SYSTEM
# (squashfs) partition; that PARTUUID must never change and this script
# never touches the ROOT_SYSTEM partition (it is managed by genimage).

log() { echo "[S15part] $*"; }

ROOT_DEV_MM=$(awk '$5 == "/" {print $3}' /proc/self/mountinfo)
if [ -n "$ROOT_DEV_MM" ] && [ -d "/sys/dev/block/$ROOT_DEV_MM" ]; then
    if [ -f "/sys/dev/block/$ROOT_DEV_MM/partition" ]; then
        DRIVE="/dev/$(basename "$(readlink -f "/sys/dev/block/$ROOT_DEV_MM/..")")"
    else
        DRIVE="/dev/$(basename "$(readlink -f "/sys/dev/block/$ROOT_DEV_MM")")"
    fi
else
    DRIVE=$(mount | grep "on / " | cut -d' ' -f1 | sed 's/[0-9]*$//')
fi

HAVE_ROMS=0; HAVE_SAVE=0
[ -b /dev/disk/by-partlabel/ROMS ] && HAVE_ROMS=1
[ -b /dev/disk/by-partlabel/SAVE ] && HAVE_SAVE=1

if [ "$HAVE_ROMS" -eq 1 ] && [ "$HAVE_SAVE" -eq 1 ]; then
    log "ROMS and SAVE found — partition setup complete."; exit 0
fi

# ─── BARE-DISK INIT ────────────────────────────────────────────────────────────
# Only zero GPT partitions detected — create all three from scratch.
if ! ls "${DRIVE}"* 2>/dev/null | grep -qv "${DRIVE}"; then
    log "Drive ${DRIVE} is blank — writing fresh GPT partitions."

    sgdisk --zap-all "$DRIVE"
    sgdisk --mbrtogpt --clear "$DRIVE"

    # 1 — EFI System Partition (FAT32, 512 MB, offset 1 MB)
    sgdisk -n 1:1M:+512M \
           -c 1:"boot" \
           -t 1:c12a7328-f81f-11d2-ba4b-00a0c93ec93b \
           "$DRIVE"

    # 2 — ROOT_SYSTEM (squashfs read-only Linux root, 4 GB)
    sgdisk -n 2:513M:+4096M \
           -c 2:"ROOT_SYSTEM" \
           -t 2:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 \
           "$DRIVE"

    # 3 — ROMS (exFAT data, 8 GB)
    sgdisk -n 3:4609M:+8192M \
           -c 3:"ROMS" \
           -t 3:0727c47a-ab4d-48d1-9968-d70a68e27d30 \
           "$DRIVE"

    # 4 — SAVE (exFAT data, 3 GB at tail)
    sgdisk -n 4:-3072M:0 \
           -c 4:"SAVE" \
           -t 4:0727c47a-ab4d-48d1-9968-d70a68e27d30 \
           "$DRIVE"

    partprobe "$DRIVE"
    udevadm settle

    log "GPT partitions written to ${DRIVE}. Now re-image and reboot."
    echo "Partitions created — re-image the drive and reboot."
    reboot
fi

log "ROOT_SYSTEM already exists, leaving existing partitions untouched."
exit 0
