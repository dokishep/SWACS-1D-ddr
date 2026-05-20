#!/bin/sh
# Example update.sh script for SWACS-1D
#
# This script will be executed as root during the update application process
# (both via USB and OTA update triggers) while the game partition (/opt/game)
# is mounted read-write.
# After this script runs, it will be automatically deleted by the update
# trigger, and the game partition will be remounted read-only.
#
# Common use cases:
# - Migrating user configuration formats in /var/data
# - Performing asset cleanups or migrations
# - Applying security patches or custom file permissions
# - Checking hardware / firmware states

echo "=========================================="
echo "Running custom update script (update.sh)..."
echo "=========================================="

# Example: Ensure score/data directory exists and clean up obsolete log files
DATA_DIR="/var/data"
if [ -d "$DATA_DIR" ]; then
    echo "Cleaning up old logs in $DATA_DIR..."
    find "$DATA_DIR" -name "*.log.old" -type f -delete
fi

# Example: Write update timestamp to highscore/data directory
echo "Last update: $(date)" > "$DATA_DIR/last_update.txt"

echo "Update script completed successfully!"
exit 0
