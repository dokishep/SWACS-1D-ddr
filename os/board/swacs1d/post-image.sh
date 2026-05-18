#!/bin/bash
set -e

# $1 is output/images directory passed by Buildroot
BINARIES_DIR="$1"
BOARD_DIR="board/swacs1d"
EFI_DIR="${BINARIES_DIR}/efi-part/EFI/BOOT"

echo "POST-IMAGE: Preparing EFI directory structure..."

# Create the folder structure genimage.cfg is looking for
mkdir -p "${EFI_DIR}"

# Copy the compiled Grub EFI binary to the standard search path
if [ -f "${BINARIES_DIR}/grub-efi.bin" ]; then
    cp "${BINARIES_DIR}/grub-efi.bin" "${EFI_DIR}/BOOTX64.EFI"
else
    echo "ERROR: grub-efi.bin not found! Ensure BR2_TARGET_GRUB2_X86_64_EFI is enabled."
    exit 1
fi

# Copy the grub config file from your board directory
cp "${BOARD_DIR}/grub.cfg" "${EFI_DIR}/grub.cfg"

# Copy the kernel so it's available for the VFAT partition
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"

echo "POST-IMAGE: EFI structure complete."