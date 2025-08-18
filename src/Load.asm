[BITS 16]
[ORG 0x0000]  ; loaded at 0x7000:0000

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
    mov al, '['
    mov ah, 0x0E
    int 0x10

    mov cx, total_sectors
.fill_spaces:
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .fill_spaces

    mov al, ']'
    mov ah, 0x0E
    int 0x10

    ; Move cursor back inside the bar
    mov cx, total_sectors+1
.cursor_back:
    mov al, 8
    mov ah, 0x0E
    int 0x10
    loop .cursor_back

    ; Load kernel.bin at 0x8000
    mov ax, 0x8000
    mov es, ax
    xor bx, bx

    mov dl, 0x00
    mov ch, 0
    mov dh, 0
    mov cl, kernel_start_sector

    mov si, total_sectors
.load_loop:
    mov ah, 0x02
    mov al, 1
    int 0x13
    jc .disk_error

    add bx, 512

    ; Print progress bar
    mov al, '#'
    mov ah, 0x0E
    int 0x10

    ; Correct CHS increment (18 sectors per track, 2 heads)
    inc cl
    cmp cl, 19        ; SPT = 18 → next track
    jl .no_cylinder_inc
    mov cl, 1
    inc dh             ; next head
    cmp dh, 2
    jl .no_cylinder_inc
    mov dh, 0
    inc ch             ; next cylinder
.no_cylinder_inc:

    dec si
    jnz .load_loop

    ; Newline after progress bar
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

total_sectors      equ 16
kernel_start_sector equ 10

times 4096-($-$$) db 0
