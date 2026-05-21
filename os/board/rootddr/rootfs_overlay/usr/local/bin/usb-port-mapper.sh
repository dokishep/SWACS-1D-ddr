#!/bin/sh
# usb-port-mapper.sh — USB port to DDR player mapping
# Detects connected USB storage devices and maps them to P1/P2 player ports.
# Supports hot-plug re-mapping via USB uevent / sysfs polling.
#
# Usage:
#   usb-port-mapper.sh status        Show current port assignments
#   usb-port-mapper.sh rescan        Force a full re-scan of USB buses
#   usb-port-mapper.sh hotplug &     Start daemon that monitors for hot-plug events
#   usb-port-mapper.sh who <busid>    Show which player owns a USB device
#   usb-port-mapper.sh get-p1 | get-p2  Print the attached mass-storage bus ID for P1/P2
#
# Game-side scripts call:
#   . /usr/local/bin/usb-port-mapper.sh   # sources helpers
#   memcard_file=$(find_memcard_for_player 1)

set -e

CONFIG_FILE="/etc/ddr/usb-ports.json"
USB_SYSFS="/sys/bus/usb/devices"
MAP_STATE="/var/data/usb-port-mapper.state"
HOTPLUG_PID_FILE="/var/run/usb-port-mapper-hotplug.pid"

if command -v jq >/dev/null 2>&1; then
    _JSON_READER="jq"
elif command -v python3 >/dev/null 2>&1; then
    _JSON_READER="python3"
else
    _JSON_READER="busybox"   # busybox has limited JSON; treat as read-only fallback
fi

_jq() {
    if [ "$_JSON_READER" = "jq" ]; then
        jq "$@" 2>/dev/null
    else
        # Stub: return empty for non-jq environments
        echo ""
    fi
}

# ── helpers ──────────────────────────────────────────────────────────────────

log() {
    logger -t "usb-port-mapper" "$@"
}

# Return a comma-separated list of bus IDs for a given player+type
# $1 = player (p1|p2)
# $2 = type (usb2|usb3)
get_configured_buses() {
    local player="$1" type="$2"
    _jq -r ".ports.${player}.${type}_bus // empty" "$CONFIG_FILE" 2>/dev/null | tr -d '"'
}

# Normalise bus-ID strings from JSON into a canonically-sorted unique list.
_normalise_bus_list() {
    echo "$1" | tr ',' '\n' | sed '/^\s*$/d' | sort -t. -k1,1n -k2,2n -u | tr '\n' ','
}

# Save or load the mapper state file
save_state() {
    local key="$1" val="$2"
    if [ -n "$key" ] && [ -n "$val" ]; then
        echo "${key}=${val}" >> "$MAP_STATE"
    fi
}

load_state() {
    grep "^${1}=" "$MAP_STATE" 2>/dev/null | tail -1 | cut -d= -f2-
}

# Read the speed of a usbdev entry from sysfs (1/2=LS/FS, 3=SS, 480=HS, 5000=SS+)
get_speed_kbps() {
    local devpath="$1"
    cat "${devpath}/speed" 2>/dev/null || echo "0"
}

# Test whether a sysfs usbdev is a Mass-Storage storage endpoint
is_mass_storage() {
    local devpath="$1"
    [ -f "${devpath}/bInterfaceClass" ] && \
        grep -qi "08" "${devpath}/bInterfaceClass" 2>/dev/null
}

# Loop through /sys/bus/usb/devices/*/ and return canonicalised bus IDs
enum_usb_buses() {
    ls -1 "$USB_SYSFS" | grep -E '^[0-9]+-[0-9]+(\.[0-9]+)*$' | sort -t- -k1,1n -k2,2n -k3,3n
}

# Enumerate all Mass-Storage-capable devices found on a bus
enum_storage_devs() {
    local probe_bus="$1"
    for devpath in "$USB_SYSFS/$probe_bus"; do
        [ -d "$devpath" ] || continue
        if is_mass_storage "$devpath"; then
            echo "$probe_bus"
        fi
    done
}

