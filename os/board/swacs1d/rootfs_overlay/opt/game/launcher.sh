#!/bin/sh
# MAME System 573 DDR Launcher
# Low-latency configuration for Konami System 573 games

set -e

# Configuration
ROM_PATH="/mnt/roms/573"
SAVE_PATH="/mnt/save/mame"
CFG_PATH="/mnt/save/mame/cfg"

# Create save directories if they don't exist
mkdir -p "$SAVE_PATH" "$CFG_PATH" "$SAVE_PATH/nvram" "$SAVE_PATH/memcard"

# System 573 MAME low-latency flags for DDR
# -window: Windowed mode (for X11)
# -video soft: Software rendering fallback
# -filter nearest: Integer scaling, no blur
# -samplerate 48000: Standard audio sample rate
# -sound_latency 1: Minimal audio latency
# -audio_buffer 0.03125: Low buffer for rhythm accuracy
# -frameskip 0: No frame skipping for timing accuracy
# -throttle on: Maintain game speed
# -speed 1.0: Normal game speed
# -refresh 60: 60Hz refresh

MAME_ARGS="-window \
    -video soft \
    -filter nearest \
    -samplerate 48000 \
    -sound_latency 1 \
    -audio_buffer 0.03125 \
    -frameskip 0 \
    -throttle on \
    -speed 1.0 \
    -refresh 60 \
    -cfg_directory $CFG_PATH \
    -nvram_directory $SAVE_PATH/nvram \
    -memcard_directory $SAVE_PATH/memcard"

# ALSA backend configuration
export ALSA_PCM_CARD=0
export SDL_AUDIODRIVER=alsa

# Launch MAME with System 573 driver
exec mame -system573 $MAME_ARGS "$@"