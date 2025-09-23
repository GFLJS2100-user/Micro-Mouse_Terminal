[BITS 16]
[ORG 0x100]

start:
    mov si, msg
    call print_string
    retf

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

msg db "Hello from a .com file!", 13, 10, 0
