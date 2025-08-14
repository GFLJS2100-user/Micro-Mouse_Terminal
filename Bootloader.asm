[BITS 16]
[ORG 0x7C00]

start:
    cli

    ; Setup segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    sti

    ; Print "Loading Micro Mouse Terminal..."
    mov si, msg_loading
.print_char:
    lodsb
    or al, al
    jz .load_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print_char

.load_kernel:
    mov bx, 0x0000          ; Offset within ES
    mov ax, 0x8000          ; Load segment 0x8000
    mov es, ax

    mov ah, 0x02            ; BIOS read sectors
    mov al, 16              ; Number of sectors to read (kernel size)
    mov ch, 0               ; Cylinder 0
    mov dh, 0               ; Head 0
    mov cl, 2               ; Start sector 2 (sector 1 is bootloader)
    mov dl, 0x00            ; Drive 0 (floppy A:)
    int 0x13
    jc .disk_error          ; Jump if carry set (error)

    ; Jump to kernel at 0x8000:0000
    cli
    mov ax, 0x8000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFF          ; Stack top in kernel segment
    sti

    jmp 0x8000:0000        ; Far jump to kernel start

.disk_error:
    mov si, msg_error
.error_loop:
    lodsb
    or al, al
    jz $
    mov ah, 0x0E
    int 0x10
    jmp .error_loop

msg_loading db "Loading Micro Mouse Terminal...", 0
msg_error db "Disk read error!", 0

times 510-($-$$) db 0
dw 0xAA55
