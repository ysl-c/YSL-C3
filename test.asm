jmp __func__main
__func__putch:
 mov ah, 0x0E
 mov al, [sp]
 int 0x10
mov sp, bp
pop bp
ret
__func__add_u8:
 mov al, [bp]
 mov bl, [bp + 1]
 add al, bl
mov sp, bp
pop bp
ret
__func__main:
push byte 0
push word 65
pop ax
mov [bp + 0], al
push bp
mov bp, sp
push byte [bp + 0]
call __func__putch
mov sp, bp
pop bp
ret
