# Building the Assembly Relay Controller

## Quick Start

This project uses **NASM** (Netwide Assembler) for the clearest, most readable assembly syntax.

### Install NASM

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install nasm

# Fedora/RHEL
sudo dnf install nasm

# Arch Linux
sudo pacman -S nasm

# macOS
brew install nasm

# Verify installation
nasm -v
```

### Build

```bash
# Standard build
make

# Minimal binary (smallest size)
make minimal

# Display help
make help
```

## Build Requirements

- **NASM**: Version 2.0 or higher
- **ld**: GNU linker (usually pre-installed)
- **Linux**: x86-64 kernel 3.0+
- **GNU Make**: For build automation

## Expected Binary Size

After successful build:
```
-rwxrwxr-x 1 user user 2.1K relay
```

Approximately **2-3 KB** - one of the smallest USB relay controllers possible!

## Verification

```bash
# Check binary was created
ls -lh relay

# Verify it's executable
file relay

# Test (requires relay hardware)
./relay status
```

## Alternative: Using GAS (GNU Assembler)

If you cannot install NASM, the project can be converted to GAS/AT&T syntax:

```bash
# Coming soon: relay_gas.s
# Build with: as relay_gas.s -o relay.o && ld relay.o -o relay
```

## Troubleshooting

### NASM not found

```
Error: nasm: No such file or directory
```

**Solution**: Install NASM (see above)

### Permission denied

```
Error: Permission denied when opening /dev/ttyUSB0
```

**Solution**:
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Or temporarily
sudo chmod 666 /dev/ttyUSB0
```

### Linker errors

If you see linker errors about missing libraries, ensure you're building statically:

```bash
make clean
make minimal
```

The `minimal` target uses the most aggressive static linking flags.

## Cross-Platform Notes

Currently supports:
- ✓ Linux x86-64

Future support planned:
- ⏳ Linux ARM64 (Raspberry Pi)
- ⏳ FreeBSD x86-64

Windows and macOS use different syscall conventions and would require separate implementations.

## Size Optimization Tips

The Makefile already includes aggressive optimizations:

1. **Static linking**: No shared library dependencies
2. **Strip symbols**: Remove all debug info
3. **Section garbage collection**: `--gc-sections`
4. **No standard library**: Direct syscalls only

Current size: ~2KB
Theoretical minimum: ~1.5KB (with further data section optimization)

Compare to:
- C implementation: ~14KB
- Rust implementation: ~4MB
- Python: N/A (interpreter required)
