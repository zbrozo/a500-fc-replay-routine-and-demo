D_WAITRASTER = $50

	incdir	ZPRJ:fc/

	section main,code_c

	bra	main

	include custom.i
	include startup.s
	include FC1.4replay.S
	
main:

	bsr	Init

	lea	module,a0
	jsr	INIT_MUSIC
	
	move.l	VectorBaseRegister(pc),a0
	move.l	#IntLevel3Handler,$6c(a0)

	move.l	#Player,pVertbInt

	move.w	#$8200,$dff096
	move.w	#$c020,$dff09a
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

	bsr	GetRaster
	sub.w	#D_WAITRASTER,d0
	lea	MaxRasterTime(pc),a0
	move.w	(a0),d1
	cmp.w	d0,d1
	bge	.ok
	move.w	d0,(a0)
.ok:
	rts

IntLevel3Handler:

	movem.l	d0-a6,-(a7)

	lea	CUSTOM,a6
	move.w	INTREQR(a6),d0
	btst	#5,d0
	beq.b	.skipVertb	

	move.w	#$20,d0
	move.w	d0,INTREQ(a6)	;twice for A4000 compatibility
	move.w	d0,INTREQ(a6)

	move.l	pVertbInt(pc),a0
	jsr	(a0)
	
.skipVertb:

	movem.l	(a7)+,d0-a6
	rte

;;; **********************************************

MaxRasterTime:
	dc.w	0

WaitVBlank:
.l1:
	tst.b	$dff005
	beq.b	.l1
.l2:
	tst.b	$dff005
	bne.b	.l2
	rts	

; in: d0 - raster value
WaitRaster:				
.l:
	move.l $dff004,d1
	lsr.l #1,d1
	lsr.w #7,d1
	cmp.w d0,d1
	bne.s .l			;wait until it matches (eq)
	rts

GetRaster: 				
	move.l $dff004,d0
	lsr.l #1,d0
	lsr.w #7,d0
	rts
	
WaitBlitter:				;wait until blitter is finished
	tst.w 	(a6)			;for compatibility with A1000
.loop:
	btst 	#6,2(a6)
	bne.s 	.loop
	rts

;;; **********************************************
ClearCounters:
	move.w	#0,d0
	move.w	d0,FrameCounter
	move.w	d0,BlitCounter
	move.w	d0,CopCounter
	rts
	
CountMaxFrames:
        move.w	FrameCounter(pc),d0           
	lea	MaxFrameCounter(pc),a0
        cmp.w   (a0),d0
        blt     .skip
        move.w  d0,(a0)
.skip:
        rts

FrameCounter:   
	dc.w	0
MaxFrameCounter:
        dc.w    0
BlitCounter:
        dc.w    0
CopCounter:
        dc.w    0

;;; **********************************************

pVertbInt:
	dc.l	NullHandler
pBlitterInt:
	dc.l	NullHandler
pCopperInt:
	dc.l	NullHandler

None:
NullHandler:
	rts

;;; **********************************************
	
ReadFrames:
        lea     $bfe001,a0
        moveq   #0,d0
        move.b  $a00(a0),d0             ; TODHI
        lsl.w   #8,d0
        move.b  $900(a0),d0             ; TODMID
        lsl.l   #8,d0
        move.b  $800(a0),d0             ; TODLO
	rts

;;; **********************************************
	
module:	
	incbin ice2
