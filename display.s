/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007-2010 Stuart Carnie
 See gpl.txt for license information.
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
.set device, 0
.set device, __arm__

.if device

// .section __TEXT, __groupme

.globl _create_bgra, _create_bgrx5551
.code 32
.align 2
.text

/*
 * INPUT:
 * r0 = dst
 * r1 = size ( in pixels )
 * r2 = src
 * r3 = palette
 */

_create_bgra:
	stmfd	sp!, {r4-r10, lr}
	
	mov		r1, r1, lsr #2			@ divide by 4, since we're working with 4 x 1 RGBA pixel = 16 bytes per iteration
	mov		r10, #255
	
loop:
	ldr		r8, [r2], #4

	and		r9, r8, #255			@ first byte from buffer
	ldr		r4, [r3, r9, lsl #2]
	
	and		r9, r8, r10, lsl #8
	ldr		r5, [r3, r9, lsr #6]
	
	and		r9, r8, r10, lsl #16
	ldr		r6, [r3, r9, lsr #14]
	
	and		r9, r8, r10, lsl #24
	ldr		r7, [r3, r9, lsr #22]
	
	stmia	r0!, {r4-r7}
	subs	r1, r1, #1
	bne		loop
	
	ldmfd	sp!, {r4-r10, pc}		@ return	


/*
 * INPUT:
 * r0 = dst
 * r1 = size ( in pixels )
 * r2 = src
 * r3 = palette
 */

_create_bgrx5551:
	stmfd	sp!, {r4-r10, lr}
	
	ldr		r10, AAA
	mov		r7, #255
	mov		r6, #0

__loop2:
	ldr		r8, [r2], #4
	and		r9, r8, #255
	ldr		r4, [r3, r9, lsl #1]

	and		r9, r8, r7, lsl #8
	ldr		r6, [r3, r9, lsr #7]
	and		r4, r4, r10
	orr		r4, r4, r6, lsl #16
			 
	and		r9, r8, r7, lsl #16
	ldr		r5, [r3, r9, lsr #15]
	
	and		r9, r8, r7, lsl #24
	ldr		r6, [r3, r9, lsr #23]
	and		r5, r5, r10
	orr		r5, r5, r6, lsl #16
			 
	stmia	r0!, {r4, r5}
	subs	r1, r1, #1
	bne		__loop2
	
	ldmfd	sp!, {r4-r10, pc}		@ return
	
AAA:	
	.long 0x0000FFFF

.endif