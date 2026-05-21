use sdl3::event::Event;
use ssdl3::keyboard::Keycode;
use sdl3::mouse::MouseButton;
use sdl3::controller::Axis;
use sdl3::controller::Button;
use sdl3::render::Canvas;
use sdl3::video::Window;
use sdl3::pixels::Color;
use sdl3::rect::Rect;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, Write};
use std::process::exit;

const SCREEN_WIDTH: u32 = 800;
const SCREEN_HEIGHT: u32 = 600;

#[derive(Debug, Clone)]
struct ButtonMapping {
    name: String,
    button_type: String, // "joypad", "keyboard"
    button_id: i32,
    description: String,
}

#[derive(Debug, Clone)]
struct ButtonPrompt {
    name: String,
    description: String,
    mapped: bool,
}

fn main() {
    // Initialize SDL3
    let sdl_context = sdl3::init().expect("Failed to initialize SDL");
    let video_subsystem = sdl_context.video().expect("Failed to get video subsystem");
    
    // Create window
    let window = video_subsystem
        .window("Input Mapping Wizard", SCREEN_WIDTH, SCREEN_HEIGHT)
        .position_centered()
        .opengl()
        .build()
        .expect("Failed to create window");
    
    let mut canvas = window.into_canvas().build().expect("Failed to create canvas");
    
    // Initialize game controller subsystem
    let _controller_context = sdl_context.game_controller().expect("Failed to initialize game controller");
    
    // Clear screen
    canvas.set_draw_color(Color::RGB(0, 0, 0));
    canvas.clear();
    canvas.present();
    
    // Define buttons to map
    let buttons_to_map = vec![
        ButtonPrompt {
            name: "step_left".to_string(),
            description: "Panel button left".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "step_down".to_string(),
            description: "Panel button down".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "step_up".to_string(),
            description: "Panel button up".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "step_right".to_string(),
            description: "Panel button right".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "service".to_string(),
            description: "Service (optional)".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "test".to_string(),
            description: "Test (optional)".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "coin".to_string(),
            description: "Coin input".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "menu_up".to_string(),
            description: "Menu navigate".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "menu_down".to_string(),
            description: "Menu navigate".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "menu_select".to_string(),
            description: "Menu select".to_string(),
            mapped: false,
        },
        ButtonPrompt {
            name: "menu_back".to_string(),
            description: "Menu back".to_string(),
            mapped: false,
        },
    ];
    
    let mut mappings: HashMap<String, ButtonMapping> = HashMap::new();
    let mut current_button_index = 0;
    
    'main: loop {
        // Handle events
        for event in sdl_context.event_pump().unwrap().poll_iter() {
            match event {
                Event::Quit { .. } => break 'main,
                Event::KeyDown { keycode: Some(Keycode::Escape), .. } => break 'main,
                Event::ControllerButtonDown { which, button, .. } => {
                    // Handle controller button press
                    if current_button_index < buttons_to_map.len() {
                        let button_name = &buttons_to_map[current_button_index].name;
                        mappings.insert(
                            button_name.clone(),
                            ButtonMapping {
                                name: button_name.clone(),
                                button_type: "joypad".to_string(),
                                button_id: button as i32,
                                description: buttons_to_map[current_button_index].description.clone(),
                            },
                        );
                        println!("Mapped {} to joypad button {}", button_name, button as i32);
                        current_button_index += 1;
                    }
                }
                Event::ControllerAxisMotion { which, axis, value, .. } => {
                    // Handle controller axis as button (for triggers, etc.)
                    if current_button_index < buttons_to_map.len() {
                        let button_name = &buttons_to_map[current_button_index].name;
                        // Only consider significant axis movement as button press
                        if (axis == Axis::TriggerLeft && value > 32767) || 
                           (axis == Axis::TriggerRight && value > 32767) {
                            mappings.insert(
                                button_name.clone(),
                                ButtonMapping {
                                    name: button_name.clone(),
                                    button_type: "joypad".to_string(),
                                    button_id: (axis as i32) * 1000 + (value as i32),
                                    description: buttons_to_map[current_button_index].description.clone(),
                                },
                            );
                            println!("Mapped {} to joypad axis {}", button_name, axis as i32);
                            current_button_index += 1;
                        }
                    }
                }
                Event::KeyDown { keycode: Some(keycode), .. } => {
                    // Handle keyboard key press
                    if current_button_index < buttons_to_map.len() {
                        let button_name = &buttons_to_map[current_button_index].name;
                        mappings.insert(
                            button_name.clone(),
                            ButtonMapping {
                                name: button_name.clone(),
                                button_type: "keyboard".to_string(),
                                button_id: keycode as i32,
                                description: buttons_to_map[current_button_index].description.clone(),
                            },
                        );
                        println!("Mapped {} to keyboard key {:?}", button_name, keycode);
                        current_button_index += 1;
                    }
                }
                _ => {}
            }
        }
        
        // Render
        canvas.set_draw_color(Color::RGB(0, 0, 0));
        canvas.clear();
        
        // Draw prompt
        if current_button_index < buttons_to_map.len() {
            let prompt = &buttons_to_map[current_button_index];
            draw_text(
                &mut canvas,
                &format!("Press the button for: {}", prompt.description),
                SCREEN_WIDTH / 2 - 200,
                SCREEN_HEIGHT / 2 - 50,
                Color::RGB(255, 255, 255),
            );
            
            draw_text(
                &mut canvas,
                "(Press ESC to skip optional buttons)",
                SCREEN_WIDTH / 2 - 150,
                SCREEN_HEIGHT / 2,
                Color::RGB(200, 200, 200),
            );
        } else {
            // All buttons mapped, save configuration
            draw_text(
                &mut canvas,
                "All buttons mapped! Saving configuration...",
                SCREEN_WIDTH / 2 - 180,
                SCREEN_HEIGHT / 2,
                Color::RGB(0, 255, 0),
            );
            canvas.present();
            
            // Save to file
            save_mappings(&mappings);
            
            // Wait a moment then exit
            ::std::thread::sleep(::std::time::Duration::from_secs(2));
            break;
        }
        
        canvas.present();
        ::std::thread::sleep(::std::time::Duration::from_millis(16));
    }
    
    // Cleanup
    drop(canvas);
    drop(window);
}

fn draw_text(canvas: &mut Canvas<Window>, text: &str, x: i32, y: i32, color: Color) {
    // Simple text rendering - in a real implementation you'd use SDL_ttf
    // For now we'll just draw a rectangle to represent text
    canvas.set_draw_color(color);
    let rect = Rect::new(x, y, text.len() as u32 * 8, 20);
    canvas.fill_rect(rect).ok();
}

fn save_mappings(mappings: &HashMap<String, ButtonMapping>) {
    let config_dir = "/var/data";
    let config_file = format!("{}/input.conf", config_dir);
    
    // Create directory if it doesn't exist
    let _ = std::fs::create_dir_all(config_dir);
    
    // Create JSON output
    let mut json = String::new();
    json.push_str("{\n");
    
    let mut first = true;
    for (name, mapping) in mappings {
        if !first {
            json.push_str(",\n");
        }
        first = false;
        
        json.push_str(&format!(
            r#"  "{}": {{"type": "{}", "button": {}, "description": "{}"}}"#,
            name, mapping.button_type, mapping.button_id, mapping.description
        ));
    }
    
    json.push_str("\n}\n");
    
    // Write to file
    if let Ok(mut file) = File::create(&config_file) {
        let _ = file.write_all(json.as_bytes());
        println!("Saved input mapping to {}", config_file);
    } else {
        eprintln!("Failed to save input mapping to {}", config_file);
    }
}