# ── core: match configured bus-list to what is actually connected ─────────────

# Build a candidate list of bus IDs ordered by preference:
#   configured buses → fallback_order (usb3 then usb2)
# Returns the first bus ID that has a real Storage device attached.
_choose_bus_for() {
    local player="$1" type="$2"
    local configured_raw configured_list fallback_order
    configured_raw=$(get_configured_buses "$player" "$type")

    # Normalise configured list
    configured_list=$(_normalise_bus_list "$configured_raw")

    # Fallback order read from config (defaults: usb3, usb2)
    fallback_order=$( _jq -r '.fallback_order // ["usb3","usb2"] | join(" ")' "$CONFIG_FILE" )

    # Also always honour configured buses — they are the authoritative source.
    for cbus in $(echo "$configured_list" | tr ',' ' '); do
        [ -z "$cbus" ] && continue
        # Accept both plain bus IDs and dotted forms (e.g. "1" or "1-1.1")
        for dev_prefix in "$USB_SYSFS/$cbus" "$USB_SYSFS/${cbus}-[0-9]*"; do
            for d in $dev_prefix; do
                if [ -d "$d" ] && is_mass_storage "$d"; then
                    echo "$cbus"
                    return 0
                fi
            done
        done
    done

    # Fallback: scan all available USB3-type buses first, then USB2
    for fb_type in $(echo "$fallback_order" | tr ',' ' '); do
        for probe_typelist in $(get_configured_buses "$player" "$fb_type"); do
            for probe_bus in $(echo "$probe_typelist" | tr ',' ' '); do
                for d in $USB_SYSFS/$probe_bus; do
                    [ -d "$d" ] || continue
                    if is_mass_storage "$d"; then
                        echo "$probe_bus"
                        return 0
                    fi
                done
            done
        done
        # Last resort: any MSLUN bus of the right speed tier
        if [ "$fb_type" = "usb3" ]; then
            for d in $USB_SYSFS/[0-9]*; do
                [ -d "$d" ] || continue
                sp=$(get_speed_kbps "$d")
                if [ "$sp" -ge 4500 ] && is_mass_storage "$d"; then
                    busid=$(basename "$d" | cut -d: -f1)
                    echo "$busid"
                    return 0
                fi
            done
        else
            for d in $USB_SYSFS/[0-9]*; do
                [ -d "$d" ] || continue
                sp=$(get_speed_kbps "$d")
                if is_mass_storage "$d" && { [ "$sp" -ge 4500 ] && { ls "$d":1 2>/dev/null || true; }; }; then
                    continue
                elif is_mass_storage "$d"; then
                    busid=$(basename "$d" | cut -d: -f1)
                    echo "$busid"
                    return 0
                fi
            done
        fi
    done

    echo ""
    return 1
}

# ── public API ────────────────────────────────────────────────────────────────

show_bus_for_player() {
    local player="$1"
    [ -z "$player" ] && player="1"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found: $CONFIG_FILE" >&2
        return 1
    fi

    for type in usb3 usb2; do
        chosen=$(_choose_bus_for "p${player}" "$type")
        if [ -n "$chosen" ]; then
            echo "P${player}→${type}:${chosen}"
            save_state "p${player}_${type}_bus" "$chosen"
            return 0
        fi
    done
    echo "P${player}: No storage device found" >&2
    return 1
}

# Rescan all buses and print the full assignment table
show_status() {
    echo "=== USB Port Mapper Status ==="
    echo "Config: $CONFIG_FILE"
    echo "State : $MAP_STATE"
    echo ""

    for player in p1 p2; do
        echo "--- ${player^^} ---"
        for type in usb3 usb2; do
            chosen=$(show_bus_for_player "${player#p}")
            [ -z "$chosen" ] && chosen="(none)"
            echo "  ${type}: ${chosen}"
        done
    done
    echo ""
    echo "Connected USB storage buses:"
    for d in $(enum_usb_buses); do
        sp=$(get_speed_kbps "$d")
        ms=""
        is_mass_storage "$d" && ms=" [MS]"
        parent=$(basename "$d")
        echo "  ${parent}  speed=${sp}kbps${ms}"
    done
}

