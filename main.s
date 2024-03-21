;;; -*- coding: cp852 -*-
;;; Demo with refactored FutureComposer1.4 replay routine and equalizers
;;; Coded by Zbrozo aka Bishop/Turnips 2024
;;;-------------------------------------------------------------------

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
D_FontColors = 8
        
D_ScreenWidth = 320
D_ScreenWidthInBytes = (D_ScreenWidth/8)
D_ScreenHeight = 8*3
D_ScreenBitplaneSize = D_ScreenWidthInBytes*D_ScreenHeight
D_ScreenBitplanes = 3
D_ScreenOneline = D_ScreenBitplanes*D_ScreenWidthInBytes
        
D_MessageLineSize = D_ScreenWidthInBytes*D_FontHeight*D_FontBitplanes
D_MessageScreenSize = D_ScreenBitplaneSize*D_ScreenBitplanes

D_MenuEntries = 7
D_MenuRasterLines = D_MenuEntries*(D_FontHeight+1)
D_MenuScreenSize = (D_FontBitmapHeight*D_ScreenWidthInBytes+D_ScreenOneline)*D_MenuEntries
                    
D_EqScreenHeight = 64
D_EqScreenWidth = 320
D_EqScreenWidthInBytes = D_EqScreenWidth/8
D_EqScreenSize = D_EqScreenWidthInBytes*D_EqScreenHeight
D_EqFreqs = 40

D_BackgroundColor = $000

D_SpritePosX = 64
D_SpriteGapX = 1
D_SpriteHeight = 64
D_SpritePosY = $30+(D_SpriteHeight/2)
D_SpriteSize = (D_SpriteHeight+2)*4
             
Main:
	bsr	Start

	lea	Music1,a0
	jsr	INIT_MUSIC

	move.l	VectorBaseRegister(pc),a0
	move.l	#IntLevel3Handler,$6c(a0)

	bsr	InitCopper
	bsr	InitFontPtrs
        
        bsr     PrintMenu
        bsr     PrintReplayTimeMessages

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
	lea	MessageScreen,a0
	adda.w	d7,a0
	bsr	WriteDecValue

	move.w	PlayerTimeMax(a5),d0
	bsr	HexToDec
	lea	Message2(pc),a1
	bsr	GetTextLen
	lea	MessageScreen,a0
	adda.w	#D_MessageLineSize,a0
	adda.w	d7,a0
	bsr	WriteDecValue

	subq.w	#1,PlayerTimeCurrDelay(a5)
	bpl.b	.ok
	move.w	#4,PlayerTimeCurrDelay(a5)

	move.w	PlayerTimeCurr(a5),d0
	bsr	HexToDec
	lea	Message3(pc),a1
	bsr	GetTextLen
	lea	MessageScreen,a0
	adda.w	#D_MessageLineSize*2,a0
	adda.w	d7,a0
	bsr	WriteDecValue
.ok:

        bsr     SpriteEqualizer
        bsr	FreqsEqualizer
        bsr     MusicSelector
        
	btst	#6,$bfe001
	bne	.loop

        lea     MenuPos(pc),a0
        move.w  (a0),d0
        move.w  2(a0),d1
        cmp.w   d0,d1
        beq     .loop
        
        cmp.w   #D_MenuEntries-1,d0
        beq.s   .quit

        move.w  d0,2(a0)

        jsr	END_MUSIC
        
        lea     MusicPtrs(pc),a0
        lsl.w   #2,d0
        adda.w  d0,a0
        move.l  (a0),a0
        jsr     INIT_MUSIC
        bra     .loop
.quit:  
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
        bsr     InitSprites
        bsr     InitEqualizerSprites

        bsr     InitMessageBitplanes

        bsr     InitMenuBitplanes
        bsr     InitMenuBars
        bsr     InitMenuColors
        
	lea	ChannelsEqualizerScreen,a0
	lea	CopperChannelsEqualizer(pc),a1
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)

	lea	FreqsEqualizerScreen,a0
	lea	CopperFreqsEqualizer(pc),a1
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)

	rts
        
