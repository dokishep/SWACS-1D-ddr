#!/bin/sh
# PS1 Memory Card Restore Utility
# Restores memory card contents from stdin or file

MEMCARD_FILE="/var/data/memcard.bin"

usage() {
    echo "Usage: memcard-restore.sh [-i input_file]"
    echo "  -i input_file   Read from file (default: stdin)"
    exit 1
}

INPUT_FILE=""

while getopts "i:h" opt; do
    case $opt in
        i) INPUT_FILE="$OPTARG" ;;
        h) usage ;;
    esac
done

if [ -n "$INPUT_FILE" ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file not found: $INPUT_FILE" >&2
        exit 1
    fi
    cp "$INPUT_FILE" "$MEMCARD_FILE"
else
    # Read from stdin
    cat > "$MEMCARD_FILE"
fi

echo "Memory card restored"
exit 0