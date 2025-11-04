//! USB Power Relay Controller - Rust GUI Application
//!
//! High-performance GUI for CH340-based USB relay modules.
//! Features: ON/OFF buttons, real-time status indicator, auto-detection.

use eframe::egui;
use serialport::{SerialPort, SerialPortType};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::mpsc;

// ============================================================================
// CONSTANTS
// ============================================================================

/// Serial communication baud rate
const BAUD_RATE: u32 = 9600;

/// Response delay after sending command (milliseconds)
const RESPONSE_DELAY_MS: u64 = 100;

/// Serial timeout
const TIMEOUT: Duration = Duration::from_millis(500);

/// Protocol commands
const CMD_OFF: [u8; 4] = [0xA0, 0x01, 0x00, 0xA1];
const CMD_ON: [u8; 4] = [0xA0, 0x01, 0x03, 0xA4];
const CMD_STATUS: [u8; 4] = [0xA0, 0x01, 0x05, 0xA6];

/// Response validation
const RESPONSE_HEADER: [u8; 2] = [0xA0, 0x01];
const STATE_ON: u8 = 0x01;
const STATE_OFF: u8 = 0x00;

/// Device detection keywords
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
            RelayState::On => egui::Color32::from_rgb(0, 200, 0),      // Green
            RelayState::Off => egui::Color32::from_rgb(200, 0, 0),     // Red
            RelayState::Unknown => egui::Color32::from_rgb(150, 150, 150), // Gray
            RelayState::Error => egui::Color32::from_rgb(255, 100, 0), // Orange
        }
    }

    fn text(&self) -> &'static str {
        match self {
            RelayState::On => "ON",
            RelayState::Off => "OFF",
            RelayState::Unknown => "UNKNOWN",
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
    /// Auto-detect and open CH340 relay device
    fn new() -> Result<Self, String> {
        let port_info = Self::detect_device()?;

        let port = serialport::new(&port_info.port_name, BAUD_RATE)
            .timeout(TIMEOUT)
            .open()
            .map_err(|e| format!("Failed to open port: {}", e))?;

        Ok(Self { port })
    }

    /// Detect CH340/CH341 device
    fn detect_device() -> Result<serialport::SerialPortInfo, String> {
        let ports = serialport::available_ports()
            .map_err(|e| format!("Failed to list ports: {}", e))?;

        // Priority 1: Look for CH340/CH341 devices
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

        // Priority 2: Look for any USB serial device
        for port in &ports {
            if matches!(port.port_type, SerialPortType::UsbPort(_)) {
                return Ok(port.clone());
            }
        }

        Err("No USB relay device found. Ensure CH340 drivers are installed.".to_string())
    }

    /// Send command and read response
    fn send_command(&mut self, command: &[u8; 4]) -> Result<Option<RelayState>, String> {
        // Clear buffers
        self.port.clear(serialport::ClearBuffer::All)
            .map_err(|e| format!("Failed to clear buffers: {}", e))?;

        // Send command
        self.port.write_all(command)
            .map_err(|e| format!("Failed to write command: {}", e))?;

        self.port.flush()
            .map_err(|e| format!("Failed to flush: {}", e))?;

        // Wait for response
        std::thread::sleep(Duration::from_millis(RESPONSE_DELAY_MS));

        // Read response
        let mut buf = [0u8; 32];
        match self.port.read(&mut buf) {
            Ok(n) if n >= 4 => {
                // Validate response header
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

    /// Turn relay ON
    fn turn_on(&mut self) -> Result<RelayState, String> {
        match self.send_command(&CMD_ON)? {
            Some(state) => Ok(state),
            None => Ok(RelayState::On), // Command sent, assume success
        }
    }

    /// Turn relay OFF
    fn turn_off(&mut self) -> Result<RelayState, String> {
        match self.send_command(&CMD_OFF)? {
            Some(state) => Ok(state),
            None => Ok(RelayState::Off), // Command sent, assume success
        }
    }

    /// Query relay status
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
    QueryStatus,
}

struct AppState {
    relay_state: RelayState,
    status_message: String,
    command_tx: mpsc::UnboundedSender<Command>,
}

impl AppState {
    fn new(command_tx: mpsc::UnboundedSender<Command>) -> Self {
        Self {
            relay_state: RelayState::Unknown,
            status_message: "Initializing...".to_string(),
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
        // Configure fonts and style
        let mut style = (*cc.egui_ctx.style()).clone();
        style.spacing.button_padding = egui::vec2(20.0, 10.0);
        style.spacing.item_spacing = egui::vec2(10.0, 15.0);
        cc.egui_ctx.set_style(style);

        // Create command channel
        let (tx, mut rx) = mpsc::unbounded_channel::<Command>();

        let state = Arc::new(Mutex::new(AppState::new(tx)));
        let state_clone = Arc::clone(&state);

        // Spawn background thread for serial communication
        std::thread::spawn(move || {
            let mut controller = match RelayController::new() {
                Ok(c) => {
                    if let Ok(mut state) = state_clone.lock() {
                        state.status_message = "Device connected".to_string();
                    }
                    c
                }
                Err(e) => {
                    if let Ok(mut state) = state_clone.lock() {
                        state.status_message = format!("Error: {}", e);
                        state.relay_state = RelayState::Error;
                    }
                    return;
                }
            };

            // Initial status query
            if let Ok(status) = controller.query_status() {
                if let Ok(mut state) = state_clone.lock() {
                    state.relay_state = status;
                    state.status_message = "Ready".to_string();
                }
            }

            // Command processing loop
            while let Some(cmd) = rx.blocking_recv() {
                let result = match cmd {
                    Command::TurnOn => {
                        controller.turn_on()
                    }
                    Command::TurnOff => {
                        controller.turn_off()
                    }
                    Command::QueryStatus => {
                        controller.query_status()
                    }
                };

                if let Ok(mut state) = state_clone.lock() {
                    match result {
                        Ok(new_state) => {
                            state.relay_state = new_state;
                            state.status_message = "Ready".to_string();
                        }
                        Err(e) => {
                            state.relay_state = RelayState::Error;
                            state.status_message = format!("Error: {}", e);
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
        // Request repaint for smooth updates
        ctx.request_repaint();

        let state = self.state.lock().unwrap();
        let relay_state = state.relay_state;
        let status_message = state.status_message.clone();
        drop(state);

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.vertical_centered(|ui| {
                ui.add_space(20.0);

                // Title
                ui.heading("USB Power Relay");
                ui.add_space(10.0);
                ui.label("CH340-based Relay Controller");
                ui.add_space(30.0);

                // Status indicator - large circle
                let status_color = relay_state.color();
                let (rect, _) = ui.allocate_exact_size(
                    egui::vec2(100.0, 100.0),
                    egui::Sense::hover()
                );
                ui.painter().circle_filled(
                    rect.center(),
                    50.0,
                    status_color,
                );

                // Status text on indicator
                ui.painter().text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    relay_state.text(),
                    egui::FontId::proportional(24.0),
                    egui::Color32::WHITE,
                );

                ui.add_space(30.0);

                // Control buttons
                ui.horizontal(|ui| {
                    ui.add_space(50.0);

                    // ON button
                    let on_button = egui::Button::new(
                        egui::RichText::new("⚡ ON").size(24.0)
                    )
                    .fill(egui::Color32::from_rgb(0, 120, 0))
                    .min_size(egui::vec2(150.0, 60.0));

                    if ui.add(on_button).clicked() {
                        let state = self.state.lock().unwrap();
                        state.send_command(Command::TurnOn);
                    }

                    ui.add_space(20.0);

                    // OFF button
                    let off_button = egui::Button::new(
                        egui::RichText::new("⭘ OFF").size(24.0)
                    )
                    .fill(egui::Color32::from_rgb(120, 0, 0))
                    .min_size(egui::vec2(150.0, 60.0));

                    if ui.add(off_button).clicked() {
                        let state = self.state.lock().unwrap();
                        state.send_command(Command::TurnOff);
                    }
                });

                ui.add_space(30.0);

                // Status message
                ui.label(format!("Status: {}", status_message));

                ui.add_space(20.0);

                // Refresh button
                if ui.button("🔄 Refresh Status").clicked() {
                    let state = self.state.lock().unwrap();
                    state.send_command(Command::QueryStatus);
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
            .with_inner_size([500.0, 450.0])
            .with_resizable(false)
            .with_title("USB Power Relay Controller"),
        ..Default::default()
    };

    eframe::run_native(
        "USB Power Relay",
        options,
        Box::new(|cc| Ok(Box::new(RelayApp::new(cc)))),
    )
}
