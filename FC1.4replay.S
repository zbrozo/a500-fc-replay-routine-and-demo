*********************************************************
**  Amiga FUTURE COMPOSER  »» V1.4 ««  Replay routine  **
*********************************************************

;Doesn't work with V1.0 - V1.3 modules !!

;; 	move.l $4,a6		;This little routine
;; 	jsr -132(a6)		;is only for test purposes
;; 	lea	music,a0
;; 	bsr.L init_music	;(Raster time measuring)
;; ploop:			;and is not needed by the
;; 	move.w #0,$dff180	;replay routine!
;; 	cmpi.b #$80,$dff006
;; 	bne.s ploop		;The results i got from the
;; 	move.w #8,$dff180	;test, is a use of approximatly
;; 	bsr play		;15-20 raster lines
;; 	btst #6,$bfe001		;which means that you need to
;; 	bne.s ploop		;allocate 20 RASTER LINES
;; 	bsr.w end_music		;------------------------
;; 	move.l $4,a6
;; 	jmp -138(a6)

FC_SAMPLES_NR		= 10
FC_WAVEFORMS_NR		= 80
FC_CHANNELS_NR		= 4

FC_MOD_SEQ_SIZE		= 4		; size of sequence table
FC_MOD_PAT 		= 8		; long - offset to patterns
FC_MOD_FRQ 		= $10		; long - offset to freq table
FC_MOD_VOL 		= $18		; long - offset to volume table (instruments)
FC_MOD_Samples 		= $20		; long - offset to the first sample
FC_MOD_Waveforms	= $24		; long - offset to the first waveform
FC_MOD_SamplesInfo 	= $28		; data of 10 samples: length.w, repeat start.l
FC_MOD_WaveformsInfo	= $64		; data of 80 waveforms: length.b
FC_MOD_SEQ 		= $B4		; sequence lines

FC_VOICE_BeginOfSeq	= 0	  	; long
FC_VOICE_PitchBendStep  = 4	  	; byte
FC_VOICE_PitchBendSustainTime = 5 	; byte
FC_VOICE_SeqPos		= 6		; word
FC_VOICE_Note		= 8		; byte
FC_VOICE_NoteInfo	= 9		; byte
FC_VOICE_VolumePtr	= 10		; long
FC_VOICE_VolumeStep	= 14		; byte
FC_VOICE_VolumeTime	= 15		; byte
FC_VOICE_VolumePos	= 16		; word
FC_VOICE_FreqPtr	= 18		; long
FC_VOICE_SoundTranspose	= 22		; byte - instrument change
FC_VOICE_VolumeSpeedTmp	= 23		; byte	- for calculation
FC_VOICE_VolumeSpeed 	= 24		; byte
FC_VOICE_SustainVolume	= 25		; byte
FC_VOICE_SustainTime	= 26		; byte
FC_VOICE_VibratoSpeed   = 27		; byte
FC_VOICE_VibratoAmp	= 28		; byte
FC_VOICE_VibratoAmpTmp	= 29		; byte - temporary value for calculation
FC_VOICE_VibratoDelay	= 30		; byte
FC_VOICE_ChannelBitMask	= 32		; word
FC_VOICE_PatternPtr	= 34		; long
FC_VOICE_VolumeDelay	= 38		; byte
FC_VOICE_PortamentoDelay = 39		; byte
FC_VOICE_PatternPos 	= 40		; word
FC_VOICE_PitchBendDelay = 42		; byte
FC_VOICE_FreqTranspose	= 43		; byte - transpose value for note
FC_VOICE_Transpose	= 44		; byte - note change
FC_VOICE_Volume		= 45		; byte
FC_VOICE_VibratoState	= 46		; byte
FC_VOICE_PortamentoInfo	= 47		; byte
FC_VOICE_FreqPos 	= 50		; word
FC_VOICE_EndOfSeq	= 52		; long
FC_VOICE_Portamento	= 56		; word
FC_VOICE_ChannelDMABase	= 60		; long
FC_VOICE_RepeatStart 	= 64		; word
FC_VOICE_RepeatLength 	= 66		; word
FC_VOICE_SamplePtr 	= 68		; long
FC_VOICE_RepeatStartAndLengthDelay = 72	; word
FC_VOICE_SIZE		= 74

FC_SEQ_SPEED		= 12		; offset to speed in sequence
FC_SEQ_SIZE		= 13		; sequence size

FC_PAT_END		= $49
FC_PAT_SIZE		= 64

END_MUSIC:
FC_END:
	;; clear periods and volumes
	lea	CUSTOM,a6
        clr.l	AUD0PER(a6)
        clr.l	AUD1PER(a6)
        clr.l	AUD2PER(a6)
        clr.l	AUD3PER(a6)
        move.w	#$000f,DMACON(a6)
        bclr	#1,$bfe001
        rts

