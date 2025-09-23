[BITS 16]
[ORG 0x0000]    ; Kernel is loaded at 0x2000:0000 by the bootloader

start:
    ; Set up proper segment registers for kernel operation
    mov ax, 0x2000  ; Use the segment where we're loaded
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x1000  ; Set stack within our segment
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
    push es
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
    pop es
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
    jne .check_dir
    call shutdown_computer
    ret

.check_dir:
    mov si, input_buf
    mov di, cmd_dir
    call strcmp
    cmp ax, 0
    jne .check_run
    call list_directory
    ret

.check_run:
    mov si, input_buf
    mov di, cmd_run
    call strncmp
    cmp ax, 0
    jne .unknown
    call run_file
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
; Soft reboot using BIOS warm reboot vector
; -----------------------------
soft_reboot:
    cli
    ; Set warm boot flag at 0x472 to 0x1234
    mov word [0x472], 0x1234
    ; Jump to BIOS start
    jmp 0xFFFF:0x0000
    ret

; -----------------------------
; Shutdown routine
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
; Run file
; -----------------------------
run_file:
    ; Extract filename from input buffer
    mov si, input_buf
    add si, 4 ; Skip "run "
.trim_spaces:
    cmp byte [si], ' '
    jne .found_filename
    inc si
    jmp .trim_spaces

.found_filename:
    ; SI now points to the filename
    call find_file
    jc .file_not_found

    ; File found, DI points to directory entry. Load it.
    mov ax, 0x4000
    mov es, ax
    mov bx, 0x0100
    call load_file
    jc .load_error

    ; Set up PSP
    mov ax, 0x4000
    mov es, ax
    mov bx, 0
    mov word [es:bx], 0x20CD ; int 20h

    ; Save kernel state
    push ds
    push es
    push ss
    push sp

    ; Set up program segment and stack
    mov ax, 0x4000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE ; Top of 64k segment

    ; Call the program
    call 0x4000:0x0100

    ; Restore kernel state
    pop sp
    pop ss
    pop es
    pop ds

    ret

.file_not_found:
    mov si, msg_file_not_found
    call print_string
    ret

.load_error:
    mov si, msg_load_error
    call print_string
    ret

; -----------------------------
; String n compare
; -----------------------------
strncmp:
    xor ax, ax
    mov cx, 3 ; "run" is 3 chars
.snc_loop:
    lodsb
    mov bl, [di]
    inc di
    cmp al, bl
    jne .sneq
    or al, al
    jz .sneq ; Should not happen if strings are different length
    loop .snc_loop

    ; Check for space after "run"
    cmp byte [si], ' '
    jne .sneq

    xor ax, ax
    ret
.sneq:
    mov ax, 1
    ret

; -----------------------------
; Data section
; -----------------------------
msg_welcome      db 13,10,"Micro Mouse Terminal by LevelPack1218",13,10,0
msg_press_key    db 13,10,"Press any key to continue...",13,10,0

prompt           db 13,10,"MMT> ",0
msg_help         db 13,10,"Commands: help, cls, dir, reboot, shutdown",13,10,0
msg_unknown      db 13,10,"Unknown command",13,10,0
msg_file_not_found db 13,10,"File not found",13,10,0
msg_load_error   db 13,10,"Error loading file",13,10,0

cmd_help         db "help",0
cmd_cls          db "cls",0
cmd_dir          db "dir",0
cmd_reboot       db "reboot",0
cmd_shutdown     db "shutdown",0
cmd_run          db "run",0

input_buf        times 128 db 0

%include "src/FAT12.asm"

times 8192-($-$$) db 0