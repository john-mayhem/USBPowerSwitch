//! USB Power Relay Controller - Minimal Rust GUI
//!
//! Simple, fast GUI for CH340-based USB relay modules.

#![windows_subsystem = "windows"]

use eframe::egui;
use serialport::{SerialPort, SerialPortType};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::mpsc;

// ============================================================================
// CONSTANTS
// ============================================================================

const BAUD_RATE: u32 = 9600;
const RESPONSE_DELAY_MS: u64 = 100;
const TIMEOUT: Duration = Duration::from_millis(500);

const CMD_OFF: [u8; 4] = [0xA0, 0x01, 0x00, 0xA1];
const CMD_ON: [u8; 4] = [0xA0, 0x01, 0x03, 0xA4];
const CMD_STATUS: [u8; 4] = [0xA0, 0x01, 0x05, 0xA6];

const RESPONSE_HEADER: [u8; 2] = [0xA0, 0x01];
const STATE_ON: u8 = 0x01;

const CH340_KEYWORDS: &[&str] = &["CH340", "CH341", "USB-SERIAL"];

// ============================================================================
// RELAY STATE
// ============================================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum RelayState {
    Unknown,
    On,
    Off,
    Error,
}

impl RelayState {
    fn color(&self) -> egui::Color32 {
        match self {
            RelayState::On => egui::Color32::from_rgb(34, 197, 94),   // Modern green
            RelayState::Off => egui::Color32::from_rgb(239, 68, 68),  // Modern red
            RelayState::Unknown => egui::Color32::from_rgb(156, 163, 175), // Gray
            RelayState::Error => egui::Color32::from_rgb(249, 115, 22), // Orange
        }
    }

    fn text(&self) -> &'static str {
        match self {
            RelayState::On => "ON",
            RelayState::Off => "OFF",
            RelayState::Unknown => "...",
            RelayState::Error => "ERROR",
        }
    }
}

// ============================================================================
// RELAY CONTROLLER
// ============================================================================

struct RelayController {
    port: Box<dyn SerialPort>,
}

impl RelayController {
    fn new() -> Result<Self, String> {
        let port_info = Self::detect_device()?;

        let port = serialport::new(&port_info.port_name, BAUD_RATE)
            .timeout(TIMEOUT)
            .open()
            .map_err(|e| format!("Failed to open port: {}", e))?;

        Ok(Self { port })
    }

    fn detect_device() -> Result<serialport::SerialPortInfo, String> {
        let ports = serialport::available_ports()
            .map_err(|e| format!("Failed to list ports: {}", e))?;

        // Look for CH340/CH341 devices
        for port in &ports {
            if let SerialPortType::UsbPort(info) = &port.port_type {
                let product = info.product.as_deref().unwrap_or("");
                let manufacturer = info.manufacturer.as_deref().unwrap_or("");
                let combined = format!("{} {}", product, manufacturer).to_uppercase();

                if CH340_KEYWORDS.iter().any(|kw| combined.contains(kw)) {
                    return Ok(port.clone());
                }
            }
        }

        // Fallback to any USB serial device
        for port in &ports {
            if matches!(port.port_type, SerialPortType::UsbPort(_)) {
                return Ok(port.clone());
            }
        }

        Err("No USB relay found".to_string())
    }

    fn send_command(&mut self, command: &[u8; 4]) -> Result<Option<RelayState>, String> {
        self.port.clear(serialport::ClearBuffer::All)
            .map_err(|e| format!("Clear failed: {}", e))?;

        self.port.write_all(command)
            .map_err(|e| format!("Write failed: {}", e))?;

        self.port.flush()
            .map_err(|e| format!("Flush failed: {}", e))?;

        std::thread::sleep(Duration::from_millis(RESPONSE_DELAY_MS));

        let mut buf = [0u8; 32];
        match self.port.read(&mut buf) {
            Ok(n) if n >= 4 => {
                if buf[0] == RESPONSE_HEADER[0] && buf[1] == RESPONSE_HEADER[1] {
                    return Ok(Some(if buf[2] == STATE_ON {
                        RelayState::On
                    } else {
                        RelayState::Off
                    }));
                }
                Ok(None)
            }
            Ok(_) => Ok(None),
            Err(ref e) if e.kind() == std::io::ErrorKind::TimedOut => Ok(None),
            Err(e) => Err(format!("Read error: {}", e)),
        }
    }

    fn turn_on(&mut self) -> Result<RelayState, String> {
        match self.send_command(&CMD_ON)? {
            Some(state) => Ok(state),
            None => Ok(RelayState::On),
        }
    }

    fn turn_off(&mut self) -> Result<RelayState, String> {
        match self.send_command(&CMD_OFF)? {
            Some(state) => Ok(state),
            None => Ok(RelayState::Off),
        }
    }

    fn query_status(&mut self) -> Result<RelayState, String> {
        match self.send_command(&CMD_STATUS)? {
            Some(state) => Ok(state),
            None => Ok(RelayState::Unknown),
        }
    }
}

// ============================================================================
// APPLICATION STATE
// ============================================================================

enum Command {
    TurnOn,
    TurnOff,
}