;;; in: a0 - module
INIT_MUSIC:
FC_INIT:
        bset	#1,$bfe001

	lea	FC_PlayInfo(pc),a5

        lea	FC_MOD_SEQ(a0),a1
	move.l	a1,FC_PlayInfo_SEQptr(a5)

	move.l	a0,a1
        add.l	FC_MOD_PAT(a0),a1
        move.l	a1,FC_PlayInfo_PATptr(a5)

        move.l	a0,a1
        add.l	FC_MOD_FRQ(a0),a1
        move.l	a1,FC_PlayInfo_FRQptr(a5)

        move.l	a0,a1
        add.l	FC_MOD_VOL(a0),a1
        move.l	a1,FC_PlayInfo_VOLptr(a5)

	move.l	FC_MOD_SEQ_SIZE(a0),d0

	bsr	FC_InitSamples
	bsr	FC_InitWaveforms

	move.l	FC_PlayInfo_SEQptr(a5),a0
	bsr	FC_InitSpeed

        lea	FC_VoicesInfo(pc),a0
	move.l	FC_PlayInfo_PATptr(a5),a1
	move.l	FC_PlayInfo_SEQptr(a5),a2
	bsr	FC_InitVoices

	rts

FC_InitSamples:
        lea	FC_MOD_SamplesInfo(a0),a1
        lea	FC_SamplesInfo+4(pc),a2
        moveq	#FC_SAMPLES_NR-1,d1
.loop1:
        move.w 	(a1)+,(a2)+	; length
        move.l 	(a1)+,(a2)+	; repeat start, repeat length
        adda.w 	#10,a2		; next sample info
        dbf 	d1,.loop1

	;; create start address for samples
        move.l	a0,d1
        add.l 	FC_MOD_Samples(a0),d1
        lea	FC_SamplesInfo(pc),a3
        move.l	d1,(a3)+
        moveq 	#9-1,d3
        moveq	#0,d2
.loop2:
        move.w	(a3),d2		; length
        add.l	d2,d1
        add.l 	d2,d1
        addq.l	#2,d1
        adda.w	#12,a3		; next sample info
        move.l	d1,(a3)+
        dbf	d3,.loop2
	rts

FC_InitWaveforms:
        lea 	FC_MOD_WaveformsInfo(a0),a1
        lea	FC_WaveformsInfo(pc),a2

        move.l	a0,a3
        add.l	FC_MOD_Waveforms(a0),a3

        moveq	#FC_WAVEFORMS_NR-1,d1
        moveq	#0,d2
.loop:
        move.l	a3,(a2)+	; address of waveform
        move.b	(a1)+,d2	; length of waveform is on 1 byte!
        move.w	d2,(a2)+	; length
        clr.w	(a2)+		; repeat start
        move.w	d2,(a2)+	; repeat length
        addq.w	#6,a2		; next waveform info
        add.w	d2,a3
        add.w	d2,a3
        dbf	d1,.loop
	rts

;;; in: a0 - seq ptr
FC_InitSpeed:
        moveq	#0,d2
        move.b	FC_SEQ_SPEED(a0),d2	;Get replay speed
        bne.s	.ok
        move.b	#3,d2			;Set default speed
.ok:
	move.w	d2,FC_PlayInfo_ReplaySpeedCounter(a5)
	move.w	d2,FC_PlayInfo_ReplaySpeed(a5)
	rts

FC_InitVoices:
	move.w	#0,FC_PlayInfo_ChannelBitMask(a5)

	lea	CUSTOM,a6
        move.w	#$000f,DMACON(a6)		; Disable audio DMA
        move.w	#$0780,INTENA(a6)		; Disable audio IRQ

	lea	(CUSTOM+AUD0LC),a6

        moveq	#0,d7		; start offset in sequence
	moveq	#0,d2		; bit number in bitmask
	moveq	#0,d3		; offset to voice in sequence table
	moveq	#FC_CHANNELS_NR-1,d5
.l:
	bsr.b	FC_InitVoice
        lea	FC_VOICE_SIZE(a0),a0
	addq.w	#3,d2		; move to next voice in sequence table
	addq.w	#1,d3		; bit number for the channel
	adda.w	#$10,a6		; next channel dma
	dbf	d5,.l
	rts

;;; in: a0 - voice info
;;; in: a1 - PAT point
;;; in: a2 - SEQ point
;;; in: a6 - custom dma + channel offset
FC_InitVoice:

	;; clear channel info
	move.l	a0,a3
	moveq	#0,d4
	moveq	#FC_VOICE_SIZE/4-1,d1
