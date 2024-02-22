;;; -*- coding: cp852 -*-
;;; Example demo with refactored FutureComposer1.4 replay routine and equalizers
;;; Coded by Bishop/Turnips 2024

	incdir ZPRJ:fc/

	section main,code_c

	bra	Main

	include custom.i
	include startup.s
	include FC1.4replay.S

D_PlayerWaitRaster = $50
D_FontCharsX = 40
D_FontCharsY = 2
D_FontQuantity = D_FontCharsX*D_FontCharsY
D_FontBitplanes = 3
D_FontWidthInBytes = 1
D_FontHeight = 8
D_FontBitmapWidthInBytes = 40
D_FontBitmapHeight = D_FontHeight*D_FontBitplanes
D_FontBitplaneSize = D_FontBitmapWidthInBytes*D_FontBitmapHeight
	
D_ScreenWidth = 320
D_ScreenWidthInBytes = (D_ScreenWidth/8)
D_ScreenHeight = 8*3
D_ScreenBitplaneSize = D_ScreenWidthInBytes*D_ScreenHeight
D_ScreenBitplanes = 3	

D_MessageLineSize = D_ScreenWidthInBytes*D_FontHeight*D_FontBitplanes
	
D_EqScreenHeight = 64
D_EqScreenWidth = 320
D_EqScreenWidthInBytes = D_EqScreenWidth/8	
D_EqScreenSize = D_EqScreenWidthInBytes*D_EqScreenHeight
	
D_BackgroundColor = $000
	
