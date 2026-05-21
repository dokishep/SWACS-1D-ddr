#!/bin/sh
# memcard-restore.sh - Restore PS1 memory card image from a file

MEMORY_CARD_IMAGE=/var/data/memcard.bin

usage() {
    echo "Usage: $0 <input_file>"
    echo "  input_file: Source memory card image to restore"
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at $INPUT_FILE"
    exit 1
fi

# Ensure /var/data exists
mkdir -p /var/data

# Copy the input file to the memory card image
cp "$INPUT_FILE" "$MEMORY_CARD_IMAGE"
echo "Memory card restored from $INPUT_FILE"