; ============================================================================
; USB Relay Controller - DEBUG VERSION with MASSIVE logging
; ============================================================================
; This version has extensive debug output to diagnose issues
; ============================================================================

    bits 64
    default rel

section .data
    ; COM port names
    com1: db "COM1", 0
    com2: db "COM2", 0
    com3: db "COM3", 0
    com4: db "COM4", 0
    com5: db "COM5", 0

    ; Relay commands
    cmd_on:     db 0xA0, 0x01, 0x03, 0xA4
    cmd_off:    db 0xA0, 0x01, 0x00, 0xA1
    cmd_status: db 0xA0, 0x01, 0x05, 0xA6

    ; Debug messages
    dbg_start: db "[DEBUG] Program started", 13, 10, 0
    dbg_got_handles: db "[DEBUG] Got console handles", 13, 10, 0
    dbg_got_cmdline: db "[DEBUG] Got command line", 13, 10, 0
    dbg_parsed_cmd: db "[DEBUG] Parsed command, code = ", 0
    dbg_trying_com: db "[DEBUG] Trying to open COM ports...", 13, 10, 0
    dbg_trying_port: db "[DEBUG] Trying: ", 0
    dbg_createfile_result: db "[DEBUG] CreateFileA returned: 0x", 0
    dbg_port_opened: db "[DEBUG] Port opened successfully!", 13, 10, 0
    dbg_configuring: db "[DEBUG] Configuring serial port...", 13, 10, 0
    dbg_configured: db "[DEBUG] Port configured", 13, 10, 0
    dbg_sending_cmd: db "[DEBUG] Sending command...", 13, 10, 0
    dbg_sent: db "[DEBUG] Command sent, waiting for response...", 13, 10, 0
    dbg_response: db "[DEBUG] Got response, bytes = ", 0
    dbg_relay_on: db "[DEBUG] Calling relay_on", 13, 10, 0
    dbg_relay_off: db "[DEBUG] Calling relay_off", 13, 10, 0
    dbg_relay_status: db "[DEBUG] Calling relay_status", 13, 10, 0
    dbg_relay_test: db "[DEBUG] Calling relay_test", 13, 10, 0
    dbg_relay_bench: db "[DEBUG] Calling relay_bench", 13, 10, 0
    dbg_exiting: db "[DEBUG] Exiting...", 13, 10, 0

    ; User messages
    msg_usage: db "USB Relay Controller - Windows Assembly Edition [DEBUG]", 13, 10
               db "Usage: relay.exe [on|off|status|test|bench]", 13, 10, 0

    msg_on:     db "Relay: ON", 13, 10, 0
    msg_off:    db "Relay: OFF", 13, 10, 0
    msg_testing: db "Testing rapid switching...", 13, 10, 0
    msg_bench_start: db "Benchmarking relay speed...", 13, 10, 0
    msg_no_device: db "Error: No relay device found on COM1-COM5", 13, 10, 0
    msg_status_on: db "Status: ON (0x01)", 13, 10, 0
    msg_status_off: db "Status: OFF (0x00)", 13, 10, 0
    msg_status_unknown: db "Status: UNKNOWN", 13, 10, 0

    ; Windows API constants
    GENERIC_READ equ 0x80000000
    GENERIC_WRITE equ 0x40000000
    OPEN_EXISTING equ 3
    INVALID_HANDLE_VALUE equ -1
    STD_OUTPUT_HANDLE equ -11

section .bss
    hCom:       resq 1
    hStdOut:    resq 1
    response:   resb 64
    bytes_written: resq 1
    bytes_read: resq 1
    num_buffer: resb 32
    dcb:        resb 128
    timeouts:   resb 20

section .text
    global main
    extern GetStdHandle
    extern WriteConsoleA
    extern ExitProcess
    extern CreateFileA
    extern CloseHandle
    extern WriteFile
    extern ReadFile
    extern GetCommState
    extern SetCommState
    extern SetCommTimeouts
    extern Sleep
    extern GetCommandLineA
    extern lstrlenA

main:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; DEBUG: Program started
    lea rcx, [dbg_start]
    call print_debug

    ; Get stdout
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [hStdOut], rax

    ; DEBUG: Got handles
    lea rcx, [dbg_got_handles]
    call print_debug

    ; Get command line
    call GetCommandLineA
    mov rbx, rax

    ; DEBUG: Got command line
    lea rcx, [dbg_got_cmdline]
    call print_debug

    ; Parse command line
    call skip_program_name
    mov rdi, rax

    ; Check if we have an argument
    test rdi, rdi
    jz .show_usage
    cmp byte [rdi], 0
    je .show_usage

    ; Parse command
    call parse_command
    cmp rax, -1
    je .show_usage

    ; DEBUG: Show parsed command code
    push rax
    lea rcx, [dbg_parsed_cmd]
    call print_debug
    pop rax
    push rax
    call print_hex_byte
    lea rcx, [newline]
    call print_debug
    pop rax

    mov r12, rax

    ; DEBUG: Trying to open COM port
    lea rcx, [dbg_trying_com]
    call print_debug

    ; Try to open COM port
    call open_com_port
    cmp rax, INVALID_HANDLE_VALUE
    je .error_no_device

    ; DEBUG: Success
    lea rcx, [dbg_port_opened]
    call print_debug

    ; Execute command
    cmp r12, 0
    je .cmd_off
    cmp r12, 1
    je .cmd_on
    cmp r12, 2
    je .cmd_status
    cmp r12, 3
    je .cmd_test
    cmp r12, 4
    je .cmd_bench
    jmp .exit_success

.show_usage:
    lea rcx, [msg_usage]
    call print_string
    jmp .exit_success

.cmd_on:
    lea rcx, [dbg_relay_on]
    call print_debug
    call relay_on
    jmp .exit_success

.cmd_off:
    lea rcx, [dbg_relay_off]
    call print_debug
    call relay_off
    jmp .exit_success

.cmd_status:
    lea rcx, [dbg_relay_status]
    call print_debug
    call relay_status
    jmp .exit_success

.cmd_test:
    lea rcx, [dbg_relay_test]
    call print_debug
    call relay_test
    jmp .exit_success

.cmd_bench:
    lea rcx, [dbg_relay_bench]
    call print_debug
    call relay_benchmark
    jmp .exit_success

.error_no_device:
    lea rcx, [msg_no_device]
    call print_string
    jmp .exit_error

.exit_success:
    lea rcx, [dbg_exiting]
    call print_debug
    call close_com_port
    xor rcx, rcx
    call ExitProcess

.exit_error:
    lea rcx, [dbg_exiting]
    call print_debug
    call close_com_port
    mov rcx, 1
    call ExitProcess

; ============================================================================
; skip_program_name
; ============================================================================
skip_program_name:
    mov rsi, rbx
.skip_space1:
    lodsb
    cmp al, ' '
    je .skip_space1
    cmp al, 9
    je .skip_space1
    dec rsi

    cmp byte [rsi], '"'
    je .quoted

.unquoted:
    lodsb
    test al, al
    jz .done
    cmp al, ' '
    je .find_arg
    jmp .unquoted

.quoted:
    inc rsi
.skip_quoted:
    lodsb
    test al, al
    jz .done
    cmp al, '"'
    jne .skip_quoted

.find_arg:
.skip_space2:
    lodsb
    cmp al, ' '
    je .skip_space2
    cmp al, 9
    je .skip_space2
    dec rsi

.done:
    mov rax, rsi
    ret

; ============================================================================
; parse_command
; ============================================================================
parse_command:
    mov al, [rdi]
    or al, 0x20
    cmp al, 'o'
    jne .check_status
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'n'
    jne .check_off
    mov rax, 1
    ret

.check_off:
    mov al, [rdi]
    or al, 0x20
    cmp al, 'o'
    jne .check_status
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'f'
    jne .check_status
    mov rax, 0
    ret

.check_status:
    mov al, [rdi]
    or al, 0x20
    cmp al, 's'
    jne .check_test
    mov rax, 2
    ret

.check_test:
    mov al, [rdi]
    or al, 0x20
    cmp al, 't'
    jne .check_bench
    mov rax, 3
    ret

.check_bench:
    mov al, [rdi]
    or al, 0x20
    cmp al, 'b'
    jne .invalid
    mov rax, 4
    ret

.invalid:
    mov rax, -1
    ret

; ============================================================================
; open_com_port
; ============================================================================
open_com_port:
    push rbx
    push r12
    push r13

    lea r12, [com1]
    mov rbx, 5