Main:
	bsr	Start

	lea	Module(pc),a0
	jsr	INIT_MUSIC

	move.l	VectorBaseRegister(pc),a0
	move.l	#IntLevel3Handler,$6c(a0)

	bsr	InitCopper
	bsr	InitFontPtrs
	bsr	ClearScreens
	
	lea	Message1(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	bsr	WriteTextLine

	lea	Message2(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	#D_MessageLineSize,a0
	bsr	WriteTextLine

	lea	Message3(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	#D_MessageLineSize*2,a0
	bsr	WriteTextLine
	
	lea	CUSTOM,a6
	move.w	#$83e0,DMACON(a6)
	move.w	#$c010,INTENA(a6)

	lea	Copper(pc),a0
	move.l	a0,COP1LCH(a6)
	
.loop:

	move.w	#$100,d0
	bsr	WaitRaster

	lea	PlayerTimes(pc),a5
	move.w	PlayerTimeMin(a5),d0
	bsr	HexToDec
	lea	Message1(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	d7,a0
	bsr	WriteDecValue

	move.w	PlayerTimeMax(a5),d0
	bsr	HexToDec
	lea	Message2(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	#D_MessageLineSize,a0
	adda.w	d7,a0
	bsr	WriteDecValue

	subq.w	#1,PlayerTimeCurrDelay(a0)
	bpl.b	.ok
	move.w	#4,PlayerTimeCurrDelay(a0)
	
	move.w	PlayerTimeCurr(a5),d0
	bsr	HexToDec
	lea	Message3(pc),a1
	bsr	GetTextLen
	lea	MessageScreen(pc),a0
	adda.w	#D_MessageLineSize*2,a0
	adda.w	d7,a0
	bsr	WriteDecValue
.ok:
	
	bsr	Equalizer
	bsr	PeriodEqualizer
	
	btst	#6,$bfe001
	bne	.loop

	jsr	END_MUSIC
	bra	Quit

;;; **********************************************
	
Player:
	bsr	GetRasterPosition
	move.w	d0,-(a7)

	move.w	#$0f0,$dff180
	jsr	PLAY_MUSIC
	move.w	#D_BackgroundColor,$dff180

	bsr	GetRasterPosition
	sub.w	(a7)+,d0

	lea	PlayerTimes(pc),a0
	move.w	d0,PlayerTimeCurr(a0)

	move.w	PlayerTimeMin(a0),d1
	cmp.w	d0,d1
	ble	.okmin
	move.w	d0,PlayerTimeMin(a0)
.okmin:
	
	move.w	PlayerTimeMax(a0),d1
	cmp.w	d0,d1
	bge	.okmax
	move.w	d0,PlayerTimeMax(a0)
.okmax:
	rts

	rsreset
PlayerTimeMin:		rs.w	1
PlayerTimeMax:		rs.w	1
PlayerTimeCurr:		rs.w	1
PlayerTimeCurrDelay:	rs.w	1
PlayerTimes:
	dc.w	99
	dc.w	0
	dc.w	0
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
	lea	D_ScreenWidthInBytes(a0),a0
	adda.w	#8,a1
	dbf	d7,.l

	lea	EqualizerScreen(pc),a0
	lea	CopperEqualizer(pc),a1
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)

	lea	PeriodEqualizerScreen(pc),a0
	lea	CopperPeriodEqualizer(pc),a1
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	rts
	
InitFontPtrs:	
	lea	Font(pc),a0		
	lea	FontPtrs(pc),a1
	moveq	#D_FontCharsY-1,d7
.l1:
	moveq	#D_FontBitmapWidthInBytes/D_FontWidthInBytes-1,d6
	move.l	a0,a2
.l2:
	move.l	a2,(a1)+
	adda.w	#D_FontWidthInBytes,a2
	dbf	d6,.l2
	adda.w	#D_FontBitmapWidthInBytes*D_FontHeight*D_FontBitplanes,a0
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
	adda.w	#D_FontWidthInBytes,a0
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

	addq.w	#D_FontWidthInBytes,a0
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

.nr	set 	0
	REPT	D_FontBitplanes*D_FontHeight
	move.b	(D_FontBitmapWidthInBytes*.nr)(a2),(D_ScreenWidthInBytes*.nr)(a3)
.nr	set 	.nr+1
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

Equalizer:
	lea	FC_VoicesInfo(pc),a0
	lea	EqualizerScreen(pc),a1
	lea	.channels(pc),a2
	moveq	#FC_CHANNELS_NR-1,d7
.loop:
	move.w	FC_VOICE_Note(a0),d0
	add.w	FC_VOICE_Transpose(a0),d0

	move.w	(a2),d1
	cmp.w	d0,d1
	beq.s	.nosound

	move.w	d0,(a2)

	moveq	#D_EqScreenHeight,d6
	move.w	d6,2(a2)

	move.l	a1,a3
	move.w	d7,d0
	add.w	d0,d0
	adda.w	d0,a3

	move.w	#$fff0,d0
	subq.w	#1,d6
.draw:
	move.w	d0,(a3)
	lea	D_EqScreenWidthInBytes(a3),a3
	dbf	d6,.draw
	bra.s	.ok
	
.nosound:
	moveq	#0,d1
	move.w	2(a2),d1
	beq.s	.ok

	move.l	a1,a3
	move.w	d7,d0
	add.w	d0,d0
	adda.w	d0,a3

	moveq	#D_EqScreenHeight,d2
	sub.b	d1,d2
	mulu	#D_EqScreenWidthInBytes,d2
	adda.w	d2,a3
	
	move.w	#0,(a3)
	subq.w	#1,d1
	move.w	d1,2(a2)
	
.ok:
	lea	FC_VOICE_SIZE(a0),a0
	addq.w	#4,a2
	dbf	d7,.loop
	rts

.channels:
	;; note value, eq height
	dc.w	0,0
	dc.w	0,0
	dc.w	0,0
	dc.w	0,0

D_EQ_PERIODS = 40
PeriodEqualizer:
	bsr.s	PeriodEqualizerDecrease

	lea	FC_VoicesInfo(pc),a0
	lea	PeriodEqualizerScreen(pc),a1
	lea	PeriodsActivated(pc),a2
	moveq	#FC_CHANNELS_NR-1,d7
.channel:
	tst.b	FC_VOICE_Volume(a0)
	beq.s	.skip

 	move.w	FC_VOICE_Period(a0),d0
 	beq.s	.skip
 	sub.w	#FC_PERIOD_MIN,d0
	
 	mulu	#D_EQ_PERIODS,d0
 	divu	#FC_PERIOD_MAX-FC_PERIOD_MIN,d0
	
	move.b	d4,(a2,d0.w)

 	move.w	#D_EqScreenHeight-1,d6
	move.l	a1,a3
	adda.w	d0,a3
.draw:
 	move.b	#$fe,(a3)
 	lea	D_EqScreenWidthInBytes(a3),a3
 	dbf	d6,.draw
.skip:
	lea	FC_VOICE_SIZE(a0),a0
	dbf	d7,.channel
	rts
	
PeriodEqualizerDecrease:	
	lea	PeriodEqualizerScreen(pc),a1
	lea	PeriodsActivated(pc),a2
	move.w	#D_EqScreenHeight,d4
	moveq	#0,d5
	moveq	#D_EQ_PERIODS-1,d7
.loop:
	moveq	#0,d0
	move.b	(a2),d0
	beq.s	.next
	subq.b	#1,(a2)

	move.w	d4,d1
	sub.w	d0,d1

	mulu	#D_EqScreenWidthInBytes,d1
	move.b	d5,(a1,d1.w)
.next:
	addq.w	#1,a1
	addq.w	#1,a2
	dbf	d7,.loop
	rts
	
PeriodsActivated:
	blk.b	D_EQ_PERIODS,0

ClearScreens:

	lea	PeriodEqualizerScreen(pc),a0
	move.w	#D_EqScreenSize-1,d7
	moveq	#0,d0
.l1:
	move.b	d0,(a0)+
	dbf	d7,.l1

	lea	EqualizerScreen(pc),a0
	move.w	#D_EqScreenSize-1,d7
	moveq	#0,d0
.l2:
	move.b	d0,(a0)+
	dbf	d7,.l2

	lea	MessageScreen(pc),a0
	move.w	#D_ScreenBitplaneSize*D_ScreenBitplanes-1,d7
	moveq	#0,d0
.l3:
	move.b	d0,(a0)+
	dbf	d7,.l3
	
	rts
	
;;; **********************************************
HexToDecTable:	dc.b	0,1,2,3,4,5,6,7,8,9,$10,$11,$12,$13,$14,$15
	
Message1:	dc.b	"MINIMUM REPLAY RASTER TIME:",0
Message2:	dc.b	"MAXIMUM REPLAY RASTER TIME:",0
Message3:	dc.b	"CURRENT REPLAY RASTER TIME:",0
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
	;;                     †     ˆ                   
	dc.b 00,00,00,00,00,00,00,09,00,00,00,00,00,05,00,00
	;;                        —  ˜              
	dc.b 00,00,00,00,02,00,00,00,04,00,00,00,00,00,00,00
	;;         ¢     ¤  ¥        ¨  ©     «
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,15,00,00
	;;                                          ½  ¾
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
	;; 
	dc.b 08,00,00,06,00,00,00,00,00,00,00,00,00,00,00,00
	;;   à        ã  ä
	dc.b 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00

BPLCON_HIRES = $8000
BPLCON_COLOR = $200
	
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

	dc.w	$180,0
	
	dc.w	$3007,$fffe
CopperEqualizer:	
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$100,$1200
	dc.w	$182,$fff
	dc.w	$7007,$fffe
	
	dc.w	$0180,D_BackgroundColor

	dc.w 	$0182,$0fd3,$0184,$0f92,$0186,$0e72
	dc.w 	$0188,$0c50,$018a,$0a41,$018c,$0930,$018e,$0720
	
	dc.w	$100,0

	dc.w	D_PlayerWaitRaster*$100+7,$fffe
	dc.w	$9c,$8010		; int request
	
	dc.w	$d807,$fffe
	dc.w	$108,D_ScreenWidthInBytes*(D_ScreenBitplanes-1)
	dc.w	$10a,D_ScreenWidthInBytes*(D_ScreenBitplanes-1)
	
CopperBitplanes:
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$e4,0
	dc.w	$e6,0
	dc.w	$e8,0
	dc.w	$ea,0

	dc.w	$100,BPLCON_COLOR+D_FontBitplanes*$1000

	dc.w	$f007,$fffe

	dc.w	$108,0
	dc.w	$10a,0

CopperPeriodEqualizer:	
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$100,$1200
	dc.w	$182,$fff
	dc.w	$ffdf,$fffe		;allow VPOS>$ff
	dc.w	$3007,$fffe
	dc.w	$100,0
	dc.w	$ffff,$fffe		;magic value to end copperlist

Font:
	incbin	font1x1x3.rawblit
FontPtrs:
	ds.l	D_FontQuantity
MessageScreen:
	ds.b	D_ScreenBitplaneSize*D_ScreenBitplanes
EqualizerScreen:
	ds.b	D_EqScreenSize
PeriodEqualizerScreen:
	ds.b	D_EqScreenSize
	
Module:
	incbin ice2	
