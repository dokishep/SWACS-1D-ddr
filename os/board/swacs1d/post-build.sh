#!/bin/bash
# $1 is the path to the target rootfs
# BINARIES_DIR is a Buildroot variable pointing to the output/images folder

# 1. Create the EFI folder structure genimage is looking for
mkdir -p "${BINARIES_DIR}/efi-part/EFI/BOOT"

# 2. Copy the Grub EFI binary to the standard UEFI search path
# Buildroot generates 'grub-efi.bin' when Grub2 EFI is enabled
cp "${BINARIES_DIR}/grub-efi.bin" "${BINARIES_DIR}/efi-part/EFI/BOOT/BOOTX64.EFI"

# 3. Copy your Grub configuration
cp board/swacs1d/grub.cfg "${BINARIES_DIR}/efi-part/EFI/BOOT/grub.cfg"

# 4. Copy the kernel to the EFI partition
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"
