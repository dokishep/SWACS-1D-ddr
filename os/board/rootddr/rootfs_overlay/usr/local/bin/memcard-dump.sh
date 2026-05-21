#!/bin/sh
# memcard-dump.sh - Dump PS1 memory card image to a file

MEMORY_CARD_IMAGE=/var/data/memcard.bin
DEFAULT_DUMP=/var/data/memcard_dump.bin

usage() {
    echo "Usage: $0 [output_file]"
    echo "  output_file: Destination for memory card dump (default: $DEFAULT_DUMP)"
    exit 1
}

if [ "$#" -gt 1 ]; then
    usage
fi

OUTPUT_FILE=${1:-$DEFAULT_DUMP}

if [ ! -f "$MEMORY_CARD_IMAGE" ]; then
    echo "Error: Memory card image not found at $MEMORY_CARD_IMAGE"
    exit 1
fi

cp "$MEMORY_CARD_IMAGE" "$OUTPUT_FILE"
echo "Memory card dumped to $OUTPUT_FILE"