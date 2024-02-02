SysBase		=	4

;;; *** Library Vector Offsets ***

;;; exec library
_LVOSupervisor		=	-30
_LVOOldOpenLibrary	=	-408
_LVOFindTask		=	-294
_LVOCloseLibrary	=	-414
_LVOForbid		=	-132
_LVOPermit		=	-138
_LVODisable		=	-120
_LVOEnable		=	-126
_LVOAddPort		=	-354
_LVORemPort		=	-360
_LVOOpenDevice		=	-444
_LVOCloseDevice		=	-450
_LVODoIO		=	-456
	
;;; graphics library
_LVOLoadView 		=	-222
_LVOWaitTOF		=	-270
_LVOOwnBlitter		=	-456
_LVODisownBlitter	=	-462
_LVOWaitBlit		=	-228
	
Start:
	bsr	StopAllFloppyDrives

	lea	_Saved(pc),a5
	bsr	StopTheSystem
	bsr	SaveAndStopDMA

	move.l	VectorBaseRegister(pc),a0
	move.l	$6c(a0),_SavedLevel3Int(a5)
        rts
        
Quit:   
	lea	_Saved(pc),a5
	bsr	RestoreDMA
	bsr	RestoreTheSystem
	moveq	#0,d0
	rts

StopAllFloppyDrives:  
	move.l	(SysBase).w,a6
	sub.l	a1,a1
	jsr	_LVOFindTask(a6)
	
	lea	_diskrep(pc),a5
	move.l	d0,16(a5)
	lea	_diskrep(pc),a1
	jsr	_LVOAddPort(a6)
	
	moveq	#4-1,d7
.loop:
	move.l	d7,d0
	moveq	#0,d1

	lea	_diskio(pc),a1
	lea	_diskrep(pc),a5
	move.l	a5,14(a1)

	lea	TrackdiskName(pc),a0
	jsr	_LVOOpenDevice(a6)
	tst.l	d0
	bne	.next

	lea	_diskio(pc),a1		
	move.w	#$9,$1c(a1)	
	move.l	#0,$24(a1)
	jsr	_LVODoIO(a6)
	lea	_diskio(pc),a1
	jsr	_LVOCloseDevice(a6)
.next:	
	dbf	d7,.loop

	move.l	(SysBase).w,a6		
	lea	_diskrep(pc),a1
	jsr	_LVORemPort(a6)
        rts
	
StopTheSystem:
	
	move.l	(SysBase).w,a6
	sub.l	a4,a4
	btst	#0,297(a6)		;68000 CPU?
	beq.b	.68k
	lea	.GetVBR(pc),a5
	jsr	_LVOSupervisor(a6)
.68k:
	lea	GfxName(pc),a1
	jsr	_LVOOldOpenLibrary(a6)
	move.l	d0,GfxBase
	
	move.l	d0,a6
	
	move.l	$22(a6),_SavedView(a5)
	move.l	$26(a6),_SavedCopperList(a5)

	sub.l	a1,a1
	jsr	_LVOLoadView(a6)

	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)

	jsr	_LVOOwnBlitter(a6)
	jsr	_LVOWaitBlit(a6)

	move.l	(SysBase).w,a6
	jsr	_LVOForbid(a6)
	jsr	_LVODisable(a6)
	rts

.GetVBR:
	dc.l	$4e7a0801	; "movec VBR,d0"
	move.l	d0,VectorBaseRegister
	rte
	
RestoreTheSystem:
	
        move.l	(SysBase).w,a6
	jsr	_LVOEnable(a6)
	jsr	_LVOPermit(a6)

	move.l	GfxBase(pc),a6	
	move.l	_SavedView(a5),a1
	jsr	_LVOLoadView(a6)
	jsr	_LVODisownBlitter(a6)

	move.l	(SysBase).w,a6
	move.l	GfxBase(pc),a1
	jsr	_LVOCloseLibrary(a6)	

	rts

SaveAndStopDMA:	
	lea	CUSTOM,a6

	move.w	INTENAR(a6),d0
	or.w	#$8000,d0
	move.w	d0,_SavedINTENA(a5)
	
	move.w	DMACONR(a6),d0
	or.w	#$8000,d0
	move.w	d0,_SavedDMACON(a5)
	
	move.w	#$7fff,INTENA(a6)
	move.w	#$7fff,DMACON(a6)
	rts
	
RestoreDMA:
	lea	CUSTOM,a6

	move.w	#$7fff,INTENA(a6)
	move.w	#$7fff,DMACON(a6)

	move.l	VectorBaseRegister(pc),a0
	move.l	_SavedLevel3Int(a5),$6c(a0)
	move.w	_SavedINTENA(a5),INTENA(a6)
	move.w	_SavedDMACON(a5),DMACON(a6)
	move.l	_SavedCopperList(a5),COP1LCH(a6)
	move.w	#0,COP1JMP(a6)
	rts

	rsreset
_SavedINTENA: 		rs.w	1
_SavedDMACON: 		rs.w	1
_SavedLevel3Int: 	rs.l	1
_SavedCopperList:	rs.l	1
_SavedView:		rs.l	1
	
_Saved:
	dc.w	0
	dc.w	0
	dc.l	0
	dc.l	0
	dc.l	0

VectorBaseRegister:
	dc.l	0
	
GfxBase:
	dc.l	0
	
GfxName:
	dc.b	"graphics.library",0
	EVEN
	
TrackdiskName:
	dc.b	"trackdisk.device",0
	EVEN

_diskio:
	blk.l	20,0
_diskrep:
	blk.l	8,0


