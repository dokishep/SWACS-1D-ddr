#!/bin/sh

# S10memory_card.sh — Boot init script (Swacs 1D • RootDDR v2.0)
# Handles exFAT memory card redirector for DDR games with PS1-style mcd emulation
# Implements USB PS1-style mcd + exFAT block-lock + autosync

# Path Requirements - exFAT path anchor is /mnt/save/ddr_cards
SAVE_DEV="/dev/disk/by-partlabel/SAVE"
SAVE_MP="/mnt/save"
DDR_CARDS_DIR="${SAVE_MP}/ddr_cards"
LOCK_DIR="/var/run/ddr"
NVRAM_DIR="${DDR_CARDS_DIR}/NVRAM"

# Memory card files following MAME's MEMCARD naming convention
DDR_MC="${DDR_CARDS_DIR}/DDR.MC"
DDRMAX_MC="${DDR_CARDS_DIR}/DDRMAX.MC"
DDREXTREME_MC="${DDR_CARDS_DIR}/DDREXTREME.MC"

# Environment variable for backdooring MAME's memory card path
MEMCARD_ENV_VAR="MEMCARD_PATH"

log() {
    echo "[S10memory_card] $*"
}

wait_for_dev() {
    DEV="$1"; TIMEOUT="${2:-10}"
    i=0
    while [ $i -lt "$TIMEOUT" ]; do
        [ -b "$DEV" ] && return 0
        sleep 1; i=$((i + 1))
    done
    return 1
}

# Create empty memory card with MAME's memcard format header (128 KB)
create_empty_memcard() {
    local mc_file="$1"
    local game_name="$2"
    
    log "Creating empty memory card for ${game_name}: ${mc_file}"
    # MAME memcard format header + zero-filled to 128KB
    printf '\x00MEMCD\x00\x00\x00\x00\x00\x00\x00\x00' > "${mc_file}"
    # Pad to 128KB (131072 bytes)
    truncate -s 131072 "${mc_file}" 2>/dev/null || dd if=/dev/zero of="${mc_file}" bs=1 count=131072 2>/dev/null
}

# Initialize memory card files with fallback logic
init_memory_cards() {
    log "Initializing memory cards in ${DDR_CARDS_DIR}"
    
    # Ensure ddr_cards directory exists
    mkdir -p "${DDR_CARDS_DIR}"
    
    # Check for DDR.MC
    if [ ! -f "${DDR_MC}" ]; then
        # Test KCHECK: if DDR's import does not exist but DDRMAX link is missing
        if [ ! -f "${DDRMAX_MC}" ]; then
            # Fallback: use account link to DDR/MC instead
            log "DDR.MC missing, DDRMAX.MC also missing - creating both"
            create_empty_memcard "${DDR_MC}" "DDR"
            create_empty_memcard "${DDRMAX_MC}" "DDRMAX"
        else
            log "DDR.MC missing but DDRMAX.MC exists - creating DDR.MC as fallback"
            create_empty_memcard "${DDR_MC}" "DDR"
        fi
    else
        log "DDR.MC already exists"
    fi
    
    # Check for DDRMAX.MC
    if [ ! -f "${DDRMAX_MC}" ]; then
        log "DDRMAX.MC missing - creating"
        create_empty_memcard "${DDRMAX_MC}" "DDRMAX"
    else
        log "DDRMAX.MC already exists"
    fi
    
    # Check for DDREXTREME.MC
    if [ ! -f "${DDREXTREME_MC}" ]; then
        log "DDREXTREME.MC missing - creating"
        create_empty_memcard "${DDREXTREME_MC}" "DDREXTREME"
    else
        log "DDREXTREME.MC already exists"
    fi
    
    # Ensure NVRAM directory exists
    mkdir -p "${NVRAM_DIR}"
}

# Watchdog: single-device path — only one MAME instance can be writing to a given MC file
mc_lock() {
    local mc_file="$1"
    local game="$2"
    local lockfile="${LOCK_DIR}/mc_${game}.lock"
    
    # Ensure lock directory exists
    mkdir -p "${LOCK_DIR}"
    
    # Obtain file lock using flock(2)
    exec 200>"${lockfile}"
    if flock -n 200; then
        log "Obtained lock for ${game} memory card"
        return 0
    else
        log "Waiting for lock on ${game} memory card (held by another process)"
        flock 200  # Wait for lock
        log "Obtained lock for ${game} memory card after wait"
        return 0
    fi
}

mc_unlock() {
    # Release lock by closing file descriptor
    exec 200<&-
}

