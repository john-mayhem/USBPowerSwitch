# ============================================================================
# Makefile for USB Relay Controller (Assembly)
# ============================================================================
# Ultra-optimized build configuration for minimal binary size
# ============================================================================

# Assembler and linker
ASM = nasm
LD = ld
STRIP = strip

# Target binary
TARGET = relay

# Source files
SRC = relay.asm

# Object files
OBJ = relay.o

# Assembler flags
ASMFLAGS = -f elf64 -g -F dwarf

# Linker flags for minimal binary
LDFLAGS = -static -nostdlib
LDFLAGS_MINIMAL = -static -nostdlib -s --gc-sections --strip-all

# ============================================================================
# Build targets
# ============================================================================

.PHONY: all clean minimal debug install uninstall test size

# Default build
all: $(TARGET)
	@echo "Build complete!"
	@ls -lh $(TARGET)
	@echo "Binary size: $$(stat -c%s $(TARGET)) bytes"

# Standard build with debug symbols
$(TARGET): $(OBJ)
	@echo "Linking $(TARGET)..."
	$(LD) $(LDFLAGS) -o $(TARGET) $(OBJ)
	@echo "Stripping debug symbols..."
	$(STRIP) --strip-all $(TARGET)

# Compile assembly
$(OBJ): $(SRC)
	@echo "Assembling $(SRC)..."
	$(ASM) $(ASMFLAGS) $(SRC) -o $(OBJ)

# Minimal build - absolute smallest binary possible
minimal: $(SRC)
	@echo "Building minimal binary..."
	$(ASM) -f elf64 $(SRC) -o $(OBJ)
	$(LD) $(LDFLAGS_MINIMAL) -o $(TARGET) $(OBJ)
	@echo "Minimal build complete!"
	@ls -lh $(TARGET)
	@echo "Binary size: $$(stat -c%s $(TARGET)) bytes"

# Debug build (with symbols)
debug: $(SRC)
	@echo "Building debug binary..."
	$(ASM) -f elf64 -g -F dwarf $(SRC) -o $(OBJ)
	$(LD) -static -nostdlib -o $(TARGET) $(OBJ)
	@echo "Debug build complete (symbols included)"

# Install to /usr/local/bin
install: $(TARGET)
	@echo "Installing $(TARGET) to /usr/local/bin..."
	@sudo install -m 755 $(TARGET) /usr/local/bin/$(TARGET)
	@echo "Installation complete!"

# Uninstall
uninstall:
	@echo "Removing $(TARGET) from /usr/local/bin..."
	@sudo rm -f /usr/local/bin/$(TARGET)
	@echo "Uninstallation complete!"

# Test basic functionality
test: $(TARGET)
	@echo "Testing relay controller..."
	@echo "Running status check..."
	-./$(TARGET) status
	@echo ""
	@echo "If device is connected, try:"
	@echo "  ./$(TARGET) on"
	@echo "  ./$(TARGET) off"
	@echo "  ./$(TARGET) test"
	@echo "  ./$(TARGET) bench"

# Display size information
size: $(TARGET)
	@echo "=== Binary Size Analysis ==="
	@ls -lh $(TARGET)
	@echo ""
	@echo "Size breakdown:"
	@size $(TARGET)
	@echo ""
	@echo "Actual file size: $$(stat -c%s $(TARGET)) bytes"
	@echo ""
	@echo "For comparison:"
	@echo "  Typical C binary: ~14-20 KB"
	@echo "  This assembly:    ~2-3 KB"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(OBJ) $(TARGET)
	@echo "Clean complete!"

# Help
help:
	@echo "USB Relay Controller - Assembly Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make          - Build standard optimized binary"
	@echo "  make minimal  - Build absolutely minimal binary"
	@echo "  make debug    - Build with debug symbols"
	@echo "  make install  - Install to /usr/local/bin (requires sudo)"
	@echo "  make test     - Test the binary"
	@echo "  make size     - Show binary size information"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Usage after building:"
	@echo "  ./relay on     - Turn relay ON"
	@echo "  ./relay off    - Turn relay OFF"
	@echo "  ./relay status - Query relay state"
	@echo "  ./relay test   - Rapid switching test (10 cycles)"
	@echo "  ./relay bench  - Benchmark maximum speed"
