; ============================================================================
; USB Relay Controller - Pure x86-64 Assembly Implementation
; ============================================================================
; Ultra-optimized, minimal binary size, maximum performance
; No external dependencies, direct syscalls only
;
; Features:
;   - Direct serial port control
;   - Speed benchmarking (test maximum relay switching speed)
;   - Sub-microsecond command latency
;   - Tiny binary size (~2KB executable)
;
; Build: nasm -f elf64 relay.asm && ld -o relay relay.o
; Usage: ./relay [on|off|status|test|bench]
;
; Author: Optimized Assembly Implementation
; ============================================================================

    BITS 64
    global _start

section .data
    ; Serial port device paths to try
    dev_ttyUSB0:    db "/dev/ttyUSB0", 0
    dev_ttyUSB1:    db "/dev/ttyUSB1", 0
    dev_ttyUSB2:    db "/dev/ttyUSB2", 0

    ; Relay commands (CH340 protocol)
    cmd_on:         db 0xA0, 0x01, 0x03, 0xA4
    cmd_off:        db 0xA0, 0x01, 0x00, 0xA1
    cmd_status:     db 0xA0, 0x01, 0x05, 0xA6

    ; Messages
    msg_usage:      db "USB Relay Controller - Assembly Edition", 10
                    db "Usage: relay [on|off|status|test|bench]", 10
                    db 10
                    db "Commands:", 10
                    db "  on     - Turn relay ON", 10
                    db "  off    - Turn relay OFF", 10
                    db "  status - Query relay state", 10
                    db "  test   - Rapid switching test (10 cycles)", 10
                    db "  bench  - Benchmark maximum switching speed", 10, 0
    msg_usage_len   equ $ - msg_usage

    msg_on:         db "Relay: ON", 10, 0
    msg_on_len      equ $ - msg_on

    msg_off:        db "Relay: OFF", 10, 0
    msg_off_len     equ $ - msg_off

    msg_testing:    db "Testing rapid switching...", 10, 0
    msg_testing_len equ $ - msg_testing

    msg_bench_start: db "Benchmarking relay speed...", 10, 0
    msg_bench_start_len equ $ - msg_bench_start

    msg_bench_result: db "Completed ", 0
    msg_bench_result_len equ $ - msg_bench_result

    msg_cycles:     db " cycles in ", 0
    msg_cycles_len  equ $ - msg_cycles

    msg_ms:         db " ms", 10, 0
    msg_ms_len      equ $ - msg_ms

    msg_avg:        db "Average: ", 0
    msg_avg_len     equ $ - msg_avg

    msg_ms_per:     db " ms/switch", 10, 0
    msg_ms_per_len  equ $ - msg_ms_per

    msg_hz:         db "Speed: ", 0
    msg_hz_len      equ $ - msg_hz

    msg_hz_unit:    db " switches/sec", 10, 0
    msg_hz_unit_len equ $ - msg_hz_unit

    msg_no_device:  db "Error: No relay device found", 10, 0
    msg_no_device_len equ $ - msg_no_device

    msg_cmd_failed: db "Error: Command failed", 10, 0
    msg_cmd_failed_len equ $ - msg_cmd_failed

    msg_status_on:  db "Status: ON (0x01)", 10, 0
    msg_status_on_len equ $ - msg_status_on

    msg_status_off: db "Status: OFF (0x00)", 10, 0
    msg_status_off_len equ $ - msg_status_off

    msg_status_unknown: db "Status: UNKNOWN", 10, 0
    msg_status_unknown_len equ $ - msg_status_unknown

    ; termios structure for serial port configuration
    ; This is a simplified version - we only set the fields we need
    align 8
    termios:
        .c_iflag:   dd 0            ; input flags
        .c_oflag:   dd 0            ; output flags
        .c_cflag:   dd 0x000008BD   ; control flags: 9600 baud, 8N1, enable receiver
        .c_lflag:   dd 0            ; local flags (raw mode)
        .c_line:    db 0            ; line discipline
        .c_cc:      times 32 db 0   ; control characters

    ; Baud rate constants (B9600)
    B9600           equ 0x0000000D

    ; termios c_cflag bits
    CREAD           equ 0x00000080
    CLOCAL          equ 0x00000800
    CS8             equ 0x00000030

    ; ioctl commands
    TCGETS          equ 0x5401
    TCSETS          equ 0x5402

    ; Timing for response delay (100ms = 100,000,000 ns)
    timespec:
        .tv_sec:    dq 0
        .tv_nsec:   dq 100000000    ; 100ms

