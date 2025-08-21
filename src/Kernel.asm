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
    jne .unknown
    call list_directory
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
; Data section
; -----------------------------
msg_welcome      db 13,10,"Micro Mouse Terminal by LevelPack1218",13,10,0
msg_press_key    db 13,10,"Press any key to continue...",13,10,0

prompt           db 13,10,"MMT> ",0
msg_help         db 13,10,"Commands: help, cls, dir, reboot, shutdown",13,10,0
msg_unknown      db 13,10,"Unknown command",13,10,0

cmd_help         db "help",0
cmd_cls          db "cls",0
cmd_dir          db "dir",0
cmd_reboot       db "reboot",0
cmd_shutdown     db "shutdown",0

input_buf        times 128 db 0

; FAT12 filesystem data
fat_buffer       times 512 db 0
dir_buffer       times 512 db 0
entries_found    dw 0

; FAT12 BPB values (from bootloader)
sectors_per_fat  dw 9
reserved_sectors dw 1
fat_count        db 2
root_entries     dw 224
sectors_per_track dw 18
heads            dw 2

; -----------------------------
; List directory (FAT12)
; -----------------------------
list_directory:
    pusha
    
    ; Print header
    mov si, dir_header
    call print_string
    
    ; Initialize entries counter
    mov word [entries_found], 0
    
    ; Calculate root directory start sector
    ; root_start = reserved_sectors + (fat_count * sectors_per_fat)
    mov ax, [sectors_per_fat]
    mov bl, [fat_count]
    xor bh, bh
    mul bx
    add ax, [reserved_sectors]
    mov bx, ax  ; BX = root directory start sector
    
    ; Calculate number of root directory sectors
    ; root_sectors = (root_entries * 32) / bytes_per_sector
    mov ax, [root_entries]
    mov cx, 32
    mul cx
    mov cx, 512
    div cx
    test dx, dx
    jz .no_remainder
    inc ax
.no_remainder:
    mov cx, ax  ; CX = number of root directory sectors
    
    ; Read root directory sectors
    mov dx, 0   ; Sector counter
    
.read_next_sector:
    cmp dx, cx
    jae .done
    
    ; Calculate current sector
    mov ax, bx
    add ax, dx
    
    ; Read sector
    push bx
    push cx
    push dx
    mov bx, dir_buffer
    mov cx, 1
    call read_sector
    pop dx
    pop cx
    pop bx
    jc .error
    
    ; Parse directory entries in this sector
    mov si, dir_buffer
    mov di, 16  ; 16 entries per 512-byte sector
    
.parse_entry:
    push bx
    push cx
    push dx
    push di
    
    ; Check if entry is empty (first byte is 0)
    mov al, [si]
    cmp al, 0
    je .end_of_dir
    
    ; Check if entry is deleted (first byte is 0xE5)
    cmp al, 0xE5
    je .next_entry
    
    ; Check if it's a volume label (attribute 0x08)
    mov al, [si + 11]
    test al, 0x08
    jnz .next_entry
    
    ; Check if it's a long filename entry (attribute 0x0F)
    cmp al, 0x0F
    je .next_entry
    
    ; Valid entry found
    inc word [entries_found]
    
    ; Check if it's a subdirectory (attribute 0x10)
    test al, 0x10
    jnz .print_dir_entry
    
    ; Regular file entry
    call print_file_entry
    jmp .next_entry
    
.print_dir_entry:
    call print_directory_entry
    
.next_entry:
    pop di
    pop dx
    pop cx
    pop bx
    add si, 32  ; Each directory entry is 32 bytes
    dec di
    jnz .parse_entry
    
    ; Move to next sector
    inc dx
    jmp .read_next_sector
    
.end_of_dir:
    pop di
    pop dx
    pop cx
    pop bx
    
.done:
    ; Check if any entries were found
    mov ax, [entries_found]
    cmp ax, 0
    jne .finish
    
    ; No entries found - show demo files
    call show_demo_files
    
