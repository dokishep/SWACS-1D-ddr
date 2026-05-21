#!/bin/sh
# S12wizard.sh — First-boot input-mapping wizard for the RootDDR cabinet.
#
# Runs automatically at boot only when /etc/ddr/input-map.json does not
# already exist (i.e. first boot after factory restore or SAVE partition
# reformat).  Guides the operator through all button -- dance-panel AND
# menu/navigation buttons -- printing clear prompts on tty1 and accepting
# either keyboard or joypad/gamepad input for each entry.
#
# The resulting /usr/lib/ddr/input-map.json is then symlinked into
# /mnt/save/ddr/  for SAVE-partition persistence.
#
# Dependencies: jq  (provided by Buildroot defconfig)

PATH=/sbin:/bin:/usr/bin:/usr/sbin
CONSOLE=/dev/tty1
INPUT_MAP="/etc/input-map.json"
DDR_DIR="/etc/ddr"
SAVE_DDR_DIR="/mnt/save/ddr"
SYS_MAP="/usr/lib/ddr/input-map.json"

# Check if wizard has already been run
if [ -f "$SYS_MAP" ]; then
    echo "Input map already exists, skipping wizard"
    exit 0
fi

# ── helpers ─────────────────────────────────────────────────────────────────

log() { printf '%s\n' "$1" >"$CONSOLE"; }
prompt() { printf '%s' "$1" >"$CONSOLE"; }

read_key() {
    IFS= read -r -n1 -s _raw 2>/dev/null
    setterm -echo on >"$CONSOLE" 2>/dev/null
    printf '%s' "$_raw"
}

wait_for_event() {
    _timeout="${1:-15}"
    _begin=$(date +%s)
    while true; do
        for f in /dev/input/js*; do
            [ -p "$f" ] || [ -c "$f" ] || continue
            if timeout 1 dd bs=8 count=1 if="$f" 2>/dev/null | grep -q .; then
                return 0
            fi
        done
        if [ "$(( $(date +%s) - _begin ))" -ge "$_timeout" ]; then
            break
        fi
        sleep 0.25
    done
    return 1
}

# ── main ─────────────────────────────────────────────────────────────────────

log "＝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━＝"
log "  RootDDR Cabinet — First-Boot Input Mapping"
log "＝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━＝"
log ""
log "This wizard will guide you through mapping every button"
log "on your DDR cabinet panel.  Take your time — there's no rush."
log ""
log "  ┌ DANCE PAD BUTTONS ─────────────────────┐"
log "  │  For each arrow: press the matching     │"
log "  │  pad button on the cabinet floor.       │"
log "  └──────────────────────────────────────────┘"
log "  ┌ MENU BUTTONS ──────────────────────────┐"
log "  │  For each menu action: press the cb.    │"
log "  │  button you want to use for navigation. │"
log "  └──────────────────────────────────────────┘"
log ""
log "Press ENTER when you are ready to begin..."
read -r < "$CONSOLE"

if [ ! -f "$INPUT_MAP" ]; then
    log ""
    log "ERROR: $INPUT_MAP not found.  Cannot run wizard."
    log "Please check that the overlay has been applied correctly."
    log ""
    exit 1
fi

ENTRIES=$(jq -c 'to_entries[]' "$INPUT_MAP")
UPDATED_ENTRIES=""
COUNT=0