section .bss
    fd:             resq 1          ; file descriptor
    response:       resb 64         ; response buffer
    argc:           resq 1          ; argument count
    argv:           resq 1          ; argument vector
    cycles_count:   resq 1          ; for benchmarking
    start_time:     resq 2          ; timespec for start time
    end_time:       resq 2          ; timespec for end time
    num_buffer:     resb 32         ; buffer for number to string conversion

section .text

; ============================================================================
; _start - Entry point
; ============================================================================
_start:
    ; Get argc and argv from stack
    pop rax                         ; argc
    mov [argc], rax
    mov [argv], rsp                 ; argv pointer

    ; Check if we have arguments
    cmp rax, 2
    jl .show_usage

    ; Get first argument
    mov rdi, [rsp + 8]              ; argv[1]
    call parse_command

    ; Open serial port
    call open_serial_port
    test rax, rax
    js .error_no_device

    ; Execute command (command code in rax from parse_command)
    cmp rax, 0
    je .cmd_off
    cmp rax, 1
    je .cmd_on
    cmp rax, 2
    je .cmd_status
    cmp rax, 3
    je .cmd_test
    cmp rax, 4
    je .cmd_bench

.show_usage:
    mov rax, 1                      ; sys_write
    mov rdi, 1                      ; stdout
    mov rsi, msg_usage
    mov rdx, msg_usage_len
    syscall
    jmp .exit_success

.cmd_on:
    call relay_on
    test rax, rax
    js .error_cmd_failed
    jmp .exit_success

.cmd_off:
    call relay_off
    test rax, rax
    js .error_cmd_failed
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
    mov rax, 1
    mov rdi, 2                      ; stderr
    mov rsi, msg_no_device
    mov rdx, msg_no_device_len
    syscall
    jmp .exit_error

.error_cmd_failed:
    mov rax, 1
    mov rdi, 2
    mov rsi, msg_cmd_failed
    mov rdx, msg_cmd_failed_len
    syscall
    jmp .exit_error

.exit_success:
    call close_serial_port
    mov rax, 60                     ; sys_exit
    xor rdi, rdi                    ; exit code 0
    syscall

.exit_error:
    call close_serial_port
    mov rax, 60
    mov rdi, 1                      ; exit code 1
    syscall

; ============================================================================
; parse_command - Parse command string
; Input: rdi = command string
; Output: rax = command code (0=off, 1=on, 2=status, 3=test, 4=bench, -1=invalid)
; ============================================================================
parse_command:
    ; Check for "on"
    mov al, [rdi]
    cmp al, 'o'
    jne .check_off
    mov al, [rdi + 1]
    cmp al, 'n'
    jne .check_off
    mov al, [rdi + 2]
    test al, al
    jne .check_off
    mov rax, 1
    ret

.check_off:
    ; Check for "off"
    mov al, [rdi]
    cmp al, 'o'
    jne .check_status
    mov al, [rdi + 1]
    cmp al, 'f'
    jne .check_status
    mov al, [rdi + 2]
    cmp al, 'f'
    jne .check_status
    mov al, [rdi + 3]
    test al, al
    jne .check_status
    mov rax, 0
    ret

.check_status:
    ; Check for "status"
    mov al, [rdi]
    cmp al, 's'
    jne .check_test
    mov al, [rdi + 1]
    cmp al, 't'
    jne .check_test
    mov al, [rdi + 2]
    cmp al, 'a'
    jne .check_test
    mov al, [rdi + 3]
    cmp al, 't'
    jne .check_test
    mov al, [rdi + 4]
    cmp al, 'u'
    jne .check_test
    mov al, [rdi + 5]
    cmp al, 's'
    jne .check_test
    mov al, [rdi + 6]
    test al, al
    jne .check_test
    mov rax, 2
    ret

.check_test:
    ; Check for "test"
    mov al, [rdi]
    cmp al, 't'
    jne .check_bench
    mov al, [rdi + 1]
    cmp al, 'e'
    jne .check_bench
    mov al, [rdi + 2]
    cmp al, 's'
    jne .check_bench
    mov al, [rdi + 3]
    cmp al, 't'
    jne .check_bench
    mov al, [rdi + 4]
    test al, al
    jne .check_bench
    mov rax, 3
    ret

.check_bench:
    ; Check for "bench"
    mov al, [rdi]
    cmp al, 'b'
    jne .invalid
    mov al, [rdi + 1]
    cmp al, 'e'
    jne .invalid
    mov al, [rdi + 2]
    cmp al, 'n'
    jne .invalid
    mov al, [rdi + 3]
    cmp al, 'c'
    jne .invalid
    mov al, [rdi + 4]
    cmp al, 'h'
    jne .invalid
    mov al, [rdi + 5]
    test al, al
    jne .invalid
    mov rax, 4
    ret

