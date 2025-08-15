[BITS 16]
[ORG 0x0000]    ; Kernel is loaded at 0x8000:0000 by the bootloader

start:
    call clear_screen
    call welcome_screen      ; Display welcome message
    call clear_screen        ; Clear screen again for prompt

main_loop:
    mov si, prompt
    call print_string
    call read_line
    call to_lowercase
    call handle_command
    jmp main_loop

; -----------------------------
; Welcome screen
; -----------------------------
welcome_screen:
    mov si, msg_welcome
.print_loop:
    lodsb
    or al, al
    jz .print_continue
    mov ah, 0x0E
    int 0x10
    jmp .print_loop

.print_continue:
    mov si, msg_press_key
.press_loop:
    lodsb
    or al, al
    jz .wait_key
    mov ah, 0x0E
    int 0x10
    jmp .press_loop

.wait_key:
    xor ah, ah
    int 0x16           ; Wait for any key
    ret

; -----------------------------
; Clear screen and reset cursor
; -----------------------------
clear_screen:
    pusha
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ah, 0x07       ; light gray on black
    mov al, ' '
    mov cx, 2000       ; 80 * 25 = 2000 chars
.clear_loop:
    stosw
    loop .clear_loop

    ; Move cursor to (0, 0)
    mov ah, 0x02
    mov bh, 0x00       ; page 0
    mov dh, 0x00       ; row 0
    mov dl, 0x00       ; col 0
    int 0x10
    popa
    ret

; -----------------------------
; Print string at SI
; -----------------------------
print_string:
.next_char:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .next_char
.done:
    ret

; -----------------------------
; Read line into input_buf
; Backspace will not erase prompt
; -----------------------------
read_line:
    mov si, input_buf
    xor cx, cx          ; cx = number of typed chars
.read_char:
    xor ah, ah
    int 0x16           ; BIOS: wait for key
    cmp al, 13         ; Enter?
    je .done

    cmp al, 8          ; Backspace?
    jne .store_char

    ; If Backspace, delete last typed character if any
    cmp cx, 0
    je .read_char      ; nothing to delete
    dec si
    dec cx
    mov ah, 0x0E
    mov al, 8          ; move cursor back
    int 0x10
    mov al, ' '        ; overwrite character
    int 0x10
    mov al, 8          ; move cursor back again
    int 0x10
    jmp .read_char

.store_char:
    mov [si], al
    inc si
    inc cx
    mov ah, 0x0E
    int 0x10           ; Echo typed character
    jmp .read_char

.done:
    mov byte [si], 0   ; Null-terminate input buffer
    ret

; -----------------------------
; Convert input_buf to lowercase
; -----------------------------
to_lowercase:
    mov si, input_buf
.lower_loop:
    mov al, [si]
    or al, al
    jz .lower_done
    cmp al, 'A'
    jb .lower_skip
    cmp al, 'Z'
    ja .lower_skip
    add al, 32         ; 'a' - 'A' = 32
    mov [si], al
.lower_skip:
    inc si
    jmp .lower_loop
.lower_done:
    ret

; -----------------------------
; Command handler
; -----------------------------
handle_command:
    ; Skip if input is empty
    mov al, [input_buf]
    cmp al, 0
    je .empty_input

    ; help
    mov si, input_buf
    mov di, cmd_help
    call strcmp
    cmp ax, 0
    jne .check_cls
    mov si, msg_help
    call print_string
    ret

.check_cls:
    mov si, input_buf
    mov di, cmd_cls
    call strcmp
    cmp ax, 0
    jne .check_reboot
    call clear_screen
    ret

.check_reboot:
    mov si, input_buf
    mov di, cmd_reboot
    call strcmp
    cmp ax, 0
    jne .check_shutdown
    call reboot_computer
    ret

.check_shutdown:
    mov si, input_buf
    mov di, cmd_shutdown
    call strcmp
    cmp ax, 0
    jne .unknown
    call shutdown_computer
    ret

.empty_input:
    ret                  ; do nothing for empty input

.unknown:
    mov si, msg_unknown
    call print_string
    ret

; -----------------------------
; String Compare (SI vs DI)
; Sets AX=0 if equal, else AX=1
; Note: SI will be advanced by lodsb
; -----------------------------
strcmp:
    xor ax, ax
.sc_loop:
    lodsb
    mov bl, [di]
    inc di
    cmp al, bl
    jne .sc_not_equal
    or al, al
    jnz .sc_loop
    xor ax, ax
    ret
.sc_not_equal:
    mov ax, 1
    ret

; -----------------------------
; Hard reboot (keyboard controller) and shutdown routines
; -----------------------------
; reboot_computer: perform keyboard-controller reset (hard reboot)
; -----------------------------
reboot_computer:
    cli
    mov al, 0xFE
    out 0x64, al        ; keyboard controller pulse reset
    hlt                 ; if reboot fails, halt
    jmp $               ; infinite loop
    ret

; -----------------------------
; shutdown_computer: attempt APM power-off; fall back to halt
; -----------------------------
shutdown_computer:
    cli
    ; Try APM power-off (function 0x5307)
    mov ax, 0x5307
    mov bx, 0x0001      ; device (all)
    mov cx, 0x0003      ; power state = off
    int 0x15
    jc .apm_fail        ; if carry set, APM call failed

    ; If APM succeeded, BIOS may power off the system here.
    ; If it returns, fall through to halt as fallback.
.apm_fail:
    ; Best-effort ACPI/QEMU shutdown attempt: write to a common QEMU port
    ; (non-standard; may or may not do anything)
    push ax
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax
    pop ax

    ; Fallback: halt CPU
.halt_loop:
    hlt
    jmp .halt_loop
    ret

; -----------------------------
; Data Section
; -----------------------------
msg_welcome      db 13,10,"Micro Mouse Terminal",13,10,0
msg_press_key    db 13,10,"Press any key to continue...",13,10,0

prompt           db 13,10,"MMT> ",0
msg_help         db 13,10,"Commands: help, cls, reboot, shutdown",13,10,0
msg_unknown      db 13,10,"Unknown command",13,10,0

cmd_help         db "help",0
cmd_cls          db "cls",0
cmd_reboot       db "reboot",0
cmd_shutdown     db "shutdown",0

input_buf        times 128 db 0

; -----------------------------
; Pad kernel to 8192 bytes
; -----------------------------
times 8192-($-$$) db 0