for ENTRY in $ENTRIES; do
    COUNT=$((COUNT + 1))
    NAME=$(printf '%s' "$ENTRY" | jq -r '.key')
    DESC=$(printf '%s' "$ENTRY" | jq -r '.value.description // empty')
    TYPE=$(printf '%s' "$ENTRY" | jq -r '.value.type // "keyboard"')
    CUR_KEY=$(printf '%s' "$ENTRY" | jq -r '.value.key // empty')
    CUR_BTN=$(printf '%s' "$ENTRY" | jq -r '.value.button // empty')

    case "$NAME" in
        step_left)   LABEL="Dance pad LEFT  (←)" ;;
        step_down)   LABEL="Dance pad DOWN  (↓)" ;;
        step_up)     LABEL="Dance pad UP    (↑)" ;;
        step_right)  LABEL="Dance pad RIGHT (→)" ;;
        service)     LABEL="Service button (optional)" ;;
        test)        LABEL="Test button    (optional)" ;;
        coin)        LABEL="Coin button" ;;
        menu_up)     LABEL="Menu UP    (navigate up in ddr-picker)" ;;
        menu_down)   LABEL="Menu DOWN  (navigate down in ddr-picker)" ;;
        menu_select) LABEL="Menu SELECT (confirm game in ddr-picker)" ;;
        menu_back)   LABEL="Menu BACK  (cancel / return to picker)" ;;
        *)           LABEL="$NAME" ;;
    esac

    MENU_BUTTON=
    MENU_KEY=

    if [ "$TYPE" = "joypad" ] || [ -n "$CUR_BTN" ]; then
        log ""
        log "─── $LABEL ─────────────────────────────────"
        log ""
        log "  Stage 1 — Gamepad / cabinet button"
        log ""
        log "  Press the joypad button you want to map to this action."
        log "  (Hold it for ~1 s; timeout in 15 s if no gamepad is attached.)"
        log ""
        log "  [joypad] waiting…"
        if wait_for_event 15; then
            BTN_IDX=$(timeout 1 dd bs=8 count=1 if="/dev/input/js*" 2>/dev/null | \
                od -An -t u1 | tr -s ' ' '\n' | grep -v '^$' | tail -n 2 | head -n 1)
            if [ -n "$BTN_IDX" ]; then
                MENU_BUTTON="$BTN_IDX"
                log "  ✓  Detected gamepad button #$BTN_IDX"
            else
                log "  ⚠  Could not read button index — keeping existing map."
            fi
        else
            log "  ⏳  Timed out — no gamepad events received."
            log "       Keeping existing gamepad map (btn=$CUR_BTN)"
            MENU_BUTTON="$CUR_BTN"
        fi

        log ""
        log "  Stage 2 — Keyboard key (optional alternative)"
        log "  Press a keyboard key now, or press ENTER to skip…"
        log "  [keyboard] waiting…"
        setterm -echo off >"$CONSOLE" 2>/dev/null
        IFS= read -r -n1 -s KBYTE 2>/dev/null
        setterm -echo on >"$CONSOLE" 2>/dev/null
        case "$KBYTE" in
            "$(printf '\n')") log "  [keyboard] skipped." ;;
            *)
                case "$KBYTE" in
                    "$(printf '\033')")  MENU_KEY="Escape" ;;
                    "$(printf '\r')")    MENU_KEY="Return" ;;
                    "$(printf '\n')")    MENU_KEY="Enter"  ;;
                    "$(printf '\x7f')")  MENU_KEY="Backspace" ;;
                    *)                   MENU_KEY="$(printf '%d' "'$KBYTE")" ;;
                esac
                log "  ✓  Detected key: $MENU_KEY"
                ;;
        esac

    else
        log ""
        log "─── $LABEL ─────────────────────────────────"
        log ""
        log "  Press the desired keyboard key now, or press ENTER to skip…"
        setterm -echo off >"$CONSOLE" 2>/dev/null
        IFS= read -r -n1 -s KBYTE 2>/dev/null
        setterm -echo on >"$CONSOLE" 2>/dev/null
        case "$KBYTE" in
            "$(printf '\n')") MENU_KEY="" ;;
            "$(printf '\033')")  MENU_KEY="Escape" ;;
            "$(printf '\r')")    MENU_KEY="Return" ;;
            "$(printf '\n')")    MENU_KEY="Enter"  ;;
            "$(printf '\x7f')")  MENU_KEY="Backspace" ;;
            *)                   MENU_KEY="$(printf '%d' "'$KBYTE")" ;;
        esac
        if [ -n "$MENU_KEY" ]; then
            log "  ✓  Mapped to keyboard key: $MENU_KEY"
        fi
    fi

    if [ -n "$MENU_BUTTON" ]; then
        ENTRY=$(printf '%s' "$ENTRY" | jq --argjson btn "$MENU_BUTTON" '.value.button = $btn')
    fi
    if [ -n "$MENU_KEY" ]; then
        ENTRY=$(printf '%s' "$ENTRY" | jq --arg key "$MENU_KEY" '.value.key = $key')
    fi

    UPDATED_ENTRIES="${UPDATED_ENTRIES}$(printf '%s\n' "$ENTRY" | jq -c '.')"$'\n'
done

NEWMAP=$(printf '%s' "$UPDATED_ENTRIES" | jq -s 'add | from_entries')
mkdir -p "$DDR_DIR" "$(dirname "$SYS_MAP")" "$SAVE_DDR_DIR"
printf '%s' "$NEWMAP" > "$SYS_MAP"
cp "$SYS_MAP" "$INPUT_MAP"

ln -sfn "$SYS_MAP"  "$DDR_DIR/input-map.json"  2>/dev/null

log ""
log "─────────────────────────────────────────────────────────────"
log "  Pre-flight Check:"
log "─────────────────────────────────────────────────────────────"
if [ -d "/mnt/save" ] && mountpoint -q "/mnt/save" 2>/dev/null; then
    log "  ✓  SAVE partition mounted — flushing persistent copy…"
    cp "$SYS_MAP" "$SAVE_DDR_DIR/input-map.json"
    log "  ✓  Input map flushed to SAVE partition:"
    log "     $SAVE_DDR_DIR/input-map.json"
else
    log "  ⚠  SAVE partition not yet mounted."
    log "     The input map will be copied to the SAVE partition"
    log "     when /mnt/save becomes available on next boot."
fi
log ""
log "  ✓  Input map saved to system location:"
log "     $SYS_MAP"
log ""
log "─────────────────────────────────────────────────────────────"
log "  ✓  Mapping complete!"
log "─────────────────────────────────────────────────────────────"
log ""
log "  Your ddr-picker / pegasus menu will now respond to the"
log "  gamepad buttons you just assigned via joymapd."
log ""
log "  Press ENTER to continue boot…"
read -r < "$CONSOLE"

exit 0