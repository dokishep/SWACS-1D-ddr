#!/bin/sh
# S90mame_launcher.sh - Primary entry point after Xorg starts
#
# Checks /var/lib/ddr/state.json for last_played game. If found and ROM CHD exists,
# launches MAME with that ROM. Otherwise launches ddr-picker.
# Includes Service+Test hotkey watcher for clean MAME exit.

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
MAME_FLAGS="-window -video soft -filter nearest -samplerate 48000 -sound fps 60 -audio_latency 1 -audio_buffer 0.03125 -center_c 0.5 -center_y 0.5 -frameskip 0 -throttle on -speed 1.0 -audio_normal 1"

# Find ROM/CHD for the game
find_rom() {
    local game="$1"
    for ext in zip chd; do
        if [ -f "$ROMS_DIR/573/${game}.${ext}" ]; then
            return 0
        fi
    done
    if [ -d "$GAMES_DIR" ]; then
        for ext in zip chd; do
            if [ -f "$GAMES_DIR/${game}.${ext}" ]; then
                return 0
            fi
        done
    fi
    return 1
}

launch_mame() {
    local game="$1"
    python3 /usr/libexec/mame_hotkey_watcher.py &
    HOTKEY_PID=$!
    mame -rompath "$ROMS_DIR" $MAME_FLAGS "$game"
    kill $HOTKEY_PID 2>/dev/null
}

if [ -n "$LAST_GAME" ]; then
    if find_rom "$LAST_GAME"; then
        echo "Launching MAME with last played game: $LAST_GAME"
        launch_mame "$LAST_GAME"
    else
        echo "ROM not found for $LAST_GAME, launching ddr-picker"
    fi
fi

# Save last_played to state for next boot
update_state() {
    local game="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    if [ -f "$STATE_FILE" ]; then
        tmp=$(mktemp)
        jq ".last_played = \"$game\"" "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE"
    else
        echo "{\"last_played\": \"$game\"}" > "$STATE_FILE"
    fi
}

# Launch ddr-picker as fallback
if [ -x "/opt/ddr-picker/ddr-picker" ]; then
    exec /opt/ddr-picker/ddr-picker
else
    echo "ERROR: ddr-picker not found"
    exit 1
fi