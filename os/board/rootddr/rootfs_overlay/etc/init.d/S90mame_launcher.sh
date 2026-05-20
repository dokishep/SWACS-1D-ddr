#!/bin/sh
# MAME launcher for DDR games
# Checks state.json for last played game or launches ddr-picker

STATE_FILE="/var/lib/ddr/state.json"

if [ -f "$STATE_FILE" ]; then
    LAST_GAME=$(jq -r '.last_played // empty' "$STATE_FILE" 2>/dev/null)
    if [ -n "$LAST_GAME" ] && [ -f "/mnt/roms/573/$LAST_GAME.chd" ]; then
        echo "Launching MAME with last played game: $LAST_GAME"
        export MEMCARD_ROOT=/mnt/save/ddr_cards
        exec mame -window -video soft -filter nearest -samplerate 48000 \
          -sound_latency 1 -audio_buffer 0.03125 -frameskip 0 \
          -center_x 0.5 -center_y 0.5 "$LAST_GAME"
    fi
fi

# No state or missing ROM, launch ddr-picker
echo "Launching ddr-picker"
if [ -x /opt/ddr-picker/ddr-picker ]; then
    exec /opt/ddr-picker/ddr-picker
fi

echo "No game launcher available"