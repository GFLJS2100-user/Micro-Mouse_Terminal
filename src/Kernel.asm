[BITS 16]
[ORG 0x0000]    ; Kernel loaded at 0x8000:0000 by bootloader

start:
    cli
    call setup_exception_handlers
    sti

    call clear_screen
    call welcome_screen
    call clear_screen

main_loop:
    mov si, prompt
    call print_string
    call read_line
    call to_lowercase
    call handle_command
    jmp main_loop

; -----------------------------
; Exception handler setup
; -----------------------------
setup_exception_handlers:
    cli
    ; Handlers are placeholders, in real mode without IDT, just labels
    sti
    ret

; -----------------------------
; Exception template
; -----------------------------
exception_template:
    pusha
.print_msg:
    lodsb
    or al, al
    jz .halt_loop
    mov ah, 0x0E
    int 0x10
    jmp .print_msg
.halt_loop:
    hlt
    jmp .halt_loop
    popa
    iret

; -----------------------------
; CPU Exception Handlers
; -----------------------------
pf_handler:
    mov di, pf_msg
    jmp exception_template

gp_handler:
    mov di, gp_msg
    jmp exception_template

np_handler:
    mov di, np_msg
    jmp exception_template

df_handler:
    mov di, df_msg
    jmp exception_template

ss_handler:
    mov di, ss_msg
    jmp exception_template

br_handler:
    mov di, br_msg
    jmp exception_template

nm_handler:
    mov di, nm_msg
    jmp exception_template

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
    int 0x16
    ret

; -----------------------------
; Clear screen
; -----------------------------
clear_screen:
    pusha
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ah, 0x07
    mov al, ' '
    mov cx, 2000
.clear_loop:
    stosw
    loop .clear_loop

    mov ah, 0x02
    mov bh, 0x00
    mov dh, 0x00
    mov dl, 0x00
    int 0x10
    popa
    ret

; -----------------------------
; Print string
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
; Read line
; -----------------------------
read_line:
    mov si, input_buf
    xor cx, cx
.read_char:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .done
    cmp al, 8
    jne .store_char
    cmp cx, 0
    je .read_char
    dec si
    dec cx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .read_char
.store_char:
    mov [si], al
    inc si
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .read_char
.done:
    mov byte [si], 0
    ret

; -----------------------------
; To lowercase
; -----------------------------
to_lowercase:
    mov si, input_buf
.lower_loop:
    mov al, [si]
    or al, al
    jz .done
    cmp al, 'A'
    jb .skip
    cmp al, 'Z'
    ja .skip
    add al, 32
    mov [si], al
.skip:
    inc si
    jmp .lower_loop
.done:
    ret

; -----------------------------
; Command handler
; -----------------------------
handle_command:
    mov al, [input_buf]
    cmp al, 0
    je .empty_input

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
    call soft_reboot
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
    ret

.unknown:
    mov si, msg_unknown
    call print_string
    ret

; -----------------------------
; String compare
; -----------------------------
strcmp:
    xor ax, ax
.sc_loop:
    lodsb
    mov bl, [di]
    inc di
    cmp al, bl
    jne .neq
    or al, al
    jnz .sc_loop
    xor ax, ax
    ret
.neq:
    mov ax, 1
    ret

; -----------------------------
; Soft reboot
; -----------------------------
soft_reboot:
    cli
    mov word [0x472], 0x1234
    jmp 0xFFFF:0x0000
    ret

; -----------------------------
; Shutdown
; -----------------------------
shutdown_computer:
    cli
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    jc .halt
.halt:
    hlt
    jmp .halt

; -----------------------------
; Data Section
; -----------------------------
msg_welcome      db 13,10,"Micro Mouse Terminal",13,10,0
msg_press_key    db 13,10,"Press any key to continue...",13,10,0

prompt           db 13,10,"MMT> ",0
msg_help         db 13,10,"Commands: help, cls, reboot, shutdown",13,10,0
msg_unknown      db 13,10,"Unknown command",13,10,0

; CPU Exception Messages
pf_msg           db 13,10,"CPU Exception: Page Fault (#PF)",13,10,0
gp_msg           db 13,10,"CPU Exception: General Protection (#GP)",13,10,0
np_msg           db 13,10,"CPU Exception: Segment Not Present (#NP)",13,10,0
df_msg           db 13,10,"CPU Exception: Double Fault (#DF)",13,10,0
ss_msg           db 13,10,"CPU Exception: Stack Fault (#SS)",13,10,0
br_msg           db 13,10,"CPU Exception: Bounds (#BR)",13,10,0
nm_msg           db 13,10,"CPU Exception: Device Not Available (#NM)",13,10,0

cmd_help         db "help",0
cmd_cls          db "cls",0
cmd_reboot       db "reboot",0
cmd_shutdown     db "shutdown",0

input_buf        times 128 db 0

times 8192-($-$$) db 0