.l:
	move.l	d4,(a3)+
	dbf	d1,.l

        move.l	#FC_SILENT_VOLUME,FC_VOICE_VolumePtr(a0)
        move.l	#FC_SILENT_FREQ,FC_VOICE_FreqPtr(a0)
        move.w	#FC_SEQ_SIZE,FC_VOICE_SeqPos(a0)
	move.b	#1,FC_VOICE_VolumeSpeedTmp(a0)
        move.b	#1,FC_VOICE_VolumeSpeed(a0)

        moveq	#0,d4
        bset	d3,d4
        move.w	d4,FC_VOICE_ChannelBitMask(a0)

 	;; initialize channel dma
        move.l	#FC_SILENT_SAMPLE,(a6)
        move.w	#2,4(a6)
        move.w	#0,6(a6)
        move.w	#0,8(a6)

	move.l	a6,FC_VOICE_ChannelDMABase(a0)

        move.l	a2,a3
	adda.w	d0,a3
        adda.w	d2,a3
	move.l	a3,FC_VOICE_EndOfSeq(a0)

        move.l	a2,a3
        adda.w	d7,a3
        adda.w	d2,a3
	move.l	a3,FC_VOICE_BeginOfSeq(a0)

        move.l 	(a0),a3			; pattern pointer
        move.b	(a3),d1
	andi.l	#$00ff,d1
        lsl.w	#6,d1			; pattern size = 64 bytes

        move.b	1(a3),FC_VOICE_Transpose(a0)
        move.b	2(a3),FC_VOICE_SoundTranspose(a0)

        move.l	a1,a3
        adda.w	d1,a3
        move.l	a3,FC_VOICE_PatternPtr(a0)
	rts
;;; ----------------------------------
;;; ----------------------------------
;;; ----------------------------------
PLAY_MUSIC:
FC_PLAY:
	lea	FC_PlayInfo(pc),a5
	lea 	CUSTOM,a6

        moveq	#0,d5			; for setting zero
        moveq	#6,d6			; for multiplying by 64

	subq.w	#1,FC_PlayInfo_ReplaySpeedCounter(a5)
        bne.s	.nonewnote
        move.w	FC_PlayInfo_ReplaySpeed(a5),FC_PlayInfo_ReplaySpeedCounter(a5)		;Restore replayspeed counter

	lea	FC_VoicesInfo(pc),a0
        bsr	FC_NewNote
	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_NewNote
	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_NewNote
	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_NewNote

.nonewnote:
	move.w	d5,FC_PlayInfo_ChannelBitMask(a5)

	move.l	#$00f000e0,d3	; command masks ($f0 and $e0)

	lea 	FC_VoicesInfo(pc),a0
        bsr	FC_Effects
        move.l	d0,AUD0PER(a6)		; set period and volume

	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_Effects
        move.l	d0,AUD1PER(a6)

	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_Effects
        move.l	d0,AUD2PER(a6)

	lea	FC_VOICE_SIZE(a0),a0
        bsr	FC_Effects
        move.l	d0,AUD3PER(a6)

        lea	FC_VoicesInfo(pc),a0
        move.l 	FC_VOICE_SamplePtr+(0*FC_VOICE_SIZE)(a0),a1		;Get samplepointer
        adda.w 	FC_VOICE_RepeatStart+(0*FC_VOICE_SIZE)(a0),a1		;add repeat_start
        move.l 	FC_VOICE_SamplePtr+(1*FC_VOICE_SIZE)(a0),a2
        adda.w 	FC_VOICE_RepeatStart+(1*FC_VOICE_SIZE)(a0),a2
        move.l 	FC_VOICE_SamplePtr+(2*FC_VOICE_SIZE)(a0),a3
        adda.w 	FC_VOICE_RepeatStart+(2*FC_VOICE_SIZE)(a0),a3
        move.l 	FC_VOICE_SamplePtr+(3*FC_VOICE_SIZE)(a0),a4
        adda.w 	FC_VOICE_RepeatStart+(3*FC_VOICE_SIZE)(a0),a4
        move.w 	FC_VOICE_RepeatLength+(0*FC_VOICE_SIZE)(a0),d1		;Get repeat_length
        move.w 	FC_VOICE_RepeatLength+(1*FC_VOICE_SIZE)(a0),d2
        move.w 	FC_VOICE_RepeatLength+(2*FC_VOICE_SIZE)(a0),d3
        move.w 	FC_VOICE_RepeatLength+(3*FC_VOICE_SIZE)(a0),d4

	;; Turn on channels
        move.w	(a5),d7			; Bitmask
        ori.w	#$8000,d7		; Set/clr bit = 1
        move.w	d7,DMACON(a6)		; Enable audio DMA

	;; Set repeat start and length of the sample in the channel
        moveq 	#2,d0
        moveq	#0,d5
.chan1:
	lea	(FC_VoicesInfo+FC_VOICE_RepeatStartAndLengthDelay)(pc),a0
        move.w	(a0),d7
        beq.s	.chan2
        subq.w	#1,(a0)
        cmp.w	d0,d7
        bne.s	.chan2
        move.w	d5,(a0)
        move.l	a1,AUD0LC(a6)		;Set samplestart
        move.w	d1,AUD0LEN(a6)		;Set samplelength