.try_next:
    ; DEBUG: Show which port we're trying
    lea rcx, [dbg_trying_port]
    call print_debug
    mov rcx, r12
    call print_string
    lea rcx, [newline]
    call print_debug

    ; CreateFileA with proper calling convention
    sub rsp, 64

    mov dword [rsp + 32], OPEN_EXISTING
    mov qword [rsp + 40], 0
    mov qword [rsp + 48], 0

    mov rcx, r12
    mov edx, GENERIC_READ
    or edx, GENERIC_WRITE
    xor r8d, r8d
    xor r9, r9

    call CreateFileA
    add rsp, 64

    ; DEBUG: Show result
    push rax
    lea rcx, [dbg_createfile_result]
    call print_debug
    pop rax
    push rax
    call print_hex_qword
    lea rcx, [newline]
    call print_debug
    pop rax

    cmp rax, INVALID_HANDLE_VALUE
    jne .opened

    add r12, 5
    dec rbx
    jnz .try_next

    mov rax, INVALID_HANDLE_VALUE
    jmp .done

.opened:
    mov [hCom], rax

    lea rcx, [dbg_configuring]
    call print_debug

    call configure_com_port

    lea rcx, [dbg_configured]
    call print_debug

    mov rax, [hCom]

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; configure_com_port - FIXED with correct DCB offsets
; ============================================================================
configure_com_port:
    sub rsp, 40

    ; Get current DCB settings
    mov rcx, [hCom]
    lea rdx, [dcb]
    mov dword [rdx], 28          ; DCBlength = 28 (actual size of DCB structure is 28 bytes minimum)
    call GetCommState

    ; DCB structure (correct offsets):
    ; +0  = DCBlength (DWORD)
    ; +4  = BaudRate (DWORD)
    ; +8  = flags (DWORD) - contains fBinary and other bitfields
    ; +12 = wReserved (WORD)
    ; +14 = XonLim (WORD)
    ; +16 = XoffLim (WORD)
    ; +18 = ByteSize (BYTE)
    ; +19 = Parity (BYTE)
    ; +20 = StopBits (BYTE)
    ; +21 = XonChar (char)
    ; +22 = XoffChar (char)
    ; +23 = ErrorChar (char)
    ; +24 = EofChar (char)
    ; +25 = EvtChar (char)
    ; +26 = wReserved1 (WORD)

    lea rax, [dcb]

    ; Set baud rate to 9600
    mov dword [rax + 4], 9600

    ; Set flags: PRESERVE existing flags, only set fBinary bit
    mov edx, [rax + 8]           ; Read existing flags
    or edx, 1                    ; Set bit 0 (fBinary) = TRUE
    mov dword [rax + 8], edx     ; Write back with fBinary set

    ; Set ByteSize = 8, Parity = 0 (None), StopBits = 0 (1 stop bit)
    mov byte [rax + 18], 8       ; ByteSize = 8 bits
    mov byte [rax + 19], 0       ; Parity = NOPARITY
    mov byte [rax + 20], 0       ; StopBits = ONESTOPBIT

    ; Apply settings
    mov rcx, [hCom]
    lea rdx, [dcb]
    call SetCommState

    ; Set timeouts (generous for debugging)
    lea rax, [timeouts]
    mov dword [rax], 1000        ; ReadIntervalTimeout = 1000ms
    mov dword [rax + 4], 0       ; ReadTotalTimeoutMultiplier = 0
    mov dword [rax + 8], 2000    ; ReadTotalTimeoutConstant = 2000ms (2 seconds!)
    mov dword [rax + 12], 0      ; WriteTotalTimeoutMultiplier = 0
    mov dword [rax + 16], 1000   ; WriteTotalTimeoutConstant = 1000ms

    mov rcx, [hCom]
    lea rdx, [timeouts]
    call SetCommTimeouts

    add rsp, 40
    ret

; ============================================================================
; close_com_port
; ============================================================================
close_com_port:
    sub rsp, 32
    mov rcx, [hCom]
    cmp rcx, 0
    je .done
    call CloseHandle
.done:
    add rsp, 32
    ret

