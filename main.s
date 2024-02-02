D_WAITRASTER = $50

	incdir	ZPRJ:fc/

	section main,code_c

	bra	main

	include custom.i
	include startup.s
	include FC1.4replay.S

main:

	bsr	Start

	lea	module,a0
	jsr	INIT_MUSIC

	move.l	VectorBaseRegister(pc),a0
	move.l	#IntLevel3Handler,$6c(a0)

	lea	CUSTOM,a6
	move.w	#$8200,DMACON(a6)
	move.w	#$c020,INTENA(a6)
.l:

	*move.w	#$100,d0
	*bsr	WaitRaster

	*move.w	#$f00,$dff180
	*jsr	PLAY_MUSIC
	*move.w	#0,$dff180

	btst	#6,$bfe001
	bne	.l

	jsr	END_MUSIC

	bra	Quit

Player:
	move.w	#D_WAITRASTER,d0
	bsr	WaitRaster

	move.w	#$0f0,$dff180
	jsr	PLAY_MUSIC
	move.w	#$000,$dff180

	bsr	GetRasterPosition
	sub.w	#D_WAITRASTER,d0
	lea	MaxRasterTime(pc),a0
	move.w	(a0),d1
	cmp.w	d0,d1
	bge	.ok
	move.w	d0,(a0)
.ok:
	rts

MaxRasterTime:
	dc.w	0

IntLevel3Handler:

	movem.l	d0-a6,-(a7)

	lea	CUSTOM,a6
	move.w	INTREQR(a6),d0
	btst	#5,d0
	beq.b	.skipVertb

	move.w	#$20,d0
	move.w	d0,INTREQ(a6)	;twice for A4000 compatibility
	move.w	d0,INTREQ(a6)

	bsr	Player

.skipVertb:

	movem.l	(a7)+,d0-a6
	rte

;;; **********************************************

WaitVBlank:
.l1:
	tst.b	CUSTOM+VPOSR+1
	beq.b	.l1
.l2:
	tst.b	CUSTOM+VPOSR+1
	bne.b	.l2
	rts

;;; in: d0 - raster value
WaitRaster:
.l:
	move.l CUSTOM+VPOSR,d1
	lsr.l #1,d1
	lsr.w #7,d1
	cmp.w d0,d1
	bne.s .l			;wait until it matches (eq)
	rts

;;; out: d0 - raster number
GetRasterPosition:
	move.l CUSTOM+VPOSR,d0
	lsr.l #1,d0
	lsr.w #7,d0
	rts

;;; in: a6 - $dff000
WaitBlitter:				;wait until blitter is finished
	tst.w	(a6)			;for compatibility with A1000
.loop:
	btst	#6,2(a6)
	bne.s	.loop
	rts

;;; **********************************************

module:
	incbin ice2
