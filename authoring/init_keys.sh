#!/bin/bash
# Generate testing keys for SWACS-1D provisioning and update bundles
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Generating private RSA key..."
openssl genrsa -out update_private.pem 2048

echo "Extracting public RSA key..."
openssl rsa -pubout -in update_private.pem -out update_public.pem

echo "Creating AES key with 0000 password..."
echo -n "0000" > update_aes.key

# Generate UEFI Secure Boot keys
SB_KEYS_DIR="../os/board/swacs1d/keys"
mkdir -p "$SB_KEYS_DIR"
if [ ! -f "$SB_KEYS_DIR/db.key" ]; then
    echo "Generating UEFI Secure Boot keys..."
    openssl req -new -x509 -newkey rsa:2048 -nodes -keyout "$SB_KEYS_DIR/db.key" -out "$SB_KEYS_DIR/db.crt" -days 3650 -subj "/CN=SWACS Secure Boot DB/"
    openssl x509 -in "$SB_KEYS_DIR/db.crt" -outform DER -out "$SB_KEYS_DIR/db.der"
fi

echo "Keys initialized successfully!"
