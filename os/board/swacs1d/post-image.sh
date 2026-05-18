#!/bin/bash
set -e

# Buildroot variables
BINARIES_DIR="$1"
BOARD_DIR="board/swacs1d"
EFI_DIR="${BINARIES_DIR}/efi-part/EFI/BOOT"

echo "POST-IMAGE: Preparing EFI directory structure..."

mkdir -p "${EFI_DIR}"

# Copy the compiled Grub EFI binary
if [ -f "${BINARIES_DIR}/grub-efi.bin" ]; then
    cp "${BINARIES_DIR}/grub-efi.bin" "${EFI_DIR}/BOOTX64.EFI"
else
    echo "ERROR: grub-efi.bin not found! Check your defconfig for BR2_TARGET_GRUB2_X86_64_EFI"
    exit 1
fi

# Copy the grub config
cp "${BOARD_DIR}/grub.cfg" "${EFI_DIR}/grub.cfg"

# Copy the kernel
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"

echo "POST-IMAGE: EFI structure complete."