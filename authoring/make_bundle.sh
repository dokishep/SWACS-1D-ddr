#!/bin/bash
# Usage: ./make_bundle.sh <version_int>
VERSION=$1; AES_KEY="update_aes.key"; PRIV_KEY="update_private.pem"

echo "{\"version\": $VERSION}" > manifest.json
tar --zstd -cf - -C ./update_files . | openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$AES_KEY" -out payload.enc
tar -cf unverified.tar manifest.json payload.enc
openssl dgst -sha256 -sign "$PRIV_KEY" -out bundle.sig unverified.tar
tar -cf "update_v${VERSION}.bundle" unverified.tar bundle.sig
rm unverified.tar bundle.sig manifest.json payload.enc