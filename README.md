# USB Power Relay Controller

High-performance GUI application for controlling CH340-based USB power relay modules. Built with Rust for maximum speed and efficiency.

![Relay Status](https://img.shields.io/badge/Status-Production-green)
![Rust](https://img.shields.io/badge/Rust-1.70+-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **Simple GUI** - Just ON/OFF buttons and a status indicator
- **Real-time Status** - Live relay state visualization
- **Auto-detection** - Automatically finds CH340/CH341 devices
- **High Performance** - Optimized Rust implementation with zero-cost abstractions
- **Cross-platform** - Works on Windows, Linux, and macOS

## Hardware Specifications

- **Module**: CH340/CH341 USB-to-Serial Relay
- **Relay Rating**: 10A @ 250V AC / 10A @ 30V DC
- **Communication**: Serial 9600 baud, 8N1
- **Protocol**: 4-byte commands (0xA0 0x01 CMD CHECKSUM)
- **Switching Speed**: ~10 switches/second (100ms per switch)

## Safety Warning

⚠️ **This relay switches mains voltage (110-250V AC)!**

- Always disconnect power before wiring
- Follow local electrical codes
- Consider professional electrician for AC wiring
- Test with low voltage (9V battery + LED) first

## Prerequisites

### 1. Install CH340/CH341 Drivers

**Windows:**
- Download from: https://www.wch.cn/downloads/CH341SER_ZIP.html
- Run the installer and restart your computer

**Linux:**
- Driver is usually included in kernel (4.0+)
- Check with: `lsmod | grep ch341`
- Install build dependencies:
  ```bash
  # Ubuntu/Debian
  sudo apt-get install libudev-dev pkg-config

  # Fedora/RHEL
  sudo dnf install systemd-devel

  # Arch Linux
  sudo pacman -S systemd
  ```

**macOS:**
- Download from: https://www.wch.cn/downloads/CH341SER_MAC_ZIP.html
- Follow installation instructions

### 2. Install Rust

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Or on Windows, download from: https://rustup.rs/
```

### 3. Verify Device Connection

**Windows:**
- Open Device Manager → Ports (COM & LPT)
- Look for "USB-SERIAL CH340" or similar

**Linux:**
```bash
ls /dev/ttyUSB*
# or
dmesg | grep ch341
```

**macOS:**
```bash
ls /dev/cu.wchusbserial*
```

## Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd USBPowerSwitch

# Build release version (optimized)
cargo build --release

# The executable will be in: target/release/usb-power-relay
# (or usb-power-relay.exe on Windows)
```

## Running the Application

```bash
# Run directly with cargo
cargo run --release

# Or run the compiled executable
./target/release/usb-power-relay  # Linux/macOS
target\release\usb-power-relay.exe  # Windows
```

## Usage

1. **Connect** your CH340 relay module to a USB port
2. **Launch** the application
3. **Wait** for device auto-detection (shown in status message)
4. **Click** ON or OFF buttons to control the relay
5. **Watch** the status indicator change color:
   - 🟢 **Green** = Relay ON (circuit closed)
   - 🔴 **Red** = Relay OFF (circuit open)
   - ⚪ **Gray** = Unknown state
   - 🟠 **Orange** = Error/disconnected

## Command-Line Tool (Python)

A Python CLI tool is also included for quick testing:

```bash
# Install dependencies
pip install pyserial

# Control relay from command line
python relay_control.py on              # Turn ON
python relay_control.py off             # Turn OFF
python relay_control.py toggle          # Toggle state
python relay_control.py status          # Query status
python relay_control.py on --port COM5  # Use specific port
python relay_control.py status -v       # Verbose mode
```

## Protocol Reference

### Command Format

All commands are 4 bytes: `[0xA0, 0x01, CMD, CHECKSUM]`

| Command | Hex Code | Description | Response |
|---------|----------|-------------|----------|
| OFF | `A0 01 00 A1` | Open relay contacts | Via status query |
| ON | `A0 01 03 A4` | Close relay contacts | Returns state |
| Toggle | `A0 01 04 A5` | Switch state | Returns new state |
| Status | `A0 01 05 A6` | Query current state | Returns 0x00/0x01 |

### Response Format

Response header: `[0xA0, 0x01, STATE, ...]`
- `STATE = 0x01` → Relay ON
- `STATE = 0x00` → Relay OFF

## Wiring Guide

### Low Voltage Testing (Safe)

```
9V Battery (+) → LED (+) → COM terminal
9V Battery (-) → NO terminal
```

### AC Wiring (Dangerous - Professional Only)

```
Line/Hot (AC) → COM (Common)
Load → NO (Normally Open)
```

Terminals:
- **COM**: Common terminal (always connected)
- **NO**: Normally Open (connected when relay ON)
- **NC**: Normally Closed (connected when relay OFF)

## Troubleshooting

### Device Not Found

1. Check USB connection
2. Install/reinstall CH340 drivers
3. Verify in Device Manager (Windows) or `lsusb` (Linux)
4. Try a different USB port
5. Check if another program is using the port

### Permission Denied (Linux)

```bash
# Add your user to dialout group
sudo usermod -a -G dialout $USER
# Then logout and login again
```

### Build Errors

**Missing libudev (Linux):**
```bash
# Ubuntu/Debian
sudo apt-get install libudev-dev pkg-config

# Fedora/RHEL
sudo dnf install systemd-devel

# Then rebuild
cargo clean
cargo build --release
```

**General build issues:**
```bash
# Update Rust
rustup update

# Clean and rebuild
cargo clean
cargo build --release
```

## Performance Optimizations

The Rust application uses several optimizations:

- **LTO (Link-Time Optimization)** - Whole-program optimization
- **Codegen units = 1** - Single compilation unit for better optimization
- **Strip = true** - Removes debug symbols for smaller binary
- **Opt-level = 3** - Maximum optimization level
- **Async I/O** - Non-blocking serial communication
- **Immediate mode GUI** - Fast rendering with egui

## Development

### Project Structure

```
USBPowerSwitch/
├── Cargo.toml           # Rust dependencies and build config
├── src/
│   └── main.rs          # Main application code
├── relay_control.py     # Python CLI tool
└── README.md           # This file
```

### Key Dependencies

- **eframe/egui** - Fast immediate-mode GUI framework
- **serialport** - Cross-platform serial port communication
- **tokio** - Async runtime for non-blocking operations

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Credits

- Hardware: CH340/CH341 USB-to-Serial relay module
- GUI Framework: [egui](https://github.com/emilk/egui)
- Serial Library: [serialport-rs](https://github.com/serialport/serialport-rs)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the protocol reference
3. Open an issue on GitHub

---

**Made with ⚡ Rust for maximum performance**
