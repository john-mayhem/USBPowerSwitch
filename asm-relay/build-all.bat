@echo off
REM ============================================================================
REM Continuous Auto-Build Script for Windows
REM ============================================================================
REM Watches for file changes and rebuilds automatically
REM ============================================================================

setlocal enabledelayedexpansion

echo ========================================
echo USB Relay - Continuous Build Mode
echo ========================================
echo.
echo Watching relay.asm for changes...
echo Press Ctrl+C to stop
echo.

REM Initial build
call build.bat

REM Store initial timestamp
for %%F in (relay.asm) do set LAST_MODIFIED=%%~tF

:watch_loop
    REM Wait a bit
    timeout /t 2 /nobreak >nul

    REM Check if file was modified
    for %%F in (relay.asm) do set CURRENT_MODIFIED=%%~tF

    if not "!CURRENT_MODIFIED!" == "!LAST_MODIFIED!" (
        echo.
        echo ========================================
        echo [%time%] Change detected! Rebuilding...
        echo ========================================
        echo.

        call build.bat

        set LAST_MODIFIED=!CURRENT_MODIFIED!

        echo.
        echo Watching for changes...
        echo.
    )

    goto watch_loop
