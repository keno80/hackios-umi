/*
 * umi CPU0 bring-up only. Append to the already initialized Linux ramoops
 * console at 0xb0000000..0xb0200000. Never touch its adjacent pmsg region.
 * No stack, allocation, calls, UART or firmware services. x9..x17/NZCV scratch;
 * use only at the reviewed startup boundaries where those registers are dead.
 * The caller supplies a physical or explicitly mapped, uncached address.
 */
.macro UMI_PUTC
	strb	w16, [x11, x12]
	add	x12, x12, #1
	cmp	x12, x17
	csel	x12, xzr, x12, eq
	add	x13, x13, #1
	cmp	x13, x17
	csel	x13, x17, x13, hi
.endmacro

.macro UMI_HEX
	and	w16, w16, #15
	add	w16, w16, #48
	add	w14, w16, #39
	cmp	w16, #57
	csel	w16, w14, w16, hi
	UMI_PUTC
.endmacro

/* Boot-args video ABI: [0x28]=frame buffer PA, [0x38]=row bytes, [0x48]=rows.
 * Paint band \slot (counted from the top, 1..15) with BGRA colour \colour while
 * the MMU is still off, so the phone screen itself carries the progress and no
 * reboot-and-read cycle is needed to learn whether the kernel started at all.
 * Scratch x11..x17 only; named labels so they cannot clash with the numeric
 * locals inside UMI_TRACE_BODY. Filled with 4-byte stores and the byte count
 * masked to 4, because a row pitch that is not a multiple of 8 would leave STP
 * misaligned and make an 8-byte countdown underflow into an endless loop. */
.macro UMI_BAND slot, colour, base
	ldr	x11, [\base, #0x28]
	cbz	x11, Lumi_band\slot\()_done
	ldr	x12, [\base, #0x38]
	ldr	x13, [\base, #0x48]
	lsr	x13, x13, #4
	cbz	x13, Lumi_band\slot\()_done
	mov	x15, #\slot
	mul	x14, x13, x15
	mul	x14, x14, x12
	add	x11, x11, x14
	mul	x13, x13, x12
	bic	x13, x13, #3
	cmp	x13, #4
	b.lo	Lumi_band\slot\()_done
	mov	w17, #(\colour & 0xffff)
	movk	w17, #((\colour >> 16) & 0xffff), lsl #16
Lumi_band\slot\()_loop:
	str	w17, [x11], #4
	subs	x13, x13, #4
	b.hi	Lumi_band\slot\()_loop
	dsb	sy
Lumi_band\slot\()_done:
.endmacro

/* x9=phase, x10=value, x11=console header. Preserve x0..x8, x18..x30. */
.macro UMI_TRACE_BODY
	cbz	x11, 9f
	ldr	w16, [x11]
	mov	w17, #0x4244
	movk	w17, #0x4347, lsl #16
	cmp	w16, w17
	b.ne	9f
	mov	x17, #0xfff4
	movk	x17, #0x1f, lsl #16
	ldr	w12, [x11, #4]
	ldr	w13, [x11, #8]
	cmp	x13, x17
	b.hi	9f
	cmp	x12, x13
	b.hi	9f
	cmp	x12, x17
	csel	x12, xzr, x12, eq
	add	x11, x11, #12
	adr	x14, Lumi_trace_prefix
1:
	ldrb	w16, [x14], #1
	cbz	w16, 2f
	UMI_PUTC
	b	1b
2:
	lsr	w16, w9, #4
	UMI_HEX
	mov	w16, w9
	UMI_HEX
	mov	w16, #32
	UMI_PUTC
	mov	x15, #60
3:
	lsr	x16, x10, x15
	UMI_HEX
	subs	x15, x15, #4
	b.ge	3b
	mov	w16, #10
	UMI_PUTC
	dsb	sy
	stur	w13, [x11, #-4]
	stur	w12, [x11, #-8]
	dsb	sy
9:
.endmacro

.macro UMI_TRACE
	mov	x9, $0
	mov	x10, $1
	mov	x11, #0xb0000000
	UMI_TRACE_BODY
.endmacro

/* C ABI wrapper: phase, value, console address. Leaf, no stack protector.
 * x3 is caller-saved. Mask IRQ/FIQ across each record so a timer observer
 * cannot interrupt another writer on CPU0. Restore the exact incoming DAIF.
 * The early assembly-only UMI_TRACE macro remains unchanged.
 */
.text
.align 2
.globl EXT(umi_early_trace)
LEXT(umi_early_trace)
	mrs	x3, daif
	msr	daifset, #3
	mov	x9, x0
	mov	x10, x1
	mov	x11, x2
	UMI_TRACE_BODY
	msr	daif, x3
	ret
Lumi_trace_prefix:
	.asciz	"\nUMI XNU "
.align 2
