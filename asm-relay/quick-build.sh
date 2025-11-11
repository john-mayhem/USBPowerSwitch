#!/bin/bash
# ============================================================================
# Quick Build Script - Minimal output, fast compilation
# ============================================================================

# Build silently
nasm -f elf64 relay.asm -o relay.o 2>&1 | grep -i error || true
ld -static -nostdlib -o relay relay.o 2>&1 | grep -i error || true
strip --strip-all relay 2>/dev/null

# Check if successful
if [[ -f relay ]]; then
    echo "✓ Built successfully ($(stat -c%s relay) bytes)"
else
    echo "✗ Build failed"
    exit 1
fi
