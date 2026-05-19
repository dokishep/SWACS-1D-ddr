#!/bin/sh

# 1. Configure screen to 640x480 at highest reported refresh rate
OUTPUT=$(xrandr | grep " connected" | cut -d' ' -f1 | head -n 1)
if [ -n "$OUTPUT" ]; then
    HIGHEST_HZ=$(xrandr | grep -A 10 "$OUTPUT" | grep -w "640x480" | tr -s ' ' | cut -d' ' -f3- | tr ' ' '\n' | tr -d '*+' | sort -rg | head -n 1)
    if [ -n "$HIGHEST_HZ" ]; then
        xrandr --output "$OUTPUT" --mode 640x480 --rate "$HIGHEST_HZ"
    else
        xrandr --output "$OUTPUT" --mode 640x480
    fi
fi

# 2. Launch the Rust game (binary name: bootstrap) in the foreground
exec /opt/game/bootstrap
