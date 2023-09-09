jmp __func__main
__func__sayA:
push bp
mov bp, sp
call __func__mov
call __func__mov
call __func__int
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
