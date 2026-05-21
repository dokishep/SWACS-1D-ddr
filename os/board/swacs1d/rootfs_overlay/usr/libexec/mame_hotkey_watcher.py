#!/usr/bin/python3
"""
mame_hotkey_watcher.py - Monitor joypad for Service+Test exit combo
Holds SERVICE (button 8) + TEST (button 9) for 2 seconds to exit MAME cleanly
"""

import os
import sys
import time
import json
import struct
import select

INPUT_MAP = "/usr/lib/ddr/input-map.json"
STATE_FILE = "/var/lib/ddr/state.json"

DEV_MAP = {
    "service": 8,   # Joypad1StartButton
    "test": 9,      # Coin1Button
}

def load_button_map():
    """Load button mappings from input-map.json"""
    try:
        with open(INPUT_MAP) as f:
            mapping = json.load(f)
        return {
            "service": mapping.get("service", {}).get("button", 8),
            "test": mapping.get("test", {}).get("button", 9),
        }
    except:
        return DEV_MAP

def find_gamepad():
    """Find first joystick/gamepad device"""
    for f in os.listdir("/dev/input"):
        if f.startswith("js"):
            path = f"/dev/input/{f}"
            if os.path.exists(path):
                return path
    return None

def main():
    btn = load_button_map()
    dev = find_gamepad()
    
    if not dev:
        print("No gamepad found, hotkey watcher disabled", file=sys.stderr)
        sys.exit(0)
    
    print(f"Hotkey watcher monitoring {dev}", file=sys.stderr)
    
    fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
    EV_SIZE = struct.calcsize("llHHI")
    
    service_held = False
    test_held = False
    hold_start = 0
    
    while True:
        r, _, _ = select.select([fd], [], [], 0.1)
        if not r:
            continue
        
        try:
            ev = os.read(fd, EV_SIZE)
        except:
            continue
        
        if len(ev) < EV_SIZE:
            continue
        
        sec, usec, typ, code, value = struct.unpack("llHHI", ev)
        
        if typ != 0x01:  # EV_KEY
            continue
        
        if code == btn["service"]:
            service_held = (value != 0)
        elif code == btn["test"]:
            test_held = (value != 0)
        
        if service_held and test_held:
            if hold_start == 0:
                hold_start = time.time()
            elif time.time() - hold_start >= 2.0:
                print("Service+Test held for 2s, exiting MAME...", file=sys.stderr)
                os.kill(os.getppid(), 2)  # SIGINT to parent (mame)
                time.sleep(1)
                os.execvp("/opt/ddr-picker/ddr-picker", ["ddr-picker"])
        else:
            hold_start = 0

if __name__ == "__main__":
    main()