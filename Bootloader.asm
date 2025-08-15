[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Print "Booting..."
    mov si, msg_boot
.print_msg:
    lodsb
    or al, al
    jz .load_loadbin
    mov ah, 0x0E
    int 0x10
    jmp .print_msg

; -----------------------------
; Load load.bin (8 sectors, 4096 bytes)
; -----------------------------
.load_loadbin:
    mov ax, 0x7000       ; Load load.bin at segment 0x7000
    mov es, ax
    xor bx, bx

    mov dl, 0x00         ; Drive A:
    mov ch, 0
    mov dh, 0
    mov cl, 2            ; load.bin starts at sector 2

    mov si, load_sectors ; number of sectors to read
.read_loop:
    mov ah, 0x02         ; BIOS read 1 sector
    mov al, 1
    int 0x13
    jc .disk_error

    add bx, 512          ; next memory offset

    ; Advance sector
    inc cl
    cmp cl, 0x3F
    jle .no_cylinder_inc
    xor cl, cl
    inc ch
.no_cylinder_inc:

    dec si
    jnz .read_loop

    ; Jump to load.bin
    jmp 0x7000:0000

.disk_error:
    mov si, msg_error
.error_loop:
    lodsb
    or al, al
    jz $
    mov ah, 0x0E
    int 0x10
    jmp .error_loop

msg_boot db "Booting...",0
msg_error db "Disk read error!",0

; -----------------------------
; Configuration
; -----------------------------
load_sectors equ 8  ; load.bin = 4096 bytes = 8 sectors

; -----------------------------
; Pad bootloader to 512 bytes
; -----------------------------
times 510-($-$$) db 0
dw 0xAA55
