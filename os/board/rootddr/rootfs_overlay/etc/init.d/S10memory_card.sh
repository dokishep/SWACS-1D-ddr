#!/bin/sh
# S10memory_card.sh — Game-specific memory card selection
#
# Runs at init priority S10 (before S07gadget) to determine which DDR
# game is active and activate the correct memory card image file.
#
# Memory card mapping:
#   DDR.mc          DDR 1st Mix  → DDR 5th Mix  (game_id: ddr through ddr5ms)
#   DDRMAX.mc       DDR MAX      → DDR MAX2     (game_id: ddrmax, ddrmax2)
#                   fallback: DDR.mc
#   DDREXTREME.mc   DDR EXTREME  (game_id: ddrextreme)
#                   fallback: DDR.mc
#
# Memory card images are stored at /var/data/ by base name.
# The active card is linked as /var/data/memcard.bin for gadget-init.sh.
#
# Usage: S10memory_card.sh {start|stop|restart|status}

set -e

MEMCARD_DIR="/var/data"
ACTIVE_CARD="/var/data/memcard.bin"
ACTIVE_CARD_META="/var/data/.memcard_active"
LAST_GAME_FILE="/var/data/active_game.txt"
LAUNCHER_LOCK="/var/data/.last_game"
GAME_STATE_DIR="/opt/game/state"

# ── memory card file definitions ─────────────────────────────────────────────

get_memcard_file() {
    # Returns the backing file path for the given game, or "" if no mapping exists.
    # $1 = game_id (e.g. ddr3ms, ddrmax, ddrextreme)
    # $2 = optional "fallback" flag — print fallback chain on failure

    local game_id="$1"
    case "$game_id" in
        ddr|ddr1st|ddr2ms|ddr3rd|ddr3ms|ddr4th|ddr4ms|ddr5ms)
            echo "${MEMCARD_DIR}/DDR.mc"
            ;;
        ddrmax|ddrmax2|dnus)
            if [ -f "${MEMCARD_DIR}/DDRMAX.mc" ]; then
                echo "${MEMCARD_DIR}/DDRMAX.mc"
            else
                # Fallback: DDR.mc — DDRMAX.mc not present yet
                echo "${MEMCARD_DIR}/DDR.mc"
            fi
            ;;
        ddrextreme|ddrx)
            if [ -f "${MEMCARD_DIR}/DDREXTREME.mc" ]; then
                echo "${MEMCARD_DIR}/DDREXTREME.mc"
            else
                # Fallback: DDR.mc — DDREXTREME.mc not present yet
                echo "${MEMCARD_DIR}/DDR.mc"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── memory card creation ─────────────────────────────────────────────────────

create_memcard_if_needed() {
    local card_file="$1"
    [ -z "$card_file" ] && return 1

    if [ ! -f "$card_file" ]; then
        echo "Creating empty memory card image: $(basename "$card_file")"
        # 128 KB PS1/573 memory card
        truncate -s 131072 "$card_file" 2>/dev/null || \
            dd if=/dev/zero of="$card_file" bs=128K count=1 2>/dev/null
    fi
}

# Allocate all known memory card files (so they exist before the console
# selects them). Called once at boot.
prime_memcards() {
    touch "${MEMCARD_DIR}/DDR.mc"
    create_memcard_if_needed "${MEMCARD_DIR}/DDR.mc"
    create_memcard_if_needed "${MEMCARD_DIR}/DDRMAX.mc"
    create_memcard_if_needed "${MEMCARD_DIR}/DDREXTREME.mc"
}

# ── game detection ───────────────────────────────────────────────────────────

