# Auto-Compilation Build Scripts

This directory contains multiple build scripts for different platforms and use cases.

## Quick Reference

| Script | Platform | Purpose |
|--------|----------|---------|
| `build.bat` | Windows | Single build with WSL support |
| `build-all.bat` | Windows | Continuous auto-rebuild (watches files) |
| `watch-build.sh` | Linux/macOS | Auto-rebuild on file changes |
| `quick-build.sh` | Linux/macOS | Fast silent build |
| `Makefile` | Linux/macOS | Full-featured build system |

---

## Windows Scripts

### build.bat - Single Build

**Purpose**: Build the relay controller once

**Usage**:
```batch
build.bat
```

**Features**:
- Checks for NASM installation
- Detects WSL (Windows Subsystem for Linux)
- Assembles relay.asm to relay.o
- Links using WSL's ld (if available)
- Shows binary size

**Requirements**:
- NASM for Windows: https://www.nasm.us/
- WSL (for linking): `wsl --install`

**Output**:
```
========================================
USB Relay Controller - Auto Build
========================================

[OK] NASM found
NASM version 2.15.05

[1/3] Assembling relay.asm...
[OK] Assembly complete

[2/3] Linking with WSL ld...
[OK] Linking complete

[3/3] Stripping symbols...
[OK] Strip complete

========================================
BUILD SUCCESSFUL!
========================================
-rwxrwxr-x 1 user user 2.1K relay

Binary size: 2144 bytes

To run: wsl ./relay [on|off|status|test|bench]
```

### build-all.bat - Continuous Build

**Purpose**: Watch relay.asm and rebuild automatically when it changes

**Usage**:
```batch
build-all.bat
```

**Features**:
- Monitors relay.asm for modifications
- Automatically rebuilds when changes detected
- Shows timestamp of each rebuild
- Runs until Ctrl+C pressed

**Use Case**: Keep this running while editing relay.asm for instant feedback

**Output**:
```
========================================
USB Relay - Continuous Build Mode
========================================

Watching relay.asm for changes...
Press Ctrl+C to stop

[builds immediately]

========================================
[14:32:15] Change detected! Rebuilding...
========================================
[rebuilds...]

Watching for changes...
```

---

## Linux/macOS Scripts

### watch-build.sh - Auto-Compilation

**Purpose**: Professional auto-build system with file watching

**Usage**:
```bash
# Watch mode (continuous)
./watch-build.sh

# Build once and exit
./watch-build.sh --once
```

**Features**:
- Uses `inotifywait` for efficient file watching
- Colored output (✓ green, ✗ red, ! yellow)
- Shows build time in milliseconds
- Displays binary size
- Automatic dependency checking

**Requirements**:
```bash
# Install inotify-tools
sudo apt-get install inotify-tools  # Ubuntu/Debian
sudo dnf install inotify-tools      # Fedora
sudo pacman -S inotify-tools        # Arch
```

**Output**:
```
[14:32:15] Starting auto-compilation watch mode
[14:32:15] Watching: relay.asm

[!] Press Ctrl+C to stop

[14:32:15] Building relay controller...

[14:32:15] [1/3] Assembling relay.asm...
[✓] Assembly complete
[14:32:15] [2/3] Linking...
[✓] Linking complete
[14:32:15] [3/3] Stripping symbols...
[✓] Strip complete

==========================================
[✓] BUILD SUCCESSFUL!
==========================================
-rwxrwxr-x 1 user user 2.1K relay

Binary size: 2144 bytes
Build time:  156ms

Run with: ./relay [on|off|status|test|bench]

[14:32:15] Waiting for changes...

[!] File changed detected!

[rebuilds automatically...]
```

### quick-build.sh - Fast Silent Build

**Purpose**: Minimal output, fastest possible build

**Usage**:
```bash
./quick-build.sh
```

**Features**:
- No unnecessary output
- Only shows errors or success
- Perfect for scripts/automation

**Output**:
```
✓ Built successfully (2144 bytes)
```

Or on error:
```
✗ Build failed
relay.asm:125: error: invalid instruction
```

---

## Makefile - Full Build System

**Purpose**: Professional build system with multiple targets

**Usage**:
```bash
make              # Standard build
make minimal      # Smallest possible binary
make debug        # Build with debug symbols
make clean        # Remove build artifacts
make test         # Test the binary
make size         # Show size analysis
make install      # Install to /usr/local/bin
make help         # Show all options
```

**Features**:
- Multiple build configurations
- Dependency tracking
- Size optimization modes
- Installation support