InitMessageBitplanes:   
        lea	MessageScreen,a0
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
        rts

InitMenuBitplanes: 
	lea	MenuScreen,a0
	lea	CopperMenuBitplanes(pc),a1
	moveq	#D_ScreenBitplanes-1,d7
.l:
	move.l	a0,d0
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	lea	D_ScreenWidthInBytes(a0),a0
	adda.w	#8,a1
	dbf	d7,.l
        rts
        
InitFontPtrs:
	lea	Font(pc),a0
	lea	FontPtrs,a1
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

InitSprites:
        lea     CopperSprites(pc),a0
        move.w  #$120,d0
        moveq   #15,d7
.sprites:     
        move.w  d0,(a0)
        addq.w  #4,a0
        addq.w  #2,d0
        dbf     d7,.sprites

	lea	CopperSprites(pc),a0
        lea     NullSprite(pc),a1
        moveq   #7,d7
.l:    
        move.l  a1,d0
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
        addq.w  #8,a0
        adda.w  #D_SpriteSize,a1	; next sprite
        dbf     d7,.l
        rts

InitEqualizerSprites:
	lea	CopperSprites(pc),a0
	lea     EqualizerSprites(pc),a1
        moveq   #3,d7
.l:     
        move.l  a1,d0
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)

        addq.w  #8,a0
        adda.w  #D_SpriteSize,a1	; next sprite
        dbf     d7,.l
	rts

InitMenuBars:
        lea     CopperMenuBars(pc),a0
        moveq   #D_MenuRasterLines-1,d7
        move.l  #$01800000,d0
        move.l  #$7107fffe,d1
        
        moveq   #0,d2
.loop:
        subq.w  #1,d2
        bpl.s   .ok
        move.w  #D_FontHeight,d2

        move.l  #$01820000,d3
        moveq   #D_FontColors-2,d6
.c:     move.l  d3,(a0)+
        add.l   #$00020000,d3
        dbf     d6,.c

.ok:    
        move.l  d0,(a0)+
        move.l  d1,(a0)+
        add.l   #$01000000,d1

        dbf     d7,.loop
        rts

InitMenuColors:
        lea     CopperMenuBars(pc),a0
        moveq   #D_MenuEntries-1,d6
.l:
        bsr.s   SetFontColors
        lea     (8*(D_FontHeight+1))(a0),a0
        dbf     d6,.l
        rts
        
SetFontColors:  
        lea     FontColors(pc),a1
        addq.w  #2,a1
        
        moveq   #D_FontColors-2,d7
.l:
        move.w  (a1)+,2(a0)
        addq.w  #4,a0
        dbf     d7,.l
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
	lea	FontPtrs,a2
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

SpriteEqualizer:
	lea	FC_VoicesInfo(pc),a0
        lea     EqualizerSprites(pc),a1
	lea	FC_PlayInfo(pc),a3
        moveq	#0,d6
        moveq   #3,d7
.l:     
        bsr     .changeChannel
        lea	FC_VOICE_SIZE(a0),a0
        lea     D_SpriteSize(a1),a1
        addq.b	#1,d6
        dbf     d7,.l
        rts

.changeChannel:
        move.w	FC_PlayInfo_ChannelBitMask(a3),d1
	btst	d6,d1
	beq.s	.nosound

	move.w	FC_VOICE_RepeatStartAndLengthDelay(a0),d1
	beq.s	.nosound

        move.b  #D_SpritePosY-(D_SpriteHeight/2),(a1)
        move.b  #D_SpritePosY+(D_SpriteHeight/2),2(a1)
	bra.s	.end
.nosound:       
        cmp.b	#D_SpritePosY-1,(a1)
	beq.s	.end
        
	add.b	#1,(a1)
	sub.b	#1,2(a1)
.end:   
        rts
        