struct AppState {
    relay_state: RelayState,
    error_message: Option<String>,
    command_tx: mpsc::UnboundedSender<Command>,
}

impl AppState {
    fn new(command_tx: mpsc::UnboundedSender<Command>) -> Self {
        Self {
            relay_state: RelayState::Unknown,
            error_message: None,
            command_tx,
        }
    }

    fn send_command(&self, cmd: Command) {
        let _ = self.command_tx.send(cmd);
    }
}

// ============================================================================
// GUI APPLICATION
// ============================================================================

struct RelayApp {
    state: Arc<Mutex<AppState>>,
}

impl RelayApp {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        // Configure style for cleaner look
        let mut style = (*cc.egui_ctx.style()).clone();
        style.visuals.window_rounding = 0.0.into();
        style.visuals.window_shadow = egui::epaint::Shadow {
            offset: egui::vec2(0.0, 0.0),
            blur: 0.0,
            spread: 0.0,
            color: egui::Color32::TRANSPARENT,
        };
        cc.egui_ctx.set_style(style);

        let (tx, mut rx) = mpsc::unbounded_channel::<Command>();
        let state = Arc::new(Mutex::new(AppState::new(tx)));
        let state_clone = Arc::clone(&state);

        // Background thread for serial communication
        std::thread::spawn(move || {
            let mut controller = match RelayController::new() {
                Ok(c) => {
                    if let Ok(mut state) = state_clone.lock() {
                        state.error_message = None;
                    }
                    c
                }
                Err(e) => {
                    if let Ok(mut state) = state_clone.lock() {
                        state.error_message = Some(e);
                        state.relay_state = RelayState::Error;
                    }
                    return;
                }
            };

            // Initial status query
            if let Ok(status) = controller.query_status() {
                if let Ok(mut state) = state_clone.lock() {
                    state.relay_state = status;
                    state.error_message = None;
                }
            }

            // Command processing loop
            while let Some(cmd) = rx.blocking_recv() {
                let result = match cmd {
                    Command::TurnOn => controller.turn_on(),
                    Command::TurnOff => controller.turn_off(),
                };

                if let Ok(mut state) = state_clone.lock() {
                    match result {
                        Ok(new_state) => {
                            state.relay_state = new_state;
                            state.error_message = None;
                        }
                        Err(e) => {
                            state.relay_state = RelayState::Error;
                            state.error_message = Some(e);
                        }
                    }
                }
            }
        });

        Self { state }
    }
}

impl eframe::App for RelayApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        ctx.request_repaint();

        let state = self.state.lock().unwrap();
        let relay_state = state.relay_state;
        let error = state.error_message.clone();
        drop(state);

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.vertical_centered(|ui| {
                ui.add_space(40.0);

                // Status indicator - large circle
                let status_color = relay_state.color();
                let (rect, _) = ui.allocate_exact_size(
                    egui::vec2(120.0, 120.0),
                    egui::Sense::hover()
                );

                ui.painter().circle_filled(
                    rect.center(),
                    60.0,
                    status_color,
                );

                ui.painter().text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    relay_state.text(),
                    egui::FontId::proportional(32.0),
                    egui::Color32::WHITE,
                );

                ui.add_space(50.0);

                // Control buttons - centered horizontally
                ui.horizontal(|ui| {
                    // Calculate total width: 2 buttons (140px each) + gap (20px) = 300px
                    // Center in 350px window: (350 - 300) / 2 = 25px spacing
                    let available_width = ui.available_width();
                    let buttons_width = 140.0 + 20.0 + 140.0;
                    let spacing = (available_width - buttons_width) / 2.0;

                    ui.add_space(spacing.max(0.0));

                    // ON button
                    let on_button = egui::Button::new(
                        egui::RichText::new("ON").size(28.0).strong()
                    )
                    .fill(egui::Color32::from_rgb(22, 163, 74))
                    .min_size(egui::vec2(140.0, 70.0));

                    if ui.add(on_button).clicked() {
                        let state = self.state.lock().unwrap();
                        state.send_command(Command::TurnOn);
                    }

                    ui.add_space(20.0);

                    // OFF button
                    let off_button = egui::Button::new(
                        egui::RichText::new("OFF").size(28.0).strong()
                    )
                    .fill(egui::Color32::from_rgb(220, 38, 38))
                    .min_size(egui::vec2(140.0, 70.0));

                    if ui.add(off_button).clicked() {
                        let state = self.state.lock().unwrap();
                        state.send_command(Command::TurnOff);
                    }
                });

                ui.add_space(30.0);

                // Error message if any
                if let Some(err) = error {
                    ui.colored_label(egui::Color32::from_rgb(239, 68, 68), err);
                }
            });
        });
    }
}

// ============================================================================
// MAIN
// ============================================================================

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([350.0, 380.0])
            .with_resizable(false)
            .with_maximize_button(false)
            .with_title("USB Relay"),
        ..Default::default()
    };

    eframe::run_native(
        "USB Relay",
        options,
        Box::new(|cc| Ok(Box::new(RelayApp::new(cc)))),
    )
}
