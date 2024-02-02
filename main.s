;;; -*- coding: cp852 -*-
	incdir ZPRJ:fc/

	section main,code_c

	bra	Main

	include custom.i
	include startup.s
	include FC1.4replay.S

D_PlayerWaitRaster = $50
D_FontQuantity = 80
D_FontWidthInBytes = 1	
D_FontHeight = 8
D_FontBitmapWidthInBytes = 40
D_FontBitmapHeight = 16
D_FontBitplaneSize = D_FontBitmapWidthInBytes*D_FontBitmapHeight
D_FontBitplanes = 3
D_ScreenWidth = 320
D_ScreenWidthInBytes = (D_ScreenWidth/8)
D_ScreenHeight = 8
D_ScreenBitplaneSize = D_ScreenWidthInBytes*D_ScreenHeight
D_ScreenBitplanes = 3	
D_BackgroundColor = $000
	
Main:
	bsr	Start

	lea	Module(pc),a0
	jsr	INIT_MUSIC

	move.l	VectorBaseRegister(pc),a0
	move.l	#IntLevel3Handler,$6c(a0)

	bsr	InitCopper
	bsr	InitFontPtrs

	lea	Message1(pc),a1
	bsr	GetTextLen
	move.w	d7,-(a7)
	lea	MessageScreen(pc),a0
	bsr	WriteTextLine
	
	lea	Message2(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	(a7)+,a0
	adda.w	#2,a0
	bsr	WriteTextLine
	
	
	lea	CUSTOM,a6
	move.w	#$83e0,DMACON(a6)
	move.w	#$c010,INTENA(a6)

	lea	Copper(pc),a0
	move.l	a0,COP1LCH(a6)
	move.w	#0,COP1JMP(a6)
	
.loop:

	move.w	#$100,d0
	bsr	WaitRaster

	move.w	PlayerMaxRasterTime(pc),d0
	bsr	HexToDec

	lea	Message1(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	d7,a0
	bsr	WriteDecValue
	
	btst	#6,$bfe001
	bne	.loop

	jsr	END_MUSIC
	bra	Quit

Player:
	move.w	#$0f0,$dff180
	jsr	PLAY_MUSIC
	move.w	#D_BackgroundColor,$dff180

	bsr	GetRasterPosition
	sub.w	#D_PlayerWaitRaster,d0
	lea	PlayerMaxRasterTime(pc),a0
	move.w	(a0),d1
	cmp.w	d0,d1
	bge	.ok
	move.w	d0,(a0)
.ok:
	rts

PlayerMaxRasterTime:
	dc.w	0

IntLevel3Handler:

	movem.l	d0-a6,-(a7)

	lea	CUSTOM,a6
	move.w	INTREQR(a6),d0
	btst	#4,d0
	beq.b	.skipCopper

	move.w	#$10,d0
	move.w	d0,INTREQ(a6)	;twice for A4000 compatibility
	move.w	d0,INTREQ(a6)

	bsr	Player

.skipCopper:

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

InitCopper:
	lea	MessageScreen(pc),a0
	lea	CopperBitplanes(pc),a1
	moveq	#D_ScreenBitplanes-1,d7
.l:
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	lea	D_ScreenBitplaneSize(a0),a0
	adda.w	#8,a1
	dbf	d7,.l
	rts
	
InitFontPtrs:	
	lea	Font(pc),a0		
	lea	FontPtrs(pc),a1
	moveq	#2-1,d7
.l1:
	moveq	#D_FontBitmapWidthInBytes-1,d6
	move.l	a0,a2
.l2:
	move.l	a2,(a1)+
	adda.w	#1,a2
	dbf	d6,.l2
	adda.w	#D_FontBitmapWidthInBytes*D_FontHeight,a0
	dbf	d7,.l1
	rts

;;; a0 - screen
;;; a1 - text
;;; d7 - text len
WriteTextLine:
	subq.w	#1,d7
.l:
	moveq	#0,d0
	move.b	(a1)+,d0
	bsr.s	PutFontChar
	adda.w	#1,a0
	dbf	d7,.l
	rts

;;; a0 - screen
;;; d0 - dec value
WriteDecValue:	
	move.w	d0,d1
	and.b	#$f0,d0
	lsr.b	#4,d0
	add.b	#'0',d0
	bsr.s	PutFontChar

	addq.w	#1,a0
	move.b	d1,d0
	
	and.b	#$0f,d0
	add.b	#'0',d0
	bsr.s	PutFontChar
	rts
	
;;; a0 - screen
;;; d0.w - char
PutFontChar:
	lea	FontCodePage852(pc),a2
	move.b	(a2,d0.w),d0
	add.w	d0,d0
	add.w	d0,d0
	lea	FontPtrs(pc),a2
	move.l	(a2,d0.w),a2

	move.l	a0,a3
	
	REPT	D_FontBitplanes
	move.b	(D_FontBitmapWidthInBytes*0)(a2),(D_ScreenWidthInBytes*0)(a3)
	move.b	(D_FontBitmapWidthInBytes*1)(a2),(D_ScreenWidthInBytes*1)(a3)
	move.b	(D_FontBitmapWidthInBytes*2)(a2),(D_ScreenWidthInBytes*2)(a3)
	move.b	(D_FontBitmapWidthInBytes*3)(a2),(D_ScreenWidthInBytes*3)(a3)
	move.b	(D_FontBitmapWidthInBytes*4)(a2),(D_ScreenWidthInBytes*4)(a3)
	move.b	(D_FontBitmapWidthInBytes*5)(a2),(D_ScreenWidthInBytes*5)(a3)
	move.b	(D_FontBitmapWidthInBytes*6)(a2),(D_ScreenWidthInBytes*6)(a3)
	move.b	(D_FontBitmapWidthInBytes*7)(a2),(D_ScreenWidthInBytes*7)(a3)
	lea	D_FontBitplaneSize(a2),a2
	lea	D_ScreenBitplaneSize(a3),a3
	ENDR
	rts
	
;;; in: a1 - text
;;; out: d7 - length
GetTextLen:
	move.l	a1,a2
.l:
	tst.b	(a2)+
	bne.s	.l
	move.l	a2,d7
	sub.l	a1,d7
	subq.w	#1,d7
	rts

;;; in: d0 - value to convert
;;; out: d0 - result
HexToDec:
	lea	HexToDecTable(pc),a0

	move.w	d0,d1
	lsr.w	#4,d1
	move.b	(a0,d1.w),d1
	mulu	#$16,d1

	and.w	#$0f,d0
	move.b	(a0,d0.w),d0
	add.w	d1,d0
	rts
	
;;; **********************************************
HexToDecTable:	dc.b	0,1,2,3,4,5,6,7,8,9,$10,$11,$12,$13,$14,$15
	
Message1:	dc.b	"RASTER TIME PLAYERA: ",0
Message2:	dc.b	" RASTR‡W",0
	EVEN
	
FontCodePage852:	
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 00,01,00,00,00,00,00,07,00,00,00,11,12,13,14,34
	;;      !  "  #  $  %  &  '  (  )  *  +  ,  -  .  /
	dc.b 16,17,18,19,20,21,22,23,24,25,26,27,00,00,00,31
	;;   0  1  2  3  4  5  6  7  8  9  :  ;  <  =  >  ?
	dc.b 00,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47
	;;   @  A  B  C  D  E  F  G  H  I  J  K  L  M  N  O
	dc.b 48,49,50,51,52,53,54,55,56,57,58,00,00,00,00,00
	;;   P  Q  R  S  T  U  V  W  X  Y  Z  [  \  ]  ^  _
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;;   `  a  b  c  d  e  f  g  h  i  j  k  l  m  n  o
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;;   p  q  r  s  t  u  v  w  x  y  z  {  |  }  ~  
	dc.b 00,00,00,00,00,00,03,00,00,00,00,00,00,10,00,03
	;;                     Ü     à              ç     è
	dc.b 00,00,00,00,00,00,00,09,00,00,00,00,00,05,00,00
	;;                        ó  ò              ù
	dc.b 00,00,00,00,02,00,00,00,04,00,00,00,00,00,00,00
	;;         ¢     §  •        ®  ©     ´
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,15,00,00
	;;                                          Ω  æ
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 08,00,00,06,00,00,00,00,00,00,00,00,00,00,00,00
	;;   ‡        „  ‰
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	
Copper:
	dc.w	$96,$20
	dc.w	$1fc,0			;Slow fetch mode, remove if AGA demo.
	dc.w	$106,$0c00		;(AGA compat. if any Dual Playf. mode)

	dc.w	$8e,$2c81		;238h display window top, left
	dc.w	$90,$2cc1		;and bottom, right.
	dc.w	$92,$38			;Standard bitplane dma fetch start
	dc.w	$94,$d0			;and stop for standard screen.

	dc.w	$108,0
	dc.w	$10a,0
	dc.w	$102,0			;Scroll register (and playfield pri)

	;; colors
	dc.w	$0180,D_BackgroundColor
	dc.w	$0182,$0400,$0184,$0a50,$0186,$0b70
	dc.w	$0188,$0c90,$018a,$0ec0,$018c,$0820,$018e,$0610

	dc.w	$100,$200

	dc.w	D_PlayerWaitRaster*$100+7,$fffe
	dc.w	$9c,$8010		; int request
	
	dc.w	$e007,$fffe
	
CopperBitplanes:
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$e4,0
	dc.w	$e6,0
	dc.w	$e8,0
	dc.w	$ea,0

	dc.w	$100,$3200

	dc.w	$e807,$fffe

	dc.w	$100,$200
	
	dc.w	$ffdf,$fffe		;allow VPOS>$ff
	dc.w	$ffff,$fffe		;magic value to end copperlist

Module:
	incbin	ice2
Font:
	incbin	font8x8.raw
FontPtrs:
	ds.l	D_FontQuantity
MessageScreen:
	ds.b	D_FontBitplaneSize*D_ScreenBitplanes

