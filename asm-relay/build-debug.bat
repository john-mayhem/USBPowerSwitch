@echo off
REM ============================================================================
REM Build DEBUG version with extensive logging
REM ============================================================================

echo ==========================================
echo Building DEBUG version...
echo ==========================================
echo.

REM Check NASM
where nasm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] NASM not found!
    pause
    exit /b 1
)

echo [1/2] Assembling relay_win_debug.asm...
nasm -f win64 relay_win_debug.asm -o relay_win_debug.obj
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Assembly failed!
    pause
    exit /b 1
)
echo [OK] Assembly complete
echo.

echo [2/2] Linking...

REM Try GoLink
where golink >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using GoLink...
    golink /console /entry main relay_win_debug.obj kernel32.dll
    if %ERRORLEVEL% EQU 0 (
        ren relay_win_debug.exe relay_debug.exe 2>nul
        goto :success
    )
)

REM Try Visual Studio link
where link >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using Microsoft Linker...
    link /SUBSYSTEM:CONSOLE /ENTRY:main /OUT:relay_debug.exe relay_win_debug.obj kernel32.lib
    if %ERRORLEVEL% EQU 0 goto :success
)

echo [ERROR] No linker found!
echo Please install GoLink or Visual Studio
pause
exit /b 1

:success
echo [OK] Linking complete!
echo.
echo ==========================================
echo BUILD SUCCESSFUL - DEBUG VERSION
echo ==========================================
dir relay_debug.exe
echo.
echo This version has EXTENSIVE debug output.
echo.
echo Run with:
echo   relay_debug.exe status
echo   relay_debug.exe on
echo   relay_debug.exe off
echo.
echo You will see [DEBUG] messages at every step!
echo.
pause
