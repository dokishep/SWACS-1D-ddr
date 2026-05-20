#!/bin/bash
set -e

# Buildroot variables
BINARIES_DIR="$1"
BOARD_DIR="board/swacs1d"
EFI_DIR="${BINARIES_DIR}/efi-part/EFI/BOOT"

echo "POST-IMAGE: Preparing EFI directory structure..."

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

# Sign the bootloader and kernel if keys and sbsign are present
SB_KEY="${BOARD_DIR}/keys/db.key"
SB_CRT="${BOARD_DIR}/keys/db.crt"

if [ -f "$SB_KEY" ] && [ -f "$SB_CRT" ] && command -v sbsign >/dev/null 2>&1; then
    echo "POST-IMAGE: Secure Boot keys found. Signing EFI bootloader..."
    sbsign --key "$SB_KEY" --cert "$SB_CRT" --output "${EFI_DIR}/bootx64.efi" "${EFI_DIR}/bootx64.efi"

    echo "POST-IMAGE: Signing Linux kernel..."
    sbsign --key "$SB_KEY" --cert "$SB_CRT" --output "${BINARIES_DIR}/efi-part/bzImage" "${BINARIES_DIR}/bzImage"
else
    echo "POST-IMAGE: WARNING: Secure Boot keys or sbsign tool missing. Copying unsigned kernel."
    cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/efi-part/bzImage"
fi

echo "POST-IMAGE: EFI structure complete."