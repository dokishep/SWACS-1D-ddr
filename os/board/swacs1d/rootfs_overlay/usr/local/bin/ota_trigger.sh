#!/bin/bash
BUNDLE="/var/data/update.bundle"
STAGING="/tmp/staging_ota"
GAME_DIR="/opt/game"
UPDATE_PUB_KEY="$GAME_DIR/keys/update_public.pem"
UPDATE_AES_KEY="$GAME_DIR/keys/update_aes.key"

while true; do
    if [ -f "$BUNDLE" ] && [ -d "$GAME_DIR" ]; then
        echo "OTA update bundle detected. Applying..."
        
        # Clean up any old staging
        rm -rf "$STAGING" && mkdir -p "$STAGING"
        
        # Extract the outer tarball
        if tar -xf "$BUNDLE" -C "$STAGING"; then
            # Verify RSA Signature
            if openssl dgst -sha256 -verify "$UPDATE_PUB_KEY" -signature "$STAGING/bundle.sig" "$STAGING/unverified.tar"; then
                # Extract the unverified.tar containing manifest.json and payload.enc
                tar -xf "$STAGING/unverified.tar" -C "$STAGING"
                
                NEW_VER=$(jq '.version' "$STAGING/manifest.json")
                CUR_VER=$(cat "$GAME_DIR/.version" 2>/dev/null || echo 0)
                
                if [ "$NEW_VER" -gt "$CUR_VER" ]; then
                    echo "OTA version $NEW_VER is newer than current $CUR_VER. Installing..."
                    
                    # Apply update
                    mount -o remount,rw "$GAME_DIR"
                    if openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass file:"$UPDATE_AES_KEY" -in "$STAGING/payload.enc" | tar --zstd -x -C "$GAME_DIR"; then
                        
                        # Run update.sh if exists
                        if [ -f "$GAME_DIR/update.sh" ]; then
                            chmod +x "$GAME_DIR/update.sh"
                            "$GAME_DIR/update.sh"
                            rm -f "$GAME_DIR/update.sh"
                        fi
                        
                        echo "$NEW_VER" > "$GAME_DIR/.version"
                        echo "OTA update successful to version $NEW_VER"
                    else
                        echo "OTA update payload decryption/extraction failed!"
                    fi
                    sync && mount -o remount,ro "$GAME_DIR"
                    
                    # Kill bootstrap so Xinit restarts the game loop
                    killall bootstrap
                else
                    echo "OTA bundle version ($NEW_VER) is not newer than current ($CUR_VER). Ignoring."
                fi
            else
                echo "OTA signature verification failed!"
            fi
        else
            echo "OTA bundle extraction failed!"
        fi
        
        # Remove the update.bundle so we don't loop on it
        rm -f "$BUNDLE"
        rm -rf "$STAGING"
    fi
    sleep 5
done
