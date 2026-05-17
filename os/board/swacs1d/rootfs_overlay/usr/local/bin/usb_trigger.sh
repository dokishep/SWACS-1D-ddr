#!/bin/bash
MOUNT_POINT="/mnt/usb"; STAGING="/tmp/staging"; GAME_DIR="/opt/game"
UPDATE_PUB_KEY="$GAME_DIR/keys/update_public.pem"
UPDATE_AES_KEY="$GAME_DIR/keys/update_aes.key"

BUNDLE=$(ls $MOUNT_POINT/*.bundle | head -n 1)
[ -z "$BUNDLE" ] || [ ! -d "$GAME_DIR" ] && exit 0

mkdir -p $STAGING && tar -xf "$BUNDLE" -C $STAGING
# Verify RSA Signature using keys from the encrypted drive
openssl dgst -sha256 -verify "$UPDATE_PUB_KEY" -signature $STAGING/bundle.sig $STAGING/unverified.tar || exit 1

tar -xf $STAGING/unverified.tar -C $STAGING
NEW_VER=$(jq '.version' $STAGING/manifest.json)
CUR_VER=$(cat $GAME_DIR/.version 2>/dev/null || echo 0)
[ "$NEW_VER" -le "$CUR_VER" ] && exit 1

# Apply update using AES key from the encrypted drive
mount -o remount,rw $GAME_DIR
openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass file:"$UPDATE_AES_KEY" -in $STAGING/payload.enc | tar --zstd -x -C $GAME_DIR
echo "$NEW_VER" > $GAME_DIR/.version
sync && mount -o remount,ro $GAME_DIR
killall bootstrap