; ChannelsEqualizer:
; 	lea	FC_VoicesInfo(pc),a0
; 	lea	ChannelsEqualizerScreen,a1
; 	lea	ChannelsEqualizerValues,a2
; 	lea	FC_PlayInfo(pc),a3
; 	moveq	#0,d6
; 	moveq	#FC_CHANNELS-1,d7
; .loop:

; 	move.w	FC_PlayInfo_ChannelBitMask(a3),d1
; 	btst	d6,d1
; 	beq.s	.nosound

; 	move.w	FC_VOICE_RepeatStartAndLengthDelay(a0),d1
; 	beq.s	.nosound

; 	moveq	#D_EqScreenHeight,d1
; 	move.b	d1,(a2)

; 	move.l	a1,a4
; 	move.w	d6,d0
; 	add.w	d0,d0
; 	adda.w	d0,a4

; 	move.w	#$fff0,d0
; 	subq.w	#1,d1
; .draw:
; 	move.w	d0,(a4)
; 	lea	D_EqScreenWidthInBytes(a4),a4
; 	dbf	d1,.draw
; 	bra.s	.ok

; .nosound:
; 	move.b	(a2),d1
; 	beq.s	.ok

; 	move.l	a1,a4
; 	move.w	d6,d0
; 	add.w	d0,d0
; 	adda.w	d0,a4

; 	moveq	#D_EqScreenHeight,d2
; 	sub.b	d1,d2
; 	mulu	#D_EqScreenWidthInBytes,d2
; 	adda.w	d2,a4
; 	move.w	#0,(a4)

; 	subq.b	#1,d1
; 	move.b	d1,(a2)
; .ok:
; 	lea	FC_VOICE_SIZE(a0),a0
; 	addq.b	#1,d6
; 	addq.w	#1,a2
; 	dbf	d7,.loop
; 	rts

FreqsEqualizer:
	bsr.s	FreqsEqualizerDecrease

	lea	FC_VoicesInfo(pc),a0
	lea	FreqsEqualizerScreen,a1
	lea	FreqsEqualizerValues(pc),a2
	lea	FC_PlayInfo(pc),a3

	moveq	#FC_CHANNELS-1,d7
	moveq	#0,d6
.channel:
	move.w	FC_PlayInfo_ChannelBitMask(a3),d0
	btst	d6,d0
	beq.s	.skip

	tst.b	FC_VOICE_Volume(a0)
	beq.s	.skip

 	move.w	FC_VOICE_Period(a0),d0
 	beq.s	.skip
 	sub.w	#FC_PERIOD_MIN,d0

 	mulu	#D_EqFreqs-1,d0
 	divu	#FC_PERIOD_MAX-FC_PERIOD_MIN,d0

	move.b	d4,(a2,d0.w)

 	move.w	#D_EqScreenHeight-1,d6
	move.l	a1,a5
	adda.w	d0,a5
	move.b	#$fe,d0
.draw:
 	move.b	d0,(a5)
 	lea	D_EqScreenWidthInBytes(a5),a5
 	dbf	d6,.draw
.skip:
	lea	FC_VOICE_SIZE(a0),a0
	addq.b	#1,d6
	dbf	d7,.channel
	rts

FreqsEqualizerDecrease:
	lea	FreqsEqualizerScreen,a1
	lea	FreqsEqualizerValues(pc),a2
	move.w	#D_EqScreenHeight,d4
	moveq	#0,d5
	moveq	#D_EqFreqs-1,d7
.loop:
	moveq	#0,d0
	move.b	(a2),d0
	beq.s	.next
	cmp.b	#1,d0
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

PrintReplayTimeMessages:
        lea	Message1(pc),a1
	bsr	GetTextLen
	lea	MessageScreen,a0
	bsr	WriteTextLine

	lea	Message2(pc),a1
	bsr	GetTextLen
	lea	MessageScreen,a0
	adda.w	#D_MessageLineSize,a0
	bsr	WriteTextLine

	lea	Message3(pc),a1
	bsr	GetTextLen
	lea	MessageScreen,a0
	adda.w	#D_MessageLineSize*2,a0
	bsr	WriteTextLine
        rts

