[BITS 16]
[ORG 0x0000]    ; Loaded at segment 0x8000:0000 by bootloader

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
    mov ah, 0x07       ; Light gray on black
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
    xor cx, cx
.read_char:
    xor ah, ah
    int 0x16           ; BIOS: wait for key
    cmp al, 13         ; Enter
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
    mov byte [si], 0   ; Null-terminate input
    ret

; -----------------------------
; Convert input_buf to lowercase
; -----------------------------
to_lowercase:
    mov si, input_buf
.loop:
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
    jmp .loop
.done:
    ret

; -----------------------------
; Command handler
; -----------------------------
handle_command:
    ; Skip if input is empty
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
    jne .unknown
    call clear_screen
    ret

.empty_input:
    ret                  ; Do nothing for empty input

.unknown:
    mov si, msg_unknown
    call print_string
    ret

; -----------------------------
; String Compare (SI vs DI)
; Sets AX=0 if equal
; -----------------------------
strcmp:
    xor ax, ax
.loop:
    lodsb
    mov bl, [di]
    inc di
    cmp al, bl
    jne .not_equal
    or al, al
    jnz .loop
    xor ax, ax
    ret
.not_equal:
    mov ax, 1
    ret

; -----------------------------
; Data Section
; -----------------------------
msg_welcome      db 13,10,"Micro Mouse Terminal",13,10,0
msg_press_key    db 13,10,"Press any key to continue...",13,10,0

prompt           db 13,10,"MMT> ",0
msg_help         db 13,10,"Commands: help, cls",13,10,0
msg_unknown      db 13,10,"Unknown command",13,10,0

cmd_help         db "help",0
cmd_cls          db "cls",0

input_buf        times 128 db 0

; -----------------------------
; Pad kernel to 8192 bytes
; -----------------------------
times 8192-($-$$) db 0
