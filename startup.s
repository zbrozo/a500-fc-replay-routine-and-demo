SysBase		=	4
Supervisor	=	-30
OldOpenLibrary	=	-408
FindTask	=	-294
CloseLibrary	=	-414
Forbid		=	-132
Permit		=	-138
Disable		=	-120
Enable		=	-126
AddPort		=	-354
RemPort		=	-360
OpenDevice	=	-444
CloseDevice	=	-450
DoIO		=	-456
	
; --- graphics library
LoadView 	=	-222
WaitTOF		=	-270
OwnBlitter	=	-456
DisownBlitter	=	-462
WaitBlit	=	-228
	
Init:
	bsr	StopAllFloppyDrives
	bsr	StopTheSystem
	bsr	SaveAndStopDMA
	
	move.l	VectorBaseRegister(pc),a0
	move.l	$6c(a0),SavedLevel3Int
        rts
        
Quit:   
	bsr	RestoreDMA
	bsr	RestoreTheSystem
	moveq	#0,d0
	rts

StopAllFloppyDrives:  
	move.l	(SysBase).w,a6
	sub.l	a1,a1
	jsr	FindTask(a6)
	
	lea	diskrep(pc),a5
	move.l	d0,16(a5)
	lea	diskrep(pc),a1
	jsr	AddPort(a6)
	
	moveq	#4-1,d7
.loop:
	move.l	d7,d0
	moveq	#0,d1

	lea	diskio(pc),a1
	lea	diskrep(pc),a5
	move.l	a5,14(a1)

	lea	TrackdiskName(pc),a0
	jsr	OpenDevice(a6)
	tst.l	d0
	bne	.next

	lea	diskio(pc),a1		
	move.w	#$9,$1c(a1)	
	move.l	#0,$24(a1)
	jsr	DoIO(a6)
	lea	diskio(pc),a1
	jsr	CloseDevice(a6)
.next:	
	dbf	d7,.loop

	move.l	(SysBase).w,a6		
	lea	diskrep(pc),a1
	jsr	RemPort(a6)
        rts
	
StopTheSystem:
	
	move.l	(SysBase).w,a6
	sub.l	a4,a4
	btst	#0,297(a6)		;68000 CPU?
	beq.b	.68k
	lea	.GetVBR(pc),a5
	jsr	Supervisor(a6)
.68k:
	lea	GfxName(pc),a1
	jsr	OldOpenLibrary(a6)
	move.l	d0,GfxBase
	
	move.l	d0,a6	
	move.l	$22(a6),SavedView
	move.l	$26(a6),SavedCopperList

	sub.l	a1,a1
	jsr	LoadView(a6)

	jsr	WaitTOF(a6)
	jsr	WaitTOF(a6)

	jsr	OwnBlitter(a6)
	jsr	WaitBlit(a6)

	move.l	(SysBase).w,a6
	jsr	Forbid(a6)
	jsr	Disable(a6)

	rts

.GetVBR:
	dc.l	$4e7a0801	; "movec VBR,d0"
	move.l	d0,VectorBaseRegister
	rte
	
RestoreTheSystem:
	
        move.l	(SysBase).w,a6
	jsr	Enable(a6)
	jsr	Permit(a6)

	move.l	GfxBase(pc),a6	
	move.l	SavedView(pc),a1
	jsr	LoadView(a6)
	jsr	DisownBlitter(a6)

	move.l	(SysBase).w,a6
	move.l	GfxBase(pc),a1
	jsr	CloseLibrary(a6)	

	rts

SaveAndStopDMA:	
	lea	CUSTOM,a6

	move.w	INTENAR(a6),d0
	or.w	#$8000,d0
	move.w	d0,SavedINTENA
	
	move.w	DMACONR(a6),d0
	or.w	#$8000,d0
	move.w	d0,SavedDMACON
	
	move.w	#$7fff,INTENA(a6)
	move.w	#$7fff,DMACON(a6)
	rts
	
RestoreDMA:
	lea	CUSTOM,a6

	move.w	#$7fff,INTENA(a6)
	move.w	#$7fff,DMACON(a6)

	move.l	VectorBaseRegister(pc),a0
	move.l	SavedLevel3Int(pc),$6c(a0)
	move.w	SavedINTENA(pc),INTENA(a6)
	move.w	SavedDMACON(pc),DMACON(a6)

	move.l	SavedCopperList(pc),$80(a6)
	move.w	#0,$88(a6)
	rts
	


VectorBaseRegister:
	dc.l	0
SavedINTENA:
	dc.w	0
SavedDMACON:
	dc.w	0
SavedLevel3Int:
	dc.l	0
SavedCopperList:
	dc.l	0
SavedView:
	dc.l	0

GfxBase:
	dc.l	0
	
GfxName:
	dc.b	"graphics.library",0
	EVEN
	
TrackdiskName:
	dc.b	"trackdisk.device",0
	EVEN
diskio:
	blk.l	20,0
diskrep:
	blk.l	8,0


