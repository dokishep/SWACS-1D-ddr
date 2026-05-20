#!/bin/bash
set -e

# Buildroot variables
BINARIES_DIR="$1"
BOARD_DIR="board/rootddr"
EFI_DIR="${BINARIES_DIR}/efi-part/EFI/BOOT"

echo "POST-IMAGE: Preparing EFI directory structure for RootDDR..."

mkdir -p "${EFI_DIR}"

# Buildroot automatically creates bootx64.efi. We just verify it's there.
if [ -f "${EFI_DIR}/bootx64.efi" ]; then
    echo "POST-IMAGE: bootx64.efi found."
else
    echo "ERROR: bootx64.efi not found in ${EFI_DIR}!"
    ls -la "${BINARIES_DIR}"
    exit 1
fi

# Copy the grub config
cp "${BOARD_DIR}/grub.cfg" "${EFI_DIR}/grub.cfg"

# Copy kernel to EFI partition (unsigned - no Secure Boot required)
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"

echo "POST-IMAGE: RootDDR EFI structure complete."