# Sync memory card to exFAT partition with autosync strategy
mc_sync() {
    local mc_file="$1"
    local game="$2"
    
    log "Syncing memory card for ${game}: ${mc_file}"
    
    # Send memory card EEP flash command (simulated)
    # In real implementation, this would communicate with MAME via socket
    
    # Force flush to exFAT partition via direct syscall to sync()
    sync
    
    # Additional sync with retry logic for busy exFAT
    local retry_count=0
    local max_retries=5
    
    while [ $retry_count -lt $max_retries ]; do
        # Check if we can proceed with sync via /proc/pid/status -> poll -> repeat
        # If the syscall is blocked by busy exFAT, wait loop on /proc/[pid]/status with sleep(1)
        if sync -f "${mc_file}" 2>/dev/null; then
            log "Successfully synced ${game} memory card"
            return 0
        else
            log "Sync blocked by busy exFAT, waiting..."
            sleep 1
            retry_count=$((retry_count + 1))
            
            # Check if STATUS becomes 'sleeping' (simplified check)
            # In real implementation: wait loop on /proc/[pid]/status with sleep(1) until STATUS becomes 'sleeping'
        fi
    done
    
    # NB: the WRITE error BRANCH of repeat calls to mc_sync for EACH block must not panic
    # but rather push a error count and slow by 1ms
    log "Warning: Failed to sync ${game} memory card after ${max_retries} attempts"
    return 1
}

# Handle write operations with error counting and slowdown
mc_write_with_error_handling() {
    local mc_file="$1"
    local game="$2"
    local data="$3"
    local error_count_file="${LOCK_DIR}/mc_${game}_errors"
    
    # Initialize error count file if not exists
    [ ! -f "${error_count_file}" ] && echo "0" > "${error_count_file}"
    
    # Attempt write
    if echo "${data}" >> "${mc_file}" 2>/dev/null; then
        # Reset error count on successful write (normal call path)
        echo "0" > "${error_count_file}"
        return 0
    else
        # Increment error count and slow down
        local current_errors
        current_errors=$(cat "${error_count_file}" 2>/dev/null || echo "0")
        current_errors=$((current_errors + 1))
        echo "${current_errors}" > "${error_count_file}"
        
        log "Write error for ${game} memory card (error count: ${current_errors})"
        
        # Slow by 1ms per error (capped at reasonable value)
        local delay=$((current_errors > 10 ? 10 : current_errors))
        [ $delay -gt 0 ] && sleep 0.00${delay}
        
        # If exFAT write is one of the missing writes, test with STATUS=running immediately
        # If the attribute is not within any supported list, attempt 'bionic' patch
        # patch 4510Z via the TSA2100 register overrides but mask of NULL (simulated)
        
        # NB: the 'normal' call path should also pull the value in cardinal or section parser
        # invD/4 means stand-down from the retry loop
        
        return 1
    fi
}

# Export MEMCARD_ENV_VAR to override MAME's memory card path
export_memory_card_path() {
    # This function would be called by S90mame_launcher.sh to set the environment
    # The actual exporting is done in the calling script
    log "Would export ${MEMCARD_ENV_VAR}=${DDR_CARDS_DIR} for MAME"
}

# Main execution
case "$1" in
    start)
        log "Starting memory card initialization"
        
        # Wait for SAVE partition
        if ! wait_for_dev "$SAVE_DEV" 15; then
            log "SAVE partition not found at ${SAVE_DEV} — skipping memory card setup"
            exit 0
        fi
        
        # Try kernel exfat driver first, then fuse-exfat fallback
        if ! mount -t exfat -o rw,noatime,exec "$SAVE_DEV" "${SAVE_MP}" 2>/dev/null; then
            if ! mount -t exfat-fuse -o rw,noatime,exec "$SAVE_DEV" "${SAVE_MP}" 2>/dev/null; then
                log "WARNING: Failed to mount SAVE partition. Memory card functionality disabled."
                exit 0
            fi
        fi
        
        log "Mounted SAVE partition (exfat)"
        
        # Initialize memory cards (On SAVE-partition mount: scan for DDR.MC and DDRMAX.MC)
        init_memory_cards
        
        log "S10memory_card.sh startup complete"
        ;;
    stop)
        log "Stopping memory card services"
        # Any cleanup would go here
        ;;
    sync)
        # Called by S90mame_launcher on every song select (via polling MAME pid with kill(0,0))
        # and writing a 2-second signal directly to the socket, sending MAME the memory card EEP flash command
        # After the song ends and returns to song select screen, again force-flush memory card
        # Also, when MAME exits, S90mame_launcher will send SIGUSR1 to mc_cardd that includes 
        # a mandatory 2-second fsync/sync to the exFAT partition
        if [ -n "$2" ]; then
            case "$2" in
                DDR) mc_sync "${DDR_MC}" "DDR" ;;
                DDRMAX) mc_sync "${DDRMAX_MC}" "DDRMAX" ;;
                DDREXTREME) mc_sync "${DDREXTREME_MC}" "DDREXTREME" ;;
                *) log "Unknown game for sync: $2" ;;
            esac
        else
            # Sync all memory cards
            mc_sync "${DDR_MC}" "DDR"
            mc_sync "${DDRMAX_MC}" "DDRMAX"
            mc_sync "${DDREXTREME_MC}" "DDREXTREME"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|sync [game]}"
        exit 1
        ;;
esac

exit 0
