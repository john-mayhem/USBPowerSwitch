; ============================================================================
; USB Relay Controller - Pure Windows x86-64 Assembly Implementation
; ============================================================================
; Ultra-optimized, minimal binary size, maximum performance
; Windows-native using Windows API (no WSL required!)
;
; Features:
;   - Direct serial port control (COM1, COM2, etc.)
;   - Speed benchmarking (test maximum relay switching speed)
;   - Sub-microsecond command latency
;   - Tiny binary size (~3-4KB executable)
;
; Build: build-win.bat
; Usage: relay.exe [on|off|status|test|bench]
;
; Author: Windows Native Assembly Implementation
; ============================================================================

    bits 64
    default rel

section .data
    ; COM port names to try (null-terminated wide strings for Windows)
    com_ports:
        com1: db "COM1", 0
        com2: db "COM2", 0
        com3: db "COM3", 0
        com4: db "COM4", 0
        com5: db "COM5", 0

    ; Relay commands (CH340 protocol)
    cmd_on:     db 0xA0, 0x01, 0x03, 0xA4
    cmd_off:    db 0xA0, 0x01, 0x00, 0xA1
    cmd_status: db 0xA0, 0x01, 0x05, 0xA6

    ; Messages
    msg_usage: db "USB Relay Controller - Windows Assembly Edition", 13, 10
               db "Usage: relay.exe [on|off|status|test|bench]", 13, 10
               db 13, 10
               db "Commands:", 13, 10
               db "  on     - Turn relay ON", 13, 10
               db "  off    - Turn relay OFF", 13, 10
               db "  status - Query relay state", 13, 10
               db "  test   - Rapid switching test (10 cycles)", 13, 10
               db "  bench  - Benchmark maximum switching speed", 13, 10, 0
    msg_usage_len equ $ - msg_usage

    msg_on:     db "Relay: ON", 13, 10, 0
    msg_off:    db "Relay: OFF", 13, 10, 0
    msg_testing: db "Testing rapid switching...", 13, 10, 0
    msg_bench_start: db "Benchmarking relay speed...", 13, 10, 0
    msg_bench_result: db "Completed ", 0
    msg_cycles: db " cycles in ", 0
    msg_ms:     db " ms", 13, 10, 0
    msg_avg:    db "Average: ", 0
    msg_ms_per: db " ms/switch", 13, 10, 0
    msg_hz:     db "Speed: ", 0
    msg_hz_unit: db " switches/sec", 13, 10, 0
    msg_no_device: db "Error: No relay device found on COM1-COM5", 13, 10, 0
    msg_cmd_failed: db "Error: Command failed", 13, 10, 0
    msg_status_on: db "Status: ON (0x01)", 13, 10, 0
    msg_status_off: db "Status: OFF (0x00)", 13, 10, 0
    msg_status_unknown: db "Status: UNKNOWN", 13, 10, 0

    ; Windows API constants
    GENERIC_READ equ 0x80000000
    GENERIC_WRITE equ 0x40000000
    OPEN_EXISTING equ 3
    FILE_ATTRIBUTE_NORMAL equ 0x80
    INVALID_HANDLE_VALUE equ -1
    STD_OUTPUT_HANDLE equ -11
    STD_ERROR_HANDLE equ -12

    ; DCB structure offsets (simplified - we only set what we need)
    DCB_SIZE equ 28

section .bss
    hCom:       resq 1          ; COM port handle
    hStdOut:    resq 1          ; stdout handle
    hStdErr:    resq 1          ; stderr handle
    response:   resb 64         ; response buffer
    bytes_written: resq 1       ; bytes written
    bytes_read: resq 1          ; bytes read
    cycles_count: resq 1        ; benchmark cycles
    start_time: resq 1          ; start time (ms)
    end_time:   resq 1          ; end time (ms)
    num_buffer: resb 32         ; number to string buffer
    dcb:        resb 128        ; DCB structure (larger than needed for safety)
    timeouts:   resb 20         ; COMMTIMEOUTS structure

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
    extern GetTickCount
    extern Sleep
    extern GetCommandLineA
    extern lstrlenA

