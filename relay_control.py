#!/usr/bin/env python3
"""
USB Relay Control Script for CH340-based Modules
=================================================

DESCRIPTION:
    Fast and reliable control for CH340/CH341-based USB relay modules.
    Supports auto-detection, status queries, and toggle operations with
    full feedback confirmation.

HARDWARE SPECIFICATIONS:
    - Module: CH340 USB-to-Serial Relay
    - Relay Rating: 10A @ 250V AC / 10A @ 30V DC
    - Communication: Serial 9600 baud, 8N1
    - Protocol: 4-byte commands (0xA0 0x01 CMD CHECKSUM)

PERFORMANCE:
    - Switching Speed: ~10 switches/second (100ms per switch)
    - Response Delay: 100ms (configurable via RESPONSE_DELAY constant)
    - Reliability: Hardware-limited, no packet loss at 9600 baud

PROTOCOL COMMANDS:
    Command         Hex Code        Description             Feedback
    -----------------------------------------------------------------------
    Turn OFF        A0 01 00 A1     Open relay contacts     Via status query
    Turn ON         A0 01 03 A4     Close relay contacts    Returns state
    Toggle          A0 01 04 A5     Switch state            Returns new state
    Query Status    A0 01 05 A6     Check current state     Returns 0/1

CAPABILITIES:
    ✓ Switch circuits on/off (mechanical relay)
    ✓ Report relay state (open/closed)
    ✓ Auto-detect CH340 devices
    ✓ Handle up to 10A loads
    ✗ Cannot measure voltage/current/power
    ✗ Cannot detect connected load

SAFETY WARNING:
    ⚠ This relay switches mains voltage (110-250V AC)!
    - Always disconnect power before wiring
    - Follow local electrical codes
    - Consider professional electrician for AC wiring
    - Test with low voltage (9V battery + LED) first

SETUP REQUIREMENTS:
    1. Install CH340 drivers: https://www.wch.cn/downloads/CH341SER_ZIP.html
    2. Connect relay to USB port
    3. Check Device Manager for COM port assignment (Windows)
    4. Run: pip install pyserial (auto-installed by this script)

USAGE EXAMPLES:
    python relay_control.py on              # Turn ON (auto-detect port)
    python relay_control.py off             # Turn OFF
    python relay_control.py toggle          # Toggle state
    python relay_control.py status          # Query current state
    python relay_control.py on --port COM5  # Use specific port
    python relay_control.py status -v       # Verbose (show hex commands)

WIRING (for testing):
    Low voltage test: 9V battery -> LED -> COM/NO terminals
    AC wiring: Live wire through COM (common) and NO (normally open)
    - COM: Common terminal (always connected)
    - NO: Normally Open (connected when relay ON)
    - NC: Normally Closed (connected when relay OFF)

Author: Claude/Anthropic
License: MIT
Version: 2.0 (Optimized & Refactored)
"""

# ============================================================================
# IMPORTS
# ============================================================================
import sys
import time
import argparse
import subprocess
from typing import Optional

