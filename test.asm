jmp __func__main
__func__sayA:
push bp
mov bp, sp
 mov ah, 0x0E
 mov al, 'A'
 int 0x10
mov sp, bp
pop bp
ret
__func__main:
push bp
mov bp, sp
call __func__sayA
mov sp, bp
pop bp
ret
