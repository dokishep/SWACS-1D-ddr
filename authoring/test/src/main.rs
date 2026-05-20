use sdl3::event::Event;
use sdl3::keyboard::Keycode;
use sdl3::pixels::Color;
use sdl3::rect::Rect;
use std::time::Duration;
use std::collections::{HashSet, HashMap};

// 5x7 font lookup for printable ASCII 32..127 (index = char - 32)
const FONT_DATA: [[u8; 5]; 95] = [
    [0x00, 0x00, 0x00, 0x00, 0x00], // (space)
    [0x00, 0x00, 0x5f, 0x00, 0x00], // !
    [0x00, 0x07, 0x00, 0x07, 0x00], // "
    [0x14, 0x7f, 0x14, 0x7f, 0x14], // #
    [0x24, 0x2a, 0x7f, 0x2a, 0x12], // $
    [0x23, 0x13, 0x08, 0x64, 0x62], // %
    [0x36, 0x49, 0x55, 0x22, 0x50], // &
    [0x00, 0x05, 0x03, 0x00, 0x00], // '
    [0x00, 0x1c, 0x22, 0x41, 0x00], // (
    [0x00, 0x41, 0x22, 0x1c, 0x00], // )
    [0x14, 0x08, 0x3e, 0x08, 0x14], // *
    [0x08, 0x08, 0x3e, 0x08, 0x08], // +
    [0x00, 0x50, 0x30, 0x00, 0x00], // ,
    [0x08, 0x08, 0x08, 0x08, 0x08], // -
    [0x00, 0x60, 0x60, 0x00, 0x00], // .
    [0x20, 0x10, 0x08, 0x04, 0x02], // /
    [0x3e, 0x51, 0x49, 0x45, 0x3e], // 0
    [0x00, 0x42, 0x7f, 0x40, 0x00], // 1
    [0x42, 0x61, 0x51, 0x49, 0x46], // 2
    [0x21, 0x41, 0x45, 0x4b, 0x31], // 3
    [0x18, 0x14, 0x12, 0x7f, 0x10], // 4
    [0x27, 0x45, 0x45, 0x45, 0x39], // 5
    [0x3c, 0x4a, 0x49, 0x49, 0x30], // 6
    [0x01, 0x71, 0x09, 0x05, 0x03], // 7
    [0x36, 0x49, 0x49, 0x49, 0x36], // 8
    [0x06, 0x49, 0x49, 0x29, 0x1e], // 9
    [0x00, 0x36, 0x36, 0x00, 0x00], // :
    [0x00, 0x56, 0x36, 0x00, 0x00], // ;
    [0x08, 0x14, 0x22, 0x41, 0x00], // <
    [0x24, 0x24, 0x24, 0x24, 0x24], // =
    [0x00, 0x41, 0x22, 0x14, 0x08], // >
    [0x02, 0x01, 0x51, 0x09, 0x06], // ?
    [0x32, 0x49, 0x79, 0x41, 0x3e], // @
    [0x7e, 0x11, 0x11, 0x11, 0x7e], // A
    [0x7f, 0x49, 0x49, 0x49, 0x36], // B
    [0x3e, 0x41, 0x41, 0x41, 0x22], // C
    [0x7f, 0x41, 0x41, 0x22, 0x1c], // D
    [0x7f, 0x49, 0x49, 0x49, 0x41], // E
    [0x7f, 0x09, 0x09, 0x09, 0x01], // F
    [0x3e, 0x41, 0x49, 0x49, 0x7a], // G
    [0x7f, 0x08, 0x08, 0x08, 0x7f], // H
    [0x00, 0x41, 0x7f, 0x41, 0x00], // I
    [0x20, 0x40, 0x41, 0x3f, 0x01], // J
    [0x7f, 0x08, 0x14, 0x22, 0x41], // K
    [0x7f, 0x40, 0x40, 0x40, 0x40], // L
    [0x7f, 0x02, 0x0c, 0x02, 0x7f], // M
    [0x7f, 0x04, 0x08, 0x10, 0x7f], // N
    [0x3e, 0x41, 0x41, 0x41, 0x3e], // O
    [0x7f, 0x09, 0x09, 0x09, 0x06], // P
    [0x3e, 0x41, 0x51, 0x21, 0x5e], // Q
    [0x7f, 0x09, 0x19, 0x29, 0x46], // R
    [0x46, 0x49, 0x49, 0x49, 0x31], // S
    [0x01, 0x01, 0x7f, 0x01, 0x01], // T
    [0x3f, 0x40, 0x40, 0x40, 0x3f], // U
    [0x1f, 0x20, 0x40, 0x20, 0x1f], // V
    [0x3f, 0x40, 0x38, 0x40, 0x3f], // W
    [0x63, 0x14, 0x08, 0x14, 0x63], // X
    [0x07, 0x08, 0x70, 0x08, 0x07], // Y
    [0x61, 0x51, 0x49, 0x45, 0x43], // Z
    [0x00, 0x7f, 0x41, 0x41, 0x00], // [
    [0x02, 0x04, 0x08, 0x10, 0x20], // \
    [0x00, 0x41, 0x41, 0x7f, 0x00], // ]
    [0x04, 0x02, 0x01, 0x02, 0x04], // ^
    [0x40, 0x40, 0x40, 0x40, 0x40], // _
    [0x00, 0x01, 0x02, 0x04, 0x00], // `
    [0x20, 0x54, 0x54, 0x54, 0x78], // a
    [0x7f, 0x48, 0x44, 0x44, 0x38], // b
    [0x38, 0x44, 0x44, 0x44, 0x20], // c
    [0x38, 0x44, 0x44, 0x48, 0x7f], // d
    [0x38, 0x54, 0x54, 0x54, 0x18], // e
    [0x08, 0x7e, 0x09, 0x01, 0x02], // f
    [0x0c, 0x52, 0x52, 0x52, 0x3e], // g
    [0x7f, 0x08, 0x04, 0x04, 0x78], // h
    [0x00, 0x44, 0x7d, 0x40, 0x00], // i
    [0x20, 0x40, 0x44, 0x3d, 0x00], // j
    [0x7f, 0x10, 0x28, 0x44, 0x00], // k
    [0x00, 0x41, 0x7f, 0x40, 0x00], // l
    [0x7c, 0x04, 0x18, 0x04, 0x78], // m
    [0x7c, 0x08, 0x04, 0x04, 0x78], // n
    [0x38, 0x44, 0x44, 0x44, 0x38], // o
    [0x7c, 0x14, 0x14, 0x14, 0x08], // p
    [0x08, 0x14, 0x14, 0x18, 0x7c], // q
    [0x7c, 0x08, 0x04, 0x04, 0x08], // r
    [0x48, 0x54, 0x54, 0x54, 0x20], // s
    [0x04, 0x3f, 0x44, 0x40, 0x20], // t
    [0x3c, 0x40, 0x40, 0x20, 0x7c], // u
    [0x1c, 0x20, 0x40, 0x20, 0x1c], // v
    [0x3c, 0x40, 0x30, 0x40, 0x3c], // w
    [0x44, 0x28, 0x10, 0x28, 0x44], // x
    [0x0c, 0x50, 0x50, 0x50, 0x3c], // y
    [0x44, 0x64, 0x54, 0x4c, 0x44], // z
    [0x00, 0x08, 0x36, 0x41, 0x00], // {
    [0x00, 0x00, 0x7f, 0x00, 0x00], // |
    [0x00, 0x41, 0x36, 0x08, 0x00], // }
    [0x08, 0x08, 0x2a, 0x1c, 0x08], // ~
];