; ============================================================================
; send_command
; ============================================================================
send_command:
    push rbx
    push r12
    sub rsp, 40

    mov r12, rcx

    lea rcx, [dbg_sending_cmd]
    call print_debug

    mov rcx, [hCom]
    mov rdx, r12
    mov r8d, 4
    lea r9, [bytes_written]
    xor eax, eax
    mov [rsp + 32], rax
    call WriteFile

    lea rcx, [dbg_sent]
    call print_debug

    mov rcx, 100
    call Sleep

    mov rcx, [hCom]
    lea rdx, [response]
    mov r8d, 64
    lea r9, [bytes_read]
    xor eax, eax
    mov [rsp + 32], rax
    call ReadFile

    lea rcx, [dbg_response]
    call print_debug
    mov rax, [bytes_read]
    call print_hex_byte
    lea rcx, [newline]
    call print_debug

    mov rax, [bytes_read]

    add rsp, 40
    pop r12
    pop rbx
    ret

; ============================================================================
; relay_on
; ============================================================================
relay_on:
    sub rsp, 32
    lea rcx, [cmd_on]
    call send_command
    lea rcx, [msg_on]
    call print_string
    add rsp, 32
    ret

; ============================================================================
; relay_off
; ============================================================================
relay_off:
    sub rsp, 32
    lea rcx, [cmd_off]
    call send_command
    lea rcx, [msg_off]
    call print_string
    add rsp, 32
    ret

; ============================================================================
; relay_status
; ============================================================================
relay_status:
    sub rsp, 32
    lea rcx, [cmd_status]
    call send_command

    cmp rax, 4
    jl .unknown

    mov al, [response]
    cmp al, 0xA0
    jne .unknown
    mov al, [response + 1]
    cmp al, 0x01
    jne .unknown

    mov al, [response + 2]
    cmp al, 0x01
    je .state_on
    cmp al, 0x00
    je .state_off

.unknown:
    lea rcx, [msg_status_unknown]
    call print_string
    jmp .done

.state_on:
    lea rcx, [msg_status_on]
    call print_string
    jmp .done

.state_off:
    lea rcx, [msg_status_off]
    call print_string

.done:
    add rsp, 32
    ret

; ============================================================================
; relay_test
; ============================================================================
relay_test:
    push rbx
    sub rsp, 32

    lea rcx, [msg_testing]
    call print_string

    mov rbx, 10

.loop:
    lea rcx, [cmd_on]
    call send_command

    lea rcx, [cmd_off]
    call send_command

    dec rbx
    jnz .loop

    add rsp, 32
    pop rbx
    ret

; ============================================================================
; relay_benchmark
; ============================================================================
relay_benchmark:
    sub rsp, 32
    lea rcx, [msg_bench_start]
    call print_string
    add rsp, 32
    ret

; ============================================================================
; print_debug
; ============================================================================
print_debug:
    push rcx
    call print_string
    pop rcx
    ret

; ============================================================================
; print_string
; ============================================================================
print_string:
    push rbx
    push r12
    sub rsp, 40

    mov r12, rcx

    call lstrlenA
    mov rbx, rax

    mov rcx, [hStdOut]
    mov rdx, r12
    mov r8, rbx
    lea r9, [bytes_written]
    xor eax, eax
    mov [rsp + 32], rax
    call WriteFile

    add rsp, 40
    pop r12
    pop rbx
    ret

; ============================================================================
; print_hex_qword - Print 64-bit hex value
; ============================================================================
print_hex_qword:
    push rbx
    push r12
    sub rsp, 32

    mov r12, rax
    mov rbx, 16

.loop:
    rol r12, 4
    mov al, r12b
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .digit
    add al, 7
.digit:
    mov [num_buffer], al
    lea rcx, [num_buffer]
    mov byte [num_buffer + 1], 0
    call print_string
    dec rbx
    jnz .loop

    add rsp, 32
    pop r12
    pop rbx
    ret

; ============================================================================
; print_hex_byte - Print 8-bit hex value
; ============================================================================
print_hex_byte:
    push rbx
    sub rsp, 32

    mov rbx, rax

    shr rbx, 4
    and rbx, 0x0F
    mov al, bl
    add al, '0'
    cmp al, '9'
    jle .digit1
    add al, 7
.digit1:
    mov [num_buffer], al

    mov rbx, rax
    and rbx, 0x0F
    mov al, bl
    add al, '0'
    cmp al, '9'
    jle .digit2
    add al, 7
.digit2:
    mov [num_buffer + 1], al
    mov byte [num_buffer + 2], 0

    lea rcx, [num_buffer]
    call print_string

    add rsp, 32
    pop rbx
    ret

newline: db 13, 10, 0
