;		   JUl 2024     Ported to FUJITSU FM TOWNS
;put into the public domain by Russell Nelson, nelson@crynwr.com

;we read the timer chip's counter zero.  It runs freely, counting down
;from 65535 to zero.  We sample the count coming in and subract the previous
;count.  Then we double it and add it to our timeout_counter.  When it overflows,
;then we've waited a tick of 27.5 ms.

timeout		dw	?		;number of ticks to wait.
timeout_counter	dw	?		;old counter zero value.
timeout_value	dw	?

	public	set_timeout
set_timeout:
;enter with ax = number of ticks (36.4 ticks per second).
	shl ax, 2		;TOWNS PIT counter0 freq is 307.2KHz PC/AT is 1.19318MHz make it 1/4
	inc	ax			;the first times out immediately.
	mov	cs:timeout,ax
	mov	cs:timeout_counter,0
	call	latch_timer
	mov	cs:timeout_value,ax
	ret

latch_timer:

	mov	al,0			;latch counter zero.
	out	46h,al			;pit control register
	in	al,40h			;read counter zero.
	mov	ah,al
	in	al,0040h		;pit counter zero
	xchg	ah,al
	ret

	public	do_timeout
do_timeout:
;call at *least* every 27.5ms when checking for timeout.  Returns nz
;if we haven't timed out yet.
	call	latch_timer
	xchg	ax,cs:timeout_value
	sub	ax,cs:timeout_value
	shl	ax,1			;keep timeout in increments of 27.5 ms.
	add	cs:timeout_counter,ax	;has the counter overflowed yet?
	jnc	do_timeout_1		;no.
	dec	cs:timeout		;Did we hit the timeout value yet?
	ret
do_timeout_1:
	or	sp,sp			;ensure nz.
	ret
