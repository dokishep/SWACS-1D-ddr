#!/bin/sh
# PS1 Memory Card Format Utility
# Formats a 128KB file as a standard PS1 memory card (.MCR format)
# Size: 128KB (131072 bytes) - standard PS1 memory card size

MEMCARD_FILE="/var/data/memcard.bin"
SIZE=131072

usage() {
    echo "Usage: memcard-format.sh [-f file] [-o]"
    echo "  -f file   Memory card file to format (default: $MEMCARD_FILE)"
    echo "  -o        Overwrite existing file"
    exit 1
}

OVERWRITE=0
while getopts "f:oh" opt; do
    case $opt in
        f) MEMCARD_FILE="$OPTARG" ;;
        o) OVERWRITE=1 ;;
        h) usage ;;
    esac
done

if [ -f "$MEMCARD_FILE" ] && [ "$OVERWRITE" -eq 0 ]; then
    echo "Error: File already exists. Use -o to overwrite." >&2
    exit 1
fi

# Create empty 128KB file
dd if=/dev/zero of="$MEMCARD_FILE" bs=1 count=0 2>/dev/null
truncate -s "$SIZE" "$MEMCARD_FILE" 2>/dev/null || dd if=/dev/zero of="$MEMCARD_FILE" bs="$SIZE" count=1 2>/dev/null

echo "Memory card formatted: $MEMCARD_FILE (128KB PS1 format)"
exit 0