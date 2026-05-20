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
xmessage -center -buttons "Shut Down" -default "Shut Down" -title "SWACS-1D OS - TPM ERROR" "
==================================================
                    ERROR!
==================================================

This board doesn't support TPM, which is essential
to guarantee game data integrity!

Without TPM, the board isn't eligible to be
factory provisioned, and any attempts of doing so
will be blocked to prevent data tampering.

Check the board UEFI settings for Security/TPM
settings and enable TPM 2.0, if this setting is
disabled later, the board will not boot!

=================================================="
