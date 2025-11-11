@echo off
REM ============================================================================
REM USB Relay Controller - Windows Build Script
REM ============================================================================
REM Auto-compilation batch file for Windows
REM
REM Requirements:
REM   - NASM installed and in PATH (download from https://www.nasm.us/)
REM   - WSL (Windows Subsystem for Linux) for running the binary
REM   OR
REM   - This script can build on Windows, but binary runs on Linux only
REM ============================================================================

echo ========================================
echo USB Relay Controller - Auto Build
echo ========================================
echo.

REM Check if NASM is installed
where nasm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] NASM not found in PATH
    echo.
    echo Please install NASM:
    echo   1. Download from https://www.nasm.us/
    echo   2. Install to C:\Program Files\NASM
    echo   3. Add to PATH: C:\Program Files\NASM
    echo.
    echo Or use WSL ^(Windows Subsystem for Linux^):
    echo   wsl sudo apt-get install nasm
    echo.
    pause
    exit /b 1
)

echo [OK] NASM found
nasm -v
echo.

REM Check if we're in the correct directory
if not exist "relay.asm" (
    echo [ERROR] relay.asm not found
    echo Please run this script from the asm-relay directory
    echo.
    pause
    exit /b 1
)

echo [INFO] Building relay controller...
echo.

REM Assemble the code
echo [1/3] Assembling relay.asm...
nasm -f elf64 -g -F dwarf relay.asm -o relay.o
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Assembly failed
    pause
    exit /b 1
)
echo [OK] Assembly complete

REM Check if we're on WSL or native Windows
where wsl >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [2/3] Linking with WSL ld...
    wsl ld -static -nostdlib -o relay relay.o
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Linking failed
        pause
        exit /b 1
    )

    echo [OK] Linking complete
    echo.
    echo [3/3] Stripping symbols...
    wsl strip --strip-all relay
    echo [OK] Strip complete
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    wsl ls -lh relay
    echo.
    echo Binary size:
    wsl stat -c%%s relay
    echo bytes
    echo.
    echo To run: wsl ./relay [on^|off^|status^|test^|bench]
    echo.
) else (
    echo.
    echo [WARNING] WSL not detected
    echo.
    echo This binary requires Linux to link and run.
    echo.
    echo Options:
    echo   1. Install WSL: wsl --install
    echo   2. Use a Linux VM
    echo   3. Cross-compile with mingw ^(not recommended^)
    echo.
    echo Object file created: relay.o
    echo Transfer relay.o to a Linux system and run:
    echo   ld -static -nostdlib -o relay relay.o
    echo   strip --strip-all relay
    echo.
)

pause