.chan2:
        lea	FC_VOICE_SIZE(a0),a0
        move.w	(a0),d7
        beq.s	.chan3
        subq.w	#1,(a0)
        cmp.w	d0,d7
        bne.s	.chan3
        move.w	d5,(a0)
        move.l	a2,AUD1LC(a6)
        move.w	d2,AUD1LEN(a6)
.chan3:
        lea	FC_VOICE_SIZE(a0),a0
        move.w	(a0),d7
        beq.s	.chan4
        subq.w	#1,(a0)
        cmp.w	d0,d7
        bne.s	.chan4
        move.w	d5,(a0)
        move.l	a3,AUD2LC(a6)
        move.w	d3,AUD2LEN(a6)
.chan4:
        lea	FC_VOICE_SIZE(a0),a0
        move.w	(a0),d7
        beq.s	.endplay
        subq.w	#1,(a0)
        cmp.w	d0,d7
        bne.s	.endplay
        move.w	d5,(a0)
        move.l	a4,AUD3LC(a6)
        move.w	d4,AUD3LEN(a6)
.endplay:

	rts

;;; ----------------------------------
;;; in: a0 - Current voice table
;;; in: a5 - FC_PlayInfo
;;; in: a6 - CUSTOM
;;; in: d5 - 0 value for clearing
;;; in: d6 - 6 value for multiplying by 64
FC_NewNote:
        move.l	FC_VOICE_PatternPtr(a0),a1
        adda.w	FC_VOICE_PatternPos(a0),a1
        cmp.b	#FC_PAT_END,(a1)	;Check "END" mark in pattern
        beq.s	.patend
        cmp.w	#FC_PAT_SIZE,FC_VOICE_PatternPos(a0)	;Have all the notes been played?
        bne.s	.samepat
.patend:
        move.w	d5,FC_VOICE_PatternPos(a0)
        move.l	FC_VOICE_BeginOfSeq(a0),a2	; sequence address
        adda.w	FC_VOICE_SeqPos(a0),a2		; Point to next sequence row
        cmpa.l	FC_VOICE_EndOfSeq(a0),a2	; Is it the end?
        bne.s	.notend
        move.w	d5,FC_VOICE_SeqPos(a0)		; yes!
        move.l	FC_VOICE_BeginOfSeq(a0),a2	; Point to first sequence
.notend:
        moveq	#1,d1
        addq.b	#1,FC_PlayInfo_ChangeSpeedCounter(a5)
        cmpi.b	#5,FC_PlayInfo_ChangeSpeedCounter(a5)
        bne.s	.nonewspd
        move.b	d1,FC_PlayInfo_ChangeSpeedCounter(a5)

        move.b	FC_SEQ_SPEED(a2),d1		; Get new replay speed
        beq.s	.nonewspd
        move.w	d1,FC_PlayInfo_ReplaySpeedCounter(a5)	; store in counter
        move.w	d1,FC_PlayInfo_ReplaySpeed(a5)
.nonewspd:
        move.b	(a2)+,d1			;Pattern to play
        move.b	(a2)+,FC_VOICE_Transpose(a0)	;Transpose value
        move.b	(a2)+,FC_VOICE_SoundTranspose(a0)	;Soundtranspose value
        lsl.w	d6,d1
        move.l	FC_PlayInfo_PATptr(a5),a1		;Get pattern pointer
        add.w	d1,a1
        move.l	a1,FC_VOICE_PatternPtr(a0)
        addi.w	#FC_SEQ_SIZE,FC_VOICE_SeqPos(a0) ; point to next sequence line
.samepat:
;;; ----------------------------------
;;; Read note and portamento
;;; ----------------------------------
        move.b	1(a1),d1		; Get info byte
        move.b	(a1)+,d0		; Get note
        bne.s	.clearPortamento
	andi.w	#%11000000,d1		; Check portamento bits
        beq.s	.noPortamento
	bra.s	.testPortamento
.clearPortamento:
	;; new note clears current portamento value
        move.w	d5,FC_VOICE_Portamento(a0)
.testPortamento:
        move.b	d5,FC_VOICE_PortamentoInfo(a0)
	;; turn portamento on ?
        btst	#7,d1
        beq.s	.noPortamento
        move.b	2(a1),FC_VOICE_PortamentoInfo(a0) ; Infobyte 2
.noPortamento:
        andi.w	#$007f,d0
        beq.s	.nextnote
        move.b	d0,FC_VOICE_Note(a0)
        move.b	(a1),d1
