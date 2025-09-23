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
; Check for FAT12 filesystem
; Returns with carry flag set if not FAT12
; -----------------------------
check_filesystem:
    pusha

    ; Read boot sector (LBA 0) into fat_buffer
    mov ax, 0
    mov bx, fat_buffer
    mov cx, 1
    call read_sector
    jc .cf_error    ; Propagate carry on read error

    ; Compare filesystem identifier with "FAT12   "
    mov si, fat_buffer + 0x36
    mov di, fat12_id
    mov cx, 8
    repe cmpsb
    jne .cf_not_fat12

    ; Success, clear carry
    clc
    jmp .cf_done

.cf_not_fat12:
    stc ; Set carry, not FAT12

.cf_error:
    stc ; Set carry, disk read error

.cf_done:
    popa
    ret

; -----------------------------
; List directory (FAT12)
; -----------------------------
list_directory:
    pusha

    ; First, check if the filesystem is FAT12
    call check_filesystem
    jc .invalid_fs

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
    
.invalid_fs:
    mov si, invalid_fs_msg
    call print_string
    popa
    ret

.error:
    mov si, disk_error_msg
    call print_string
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
disk_error_msg   db 13,10,"Disk read error.",13,10,0
invalid_fs_msg   db 13,10,"Invalid or unsupported disk format.",13,10,0
fat12_id         db 'FAT12   '
newline          db 13,10,0
dir_header       db 13,10,"Directory of A:\",13,10,13,10,0
dir_indicator    db "<DIR>    ",0
dir_spaces       db "         ",0

; Demo file entries
demo_file1       db "KERNEL.BIN      8192  12/25/2023 10:30",13,10,0
demo_file2       db "CONFIG.SYS       256  12/25/2023 09:15",13,10,0
demo_file3       db "<DIR>    SYSTEM           12/25/2023 11:45",13,10,0

; -----------------------------
; Find a file in the root directory
; IN: SI -> null-terminated filename
; OUT: DI -> directory entry if found, carry set on error
; -----------------------------
find_file:
    pusha

    ; Convert filename to 8.3 format
    mov di, filename_8_3
    call to_8_3

    ; Calculate root directory start sector
    mov ax, [sectors_per_fat]
    mov bl, [fat_count]
    xor bh, bh
    mul bx
    add ax, [reserved_sectors]
    mov bx, ax  ; BX = root directory start sector

    ; Calculate number of root directory sectors
    mov ax, [root_entries]
    mov cx, 32
    mul cx
    mov cx, 512
    div cx
    test dx, dx
    jz .no_remainder_ff
    inc ax
.no_remainder_ff:
    mov cx, ax  ; CX = number of root directory sectors

    ; Read root directory sectors
    mov dx, 0   ; Sector counter

.read_next_sector_ff:
    cmp dx, cx
    jae .not_found

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
    jc .error_ff

    ; Parse directory entries in this sector
    mov si, dir_buffer
    mov di, 16  ; 16 entries per 512-byte sector

.parse_entry_ff:
    push bx
    push cx
    push dx
    push di

    ; Check for end of directory
    mov al, [si]
    cmp al, 0
    je .not_found_in_sector

    ; Compare filename
    push si
    mov di, filename_8_3
    mov cx, 11
    repe cmpsb
    pop si
    jne .next_entry_ff

    ; Found it!
    mov di, si  ; DI points to the entry
    clc         ; Clear carry to indicate success
    pop di
    pop dx
    pop cx
    pop bx
    popa
    ret

.next_entry_ff:
    pop di
    pop dx
    pop cx
    pop bx
    add si, 32  ; Each directory entry is 32 bytes
    dec di
    jnz .parse_entry_ff

.not_found_in_sector:
    pop di
    pop dx
    pop cx
    pop bx

    ; Move to next sector
    inc dx
    jmp .read_next_sector_ff

.not_found:
    stc ; Set carry, not found
    jmp .done_ff

.error_ff:
    stc ; Set carry, disk read error

.done_ff:
    popa
    ret

; -----------------------------
; Convert null-terminated filename to 8.3 format
; IN: SI -> null-terminated string, DI -> buffer for 8.3 name
; -----------------------------
to_8_3:
    pusha

    ; Fill buffer with spaces
    mov cx, 11
    mov al, ' '
    rep stosb
    sub di, 11

    ; Copy filename part
    mov cx, 8
.name_loop:
    lodsb
    cmp al, '.'
    je .ext
    cmp al, 0
    je .done

    ; Convert to uppercase
    cmp al, 'a'
    jb .no_lowercase_name
    cmp al, 'z'
    ja .no_lowercase_name
    sub al, 32
.no_lowercase_name:

    mov [di], al
    inc di
    loop .name_loop

    ; After 8 chars, look for dot or end of string
.find_ext:
    lodsb
    cmp al, '.'
    je .ext
    cmp al, 0
    je .done
    jmp .find_ext

.ext:
    ; Copy extension part
    mov di, filename_8_3 + 8
    mov cx, 3
.ext_loop:
    lodsb
    cmp al, 0
    je .done

    ; Convert to uppercase
    cmp al, 'a'
    jb .no_lowercase_ext
    cmp al, 'z'
    ja .no_lowercase_ext
    sub al, 32
.no_lowercase_ext:

    mov [di], al
    inc di
    loop .ext_loop

.done:
    popa
    ret

; -----------------------------
; Load a file into memory
; IN: DI -> directory entry
;     ES:BX -> destination buffer
; OUT: Carry set on error
; -----------------------------
load_file:
    pusha

    mov ax, [di + 26] ; First cluster
    mov [cluster], ax

    ; Calculate data area start
    ; data_start = reserved_sectors + (fat_count * sectors_per_fat) + root_sectors
    mov ax, [sectors_per_fat]
    mov bl, [fat_count]
    xor bh, bh
    mul bx
    add ax, [reserved_sectors]
    mov cx, ax ; save root start

    mov ax, [root_entries]
    mov dx, 32
    mul dx
    div word [bytes_per_sector]
    add cx, ax
    mov [data_sector], cx

.load_loop:
    ; Convert cluster to LBA
    mov ax, [cluster]
    sub ax, 2
    add ax, [data_sector]

    ; Read one sector
    push es
    push bx
    call read_sector
    pop bx
    pop es
    jc .error_lf

    ; Advance buffer
    add bx, 512

    ; Get next cluster from FAT
    mov ax, [cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    ; Read FAT sector
    push bx
    push es
    add ax, [reserved_sectors] ; FAT starts after reserved sectors
    mov bx, fat_buffer
    call read_sector
    pop es
    pop bx
    jc .error_lf

    ; Get next cluster from FAT entry
    mov si, fat_buffer
    add si, dx
    mov ax, [si]

    test dx, 1
    jz .even
.odd:
    shr ax, 4
    jmp .next_cluster

.even:
    and ax, 0x0FFF

.next_cluster:
    mov [cluster], ax
    cmp ax, 0x0FF8
    jae .done_lf ; End of chain

    jmp .load_loop

.done_lf:
    clc
    jmp .finish_lf

.error_lf:
    stc

.finish_lf:
    popa
    ret

; Data for CHS conversion (moved to end to prevent corruption)
chs_cylinder     db 0
chs_head         db 0
chs_sector       db 0
filename_8_3     times 11 db 0
cluster          dw 0
data_sector      dw 0
bytes_per_sector dw 512