.finish:
    popa
    ret
    
.error:
    mov si, disk_error_msg
    call print_string
    ; Show demo files as fallback
    call show_demo_files
    popa
    ret

; -----------------------------
; Show demo files when no disk is available
; -----------------------------
show_demo_files:
    mov si, demo_file1
    call print_string
    mov si, demo_file2
    call print_string
    mov si, demo_file3
    call print_string
    ret

; -----------------------------
; Read sector from disk
; -----------------------------
read_sector:
    pusha
    
    ; Convert LBA to CHS
    call lba_to_chs
    
    ; Try multiple times
    mov di, 3
    
.retry:
    ; Reset disk system
    mov ah, 0x00
    mov dl, 0x00
    int 0x13
    
    ; Read sector using BIOS interrupt
    mov ah, 0x02
    mov al, cl      ; Number of sectors
    mov ch, [chs_cylinder]
    mov cl, [chs_sector]
    mov dh, [chs_head]
    mov dl, 0x00    ; Drive A:
    int 0x13
    
    ; Check for errors
    jnc .read_success
    
    ; Retry if failed
    dec di
    jnz .retry
    
    ; Failed after retries
    stc
    jmp .read_done
    
.read_success:
    clc
    
.read_done:
    popa
    ret

; -----------------------------
; Convert LBA to CHS
; -----------------------------
lba_to_chs:
    push bx
    push cx
    push dx
    
    ; AX contains LBA sector number
    ; Calculate sector
    xor dx, dx
    mov cx, 18  ; Sectors per track
    div cx
    inc dx
    mov [chs_sector], dl
    
    ; Calculate head and cylinder
    xor dx, dx
    mov cx, 2   ; Heads
    div cx
    mov [chs_head], dl
    mov [chs_cylinder], al
    
    pop dx
    pop cx
    pop bx
    ret

; -----------------------------
; Print file entry
; -----------------------------
print_file_entry:
    push si
    
    ; Print filename (8.3 format)
    call print_filename
    
    ; Print file size
    mov ax, [si + 28]  ; Low word of file size
    call print_file_size
    
    ; Print date/time (set DI to the entry pointer, preserve SI)
    push si
    mov di, si
    call print_file_datetime
    pop si
    
    ; Print newline
    mov si, newline
    call print_string
    
    pop si
    ret

