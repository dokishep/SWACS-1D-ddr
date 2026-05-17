#!/bin/bash
# 1. Create structure
mkdir -p ./factory_payload/keys
# 2. Embed the update keys so the machine can verify future bundles
cp update_public.pem update_aes.key ./factory_payload/keys/
# 3. Add your Rust binary and assets to ./factory_payload/
# 4. Pack
tar --zstd -cf factory_provision.tar.zst -C ./factory_payload .
echo "factory_provision.tar.zst ready for the distributor."