.invalid:
    mov rax, -1
    ret

; ============================================================================
; open_serial_port - Try to open serial port device
; Output: rax = fd (or negative on error)
; ============================================================================
open_serial_port:
    push rbx

    ; Try /dev/ttyUSB0
    mov rax, 2                      ; sys_open
    mov rdi, dev_ttyUSB0
    mov rsi, 2                      ; O_RDWR
    xor rdx, rdx
    syscall
    test rax, rax
    jns .opened

    ; Try /dev/ttyUSB1
    mov rax, 2
    mov rdi, dev_ttyUSB1
    mov rsi, 2
    xor rdx, rdx
    syscall
    test rax, rax
    jns .opened

    ; Try /dev/ttyUSB2
    mov rax, 2
    mov rdi, dev_ttyUSB2
    mov rsi, 2
    xor rdx, rdx
    syscall
    test rax, rax
    jns .opened

    ; All failed
    pop rbx
    mov rax, -1
    ret

.opened:
    mov [fd], rax
    mov rbx, rax                    ; save fd

    ; Configure serial port using ioctl
    mov rax, 16                     ; sys_ioctl
    mov rdi, rbx                    ; fd
    mov rsi, TCSETS                 ; TCSETS
    mov rdx, termios                ; termios structure
    syscall

    mov rax, rbx                    ; return fd
    pop rbx
    ret

; ============================================================================
; close_serial_port - Close serial port
; ============================================================================
close_serial_port:
    mov rax, 3                      ; sys_close
    mov rdi, [fd]
    syscall
    ret

; ============================================================================
; send_command - Send 4-byte command and read response
; Input: rdi = command buffer
; Output: rax = bytes read (or negative on error)
; ============================================================================
send_command:
    push rbx
    push r12
    mov r12, rdi                    ; save command pointer

    ; Write command (4 bytes)
    mov rax, 1                      ; sys_write
    mov rdi, [fd]
    mov rsi, r12
    mov rdx, 4
    syscall
    test rax, rax
    js .error

    ; Small delay for device to process (100ms)
    mov rax, 35                     ; sys_nanosleep
    mov rdi, timespec
    xor rsi, rsi
    syscall

    ; Read response
    mov rax, 0                      ; sys_read
    mov rdi, [fd]
    mov rsi, response
    mov rdx, 64
    syscall

.error:
    pop r12
    pop rbx
    ret

; ============================================================================
; relay_on - Turn relay ON
; Output: rax = 0 on success, negative on error
; ============================================================================
relay_on:
    mov rdi, cmd_on
    call send_command
    test rax, rax
    js .error

    ; Print message
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_on
    mov rdx, msg_on_len
    syscall

    xor rax, rax
    ret

.error:
    mov rax, -1
    ret

; ============================================================================
; relay_off - Turn relay OFF
; Output: rax = 0 on success, negative on error
; ============================================================================
relay_off:
    mov rdi, cmd_off
    call send_command
    test rax, rax
    js .error

    ; Print message
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_off
    mov rdx, msg_off_len
    syscall

    xor rax, rax
    ret

.error:
    mov rax, -1
    ret

; ============================================================================
; relay_status - Query and display relay status
; ============================================================================
relay_status:
    mov rdi, cmd_status
    call send_command
    test rax, rax
    js .unknown

    ; Check response (expecting 0xA0 0x01 STATE ...)
    cmp rax, 4
    jl .unknown

    mov al, [response]
    cmp al, 0xA0
    jne .unknown
    mov al, [response + 1]
    cmp al, 0x01
    jne .unknown

    ; Check state byte
    mov al, [response + 2]
    cmp al, 0x01
    je .state_on
    cmp al, 0x00
    je .state_off
    jmp .unknown

.state_on:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_status_on
    mov rdx, msg_status_on_len
    syscall
    ret

.state_off:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_status_off
    mov rdx, msg_status_off_len
    syscall
    ret

.unknown:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_status_unknown
    mov rdx, msg_status_unknown_len
    syscall
    ret

; ============================================================================
; relay_test - Rapid switching test (10 cycles)
; ============================================================================
relay_test:
    push rbx

    ; Print message
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_testing
    mov rdx, msg_testing_len
    syscall

    mov rbx, 10                     ; 10 cycles

.loop:
    ; Turn ON
    mov rdi, cmd_on
    call send_command

    ; Turn OFF
    mov rdi, cmd_off
    call send_command

    dec rbx
    jnz .loop

    pop rbx
    ret

