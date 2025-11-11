#!/bin/bash
# ============================================================================
# USB Relay Controller - Auto-Compilation Watch Script
# ============================================================================
# Automatically rebuilds when relay.asm is modified
#
# Usage:
#   ./watch-build.sh          # Watch and auto-compile
#   ./watch-build.sh --once   # Build once and exit
#
# Requirements:
#   - inotify-tools (for inotifywait)
#   - nasm
#   - ld
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running in "build once" mode
BUILD_ONCE=false
if [[ "$1" == "--once" ]]; then
    BUILD_ONCE=true
fi

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v nasm &> /dev/null; then
        missing_deps+=("nasm")
    fi

    if ! command -v ld &> /dev/null; then
        missing_deps+=("binutils")
    fi

    if [[ "$BUILD_ONCE" == false ]] && ! command -v inotifywait &> /dev/null; then
        missing_deps+=("inotify-tools")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "  Fedora:        sudo dnf install ${missing_deps[*]}"
        echo "  Arch:          sudo pacman -S ${missing_deps[*]}"
        echo ""
        exit 1
    fi
}

# Function to build the project
build_project() {
    local start_time=$(date +%s%N)

    print_status "Building relay controller..."
    echo ""

    # Clean old build artifacts
    rm -f relay.o relay 2>/dev/null || true

    # Step 1: Assemble
    print_status "[1/3] Assembling relay.asm..."
    if nasm -f elf64 -g -F dwarf relay.asm -o relay.o 2>&1; then
        print_success "Assembly complete"
    else
        print_error "Assembly failed"
        return 1
    fi

    # Step 2: Link
    print_status "[2/3] Linking..."
    if ld -static -nostdlib -o relay relay.o 2>&1; then
        print_success "Linking complete"
    else
        print_error "Linking failed"
        return 1
    fi

    # Step 3: Strip
    print_status "[3/3] Stripping symbols..."
    if strip --strip-all relay 2>&1; then
        print_success "Strip complete"
    else
        print_error "Strip failed"
        return 1
    fi

    # Calculate build time
    local end_time=$(date +%s%N)
    local elapsed=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

    echo ""
    echo "=========================================="
    print_success "BUILD SUCCESSFUL!"
    echo "=========================================="
    ls -lh relay
    echo ""
    echo "Binary size: $(stat -c%s relay) bytes"
    echo "Build time:  ${elapsed}ms"
    echo ""
    echo "Run with: ./relay [on|off|status|test|bench]"
    echo ""

    return 0
}

# Function to watch for changes
watch_and_build() {
    print_status "Starting auto-compilation watch mode"
    print_status "Watching: relay.asm"
    echo ""
    print_warning "Press Ctrl+C to stop"
    echo ""

    # Initial build
    build_project

    # Watch for changes
    while true; do
        # Wait for file modification
        inotifywait -q -e modify,create,delete relay.asm 2>/dev/null

        echo ""
        print_warning "File changed detected!"
        sleep 0.5  # Debounce rapid changes

        build_project

        echo ""
        print_status "Waiting for changes..."
        echo ""
    done
}

# Main script
main() {
    # Change to script directory
    cd "$(dirname "$0")"

    # Check if relay.asm exists
    if [[ ! -f "relay.asm" ]]; then
        print_error "relay.asm not found in current directory"
        exit 1
    fi

    # Check dependencies
    check_dependencies

    # Build or watch
    if [[ "$BUILD_ONCE" == true ]]; then
        build_project
    else
        watch_and_build
    fi
}

# Run main function
main "$@"
