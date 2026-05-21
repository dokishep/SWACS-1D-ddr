#!/bin/sh

# S90mame_launcher.sh — Boot init script (Swacs 1D • RootDDR v2.0)
# Primary entry point after Xorg starts.
#
# Boot flow:
#   1. Check /var/lib/ddr/state.json for last_played.
#   2. If found AND the ROM CHD exists under /mnt/roms/573/, launch MAME with
#      that ROM and the exact low-latency flags required for System 573 hardware.
#   3. If no state or ROM missing, launch ddr-picker (GUI ROM browser).
#
# Service+Test hotkey (exit to picker):
#   Hold Joypad1 Start (SERVICE) + Coin1 (TEST) for 2 continuous seconds
#   → kill MAME with SIGINT (clean exit, saves state) → exec /opt/ddr-picker --resume
#   If released before 2 s the timer resets.
#
# DDR System 573 clock reference:
#   Nominal master clock 27 MHz; 1-6 Mix / MAX / MAX2 clock ≈ 56 Hz
#   with dipole-dipole crystal shifter (derived from the nominal 60 Hz field).
#   MAME Config flag: -speed 1.0 -frameskip 0 -audio_latency 1 -audio_buffer 0.03125

MAME_PID=
PICKER="/opt/ddr-picker"
STATE_FILE="/var/lib/ddr/state.json"
ROM_BASE="/mnt/roms/573"
MAME="/usr/local/bin/mame"   # Buildroot MAME path

# System 573 CHD path table (ZIP stem → CHD name)
#   ddr1stmix.zip  → ddr1stmix.chd
#   ddr2ndmix.zip  → ddr2ndmix.chd
#   3rdmix.zip     → 3rdmix.chd
#   etc.
chd_for_zip() {
    local zip_stem="$1"
    echo "${ROM_BASE}/${zip_stem}.chd"
}

# Read last_played from state.json
last_played() {
    [ -f "$STATE_FILE" ] || return 1
    jq -r '.last_played // empty' "$STATE_FILE" 2>/dev/null
}

launch_mame() {
    local rom_chd="$1"
    local game_name="$2"

    log() { echo "[MAME-launch] $*"; }

    # ── LOW-LATENCY MAME FLAGS FOR DDR SYSTEM 573 ──────────────────────────
    {
        # Video: OpenGL window, integer nearest-neighbor scaling, centered
        log "Launching MAME ─ ${game_name}"
        log "ROM: ${rom_chd}"

        exec "$MAME" "${game_name}" \
            -window \
            -video opengl \
            -filter nearest \
            -samplerate 48000 \
            -sound fps 60 \
            -audio_latency 1 \
            -audio_buffer 0.03125 \
            -audio_normal 1 \
            -center_c 0.5 \
            -center_y 0.5 \
            -frameskip 0 \
            -throttle on \
            -speed 1.0 \
            -refresh 60 \
            -exit_on_escape \
            -
    } &

    MAME_PID=$!
}

launch_picker() {
    [ -x "$PICKER" ] || exit 1
    exec "$PICKER" --resume
}

# ── CONFIGURATION ───────────────────────────────────────────────────────────────
ROM="$1"

# If ROM is given we can skip state.json lookup (e.g. called from wrapper)
if [ -n "$ROM" ]; then
    ROM_CHD="$(chd_for_zip "$ROM")"
    [ -f "$ROM_CHD" ] && launch_mame "$ROM_CHD" "$ROM" && exit 0
fi

# Read state.json for auto-resume
LAST="$(last_played)"
if [ -n "$LAST" ]; then
    ROM_CHD="$(chd_for_zip "$LAST")"
    if [ -f "$ROM_CHD" ]; then
        launch_mame "$ROM_CHD" "$LAST"
        exit 0
    else
        echo "S90mame: ROM ${LAST}.chd not found at ${ROM_CHD} — falling back to picker."
    fi
fi

# No saved state or ROM missing → show picker
launch_picker
