@echo off
REM ============================================================================
REM USB Relay Controller - Windows Native Build Script
REM ============================================================================
REM Compiles relay_win.asm to relay.exe (pure Windows, no WSL!)
REM
REM Requirements:
REM   - NASM (https://www.nasm.us/)
REM   - GoLink (http://www.godevtool.com/) OR Visual Studio
REM
REM ============================================================================

echo ==========================================
echo USB Relay - Windows Native Build
echo ==========================================
echo.

REM Check if NASM is installed
where nasm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] NASM not found!
    echo.
    echo Download and install NASM:
    echo   1. Go to https://www.nasm.us/
    echo   2. Download Windows x64 installer
    echo   3. Install and add to PATH
    echo.
    pause
    exit /b 1
)

echo [OK] NASM found
nasm -v
echo.

REM Check if relay_win.asm exists
if not exist "relay_win.asm" (
    echo [ERROR] relay_win.asm not found!
    echo Please run this from the asm-relay directory
    pause
    exit /b 1
)

echo [INFO] Building Windows native relay controller...
echo.

REM ============================================================================
REM Step 1: Assemble to object file
REM ============================================================================
echo [1/2] Assembling relay_win.asm...
nasm -f win64 relay_win.asm -o relay_win.obj
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Assembly failed!
    pause
    exit /b 1
)
echo [OK] Assembly complete - relay_win.obj created
echo.

REM ============================================================================
REM Step 2: Link (try multiple linkers)
REM ============================================================================
echo [2/2] Linking...

REM Try GoLink first (simplest)
where golink >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Using GoLink...
    golink /console /entry main relay_win.obj kernel32.dll
    if %ERRORLEVEL% EQU 0 (
        ren relay_win.exe relay.exe 2>nul
        goto :build_success
    )
)

REM Try Visual Studio's link.exe
where link >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Using Microsoft Linker...
    link /SUBSYSTEM:CONSOLE /ENTRY:main /OUT:relay.exe relay_win.obj kernel32.lib
    if %ERRORLEVEL% EQU 0 goto :build_success
)

REM Try to find link.exe in common Visual Studio locations
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC" (
    echo [INFO] Found Visual Studio 2022, setting up environment...
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
    link /SUBSYSTEM:CONSOLE /ENTRY:main /OUT:relay.exe relay_win.obj kernel32.lib
    if %ERRORLEVEL% EQU 0 goto :build_success
)

if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC" (
    echo [INFO] Found Visual Studio 2019, setting up environment...
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
    link /SUBSYSTEM:CONSOLE /ENTRY:main /OUT:relay.exe relay_win.obj kernel32.lib
    if %ERRORLEVEL% EQU 0 goto :build_success
)

REM No linker found
echo.
echo [ERROR] No suitable linker found!
echo.
echo You need one of the following:
echo.
echo Option 1 - GoLink (EASIEST - Recommended):
echo   1. Download from: http://www.godevtool.com/
echo   2. Extract GoLink.exe to C:\Windows or add to PATH
echo   3. Run this script again
echo.
echo Option 2 - Visual Studio (FREE):
echo   1. Download Visual Studio Community (free)
echo   2. Install "Desktop development with C++" workload
echo   3. Run this script again
echo.
echo Option 3 - Manual linking with GoLink:
echo   Download GoLink, then run:
echo   golink /console /entry main relay_win.obj kernel32.dll
echo.
pause
exit /b 1

:build_success
echo [OK] Linking complete!
echo.
echo ==========================================
echo BUILD SUCCESSFUL!
echo ==========================================
dir relay.exe
echo.
echo Binary created: relay.exe
echo.
echo Usage:
echo   relay.exe on        - Turn relay ON
echo   relay.exe off       - Turn relay OFF
echo   relay.exe status    - Query status
echo   relay.exe test      - Rapid test (10 cycles)
echo   relay.exe bench     - Benchmark speed
echo.
echo Example:
echo   relay.exe bench
echo.
pause