PrintMenu:
        lea     MenuText(pc),a1
	lea	MenuScreen,a6
        adda.w  #D_ScreenOneline,a6
.loop:  
        tst.b   (a1)
        bne.s   .print
        rts
.print: 
        bsr     GetTextLen

        move.w  #40,d6
        sub.w   d7,d6
        lsr.w   #1,d6

        move.l  a6,a0
        adda.w  d6,a0
        
	bsr	WriteTextLine

        addq.w  #1,a1
        adda.w	#D_MessageLineSize+D_ScreenOneline,a6
        
        bra.s   .loop

MusicSelector:
        bsr.s   MenuClearBar
        bsr.s   MenuReadPosition
        bsr.s   MenuDrawBar
        rts

MenuClearBar:   
        lea     CopperMenuBars,a0
        adda.w  #D_FontColors*4,a0

        lea     MenuPos(pc),a1

        moveq   #0,d0
        move.w  (a1),d0
        mulu    #((D_FontColors-1)*4)+(8*9),d0
        adda.w  d0,a0
        
        moveq   #0,d0
        moveq   #7,d7
.clear:
        move.w  d0,6(a0)
        lea     8(a0),a0
        dbf     d7,.clear
        rts
        
MenuDrawBar:
        lea     CopperMenuBars(pc),a0
        lea     MenuPos(pc),a1
        moveq   #0,d0
        move.w  (a1),d0
        mulu    #((D_FontColors-1)*4)+(8*9),d0
        adda.w  d0,a0
        
        bsr     SetFontColors
        addq.w  #4,a0
        
        lea     MenuCols(pc),a1
        moveq   #7,d7
.loop:
        move.w  (a1)+,6(a0)
        lea     8(a0),a0
        dbf     d7,.loop
        rts
        
MenuReadPosition:
        lea     .delay(pc),a0
        subq.w  #1,(a0)
        bpl.s   .end
        move.w  #16,(a0)
        
        lea     MenuPos,a1
        lea     CUSTOM,a6
        move.w  JOY0DAT(a6),d0
        move.w  .mousePos(pc),a0
        move.w  (a0),d1
        move.w  d0,(a0)
        sub.w   d1,d0
        beq.s   .end
        bpl.s   .next
        
        tst.w   (a1)
        beq.s   .end
        subq.w  #1,(a1)
        bra.s   .end
 .next:   
        cmp.w   #D_MenuEntries-1,(a1)
        beq.s   .end
        addq.w  #1,(a1)
 .end:   
        rts
.delay: dc.w    0
.mousePos:
        dc.w    0
;;; **********************************************
HexToDecTable:	dc.b	0,1,2,3,4,5,6,7,8,9,$10,$11,$12,$13,$14,$15

Message1:	dc.b	"MINIMAL REPLAY RASTER TIME:",0
Message2:	dc.b	"MAXIMAL REPLAY RASTER TIME:",0
Message3:	dc.b	"CURRENT REPLAY RASTER TIME:",0
		EVEN

MenuCols:  	dc.w    $7,$a,$d,$f,$f,$d,$a,$7
MenuPos:        dc.w    0       	; 
                dc.w    0		; previous position
MenuText:
	dc.b	"MUSIC 1",0
	dc.b	"MUSIC 2",0
	dc.b	"MUSIC 3",0
	dc.b	"MUSIC 4",0
	dc.b	"MUSIC 5",0
	dc.b	"MUSIC 6",0
	dc.b	"EXIT DEMO",0
	dc.b	0
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
	dc.w	$1fc,0			
	dc.w	$106,$0c00		;(AGA compat. if any Dual Playf. mode)

	dc.w	$8e,$2c81		
	dc.w	$90,$2cc1		
	dc.w	$92,$38			
	dc.w	$94,$d0			

