DEF_COUNTERS = 1

	incdir	ZPRJ:fc/

	section main,code_c

	bra	main

	include startup.s
	include FC1.4replay.S
	
main:
	bsr	Init

	lea	module,a0
	jsr	INIT_MUSIC
	
	move.l	#player,pVertbInt

	move.w	#$8200,$dff096
	move.w	#$c020,$dff09a
.l:

	bsr	WaitVBlank	
	
*	move.w	#$100,d0
*	bsr	WaitRaster

*	move.w	#$f00,$dff180
*	jsr	PLAY_MUSIC	
*	move.w	#0,$dff180
	
	btst	#6,$bfe001
	bne	.l
	
	jsr	END_MUSIC
	
	bra	Quit
	
player:
	move.w	#$50,d0
	bsr	WaitRaster	
	
	move.w	#$0f0,$dff180
	jsr	PLAY_MUSIC
	move.w	#$000,$dff180
	rts
	
module:	
	incbin ice2
