[BITS 16]
[ORG 0x0000]  ; loaded at 0x7000:0000 by bootloader

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7000
    sti

    ; Print loading message
    mov si, msg_loading
.print_msg:
    lodsb
    or al, al
    jz .print_bar_start
    mov ah, 0x0E
    int 0x10
    jmp .print_msg

.print_bar_start:
    ; Print opening bracket '['
    mov al, '['
    mov ah, 0x0E
    int 0x10

    ; Initialize empty bar: 16 spaces
    mov cx, 16
.fill_spaces:
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .fill_spaces

    ; Print closing bracket ']'
    mov al, ']'
    mov ah, 0x0E
    int 0x10

    ; Move cursor back 17 positions (inside bar)
    mov cx, 17
.cursor_back:
    mov ah, 0x0E
    mov al, 8
    int 0x10
    loop .cursor_back

    ; Load kernel.bin at 0x8000
    mov ax, 0x8000
    mov es, ax
    xor bx, bx

    mov dl, 0x00       ; drive A:
    mov ch, 0
    mov dh, 0
    mov cl, 10         ; kernel.bin starts after load.bin (sector 10)

    mov si, 16         ; 16 sectors = 8192 bytes
.load_loop:
    mov ah, 0x02
    mov al, 1
    int 0x13
    jc .disk_error

    add bx, 512        ; next sector

    ; Print '#' in progress bar
    mov al, '#'
    mov ah, 0x0E
    int 0x10

    inc cl
    cmp cl, 0x3F
    jle .no_cylinder_inc
    xor cl, cl
    inc ch
.no_cylinder_inc:

    dec si
    jnz .load_loop

    ; CRLF after progress bar
    mov al, 13
    mov ah, 0x0E
    int 0x10
    mov al, 10
    int 0x10

    ; Jump to kernel
    cli
    mov ax, 0x8000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFF
    sti

    jmp 0x8000:0000

.disk_error:
    mov si, msg_error
.error_loop:
    lodsb
    or al, al
    jz $
    mov ah, 0x0E
    int 0x10
    jmp .error_loop

msg_loading db "Loading Micro Mouse Terminal: ",0
msg_error   db "Disk read error!",0

times 4096-($-$$) db 0  ; pad load.bin to 4096 bytes