; -----------------------------
; Print directory entry
; -----------------------------
print_directory_entry:
    push si                ; save entry pointer

    ; Print <DIR> indicator (print_string will change SI)
    mov si, dir_indicator
    call print_string

    pop si                 ; restore entry pointer for filename printing
    call print_filename

    ; Print spaces instead of size for directories
    push si
    mov si, dir_spaces
    call print_string
    pop si                 ; restore entry pointer

    ; Print date/time (use DI so print_file_datetime doesn't depend on SI)
    mov di, si
    call print_file_datetime

    ; Print newline
    mov si, newline
    call print_string

    ret

; -----------------------------
; Print filename in 8.3 format
; -----------------------------
print_filename:
    push si
    push cx
    
    ; Print filename (8 chars)
    mov cx, 8
.print_name:
    mov al, [si]
    cmp al, ' '
    je .print_ext
    mov ah, 0x0E
    int 0x10
    inc si
    loop .print_name
    
.print_ext:
    pop cx
    pop si
    push si
    push cx
    add si, 8
    
    ; Check if extension exists
    mov al, [si]
    cmp al, ' '
    je .pad_filename
    
    ; Print dot and extension
    mov al, '.'
    mov ah, 0x0E
    int 0x10
    
    mov cx, 3
.print_ext_chars:
    mov al, [si]
    cmp al, ' '
    je .pad_filename
    mov ah, 0x0E
    int 0x10
    inc si
    loop .print_ext_chars
    
.pad_filename:
    ; Pad filename to 12 characters for alignment
    mov cx, 4
.pad_loop:
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .pad_loop
    
    pop cx
    pop si
    ret

; -----------------------------
; Print file size with formatting
; -----------------------------
print_file_size:
    push ax
    call print_decimal_no_pad
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    int 0x10
    int 0x10
    int 0x10
    pop ax
    ret

; -----------------------------
; Print file date and time
; -----------------------------
; Expects DI = pointer to directory entry
print_file_datetime:
    push ax
    push bx
    push cx
    push dx

    ; Get date (offset 24) and time (offset 22) from DI
    mov ax, [di + 24]  ; Date
    mov bx, [di + 22]  ; Time

    ; Print date (MM/DD/YYYY format)
    ; Extract month (bits 5-8)
    mov cx, ax
    shr cx, 5
    and cx, 0x0F
    mov ax, cx
    call print_two_digits
    
    mov al, '/'
    mov ah, 0x0E
    int 0x10
    
    ; Extract day (bits 0-4)
    mov ax, [di + 24]
    and ax, 0x1F
    call print_two_digits
    
    mov al, '/'
    mov ah, 0x0E
    int 0x10
    
    ; Extract year (bits 9-15) and add 1980
    mov ax, [di + 24]
    shr ax, 9
    add ax, 1980
    call print_decimal_no_pad
    
    ; Print space
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    
    ; Print time (HH:MM format)
    ; Extract hours (bits 11-15)
    mov ax, [di + 22]
    shr ax, 11
    and ax, 0x1F
    call print_two_digits
    
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    
    ; Extract minutes (bits 5-10)
    mov ax, [di + 22]
    shr ax, 5
    and ax, 0x3F
    call print_two_digits

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------
; Print two digits with leading zero
; -----------------------------
print_two_digits:
    push ax
    push dx
    
    xor dx, dx
    mov bx, 10
    div bx
    
    ; Print tens digit
    add al, '0'
    mov ah, 0x0E
    int 0x10
    
    ; Print ones digit
    mov al, dl
    add al, '0'
    mov ah, 0x0E
    int 0x10
    
    pop dx
    pop ax
    ret

; -----------------------------
; Print decimal number without padding
; -----------------------------
print_decimal_no_pad:
    pusha
    
    ; Handle 16-bit number in AX only
    mov bx, 10
    mov cx, 0
    
    ; Handle zero case
    or ax, ax
    jnz .divide_loop
    push 0
    inc cx
    
.divide_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .divide_loop
    
.print_loop:
    pop ax
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .print_loop
    
    popa
    ret

; -----------------------------
; Print decimal number (16-bit only)
; -----------------------------
print_decimal:
    pusha
    
    ; Handle 16-bit number in AX only
    mov bx, 10
    mov cx, 0
    
    ; Handle zero case
    or ax, ax
    jnz .divide_loop
    push 0
    inc cx
    
.divide_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .divide_loop
    
.print_loop:
    pop ax
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .print_loop
    
    ; Print spaces for alignment
    mov cx, 8
.space_loop:
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .space_loop
    
    popa
    ret

; Messages
disk_error_msg   db 13,10,"Disk read error - showing demo files:",13,10,0
no_files_msg     db 13,10,"No files found - showing demo files:",13,10,0
newline          db 13,10,0
dir_header       db 13,10,"Directory of A:\",13,10,13,10,0
dir_indicator    db "<DIR>    ",0
dir_spaces       db "         ",0

; Demo file entries
demo_file1       db "KERNEL.BIN      8192  12/25/2023 10:30",13,10,0
demo_file2       db "CONFIG.SYS       256  12/25/2023 09:15",13,10,0
demo_file3       db "<DIR>    SYSTEM           12/25/2023 11:45",13,10,0

; Data for CHS conversion (moved to end to prevent corruption)
chs_cylinder     db 0
chs_head         db 0
chs_sector       db 0

times 8192-($-$$) db 0
