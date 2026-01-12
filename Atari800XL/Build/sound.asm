; sound.asm - POKEY SFX for EdVenture
; Channel 0: Footsteps, alerts. Add music later (Ch1/2/3).

POKEY_AUDF0	= $D200	; Freq low byte
POKEY_AUDC0	= $D201	; Vol/distort ($A0=square vol10, $30=noise)
POKEY_AUDCTL	= $D208	; 1.79MHz poly, 17-bit

.proc init_pokey
	mva	#$56	POKEY_AUDCTL	; 1.79MHz clock, poly on
	mva	#0	POKEY_AUDC0		; All quiet
	rts
.endp

.proc sfx_footstep
	mva	#150	POKEY_AUDF0	; ~400Hz chunky step
	mva	#$A8	POKEY_AUDC0	; Square vol8
	jsr	delay_10frames
	mva	#0	POKEY_AUDC0
	rts
.endp

.proc sfx_monster_spot	; Chase alert!
	mva	#80	POKEY_AUDF0	; Low growl ~800Hz
	mva	#$38	POKEY_AUDC0	; Noise/distort
	jsr	delay_15frames
	mva	#0	POKEY_AUDC0
	rts
.endp

.proc delay_10frames	; ~1/6 sec (60Hz)
	lda	#10
	jsr	delay_frames
	rts
.endp

.proc delay_15frames
	lda	#15
	jsr	delay_frames
	rts
.endp

.proc delay_frames	; A=frames
	pha
loop	lda	RTCLK2
wait	cmp	RTCLK2
	beq	wait
	pla
	dec
	bne	loop
	rts
.endp