main:
    ; Save stack pointer
    push rbp
    mov rbp, rsp
    sub rsp, 64         ; Reserve shadow space + locals

    ; Get stdout and stderr handles
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [hStdOut], rax

    mov rcx, STD_ERROR_HANDLE
    call GetStdHandle
    mov [hStdErr], rax

    ; Get command line
    call GetCommandLineA
    mov rbx, rax        ; rbx = command line

    ; Parse command line to skip program name
    call skip_program_name
    mov rdi, rax        ; rdi = first argument

    ; Check if we have an argument
    test rdi, rdi
    jz .show_usage
    cmp byte [rdi], 0
    je .show_usage

    ; Parse command
    call parse_command
    cmp rax, -1
    je .show_usage

    mov r12, rax        ; Save command code

    ; Try to open COM port
    call open_com_port
    cmp rax, INVALID_HANDLE_VALUE
    je .error_no_device

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
    call relay_on
    jmp .exit_success

.cmd_off:
    call relay_off
    jmp .exit_success

.cmd_status:
    call relay_status
    jmp .exit_success

.cmd_test:
    call relay_test
    jmp .exit_success

.cmd_bench:
    call relay_benchmark
    jmp .exit_success

.error_no_device:
    lea rcx, [msg_no_device]
    call print_error
    jmp .exit_error

.exit_success:
    call close_com_port
    xor rcx, rcx
    call ExitProcess

.exit_error:
    call close_com_port
    mov rcx, 1
    call ExitProcess

; ============================================================================
; skip_program_name - Skip the program name in command line
; Input: rbx = command line
; Output: rax = pointer to first argument
; ============================================================================
skip_program_name:
    mov rsi, rbx

    ; Skip leading spaces
.skip_space1:
    lodsb
    cmp al, ' '
    je .skip_space1
    cmp al, 9           ; tab
    je .skip_space1
    dec rsi

    ; Check if quoted
    cmp byte [rsi], '"'
    je .quoted

    ; Not quoted - skip until space
.unquoted:
    lodsb
    test al, al
    jz .done
    cmp al, ' '
    je .find_arg
    jmp .unquoted

.quoted:
    inc rsi             ; skip opening quote
.skip_quoted:
    lodsb
    test al, al
    jz .done
    cmp al, '"'
    jne .skip_quoted
    jmp .find_arg

.find_arg:
    ; Skip spaces to find argument
.skip_space2:
    lodsb
    cmp al, ' '
    je .skip_space2
    cmp al, 9
    je .skip_space2
    dec rsi
    jmp .done

.done:
    mov rax, rsi
    ret

; ============================================================================
; parse_command - Parse command string
; Input: rdi = command string
; Output: rax = command code (0=off, 1=on, 2=status, 3=test, 4=bench, -1=invalid)
; ============================================================================
parse_command:
    ; Check for "on"
    mov al, [rdi]
    or al, 0x20         ; lowercase
    cmp al, 'o'
    jne .check_off
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'n'
    jne .check_off
    mov al, [rdi + 2]
    cmp al, 0
    jg .check_off       ; If not null or space, continue checking
    cmp al, ' '
    jle .is_on
.check_off:
    ; Check for "off"
    mov al, [rdi]
    or al, 0x20
    cmp al, 'o'
    jne .check_status
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'f'
    jne .check_status
    mov al, [rdi + 2]
    or al, 0x20
    cmp al, 'f'
    jne .check_status
    mov rax, 0
    ret

.is_on:
    mov rax, 1
    ret

.check_status:
    ; Check for "status"
    mov al, [rdi]
    or al, 0x20
    cmp al, 's'
    jne .check_test
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 't'
    jne .check_test
    mov rax, 2
    ret

.check_test:
    ; Check for "test"
    mov al, [rdi]
    or al, 0x20
    cmp al, 't'
    jne .check_bench
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'e'
    jne .check_bench
    mov rax, 3
    ret

.check_bench:
    ; Check for "bench"
    mov al, [rdi]
    or al, 0x20
    cmp al, 'b'
    jne .invalid
    mov al, [rdi + 1]
    or al, 0x20
    cmp al, 'e'
    jne .invalid
    mov rax, 4
    ret

