#!/bin/sh
# save-state.sh - Save game state to /var/data/state.json
# Usage: save-state.sh '<json string>'

STATE_FILE="/var/data/state.json"

if [ $# -ne 1 ]; then
    echo "Usage: $0 '<json string>'" >&2
    exit 1
fi

echo "$1" > "$STATE_FILE"
if [ $? -eq 0 ]; then
    logger -t save-state "Game state saved to $STATE_FILE"
else
    logger -t save-state "Failed to save game state to $STATE_FILE"
    exit 1
fi