fn draw_char(canvas: &mut sdl3::render::Canvas<sdl3::video::Window>, c: char, x: i32, y: i32, scale: i32) {
    let code = c as usize;
    if code < 32 || code > 127 {
        return;
    }
    let data = FONT_DATA[code - 32];
    for col in 0..5 {
        let byte = data[col];
        for row in 0..8 {
            if (byte & (1 << row)) != 0 {
                let px = x + col as i32 * scale;
                let py = y + row as i32 * scale;
                let rect = Rect::new(px, py, scale as u32, scale as u32);
                let _ = canvas.fill_rect(rect);
            }
        }
    }
}

fn draw_string(canvas: &mut sdl3::render::Canvas<sdl3::video::Window>, s: &str, x: i32, y: i32, scale: i32) {
    let mut current_x = x;
    for c in s.chars() {
        draw_char(canvas, c, current_x, y, scale);
        current_x += 6 * scale;
    }
}

pub fn main() -> Result<(), String> {
    let sdl_context = sdl3::init().map_err(|e| e.to_string())?;
    let video_subsystem = sdl_context.video().map_err(|e| e.to_string())?;
    let gamepad_subsystem = sdl_context.gamepad().map_err(|e| e.to_string())?;

    let window = video_subsystem
        .window("SWACS-1D Input Test", 640, 480)
        .position_centered()
        .build()
        .map_err(|e| e.to_string())?;

    let mut canvas = window.into_canvas();
    let mut event_pump = sdl_context.event_pump().map_err(|e| e.to_string())?;

    let mut pressed_keys = HashSet::new();
    let mut opened_gamepads = HashMap::new();

    println!("Starting input test loop...");

    'running: loop {
        canvas.set_draw_color(Color::RGB(15, 15, 25));
        canvas.clear();

        for event in event_pump.poll_iter() {
            match event {
                Event::Quit { .. } |
                Event::KeyDown { keycode: Some(Keycode::Escape), .. } => {
                    break 'running;
                }
                Event::KeyDown { keycode: Some(key), .. } => {
                    pressed_keys.insert(format!("{:?}", key));
                }
                Event::KeyUp { keycode: Some(key), .. } => {
                    pressed_keys.remove(&format!("{:?}", key));
                }
                Event::ControllerDeviceAdded { which, .. } => {
                    let joystick_id = sdl3::sys::joystick::SDL_JoystickID(which);
                    if let Ok(gamepad) = gamepad_subsystem.open(joystick_id) {
                        let name = gamepad.name().unwrap_or_else(|| "Unknown Gamepad".to_string());
                        println!("Gamepad connected: {} (id={:?})", name, which);
                        opened_gamepads.insert(which, (gamepad, name));
                    }
                }
                Event::ControllerDeviceRemoved { which, .. } => {
                    if let Some((_, name)) = opened_gamepads.remove(&which) {
                        println!("Gamepad disconnected: {} (id={:?})", name, which);
                    }
                }
                _ => {}
            }
        }

        // Draw Title
        canvas.set_draw_color(Color::RGB(255, 215, 0));
        draw_string(&mut canvas, "SWACS-1D INPUT DIAGNOSTICS", 20, 20, 2);

        // Draw Keyboard Inputs
        canvas.set_draw_color(Color::RGB(200, 200, 200));
        draw_string(&mut canvas, "Pressed Keys:", 20, 60, 2);
        
        let keys_str = if pressed_keys.is_empty() {
            "[None]".to_string()
        } else {
            let mut k: Vec<String> = pressed_keys.iter().cloned().collect();
            k.sort();
            k.join(", ")
        };
        canvas.set_draw_color(Color::RGB(0, 255, 127));
        draw_string(&mut canvas, &keys_str, 20, 90, 1);

        // Draw Gamepad Section
        canvas.set_draw_color(Color::RGB(200, 200, 200));
        draw_string(&mut canvas, "Gamepads:", 20, 130, 2);

        if opened_gamepads.is_empty() {
            canvas.set_draw_color(Color::RGB(255, 100, 100));
            draw_string(&mut canvas, "No gamepads detected. Connect one now.", 20, 160, 1);
        } else {
            let mut y_offset = 160;
            for (id, (gamepad, name)) in &opened_gamepads {
                canvas.set_draw_color(Color::RGB(135, 206, 250));
                let header = format!("Gamepad (ID: {}): {}", id, name);
                draw_string(&mut canvas, &header, 20, y_offset, 1);
                y_offset += 15;

                // Render some button states
                let mut pressed_buttons = Vec::new();
                for btn in &[
                    sdl3::gamepad::Button::South,
                    sdl3::gamepad::Button::East,
                    sdl3::gamepad::Button::West,
                    sdl3::gamepad::Button::North,
                    sdl3::gamepad::Button::Back,
                    sdl3::gamepad::Button::Guide,
                    sdl3::gamepad::Button::Start,
                    sdl3::gamepad::Button::LeftStick,
                    sdl3::gamepad::Button::RightStick,
                    sdl3::gamepad::Button::LeftShoulder,
                    sdl3::gamepad::Button::RightShoulder,
                    sdl3::gamepad::Button::DPadUp,
                    sdl3::gamepad::Button::DPadDown,
                    sdl3::gamepad::Button::DPadLeft,
                    sdl3::gamepad::Button::DPadRight,
                ] {
                    if gamepad.button(*btn) {
                        pressed_buttons.push(format!("{:?}", btn));
                    }
                }

                let btn_str = if pressed_buttons.is_empty() {
                    "Buttons: [None]".to_string()
                } else {
                    format!("Buttons: {}", pressed_buttons.join(", "))
                };
                canvas.set_draw_color(Color::RGB(0, 255, 0));
                draw_string(&mut canvas, &btn_str, 30, y_offset, 1);
                y_offset += 15;

                // Render axis states
                let lx = gamepad.axis(sdl3::gamepad::Axis::LeftX) as f32 / 32767.0;
                let ly = gamepad.axis(sdl3::gamepad::Axis::LeftY) as f32 / 32767.0;
                let rx = gamepad.axis(sdl3::gamepad::Axis::RightX) as f32 / 32767.0;
                let ry = gamepad.axis(sdl3::gamepad::Axis::RightY) as f32 / 32767.0;
                let lt = gamepad.axis(sdl3::gamepad::Axis::TriggerLeft) as f32 / 32767.0;
                let rt = gamepad.axis(sdl3::gamepad::Axis::TriggerRight) as f32 / 32767.0;

                canvas.set_draw_color(Color::RGB(255, 255, 100));
                let l_stick = format!("L Stick: ({:.2}, {:.2}) | R Stick: ({:.2}, {:.2})", lx, ly, rx, ry);
                draw_string(&mut canvas, &l_stick, 30, y_offset, 1);
                y_offset += 15;

                let triggers = format!("Triggers: L={:.2}, R={:.2}", lt, rt);
                draw_string(&mut canvas, &triggers, 30, y_offset, 1);
                y_offset += 25;
            }
        }

        canvas.present();
        std::thread::sleep(Duration::from_millis(16));
    }

    Ok(())
}
