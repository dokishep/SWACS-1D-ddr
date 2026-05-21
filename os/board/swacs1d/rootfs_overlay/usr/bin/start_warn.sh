#!/bin/sh

# start_warn.sh — X11 fallback screen (genericised, no TPM required)
# Displayed when the board has no ROMS/SAVE partitions on the boot drive.
# Used by S12warn at init time — post-S10roms_mount, this confirms a drive
# has been mounted and that ddr-picker is safe to launch on first boot.

# 1. Configure screen to 640x480 at highest reported refresh rate
OUTPUT=$(xrandr | grep " connected" | cut -d' ' -f1 | head -n 1)
if [ -n "$OUTPUT" ]; then
    HIGHEST_HZ=$(xrandr | sed -n "/^$OUTPUT connected/,/^[A-Za-z]/p" | grep -w "640x480" | awk '{for(i=2;i<=NF;i++) print $i}' | tr -d '*+' | sort -rg | head -n 1)
    if [ -n "$HIGHEST_HZ" ]; then
        xrandr --output "$OUTPUT" --mode 640x480 --rate "$HIGHEST_HZ"
    else
        xrandr --output "$OUTPUT" --mode 640x480
    fi
fi

# 2. Display the warning message graphically via xmessage
xmessage -center -buttons "Continue" -default "Continue" -title "SWACS-1D OS — BOOT" "
==================================================
                    BOOT INIT
==================================================

The ROMS/SAVE partitions were not found on the
boot drive at startup.

If this is your first boot, connect a USB drive
with the ROMs directory or use SAVE partition.

Press Continue to proceed to the game picker anyway.

=================================================="
