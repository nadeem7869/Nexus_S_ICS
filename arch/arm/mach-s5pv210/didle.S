/*
 * arch/arm/mach-s5pv210/didle.S 
 * 
 * Copyright (c) Samsung Electronics Co. Ltd
 *
 * S5PV210 CPU driver helper functions
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 */
#include <linux/linkage.h>
#include <linux/init.h>
#include <asm/assembler.h>
#include <mach/regs-clock.h>
#include <mach/map.h>

#define NO_L2_CLEAN
/*
 *	v7_flush_l1_dcache()
 *
 *	Flush the L1 D-cache.
 *
 *
 */
ENTRY(v7_flush_l1_dcache)
	dmb					@ ensure ordering with previous memory accesses
	mrc	p15, 1, r0, c0, c0, 1		@ read clidr
	ands	r3, r0, #0x7000000		@ extract loc from clidr
	mov	r3, r3, lsr #23			@ left align loc bit field
	beq	finished			@ if loc is 0, then no need to clean
	mov	r10, #0				@ start clean at cache level 0
loop1:
	add	r2, r10, r10, lsr #1		@ work out 3x current cache level
	mov	r1, r0, lsr r2			@ extract cache type bits from clidr
	and	r1, r1, #7			@ mask of the bits for current cache only
	cmp	r1, #2				@ see what cache we have at this level
	blt	skip				@ skip if no cache, or just i-cache
	mcr	p15, 2, r10, c0, c0, 0		@ select current cache level in cssr
	isb					@ isb to sych the new cssr&csidr
	mrc	p15, 1, r1, c0, c0, 0		@ read the new csidr
	and	r2, r1, #7			@ extract the length of the cache lines
	add	r2, r2, #4			@ add 4 (line length offset)
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		@ find maximum number on the way size
	clz	r5, r4				@ find bit position of way size increment
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		@ extract max number of the index size
loop2:
	mov	r9, r4				@ create working copy of max way size
loop3:
	orr	r11, r10, r9, lsl r5		@ factor way and cache number into r11
	orr	r11, r11, r7, lsl r2		@ factor index number into r11
	mcr	p15, 0, r11, c7, c14, 2		@ clean & invalidate by set/way
@	mcr	p15, 0, r11, c7, c10, 2		@ clean by set/way
	subs	r9, r9, #1			@ decrement the way
	bge	loop3
	subs	r7, r7, #1			@ decrement the index
	bge	loop2
skip:
#if !defined(NO_L2_CLEAN)
	add	r10, r10, #2			@ increment cache number
	cmp	r3, r10
	bgt	loop1
#endif	
finished:
	mov	r10, #0				@ swith back to cache level 0
	mcr	p15, 2, r10, c0, c0, 0		@ select current cache level in cssr
	dsb
	isb
	mov	pc, lr
ENDPROC(v7_flush_l1_dcache)

ENTRY(v7_flush_cache_for_didle)
	stmfd	sp!, {r4-r5, r7, r9-r11, lr}
	bl	v7_flush_l1_dcache
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ I+BTB cache invalidate
	ldmfd	sp!, {r4-r5, r7, r9-r11, lr}
	mov	pc, lr
ENDPROC(v7_flush_cache_for_didle)

ENTRY(s5p_didle)
	stmfd	sp!, {r4-r5, r7, r9-r11, lr}

	bl	v7_flush_cache_for_didle

	ldmfd	sp!, {r4-r5, r7, r9-r11, lr}
	dmb
	dsb
	wfi
	
	b	.

ENDPROC(s5p_didle)
