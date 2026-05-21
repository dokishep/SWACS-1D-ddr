#!/bin/sh
# S90mame_launcher.sh - Primary entry point after Xorg starts
#
# Checks /var/lib/ddr/state.json for last_played game. If found and ROM CHD exists,
# launches MAME with that ROM. Otherwise launches ddr-picker.

STATE_FILE="/var/lib/ddr/state.json"
ROMS_DIR="/mnt/roms"
SAVE_DIR="/mnt/save"
GAMES_DIR="/mnt/roms/Games"

# Wait for partitions to be mounted
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -d "$ROMS_DIR" ] && break
    sleep 1
done

# Check for state.json with last_played game
LAST_GAME=""
if [ -f "$STATE_FILE" ]; then
    LAST_GAME=$(jq -r '.last_played // empty' "$STATE_FILE" 2>/dev/null)
fi

# MAME low-latency flags for DDR System 573
MAME_FLAGS="-window -video soft -filter nearest -samplerate 48000 -sound fps 60 -audio_latency 1 -audio_buffer 0.03125 -center_c 0.5 -center_y 0.5 -frameskip 0 -throttle on -speed 1.0"

# Find ROM/CHD for the game
find_rom() {
    local game="$1"
    # Check for zip file in 573 directory
    if [ -f "$ROMS_DIR/573/${game}.zip" ]; then
        echo "$ROMS_DIR/573/${game}.zip"
        return 0
    fi
    # Check Games directory
    if [ -d "$GAMES_DIR" ]; then
        for ext in zip chd; do
            if [ -f "$GAMES_DIR/${game}.${ext}" ]; then
                echo "$GAMES_DIR/${game}.${ext}"
                return 0
            fi
        done
    fi
    return 1
}

if [ -n "$LAST_GAME" ]; then
    ROM_PATH=$(find_rom "$LAST_GAME")
    if [ -n "$ROM_PATH" ]; then
        echo "Launching MAME with last played game: $LAST_GAME"
        exec mame -rompath "$ROMS_DIR" $MAME_FLAGS "$LAST_GAME"
    else
        echo "ROM not found for $LAST_GAME, launching ddr-picker"
    fi
fi

# Launch ddr-picker as fallback
if [ -x "/opt/ddr-picker/ddr-picker" ]; then
    exec /opt/ddr-picker/ddr-picker
else
    echo "ERROR: ddr-picker not found"
    exit 1
fi