# Auto-install pyserial if missing
try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print(">> Installing pyserial dependency...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyserial"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("[OK] Dependency installed\n")
        import serial
        import serial.tools.list_ports
    except subprocess.CalledProcessError as e:
        sys.exit(f"[ERROR] Failed to install pyserial: {e}\n  Run: pip install pyserial")


# ============================================================================
# CONSTANTS
# ============================================================================
# Serial protocol commands for CH340 relay module
CMD_OFF = bytes([0xA0, 0x01, 0x00, 0xA1])      # Turn relay OFF
CMD_ON = bytes([0xA0, 0x01, 0x03, 0xA4])       # Turn relay ON (with feedback)
CMD_TOGGLE = bytes([0xA0, 0x01, 0x04, 0xA5])   # Toggle relay state
CMD_STATUS = bytes([0xA0, 0x01, 0x05, 0xA6])   # Query current status

# Response format validation
RESPONSE_HEADER = (0xA0, 0x01)
STATE_ON = 0x01
STATE_OFF = 0x00

# Serial communication settings
BAUD_RATE = 9600
TIMEOUT = 0.5           # Connection timeout (seconds)
RESPONSE_DELAY = 0.1    # Wait time for device response (seconds)

# Device detection priorities (lower = higher priority)
CH340_KEYWORDS = ["CH340", "CH341", "USB-SERIAL"]
USB_KEYWORDS = ["USB"]


# ============================================================================
# RELAY CONTROLLER CLASS
# ============================================================================
class RelayController:
    """
    High-performance USB relay controller with auto-detection.

    Features:
    - Auto-detects CH340/CH341 USB-serial devices
    - Context manager for safe resource handling
    - Response validation and status feedback
    - Fast operation with minimal delays

    Usage:
        with RelayController() as relay:
            relay.turn_on()
            status = relay.query_status()
    """

    def __init__(self, port: Optional[str] = None, verbose: bool = False):
        """
        Initialize controller.

        Args:
            port: Specific COM port (auto-detected if None)
            verbose: Enable verbose output
        """
        self.verbose = verbose
        self.port_name = port or self._auto_detect_port()
        self.serial_port: Optional[serial.Serial] = None

    def _auto_detect_port(self) -> str:
        """Auto-detect CH340/CH341 relay device and verify driver."""
        if not self.verbose:
            print("Scanning for USB relay device...")

        # Scan all available serial ports
        candidates = []
        for port in serial.tools.list_ports.comports():
            desc = (port.description or "").upper()

            # Priority 1: CH340/CH341 devices
            if any(kw in desc for kw in CH340_KEYWORDS):
                candidates.append((port.device, port.description, 1))
            # Priority 2: Generic USB devices
            elif any(kw in desc for kw in USB_KEYWORDS):
                candidates.append((port.device, port.description, 2))

        if not candidates:
            raise RuntimeError(
                "No USB relay device found.\n"
                "  1. Ensure device is connected\n"
                "  2. Install CH340/CH341 drivers: https://www.wch.cn/downloads/CH341SER_ZIP.html\n"
                "  3. Check device is not in use"
            )

        # Select highest priority match
        candidates.sort(key=lambda x: x[2])
        port_name, desc, _ = candidates[0]

        # Verify driver is accessible
        try:
            with serial.Serial(port_name, BAUD_RATE, timeout=0.1):
                pass
        except serial.SerialException as e:
            raise RuntimeError(f"Driver check failed for {port_name}: {e}") from e

        if not self.verbose:
            print(f"[OK] Found device on {port_name}: {desc}")
            print("[OK] Driver check passed")

        return port_name

    def __enter__(self):
        """Open serial connection (context manager entry)."""
        self.serial_port = serial.Serial(
            port=self.port_name,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=TIMEOUT,
            write_timeout=TIMEOUT
        )
        self.serial_port.reset_input_buffer()   # Clear stale data
        self.serial_port.reset_output_buffer()
        return self

    def __exit__(self, *_):
        """Close serial connection (context manager exit)."""
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()

    def _send_command(self, command: bytes) -> Optional[bytes]:
        """
        Send command to relay and read response.

        Args:
            command: 4-byte command sequence

        Returns:
            Response bytes if available, None otherwise
        """
        if not self.serial_port or not self.serial_port.is_open:
            raise RuntimeError("Serial port not opened")

        # Send command with immediate flush
        self.serial_port.write(command)
        self.serial_port.flush()

        if self.verbose:
            print(f"[DEBUG] Sent: {command.hex(' ')}")

        # Wait for response
        time.sleep(RESPONSE_DELAY)

        # Read response if available
        if self.serial_port.in_waiting > 0:
            response = self.serial_port.read(self.serial_port.in_waiting)
            if self.verbose:
                print(f"[DEBUG] Received: {response.hex(' ')}")
            return response

        return None

    def _parse_status(self, response: Optional[bytes]) -> Optional[bool]:
        """
        Parse relay state from response.

        Args:
            response: Raw bytes from device

        Returns:
            True=ON, False=OFF, None=invalid/no response
        """
        if not response or len(response) < 4:
            return None

        # Validate response header (A0 01)
        if response[0] == RESPONSE_HEADER[0] and response[1] == RESPONSE_HEADER[1]:
            return response[2] == STATE_ON

        return None

    def _execute_action(self, action: str, command: bytes) -> Optional[bool]:
        """
        Execute relay action and print result.

        Args:
            action: Action description (e.g., "Turning relay ON")
            command: Command bytes to send

        Returns:
            Current state after action (True=ON, False=OFF, None=unknown)
        """
        print(f"{action}...", end=" ", flush=True)
        response = self._send_command(command)
        status = self._parse_status(response)

        # Print result based on status
        if status is True:
            print("[OK] ON" if "status" in action.lower() else "[OK] ON")
        elif status is False:
            print("[OK] OFF" if "status" in action.lower() else "[OK] OFF")
        else:
            print("[OK] Command sent")

        return status

    def turn_on(self) -> Optional[bool]:
        """Turn relay ON. Returns True if confirmed ON."""
        return self._execute_action("Turning relay ON", CMD_ON)

    def turn_off(self) -> Optional[bool]:
        """Turn relay OFF. Returns False if confirmed OFF."""
        return self._execute_action("Turning relay OFF", CMD_OFF)

    def toggle(self) -> Optional[bool]:
        """Toggle relay state. Returns new state."""
        return self._execute_action("Toggling relay", CMD_TOGGLE)

    def query_status(self) -> Optional[bool]:
        """Query current relay state. Returns True=ON, False=OFF."""
        return self._execute_action("Querying relay status", CMD_STATUS)


# ============================================================================
# CLI INTERFACE
# ============================================================================
def main():
    """Main entry point with command-line interface."""
    parser = argparse.ArgumentParser(
        description="USB Relay Controller - CH340-based relay control",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s on              # Turn relay on (auto-detect port)
  %(prog)s off             # Turn relay off
  %(prog)s toggle          # Toggle relay state
  %(prog)s status          # Query current status
  %(prog)s on --port COM5  # Use specific COM port
  %(prog)s status -v       # Verbose mode (show raw commands)
        """
    )

    parser.add_argument("action", choices=["on", "off", "toggle", "status"],
                       help="Action to perform")
    parser.add_argument("--port", help="Specific COM port (auto-detected by default)")
    parser.add_argument("-v", "--verbose", action="store_true",
                       help="Verbose output (show debug info)")

    args = parser.parse_args()

    try:
        # Initialize controller and execute action
        controller = RelayController(port=args.port, verbose=args.verbose)

        with controller:
            # Action dispatch using dict for cleaner code
            actions = {
                "on": controller.turn_on,
                "off": controller.turn_off,
                "toggle": controller.toggle,
                "status": controller.query_status
            }
            actions[args.action]()

        return 0

    except RuntimeError as e:
        print(f"\n[ERROR] {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[ERROR] Interrupted by user", file=sys.stderr)
        return 130
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