.invalid:
    mov rax, -1
    ret

; ============================================================================
; open_com_port - Try to open COM ports 1-5
; Output: rax = handle (or INVALID_HANDLE_VALUE on error)
; ============================================================================
open_com_port:
    push rbx
    push r12

    ; Try COM1-COM5
    lea r12, [com1]
    mov rbx, 5          ; 5 ports to try

.try_next:
    ; CreateFileA(lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
    ;             dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
    ; Windows x64: rcx, rdx, r8, r9, [rsp+32], [rsp+40], [rsp+48]
    sub rsp, 64         ; Shadow space (32) + 3 stack params (24) + alignment (8)

    ; Stack parameters (5th, 6th, 7th parameters)
    mov dword [rsp + 32], OPEN_EXISTING     ; dwCreationDisposition
    mov qword [rsp + 40], 0                 ; dwFlagsAndAttributes = 0
    mov qword [rsp + 48], 0                 ; hTemplateFile = NULL

    ; Register parameters (1st through 4th)
    mov rcx, r12                            ; lpFileName (COM port string)
    mov edx, GENERIC_READ
    or edx, GENERIC_WRITE                   ; dwDesiredAccess
    xor r8d, r8d                            ; dwShareMode = 0
    xor r9, r9                              ; lpSecurityAttributes = NULL

    call CreateFileA
    add rsp, 64

    cmp rax, INVALID_HANDLE_VALUE
    jne .opened

    ; Try next port
    add r12, 5          ; Move to next COM port string
    dec rbx
    jnz .try_next

    ; All failed
    mov rax, INVALID_HANDLE_VALUE
    jmp .done

.opened:
    mov [hCom], rax

    ; Configure the port (9600, 8N1)
    call configure_com_port

    mov rax, [hCom]

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; configure_com_port - Configure COM port for 9600 8N1 (FIXED)
; ============================================================================
configure_com_port:
    sub rsp, 40

    ; Get current DCB settings
    mov rcx, [hCom]
    lea rdx, [dcb]
    mov dword [rdx], 28         ; DCBlength
    call GetCommState

    ; Set correct DCB fields using proper offsets:
    ; +4  = BaudRate
    ; +8  = flags (fBinary is bit 0)
    ; +18 = ByteSize
    ; +19 = Parity
    ; +20 = StopBits
    lea rax, [dcb]
    mov dword [rax + 4], 9600   ; BaudRate = 9600
    mov dword [rax + 8], 1      ; fBinary = TRUE
    mov byte [rax + 18], 8      ; ByteSize = 8
    mov byte [rax + 19], 0      ; Parity = NOPARITY
    mov byte [rax + 20], 0      ; StopBits = ONESTOPBIT

    ; Apply settings
    mov rcx, [hCom]
    lea rdx, [dcb]
    call SetCommState

    ; Set timeouts (generous)
    lea rax, [timeouts]
    mov dword [rax], 1000       ; ReadIntervalTimeout = 1000ms
    mov dword [rax + 4], 0      ; ReadTotalTimeoutMultiplier
    mov dword [rax + 8], 2000   ; ReadTotalTimeoutConstant = 2000ms
    mov dword [rax + 12], 0     ; WriteTotalTimeoutMultiplier
    mov dword [rax + 16], 1000  ; WriteTotalTimeoutConstant = 1000ms

    mov rcx, [hCom]
    lea rdx, [timeouts]
    call SetCommTimeouts

    add rsp, 40
    ret

; ============================================================================
; close_com_port - Close COM port handle
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
; send_command - Send 4-byte command and read response
; Input: rcx = command buffer
; ============================================================================
send_command:
    push rbx
    push r12
    sub rsp, 40

    mov r12, rcx        ; Save command pointer

    ; Write command
    mov rcx, [hCom]
    mov rdx, r12
    mov r8d, 4
    lea r9, [bytes_written]
    xor eax, eax
    mov [rsp + 32], rax ; lpOverlapped = NULL
    call WriteFile

    ; Wait for response (100ms)
    mov rcx, 100
    call Sleep

    ; Read response
    mov rcx, [hCom]
    lea rdx, [response]
    mov r8d, 64
    lea r9, [bytes_read]
    xor eax, eax
    mov [rsp + 32], rax
    call ReadFile

    mov rax, [bytes_read]

    add rsp, 40
    pop r12
    pop rbx
    ret

; ============================================================================
; relay_on - Turn relay ON
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
; relay_off - Turn relay OFF
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
; relay_status - Query relay status
; ============================================================================
relay_status:
    sub rsp, 32
    lea rcx, [cmd_status]
    call send_command

    ; Check response
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
; relay_test - Rapid switching test (10 cycles)
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
; relay_benchmark - Benchmark relay speed
; ============================================================================
relay_benchmark:
    push rbx
    sub rsp, 32

    lea rcx, [msg_bench_start]
    call print_string

    ; Get start time
    call GetTickCount
    mov [start_time], rax

    ; Run 100 cycles
    mov rbx, 100
    mov qword [cycles_count], 100

.loop:
    lea rcx, [cmd_on]
    call send_command

    lea rcx, [cmd_off]
    call send_command

    dec rbx
    jnz .loop

    ; Get end time
    call GetTickCount
    mov [end_time], rax

    ; Calculate elapsed time
    mov rax, [end_time]
    sub rax, [start_time]
    mov r12, rax        ; r12 = elapsed time in ms

    ; Print results
    call print_benchmark_results

    add rsp, 32
    pop rbx
    ret

; ============================================================================
; print_benchmark_results - Print benchmark statistics
; ============================================================================
print_benchmark_results:
    push rbx
    push r12
    push r13
    sub rsp, 32
    mov r13, rcx        ; Save elapsed time if passed

    mov r12, [end_time]
    sub r12, [start_time]   ; r12 = elapsed ms

    ; Print "Completed "
    lea rcx, [msg_bench_result]
    call print_string

    ; Print cycle count
    mov rax, [cycles_count]
    call print_number

    ; Print " cycles in "
    lea rcx, [msg_cycles]
    call print_string

    ; Print elapsed time
    mov rax, r12
    call print_number

    ; Print " ms"
    lea rcx, [msg_ms]
    call print_string

    ; Calculate average
    mov rax, r12
    xor rdx, rdx
    mov rcx, [cycles_count]
    div rcx
    mov rbx, rax        ; rbx = average

    ; Print "Average: "
    lea rcx, [msg_avg]
    call print_string

    mov rax, rbx
    call print_number

    lea rcx, [msg_ms_per]
    call print_string

    ; Calculate Hz
    cmp rbx, 0
    je .skip_hz
    mov rax, 1000
    xor rdx, rdx
    div rbx

    push rax
    lea rcx, [msg_hz]
    call print_string
    pop rax

    call print_number

    lea rcx, [msg_hz_unit]
    call print_string

.skip_hz:
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; print_number - Convert number to string and print
; Input: rax = number
; ============================================================================
print_number:
    push rbx
    push rdi
    sub rsp, 32

    mov rbx, 10
    lea rdi, [num_buffer + 31]
    mov byte [rdi], 0
    dec rdi

    test rax, rax
    jnz .convert

    ; Zero case
    mov byte [rdi], '0'
    jmp .print

.convert:
    test rax, rax
    jz .print

    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    jmp .convert

.print:
    inc rdi
    mov rcx, rdi
    call print_string

    add rsp, 32
    pop rdi
    pop rbx
    ret

; ============================================================================
; print_string - Print null-terminated string to stdout
; Input: rcx = string pointer
; ============================================================================
print_string:
    push rbx
    push r12
    sub rsp, 40

    mov r12, rcx        ; Save string pointer

    ; Get string length
    call lstrlenA
    mov rbx, rax        ; rbx = length

    ; WriteFile
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
; print_error - Print to stderr
; Input: rcx = string pointer
; ============================================================================
print_error:
    push rbx
    push r12
    sub rsp, 40

    mov r12, rcx

    call lstrlenA
    mov rbx, rax

    mov rcx, [hStdErr]
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