*        move.b	d1,FC_VOICE_NoteInfo(a0)
;;; ----------------------------------

	;; turn off channel
	move.w	FC_VOICE_ChannelBitMask(a0),d3
        or.w	d3,(a5)
        move.w	d3,DMACON(a6)

        andi.w	#$003f,d1			; Max 64 instruments
        add.b	FC_VOICE_SoundTranspose(a0),d1	; add Soundtranspose

        move.l	FC_PlayInfo_VOLptr(a5),a2
        lsl.w	d6,d1
        adda.w	d1,a2				; instrument table address

        move.w	d5,FC_VOICE_VolumePos(a0)
        move.b	(a2),FC_VOICE_VolumeSpeedTmp(a0)
        move.b	(a2)+,FC_VOICE_VolumeSpeed(a0)

        moveq	#0,d1
        move.b	(a2)+,d1			; Frequency table number
        move.b	(a2)+,FC_VOICE_VibratoSpeed(a0)
        move.b	#0,FC_VOICE_VibratoState(a0) 	; Start vibrato in down direction
        move.b	(a2),FC_VOICE_VibratoAmp(a0)
        move.b	(a2)+,FC_VOICE_VibratoAmpTmp(a0)
        move.b	(a2)+,FC_VOICE_VibratoDelay(a0)
        move.l	a2,FC_VOICE_VolumePtr(a0)

        move.l	FC_PlayInfo_FRQptr(a5),a2
        lsl.w	d6,d1
        adda.w	d1,a2

        move.l	a2,FC_VOICE_FreqPtr(a0)
        move.w	d5,FC_VOICE_FreqPos(a0)
        move.b	d5,FC_VOICE_SustainVolume(a0)
        move.b 	d5,FC_VOICE_SustainTime(a0)
.nextnote:
        addq.w	#2,FC_VOICE_PatternPos(a0)
        rts

