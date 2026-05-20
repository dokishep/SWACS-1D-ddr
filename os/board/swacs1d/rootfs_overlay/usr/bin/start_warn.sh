#!/bin/sh

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
xmessage -center -buttons "" -title "SWACS-1D OS - PROVISIONING REQUIRED" "
==================================================
                    WARNING!
==================================================

This board has not been initialized/provisioned yet.

For distributor: Now is the time to plug in the
factory provision USB device to the board.

For operator: Please contact the distributor and
send the board back to them.

A .bundle file (either patch or upgrade) will NOT WORK!

=================================================="