See `Makefile` for full documentation.

---

## Comparison

### Build Speed

| Method | Time | Use Case |
|--------|------|----------|
| `quick-build.sh` | ~150ms | Fastest, automation |
| `watch-build.sh --once` | ~200ms | Development, verbose output |
| `make` | ~250ms | Standard builds |
| `build.bat` (WSL) | ~500ms | Windows with WSL |

### Feature Comparison

| Feature | build.bat | build-all.bat | watch-build.sh | quick-build.sh | Makefile |
|---------|-----------|---------------|----------------|----------------|----------|
| Windows support | ✓ | ✓ | ✗ | ✗ | ✗ |
| Linux support | via WSL | via WSL | ✓ | ✓ | ✓ |
| Auto-rebuild | ✗ | ✓ | ✓ | ✗ | ✗ |
| Colored output | ✗ | ✗ | ✓ | minimal | minimal |
| Build time | ✗ | ✗ | ✓ | ✗ | ✗ |
| Dependency check | basic | basic | ✓ | ✗ | ✓ |
| Multiple targets | ✗ | ✗ | ✗ | ✗ | ✓ |

---

## Recommended Workflows

### For Windows Users

**One-time build**:
```batch
build.bat
```

**Active development** (auto-rebuild):
```batch
build-all.bat
```

**After installation**, just run:
```batch
wsl ./relay on
```

### For Linux Users

**Development** (auto-rebuild):
```bash
./watch-build.sh
```

**Quick test**:
```bash
./quick-build.sh && ./relay test
```

**Production build**:
```bash
make minimal
sudo make install
relay on
```

### For CI/CD Pipelines

```bash
# Fast, silent, exit code on failure
./quick-build.sh || exit 1

# Or with make
make minimal
```

---

## Installation Steps

### Windows Setup

1. **Install NASM**:
   - Download: https://www.nasm.us/pub/nasm/releasebuilds/
   - Install to: `C:\Program Files\NASM`
   - Add to PATH

2. **Install WSL**:
   ```powershell
   wsl --install
   ```

3. **Build**:
   ```batch
   cd asm-relay
   build.bat
   ```

### Linux Setup

1. **Install dependencies**:
   ```bash
   sudo apt-get install nasm inotify-tools
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Start watching**:
   ```bash
   ./watch-build.sh
   ```

---

## Troubleshooting

### Windows: "NASM not found"

**Solution**:
```batch
REM Add NASM to PATH
set PATH=%PATH%;C:\Program Files\NASM
```

Or reinstall and check "Add to PATH" during installation.

### Windows: "WSL not detected"

**Solution**:
```powershell
wsl --install
wsl --update
```

Then restart and try again.

### Linux: "inotifywait: command not found"

**Solution**:
```bash
sudo apt-get install inotify-tools
```

### Build Hangs

**Possible causes**:
- File permissions issue
- Disk full
- Antivirus blocking

**Solution**:
```bash
# Check permissions
ls -l relay.asm

# Check disk space
df -h .

# Try clean build
make clean
make
```

### "Permission denied" when running

**Solution**:
```bash
chmod +x relay
```

---

## Advanced Usage

### Custom Build Options

Edit the scripts to customize:

**build.bat** - Change NASM flags:
```batch
nasm -f elf64 -O3 relay.asm -o relay.o
```

**watch-build.sh** - Adjust debounce time:
```bash
sleep 0.5  # Change to 1.0 for slower filesystems
```

**Makefile** - Add custom targets:
```makefile
myrelease: minimal
	upx --best relay  # Compress with UPX
```

### Integration with IDEs

**VS Code** - Add to `.vscode/tasks.json`:
```json
{
    "label": "Build Relay",
    "type": "shell",
    "command": "./quick-build.sh",
    "problemMatcher": [],
    "group": {
        "kind": "build",
        "isDefault": true
    }
}
```

**Vim** - Add to `.vimrc`:
```vim
nnoremap <F5> :!./quick-build.sh<CR>
```

---

## Performance Tips

1. **Use quick-build.sh** for fastest rebuilds
2. **Keep watch-build.sh running** during active development
3. **Use make minimal** for production releases
4. **Disable antivirus** temporarily for faster builds on Windows

---

## Script Maintenance

All scripts are designed to be:
- ✓ Self-contained (no external config files)
- ✓ Fail-fast (exit on errors)
- ✓ Informative (helpful error messages)
- ✓ Portable (work across different systems)

Feel free to modify them for your specific needs!
