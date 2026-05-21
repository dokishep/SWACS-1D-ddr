#!/bin/bash
set -e

# Buildroot variables
BINARIES_DIR="$1"
BOARD_DIR="board/swacs1d"
EFI_DIR="${BINARIES_DIR}/efi-part/EFI/BOOT"

echo "POST-IMAGE: Preparing EFI directory structure..."

mkdir -p "${EFI_DIR}"

# Buildroot automatically creates bootx64.efi. Verify it's present.
if [ -f "${EFI_DIR}/bootx64.efi" ]; then
    echo "POST-IMAGE: bootx64.efi found."
else
    echo "ERROR: bootx64.efi not found in ${EFI_DIR}!"
    ls -la "${BINARIES_DIR}"
    exit 1
fi

# Copy grub config into the EFI partition
cp "${BOARD_DIR}/grub.cfg" "${EFI_DIR}/grub.cfg"

# Copy the kernel into the EFI partition (unsigned — no Secure Boot on this board)
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"

echo "POST-IMAGE: EFI structure complete."
