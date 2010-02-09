.set device, 0
.set device,__arm__

.if device

.globl _draw_border

_draw_border:
    str r1, [r0]
    str r1, [r0, #4]
    mov	pc, lr

.endif