CopperSprites:
        blk.l   16,0
        
	dc.w	$108,0
	dc.w	$10a,0
	dc.w	$102,0		       

	dc.w	$180,0
        
        ;; sprite colors
	dc.w	$01a2,$fff
	dc.w	$01aa,$fff
        
	dc.w	$3007,$fffe
CopperChannelsEqualizer:
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$100,$1200
	dc.w	$182,$fff
        
	dc.w	$7007,$fffe
        
	dc.w	$108,D_ScreenWidthInBytes*(D_ScreenBitplanes-1)
	dc.w	$10a,D_ScreenWidthInBytes*(D_ScreenBitplanes-1)
        
CopperMenuBitplanes:
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$e4,0
	dc.w	$e6,0
	dc.w	$e8,0
	dc.w	$ea,0

        dc.w	$100,$3200

CopperMenuBars:
        blk.l   (D_MenuRasterLines*2)+(D_MenuEntries*(D_FontColors-1)),0

        dc.w    $100,0
        
        dc.w    $b007,$fffe
        
	*dc.w	D_PlayerWaitRaster*$100+7,$fffe
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

CopperFreqsEqualizer:
	dc.w	$e0,0
	dc.w	$e2,0
	dc.w	$100,$1200
	dc.w	$182,$fff
	dc.w	$ffdf,$fffe		;allow VPOS>$ff
	dc.w	$3007,$fffe
	dc.w	$100,0
	dc.w	$ffff,$fffe		;magic value to end copperlist

EqualizerSprites:
        dc.b	D_SpritePosY-1
	dc.b	D_SpritePosX
	dc.b	D_SpritePosY
	dc.b	0
	blk.l	D_SpriteHeight,$ffff0000
	dc.l    0

        dc.b	D_SpritePosY-1
	dc.b	D_SpritePosX+8+D_SpriteGapX
	dc.b	D_SpritePosY
	dc.b	0
	blk.l	D_SpriteHeight,$ffff0000
	dc.l	0

        dc.b	D_SpritePosY-1
	dc.b	D_SpritePosX+((8+D_SpriteGapX)*2)
	dc.b	D_SpritePosY
	dc.b	0
	blk.l	D_SpriteHeight,$ffff0000
	dc.l	0

        dc.b	D_SpritePosY-1
	dc.b	D_SpritePosX+((8+D_SpriteGapX)*3)
	dc.b	D_SpritePosY
	dc.b	0
	blk.l	D_SpriteHeight,$ffff0000
	dc.l	0

NullSprite:
	dc.b	0
	dc.b	0
	dc.b	1
	dc.b	0
	dc.l	0,0
       
;;;-------------------------------------------------------------------
ChannelsEqualizerValues:
	dc.b	0,0,0,0
FreqsEqualizerValues:
	blk.b	D_EqFreqs,0

Font:
	incbin	font1x1x3.rawblit

FontColors:     
	dc.w	0,$0fd3,$0f92,$0e72,$0c50,$0a41,$0930,$0720
        
MusicPtrs:
        dc.l    Music1
        dc.l    Music2
        dc.l    Music3
        dc.l    Music4
        dc.l    Music5
        dc.l    Music6
        
Music1:
	incbin modules/ice2.fc
Music2:
	incbin modules/shaolin.fc
Music3:
	incbin modules/horizon.fc
Music4:
	incbin modules/complex.fc
Music5:
	incbin modules/trsi2.fc
Music6:
	incbin modules/trilogy.fc

;;;-------------------------------------------------------------------

        section buffers,bss_c
        
FontPtrs:
	ds.l	D_FontQuantity
MessageScreen:
	ds.b	D_MessageScreenSize
ChannelsEqualizerScreen:
	ds.b	D_EqScreenSize
FreqsEqualizerScreen:
	ds.b	D_EqScreenSize
MenuScreen:
        ds.b    D_MenuScreenSize
        