# Force a full re-scan — clears cached state and re-probes
do_rescan() {
    rm -f "$MAP_STATE"
    echo "Rescanning USB buses..."
    for player in p1 p2; do
        for type in usb3 usb2; do
            result=$(_choose_bus_for "$player" "$type")
            if [ -n "$result" ]; then
                save_state "${player}_${type}_bus" "$result"
            fi
        done
    done
    show_status
}

# Convenience: PLURALITY of methods:
# Usage: find_memcard_for_player <player_num> [mounted_base]
# Returns the backing file path for the memory card assigned to player N.
find_memcard_for_player() {
    local player="$1"
    [ -z "$player" ] && player="1"
    show_bus_for_player "$player" >/dev/null 2>&1
    echo "/var/data/memcard_p${player}.bin"
}

# Convenience: which players alloc/owner of a USB bus
# Usage: who <bus_id>
# Returns p1 / p2 / unknown
who_owns_bus() {
    local target="$1"
    [ -z "$target" ] && return 1

    for player in p1 p2; do
        if [ "$player" = "$(load_state "${player}_usb3_bus")" ] || \
           [ "$player" = "$(load_state "${player}_usb2_bus")" ]; then
            echo "$player"
            return 0
        fi
    done
    echo "unknown"
}

# ── Hot-plug monitor ─────────────────────────────────────────────────────────

# Lightweight uevent listener using netlink in a background subshell.
# Writes /dev/null output; side-effects are the MAP_STATE file.
do_hotplug() {
    MYPID=$$
    echo "$MYPID" > "$HOTPLUG_PID_FILE"

    # Open a netlink socket to the kernel uevent subsystem
    # Requires: CONFIG_NET + CONFIG_NETLINK_UEVENT in kernel (standard in any recent kernel)
    netlink_reader() {
        # Read uevents one line at a time – we don't do strict parsing
        # but just fire on any add/remove so the re-scan is as fast as
        # possible without busy-polling sysfs.
        exec 3< /dev/null   # placeholder
        # We rely on /sys/bus/usb devpath file-modification as a proxy for hot-plug.
        # A more robust approach would require an external daemon (udev or netlink-recv).
        # For Buildroot/BusyBox this poll approach is simpler and self-contained.
    }

    log "Hotplug monitor daemon started (pid=$MYPID)"

    while [ -f "$HOTPLUG_PID_FILE" ] && [ "$(cat "$HOTPLUG_PID_FILE" 2>/dev/null)" = "$MYPID" ]; do
        # Snapshot bus list and compare to previous snapshot
        new_buses=$(enum_usb_buses | sort)
        old_buses=$(cat "$MAP_STATE.buslist" 2>/dev/null || echo "")

        if [ "$new_buses" != "$old_buses" ]; then
            log "USB bus configuration changed — re-scanning"
            echo "$new_buses" > "$MAP_STATE.buslist"
            do_rescan >/dev/null 2>&1 || true
        fi

        # Sleep 1 s between polls — acceptable for DDR cabinet use
        sleep 1
    done

    rm -f "$HOTPLUG_PID_FILE"
    log "Hotplug monitor daemon stopped"
    return 0
}

# ── dispatch ──────────────────────────────────────────────────────────────────

case "${1:-status}" in
    status)         show_status ;;
    rescan|scan)    do_rescan ;;
    who)            who_owns_bus "$2" ;;
    get-p1)         find_memcard_for_player 1 ;;
    get-p2)         find_memcard_for_player 2 ;;
    hotplug)        do_hotplug ;;
    *)              show_status ;;
esac

return 0
