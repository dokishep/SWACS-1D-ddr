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

# 2. Launch the Rust game (binary name: bootstrap) in the foreground
exec /opt/game/bootstrap