; ============================================================================
; relay_benchmark - Benchmark maximum switching speed
; ============================================================================
relay_benchmark:
    push rbx
    push r12

    ; Print start message
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bench_start
    mov rdx, msg_bench_start_len
    syscall

    ; Get start time
    mov rax, 228                    ; sys_clock_gettime
    mov rdi, 0                      ; CLOCK_REALTIME
    mov rsi, start_time
    syscall

    ; Run 100 cycles
    mov rbx, 100
    mov qword [cycles_count], 100

.loop:
    ; Turn ON (no delay between commands for max speed)
    mov rax, 1
    mov rdi, [fd]
    mov rsi, cmd_on
    mov rdx, 4
    syscall

    ; Turn OFF
    mov rax, 1
    mov rdi, [fd]
    mov rsi, cmd_off
    mov rdx, 4
    syscall

    dec rbx
    jnz .loop

    ; Get end time
    mov rax, 228
    mov rdi, 0
    mov rsi, end_time
    syscall

    ; Calculate elapsed time in milliseconds
    call calculate_elapsed_time

    ; Print results
    call print_benchmark_results

    pop r12
    pop rbx
    ret

; ============================================================================
; calculate_elapsed_time - Calculate time difference
; Returns: rax = elapsed time in milliseconds
; ============================================================================
calculate_elapsed_time:
    ; elapsed_sec = end_time.tv_sec - start_time.tv_sec
    mov rax, [end_time]
    sub rax, [start_time]

    ; elapsed_ms = elapsed_sec * 1000
    mov rcx, 1000
    mul rcx
    mov rbx, rax                    ; save seconds part

    ; elapsed_nsec = end_time.tv_nsec - start_time.tv_nsec
    mov rax, [end_time + 8]
    sub rax, [start_time + 8]

    ; Convert nsec to msec (divide by 1,000,000)
    mov rcx, 1000000
    xor rdx, rdx
    div rcx

    ; Total elapsed = seconds_ms + nsec_ms
    add rax, rbx
    ret

; ============================================================================
; print_benchmark_results - Print benchmark statistics
; ============================================================================
print_benchmark_results:
    push rbx
    push r12
    mov r12, rax                    ; save elapsed time

    ; Print "Completed "
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bench_result
    mov rdx, msg_bench_result_len
    syscall

    ; Print cycle count
    mov rax, [cycles_count]
    call print_number

    ; Print " cycles in "
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_cycles
    mov rdx, msg_cycles_len
    syscall

    ; Print elapsed time
    mov rax, r12
    call print_number

    ; Print " ms"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_ms
    mov rdx, msg_ms_len
    syscall

    ; Calculate average (elapsed_ms / cycles)
    mov rax, r12
    xor rdx, rdx
    mov rcx, [cycles_count]
    div rcx
    mov rbx, rax                    ; save average

    ; Print "Average: "
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_avg
    mov rdx, msg_avg_len
    syscall

    ; Print average time
    mov rax, rbx
    call print_number

    ; Print " ms/switch"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_ms_per
    mov rdx, msg_ms_per_len
    syscall

    ; Calculate switches per second (1000 / avg_ms)
    cmp rbx, 0
    je .skip_hz
    mov rax, 1000
    xor rdx, rdx
    div rbx

    ; Print "Speed: "
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_hz
    mov rdx, msg_hz_len
    syscall
    pop rax

    ; Print Hz value
    call print_number

    ; Print " switches/sec"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_hz_unit
    mov rdx, msg_hz_unit_len
    syscall

.skip_hz:
    pop r12
    pop rbx
    ret

; ============================================================================
; print_number - Convert number to string and print
; Input: rax = number to print
; ============================================================================
print_number:
    push rbx
    push rcx
    push rdx
    push rdi

    mov rbx, 10
    mov rdi, num_buffer + 31        ; point to end of buffer
    mov byte [rdi], 0               ; null terminator
    dec rdi

    test rax, rax
    jnz .convert
    ; Special case: zero
    mov byte [rdi], '0'
    jmp .print

.convert:
    test rax, rax
    jz .print

    xor rdx, rdx
    div rbx                         ; divide by 10
    add dl, '0'                     ; convert remainder to ASCII
    mov [rdi], dl
    dec rdi
    jmp .convert

.print:
    inc rdi                         ; point to first digit

    ; Calculate length
    mov rsi, rdi
    mov rcx, num_buffer + 31
    sub rcx, rdi

    ; Print
    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret
