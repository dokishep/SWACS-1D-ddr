#!/bin/sh
# PS1 Memory Card Dump Utility
# Dumps memory card contents to stdout or file

MEMCARD_FILE="/var/data/memcard.bin"
OUTPUT_FILE=""

usage() {
    echo "Usage: memcard-dump.sh [-o output_file]"
    echo "  -o output_file  Save to file (default: stdout)"
    exit 1
}

while getopts "o:h" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG" ;;
        h) usage ;;
    esac
done

if [ ! -f "$MEMCARD_FILE" ]; then
    echo "Error: Memory card file not found at $MEMCARD_FILE" >&2
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    cp "$MEMCARD_FILE" "$OUTPUT_FILE"
    echo "Memory card dumped to $OUTPUT_FILE"
else
    cat "$MEMCARD_FILE"
fi

exit 0