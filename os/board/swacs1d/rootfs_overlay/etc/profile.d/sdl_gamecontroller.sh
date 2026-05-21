#!/bin/sh
# Export SDL_GAMECONTROLLERCONFIG from saved input mapping

INPUT_MAP_CONF="/var/data/input.conf"

if [ -f "$INPUT_MAP_CONF" ]; then
    # Convert JSON mapping to SDL gamecontroller format
    export SDL_GAMECONTROLLERCONFIG="$(cat "$INPUT_MAP_CONF" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Mapping from our internal names to SDL controller buttons
    button_map = {
        'step_left': 'leftshoulder',
        'step_down': 'rightshoulder', 
        'step_up': 'lefttrigger',
        'step_right': 'righttrigger',
        'service': 'start',
        'test': 'back',
        'coin': 'a',
        'menu_up': 'dpup',
        'menu_down': 'dpdown',
        'menu_select': 'start',
        'menu_back': 'b'
    }
    
    # Build SDL controller mapping string
    sdl_parts = ['030000004c0500006802000000010000,DDR Controller,platform:Linux,']
    
    for internal_name, sdl_button in button_map.items():
        if internal_name in data:
            mapping = data[internal_name]
            if mapping['type'] == 'joypad':
                # Joypad button mapping
                sdl_parts.append(f'{sdl_button}:b{mapping[\"button\"]},')
            elif mapping['type'] == 'keyboard':
                # Keyboard mapping (simplified)
                sdl_parts.append(f'{sdl_button}:k{mapping[\"button\"]},')
    
    # Remove trailing comma and join
    result = ''.join(sdl_parts)
    if result.endswith(','):
        result = result[:-1]
    print(result)
except Exception as e:
    # Fallback to default mapping
    print('030000004c0500006802000000010000,DDR Controller,platform:Linux,')
")"
fi