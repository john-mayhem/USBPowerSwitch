@echo off
REM ============================================================================
REM QUICK START - Download GoLink and Build
REM ============================================================================
REM This script will download GoLink (tiny linker) and build relay.exe
REM ============================================================================

echo ==========================================
echo USB Relay - Quick Start Setup
echo ==========================================
echo.
echo This will:
echo   1. Check for NASM
echo   2. Download GoLink linker (if needed)
echo   3. Build relay.exe
echo.
pause

REM Check NASM
where nasm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] NASM not installed!
    echo.
    echo Please install NASM first:
    echo   1. Go to: https://www.nasm.us/
    echo   2. Download and install
    echo   3. Run this script again
    echo.
    pause
    exit /b 1
)

echo [OK] NASM found
echo.

REM Check if GoLink exists
where golink >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] GoLink already installed
    goto :build
)

echo [INFO] GoLink not found. Checking local directory...
if exist "GoLink.exe" (
    echo [OK] Found GoLink.exe in current directory
    set PATH=%PATH%;%CD%
    goto :build
)

echo.
echo [INFO] GoLink needs to be downloaded manually.
echo.
echo Please do ONE of the following:
echo.
echo OPTION A - Download GoLink (EASIEST):
echo   1. Go to: http://www.godevtool.com/
echo   2. Download GoLink.zip
echo   3. Extract GoLink.exe to this folder: %CD%
echo   4. Run this script again
echo.
echo OPTION B - Use Visual Studio:
echo   1. Install Visual Studio Community (free)
echo   2. Run: build-windows.bat
echo.
pause
exit /b 1

:build
echo.
echo ==========================================
echo Building relay.exe...
echo ==========================================
echo.

call build-windows.bat
