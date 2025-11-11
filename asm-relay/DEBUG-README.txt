==========================================
DEBUG VERSION - Diagnostic Tool
==========================================

This is a heavily instrumented debug version that prints
EXTENSIVE diagnostic information at every step.

==========================================
HOW TO BUILD
==========================================

1. Double-click: build-debug.bat

   OR manually:

   nasm -f win64 relay_win_debug.asm -o relay_win_debug.obj
   golink /console /entry main relay_win_debug.obj kernel32.dll

2. This creates: relay_debug.exe

==========================================
HOW TO USE
==========================================

Run any command:

  relay_debug.exe status
  relay_debug.exe on
  relay_debug.exe off
  relay_debug.exe test
  relay_debug.exe bench

==========================================
WHAT YOU'LL SEE
==========================================

TONS of debug output like:

  [DEBUG] Program started
  [DEBUG] Got console handles
  [DEBUG] Got command line
  [DEBUG] Parsed command, code = 02
  [DEBUG] Trying to open COM ports...
  [DEBUG] Trying: COM1
  [DEBUG] CreateFileA returned: 0xFFFFFFFFFFFFFFFF
  [DEBUG] Trying: COM2
  [DEBUG] CreateFileA returned: 0xFFFFFFFFFFFFFFFF
  [DEBUG] Trying: COM3
  [DEBUG] CreateFileA returned: 0xFFFFFFFFFFFFFFFF
  [DEBUG] Trying: COM4
  [DEBUG] CreateFileA returned: 0xFFFFFFFFFFFFFFFF
  [DEBUG] Trying: COM5
  [DEBUG] CreateFileA returned: 0x00000000000000B4
  [DEBUG] Port opened successfully!
  [DEBUG] Configuring serial port...
  [DEBUG] Configured
  [DEBUG] Calling relay_status
  [DEBUG] Sending command...
  [DEBUG] Command sent, waiting for response...
  [DEBUG] Got response, bytes = 04
  Status: OFF (0x00)
  [DEBUG] Exiting...

==========================================
WHAT TO LOOK FOR
==========================================

1. Does "[DEBUG] Program started" appear?
   - NO: Program crashes immediately
   - YES: Continue...

2. Does it try to open COM ports?
   - NO: Issue before COM port code
   - YES: Continue...

3. What are the CreateFileA return values?
   - 0xFFFFFFFFFFFFFFFF: Failed to open (expected for wrong ports)
   - Other hex value: Success! That's the handle

4. Does it say "Port opened successfully!"?
   - NO: All COM1-5 failed. Your relay is on COM6+
   - YES: Continue...

5. Does it send commands?
   - Check for "[DEBUG] Sending command..."
   - Check for response byte count

==========================================
COMMON ISSUES WE'LL FIND
==========================================

Issue #1: No output at all
  -> Program crashes before reaching first print
  -> Likely entry point or linking issue

Issue #2: Output stops at specific point
  -> We'll see exactly where it crashes

Issue #3: All COM ports return 0xFFFFFFFFFFFFFFFF
  -> Your relay is on COM6 or higher
  -> Need to add more COM ports

Issue #4: CreateFileA succeeds but configuration fails
  -> DCB structure issue
  -> Will see which step fails

Issue #5: Commands send but no response
  -> Timing issue
  -> Protocol issue

==========================================
NEXT STEPS
==========================================

1. Run relay_debug.exe status
2. Copy ALL the output
3. Send it back
4. We'll analyze and fix the exact issue
5. Once fixed, we remove all debug code

==========================================

The debug version is ~50% larger but gives us
COMPLETE visibility into every operation!
