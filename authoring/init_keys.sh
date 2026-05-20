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

echo "Keys initialized successfully!"