# Detect the active DDR MAME machine by checking several sources:
#   1. MAME process arguments (most reliable while running)
#   2. /var/data/active_game.txt (written by launcher at game start)
#   3. /opt/game/state/ game dump files (partial heuristic)
#   4. /var/data/.last_game (legacy lock file maintained by S90gui / reaper)
detect_running_game() {
    local game_id=""

    # ── 1. active_game.txt (written by the DDR launcher before exec mame) ──
    if [ -f "$LAST_GAME_FILE" ]; then
        game_id=$(cat "$LAST_GAME_FILE" 2>/dev/null | tr -d '[:space:]')
    fi

    # ── 2. MAME process command line ─────────────────────────────────────────
    if [ -z "$game_id" ]; then
        local mame_args=""
        mame_args=$(cat /proc/*/cmdline 2>/dev/null | tr '\0' ' ' | \
                    grep -oP '\mame\s+\K[^\s]+' 2>/dev/null || true)
        if [ -n "$mame_args" ]; then
            # MAME 573 targets commonly include the machine name as first arg
            game_id=$(echo "$mame_args" | awk '{print $1}' | tr -d '\n' | \
                      sed 's/^[+-]//')
        fi
    fi

    # ── 3. Legacy .last_game lock file ───────────────────────────────────────
    if [ -z "$game_id" ]; then
        if [ -f "$LAUNCHER_LOCK" ]; then
            game_id=$(cat "$LAUNCHER_LOCK" 2>/dev/null | head -1 | tr -d '\n')
        fi
    fi

    # ── 4. State directory heuristic ─────────────────────────────────────────
    if [ -z "$game_id" ] && [ -d "$GAME_STATE_DIR" ]; then
        # pick the newest .state file and strip extension / path
        local latest_state
        latest_state=$(ls -t "$GAME_STATE_DIR"/*.state 2>/dev/null | head -1)
        if [ -n "$latest_state" ]; then
            game_id=$(basename "$latest_state" .state)
        fi
    fi

    echo "${game_id:-none}"
}

# Normalise a raw game name (from MAME / file system) to the canonical
# ID used in the memory card lookup table.
normalise_game_id() {
    local raw="$1"
    # Lowercase everything first, strip whitespace
    raw=$(echo "$raw" | tr '[:upper:] ' '[:lower:]_' | tr -d '\n')

    # DDR 1st Mix  .. 5th Mix family
    case "$raw" in
        ddr|ddr1st|ddrmix|"ddr:573:us")              echo "ddr"      ;;
        ddr2ms*|"ddr2ndmix"|"ddr2:573:us")           echo "ddr2ms"   ;;
        ddr3rd*|"ddr3rdmix"|"ddr3rs"|"ddr3:573:us")  echo "ddr3ms"   ;;
        ddr4th*|"ddr4thmix"|"ddr4rs"|"ddr4:573:us")  echo "ddr4ms"   ;;
        ddr5th*|ddr5ms*|"ddr5f"|"ddr5:573:us")       echo "ddr5ms"   ;;
        ddrmax|ddrmax2|dnus|"dnus:573:us")           echo "ddrmax"   ;;
        ddrextreme|ddrx|"ddrx:573:us")                echo "ddrextreme" ;;
        *)           echo "$raw" ;;   # pass through — may still match
    esac
}

# ── activation logic ──────────────────────────────────────────────────────────

do_start() {
    mkdir -p "$MEMCARD_DIR"
    mkdir -p "$GAME_STATE_DIR"

    # Make sure all base card images exist
    prime_memcards

    # ── Detect running game ──────────────────────────────────────────────────
    raw_game=$(detect_running_game)
    game_id=$(normalise_game_id "$raw_game")

    if [ "$game_id" = "none" ]; then
        echo "No active game detected — defaulting to DDR.mc"
        target_card="${MEMCARD_DIR}/DDR.mc"
    else
        echo "Detected game: ${game_id} (raw: ${raw_game})"
        resolved=$(get_memcard_file "$game_id")
        if [ -z "$resolved" ]; then
            echo "Unknown game '${game_id}' — defaulting to DDR.mc"
            target_card="${MEMCARD_DIR}/DDR.mc"
        else
            target_card="$resolved"
            if echo "$resolved" | grep -q "DDRMAX.mc"; then
                echo "Selected DDRMAX.mc for game '${game_id}'"
            elif echo "$resolved" | grep -q "DDREXTREME.mc"; then
                echo "Selected DDREXTREME.mc for game '${game_id}'"
            else
                echo "Selected DDR.mc for game '${game_id}'"
            fi
        fi
    fi

    # ── Create card if needed ───────────────────────────────────────────────
    create_memcard_if_needed "$target_card"

    # ── Activate: replace symlink / copy into active slot ──────────────────
    # Using a symlink lets the guest see the card change in-place without
    # having to re-write into /var/data/plurks
    rm -f "$ACTIVE_CARD"
    ln -s "$(basename "$target_card")" "$ACTIVE_CARD"
    echo "$(basename "$target_card")" > "$ACTIVE_CARD_META"

    echo "Active memory card → $(basename "$target_card")"
}

do_stop() {
    if [ -L "$ACTIVE_CARD" ] || [ -f "$ACTIVE_CARD" ]; then
        echo "Unlinking active memory card symlink"
        rm -f "$ACTIVE_CARD"
    fi
    rm -f "$ACTIVE_CARD_META"
}

do_status() {
    echo "Memory card selection status:"
    if [ -L "$ACTIVE_CARD" ]; then
        target=$(readlink "$ACTIVE_CARD")
        echo "  Active card  : ${target}"
        size=$(stat -c%s "${MEMCARD_DIR}/${target}" 2>/dev/null || echo "?")
        echo "  Size         : ${size} bytes"
    elif [ -f "$ACTIVE_CARD" ]; then
        echo "  Active card  : memcard.bin (real file, not symlink)"
        size=$(stat -c%s "$ACTIVE_CARD" 2>/dev/null || echo "?")
        echo "  Size         : ${size} bytes"
    else
        echo "  Active card  : (none)"
    fi
    echo "  Available cards:"
    for card in "${MEMCARD_DIR}/DDR.mc" "${MEMCARD_DIR}/DDRMAX.mc" "${MEMCARD_DIR}/DDREXTREME.mc"; do
        [ -f "$card" ] || continue
        b=$(basename "$card")
        s=$(stat -c%s "$card" 2>/dev/null || echo "?")
        echo "    ${b}  (${s} bytes)"
    done
}

# ── dispatch ─────────────────────────────────────────────────────────────────

case "${1:-start}" in
    start)   do_start   ;;
    stop)    do_stop    ;;
    restart) do_stop; do_start ;;
    status)  do_status  ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