;;; ----------------------------------
;;; in: a0 - Current voice table
;;; in: a5 - FC_PlayInfo
;;; in: a6 - CUSTOM
;;; in: d6 = 6 (for multiplying by 64 - it's max length of freq table)
FC_Effects:
	moveq	#0,d7		; for clearing
.testsustain:
        tst.b	FC_VOICE_SustainTime(a0)	; Is sustain counter = 0
        beq.s	.sustzero
        subq.b	#1,FC_VOICE_SustainTime(a0)	; if no, decrease counter
        bra	FC_VOLUfx
.sustzero:				; Next part of effect sequence
	move.l	FC_VOICE_FreqPtr(a0),a1	; can be executed now.
        adda.w	FC_VOICE_FreqPos(a0),a1
.testeffects:

	moveq	#0,d0
	move.b	(a1),d0
	move.b	d0,d1
	swap	d3
	and.b	d3,d1
	swap	d3
	cmp.b	d3,d1
	bne	.transpose
	sub.b	d3,d0
	add.w	d0,d0
	move.w	.cmds(pc,d0.w),d0
	jmp	.cmds(pc,d0.w)

.cmds:
	dc.w	.cmdE0loop-.cmds	;E0 = loop to other part of sequence
	dc.w	FC_VOLUfx-.cmds		;E1 = end of FREQseq sequence
	dc.w	.cmdE2newsound-.cmds	;E2 = set waveform
	dc.w	.cmdE3newvib-.cmds	;E3
	dc.w	.cmdE4changesound-.cmds ;E4
	dc.w	FC_VOLUfx-.cmds		;E5 - not used
	dc.w	FC_VOLUfx-.cmds		;E6 - not used
	dc.w	.cmdE7jmp-.cmds		;E7
	dc.w	.cmdE8newsustain-.cmds	;E8
	dc.w	.cmdE9newsample-.cmds	;E9
	dc.w	.cmdEApitchbend-.cmds	;EA

;;; ----------------------------------
;;; Freq commands
;;; ----------------------------------
.cmdE0loop:
	move.b	1(a1),d1		;loop to start of sequence + 1(a1)
        andi.w	#$003f,d1
        move.w	d1,FC_VOICE_FreqPos(a0)
        move.l	FC_VOICE_FreqPtr(a0),a1
        adda.w	d1,a1
	bra.s	.testeffects

.cmdE2newsound:
	;; turn off channel
        move.w	FC_VOICE_ChannelBitMask(a0),d1
        or.w	d1,(a5)
        move.w	d1,DMACON(a6)

	moveq	#0,d0
        move.b	1(a1),d0

        lea	FC_SamplesInfo(pc),a4
        lsl.w	#4,d0
        adda.w	d0,a4

        move.l	FC_VOICE_ChannelDMABase(a0),a3
        move.l	(a4)+,d1
        move.l	d1,(a3)				; sample start
        move.l	d1,FC_VOICE_SamplePtr(a0)
        move.w	(a4)+,4(a3)			; sample length
        move.l	(a4),FC_VOICE_RepeatStart(a0) 	; save repeat start and length
        move.w	#3,FC_VOICE_RepeatStartAndLengthDelay(a0)

	move.w	d7,FC_VOICE_VolumePos(a0)
        move.b	#1,FC_VOICE_VolumeSpeedTmp(a0)

	addq.w	#2,FC_VOICE_FreqPos(a0)
        bra	.transpose
.cmdE4changesound:
	moveq	#0,d0
        move.b	1(a1),d0

        lea	FC_SamplesInfo(pc),a4
        lsl.w	#4,d0
        adda.w	d0,a4

        move.l	FC_VOICE_ChannelDMABase(a0),a3
        move.l	(a4)+,d1
        move.l	d1,(a3)				; sample start
        move.l	d1,FC_VOICE_SamplePtr(a0)
        move.w	(a4)+,4(a3)			; sample length
        move.l	(a4),FC_VOICE_RepeatStart(a0)	; save repeat start and length
        move.w	#3,FC_VOICE_RepeatStartAndLengthDelay(a0)

        addq.w	#2,FC_VOICE_FreqPos(a0)
        bra	.transpose
.cmdE9newsample:
	;; turn off channel
        move.w	FC_VOICE_ChannelBitMask(a0),d1
        or.w	d1,(a5)
        move.w	d1,DMACON(a6)

        moveq	#0,d0
        move.b	1(a1),d0

        lea	FC_SamplesInfo(pc),a4
        lsl.w	#4,d0
        adda.w	d0,a4

        move.l	(a4),a2
        cmpi.l	#"SSMP",(a2)+
        bne.s	.nossmp

        lea	320(a2),a4	; skip samples info - move to sample data
        moveq	#0,d1
        move.b	2(a1),d1
        lsl.w	#4,d1
        add.w	d1,a2

        add.l	(a2),a4
        move.l	FC_VOICE_ChannelDMABase(a0),a3
        move.l	a4,(a3)
        move.l	4(a2),4(a3)
        move.l	a4,FC_VOICE_SamplePtr(a0)
        move.l	6(a2),FC_VOICE_RepeatStart(a0)
        move.w	d7,FC_VOICE_VolumePos(a0)
        move.b	#1,FC_VOICE_VolumeSpeedTmp(a0)
        move.w	#3,FC_VOICE_RepeatStartAndLengthDelay(a0)
.nossmp:
        addq.w	#3,FC_VOICE_FreqPos(a0)
        bra.s	.transpose

.cmdE7jmp:
        moveq	#0,d0
        move.b	1(a1),d0
        lsl.w	d6,d0
	move.l	FC_PlayInfo_FRQptr(a5),a1
        adda.w	d0,a1

        move.l	a1,FC_VOICE_FreqPtr(a0)
        move.w	d7,FC_VOICE_FreqPos(a0)

        bra	.testeffects

.cmdEApitchbend:
	move.b	1(a1),FC_VOICE_PitchBendStep(a0)
        move.b	2(a1),FC_VOICE_PitchBendSustainTime(a0)
        addq.w	#3,FC_VOICE_FreqPos(a0)
        bra.s	.transpose

.cmdE8newsustain:
        move.b	1(a1),FC_VOICE_SustainTime(a0)
        addq.w	#2,FC_VOICE_FreqPos(a0)
        bra	.testsustain

.cmdE3newvib:
        move.b	1(a1),FC_VOICE_VibratoSpeed(a0)
        move.b	2(a1),FC_VOICE_VibratoAmp(a0)

        addq.w	#3,FC_VOICE_FreqPos(a0)

.transpose:
        move.l	FC_VOICE_FreqPtr(a0),a1
        adda.w	FC_VOICE_FreqPos(a0),a1
        move.b	(a1),FC_VOICE_FreqTranspose(a0)
        addq.w	#1,FC_VOICE_FreqPos(a0)

;;; ----------------------------------
FC_VOLUfx:
        tst.b	FC_VOICE_SustainVolume(a0)
        beq.s	.volsustzero
        subq.b	#1,FC_VOICE_SustainVolume(a0)
        bra	.calcperiod
.volsustzero:
        tst.b	FC_VOICE_VolumeTime(a0)
        bne.s	.do_VOLbend

        subq.b	#1,FC_VOICE_VolumeSpeedTmp(a0)
        bne	.calcperiod
        move.b	FC_VOICE_VolumeSpeed(a0),FC_VOICE_VolumeSpeedTmp(a0)

.volu_cmd:
        move.l	FC_VOICE_VolumePtr(a0),a1
        adda.w	FC_VOICE_VolumePos(a0),a1

	moveq	#0,d0
        move.b	(a1),d0
	move.b	d0,d1
	swap	d3
	and.b	d3,d1
	swap	d3
	cmp.b	d3,d1
	bne.s	.setvolume
	sub.b	d3,d0
	move.b	.cmds(pc,d0.w),d0
	jmp	.cmds(pc,d0.w)

.cmds:
	dc.b	.cmdE0volumeLoop-.cmds 		;E0
	dc.b	.calcperiod-.cmds      		;E1 - volume end
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.cmdE8volumeSustain-.cmds 	;E8
	dc.b	.calcperiod-.cmds		;not used
	dc.b	.cmdEAvolumeSlide-.cmds		;EA
	EVEN

.cmdEAvolumeSlide:
        move.b	1(a1),FC_VOICE_VolumeStep(a0)
        move.b	2(a1),FC_VOICE_VolumeTime(a0)
        addq.w	#3,FC_VOICE_VolumePos(a0)
.do_VOLbend:
        not.b	FC_VOICE_VolumeDelay(a0)
        beq.s	.calcperiod
        subq.b	#1,FC_VOICE_VolumeTime(a0)
        move.b	FC_VOICE_VolumeStep(a0),d1
        add.b	d1,FC_VOICE_Volume(a0)
        bpl.s	.calcperiod
        moveq	#0,d1
        move.b	d1,FC_VOICE_VolumeTime(a0)
        move.b	d1,FC_VOICE_Volume(a0)
        bra.s	.calcperiod

.cmdE8volumeSustain:
        addq.w	#2,FC_VOICE_VolumePos(a0)
        move.b	1(a1),FC_VOICE_SustainVolume(a0)
        bra.s	.calcperiod

.cmdE0volumeLoop:
        move.b	1(a1),d0
        andi.w	#$003f,d0
        subq.b	#5,d0
        move.w	d0,FC_VOICE_VolumePos(a0)
        bra.s	.volu_cmd

.setvolume:

        move.b	(a1),FC_VOICE_Volume(a0)
        addq.w	#1,FC_VOICE_VolumePos(a0)

.calcperiod:
        move.b	FC_VOICE_FreqTranspose(a0),d0
        bmi.s	.lockednote

        add.b	FC_VOICE_Note(a0),d0
        add.b	FC_VOICE_Transpose(a0),d0
.lockednote:
        moveq	#$7f,d1
        and.w	d1,d0
	add.w	d0,d0
        move.w	d0,d1

        lea	FC_PERIODS(pc),a1
	adda.w	d0,a1
        move.w	(a1),d0

;;; ----------------------------------
;;; VIBRATO
;;; ----------------------------------

	tst.b	FC_VOICE_VibratoDelay(a0)		;Vibrato_delay = zero ?
        beq.s	.vibrator
        subq.b	#1,FC_VOICE_VibratoDelay(a0)
        bra.s	.noVibrato
.vibrator:
        move.b	d1,d5		; position in period table

	moveq	#0,d2
        move.b	FC_VOICE_VibratoAmp(a0),d2
        add.b	d2,d2	; calc max vibrato amplitude (0, 2*amp)
        move.b	FC_VOICE_VibratoAmpTmp(a0),d1

	move.b	FC_VOICE_VibratoState(a0),d7
        tst.b	d7
        bne.s	.vibUp
        sub.b	FC_VOICE_VibratoSpeed(a0),d1
        bcc.s	.vibSave

	;; change vibrato direction to up
        not.b	d7
        moveq	#0,d1
        bra.s	.vibSave
.vibUp:
        add.b	FC_VOICE_VibratoSpeed(a0),d1
        cmp.b	d2,d1
        bcs.s	.vibSave

	;; change vibrato direction to down
        not.b	d7
        move.b	d2,d1
.vibSave:
        move.b	d1,FC_VOICE_VibratoAmpTmp(a0)
	move.b	d7,FC_VOICE_VibratoState(a0)

	lsr.b	#1,d2
	sub.w	d2,d1 ; move to (-amp, amp)

	;; double vibrato value for first 4 octaves in the period table
	;; $100-$a0 = $60 and $60/2=$30
	;; which is position after first 4 octaves in the period table

        addi.b	#$a0,d5
        bcs.s	.vibNoDouble

	moveq	#2*12,d7	; 2*12 = $18 (two octaves)
.vibDoubleLoop:
        add.w	d1,d1
        add.b	d7,d5		; adds until 256 reached
        bcc.s	.vibDoubleLoop
.vibNoDouble:

        add.w	d1,d0
.noVibrato:

;;; ----------------------------------
;;; PORTAMENTO
;;; in: d0 - period
;;; ----------------------------------

        not.b	FC_VOICE_PortamentoDelay(a0)
        beq.s	.pitchbend
        moveq	#0,d1
        move.b	FC_VOICE_PortamentoInfo(a0),d1	;get portavalue
        beq.s	.pitchbend		;0=no portamento
        cmpi.b	#$1f,d1
        bls.s	.portaup
        andi.w	#$1f,d1
        neg.w	d1
.portaup:
        sub.w	d1,FC_VOICE_Portamento(a0)


;;; ----------------------------------
;;; PITCH BEND
;;; ----------------------------------

.pitchbend:
        not.b	FC_VOICE_PitchBendDelay(a0)
        beq.s	.addPortamento
        tst.b	FC_VOICE_PitchBendSustainTime(a0)
        beq.s	.addPortamento
        subq.b	#1,FC_VOICE_PitchBendSustainTime(a0)
        moveq	#0,d1
        move.b	FC_VOICE_PitchBendStep(a0),d1
        bpl.s	.pitchup
        ext.w	d1
.pitchup:
        sub.w	d1,FC_VOICE_Portamento(a0)


;;; ----------------------------------

.addPortamento:
        add.w	FC_VOICE_Portamento(a0),d0

;;; ----------------------------------
;;; Keep period in range
;;; ----------------------------------

	cmpi.w	#$0070,d0
        bhi.s	.nn1
        move.w	#$0071,d0
.nn1:
        cmpi.w	#$0d60,d0
        bls.s	.nn2
        move.w	#$0d60,d0
.nn2:

;;; ----------------------------------
;;; Prepare result (period and volume)
;;; ----------------------------------
        swap	d0
        move.b	FC_VOICE_Volume(a0),d0
	rts

;;; ----------------------------------
;;; ----------------------------------
;;; ----------------------------------

	rsreset
FC_PlayInfo_ChannelBitMask	rs.w	1
FC_PlayInfo_ChangeSpeedCounter	rs.w	1
FC_PlayInfo_ReplaySpeedCounter	rs.w	1
FC_PlayInfo_ReplaySpeed		rs.w	1
FC_PlayInfo_SEQptr		rs.l	1
FC_PlayInfo_PATptr		rs.l	1
FC_PlayInfo_FRQptr		rs.l	1
FC_PlayInfo_VOLptr		rs.l	1

FC_PlayInfo:
	dc.w 0		;Channels bitmask
	dc.w 0		;Speed
	dc.w 0		;Replay speed counter
	dc.w 0		;Replay speed counter temp
	dc.l 0		;seq
	dc.l 0		;pat
	dc.l 0		;frq
	dc.l 0		;vol

;;; Silent instrument definition
FC_SILENT_VOLUME: 	dc.b 1,0,0,0,0,0
FC_SILENT_FREQ: 	dc.b $e1
			EVEN

FC_SILENT_SAMPLE:	dc.w 0

FC_VoicesInfo:
	ds.b FC_VOICE_SIZE	;Voice 1 data area
	ds.b FC_VOICE_SIZE	;Voice 2 data area
	ds.b FC_VOICE_SIZE	;Voice 3 data area
	ds.b FC_VOICE_SIZE	;Voice 4 data area

FC_PERIODS:
	dc.w $06b0,$0650,$05f4,$05a0,$054c,$0500,$04b8,$0474,$0434,$03f8,$03c0,$038a ; octave 2
	dc.w $0358,$0328,$02fa,$02d0,$02a6,$0280,$025c,$023a,$021a,$01fc,$01e0,$01c5 ; octave 3
	dc.w $01ac,$0194,$017d,$0168,$0153,$0140,$012e,$011d,$010d,$00fe,$00f0,$00e2 ; octave 4
	dc.w $00d6,$00ca,$00be,$00b4,$00aa,$00a0,$0097,$008f,$0087,$007f,$0078,$0071 ; octave 5
	dc.w $0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071
	dc.w $0d60,$0ca0,$0be8,$0b40,$0a98,$0a00,$0970,$08e8,$0868,$07f0,$0780,$0714 ; octave 1
*	dc.w $1ac0,$1940,$17d0,$1680,$1530,$1400,$12e0,$11d0,$10d0,$0fe0,$0f00,$0e28 ; useless octave - there is period validation at the end of player
	dc.w $06b0,$0650,$05f4,$05a0,$054c,$0500,$04b8,$0474,$0434,$03f8,$03c0,$038a
	dc.w $0358,$0328,$02fa,$02d0,$02a6,$0280,$025c,$023a,$021a,$01fc,$01e0,$01c5
	dc.w $01ac,$0194,$017d,$0168,$0153,$0140,$012e,$011d,$010d,$00fe,$00f0,$00e2
	dc.w $00d6,$00ca,$00be,$00b4,$00aa,$00a0,$0097,$008f,$0087,$007f,$0078,$0071
	dc.w $0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071

FC_SamplesInfo:
	REPT	FC_SAMPLES_NR
	dc.l	0		; start
	dc.w	0		; length
	dc.w	0		; repeat start
	dc.w	0		; repeat length
	blk.b	6,0		; not used
	ENDR

FC_WaveformsInfo:
	REPT	FC_WAVEFORMS_NR
	dc.l	0		; start
	dc.w	0		; length
	dc.w	0		; repeat start
	dc.w	0		; repeat length
	blk.b	6,0		; not used
	ENDR
