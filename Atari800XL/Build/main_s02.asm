	sbc #10                    ; Subtract 10
	inx                        ; Increment segment counter
	cpx #9                     ; Max 9 segments
	bcc calc_segments

draw_bars
	stx tmp                    ; Save number of full segments

	; Draw left border
	ldy #0
	lda #UI_BAR_LEFT
	sta (screen_ptr),y
	inc16 screen_ptr

	; Draw full segments
	ldx tmp
draw_full
	cpx #0
	beq draw_empty             ; No more full segments
	lda #UI_XP_FULL
	sta (screen_ptr),y
	inc16 screen_ptr
	dex
	jmp draw_full

draw_empty
	; Fill remaining with empty segments up to 9
	lda tmp
fill_loop
	cmp #9
	bcs draw_right             ; Already drew 9 slots
	lda #UI_BAR_EMPTY
	sta (screen_ptr),y
	inc16 screen_ptr
	lda tmp
	clc
	adc #1
	sta tmp
	jmp fill_loop

draw_right
	lda #UI_BAR_RIGHT
	sta (screen_ptr),y

	rts
.endp

; Update the level display in the HUD (top right after HP bar)
; Displays level 1-9 as a single digit at position 38
.proc update_level_display
	mwa #screen screen_ptr
	adw screen_ptr #38         ; Position at level number (col 38)

	; Convert level to UI_NUMBER character
	; UI_NUMBER_0 = 44, so UI_NUMBER_0 + level = correct character
	lda player_level
	clc
	adc #UI_NUMBER_0           ; Add base offset to get UI_NUMBER_X
	ldy #0
	sta (screen_ptr),y

	rts
.endp

; Update the melee damage display in the HUD (row 1, positions 28-30)
; Displays 3-digit number (000-255)
.proc update_melee_display
    mwa #screen screen_ptr
    adw screen_ptr #(screen_char_width + 28)  ; Row 1, col 28

    ; Convert player_melee_dmg to 3 digits
    lda player_melee_dmg
    jsr display_3_digits

    rts
.endp

; Update the ranged damage display in the HUD (row 1, positions 35-37)
; Displays 3-digit number (000-255)
.proc update_ranged_display
    mwa #screen screen_ptr
    adw screen_ptr #(screen_char_width + 35)  ; Row 1, col 35

    ; Convert player_ranged_dmg to 3 digits
    lda player_ranged_dmg
    jsr display_3_digits

    rts
.endp

; Helper: Display a 3-digit number from A register at screen_ptr
; Destroys: A, X, Y, tmp, tmp2
.proc display_3_digits
    sta tmp                     ; Save value to convert

    ; Calculate hundreds digit
    ldx #0
hundreds_loop
    cmp #100
    bcc tens
    sec
    sbc #100
    inx
    jmp hundreds_loop

tens
    sta tmp2                    ; Save remainder for tens
    txa
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #0
    sta (screen_ptr),y          ; Display hundreds digit

    ; Calculate tens digit
    lda tmp2
    ldx #0
tens_loop
    cmp #10
    bcc ones
    sec
    sbc #10
    inx
    jmp tens_loop

ones
    sta tmp2                    ; Save remainder for ones
    txa
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #1
    sta (screen_ptr),y          ; Display tens digit

    ; Display ones digit
    lda tmp2
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #2
    sta (screen_ptr),y          ; Display ones digit

    rts
.endp

; Check if player has enough XP to level up
; If player_xp >= 90, level up:
;   - Increment player_level
;   - Reset player_xp (carry over excess)
;   - Restore player_hp to player_max_hp
;   - Increase player_melee_dmg by 25%
;   - Update HP and XP bars
.proc check_level_up
	lda player_xp
	cmp #90                    ; Check if XP >= 90
	bcc no_level_up            ; If less than 90, no level up

level_up
	; Subtract 90 from XP (carry over excess)
	lda player_xp
	sec
	sbc #90
	sta player_xp

	; Increment level
	inc player_level

	; Restore HP to max
	lda player_max_hp
	sta player_hp

	; Increase damage by 25% (new_dmg = old_dmg + old_dmg/4)
	lda player_melee_dmg
	sta tmp                    ; Save original damage
	lsr                        ; Divide by 2
	lsr                        ; Divide by 4 (now A = damage/4)
	clc
	adc tmp                    ; Add original damage (A = damage + damage/4 = 1.25 * damage)
	sta player_melee_dmg

	; Update all displays to reflect changes
	jsr update_hp_bar
	jsr update_xp_bar
	jsr update_level_display
	jsr update_melee_display

no_level_up
	rts
.endp


.macro get_input
	lda clock
	sec
	sbc input_timer
	cmp #input_speed
	bcc input_done
	read_joystick()
	blit_screen()
	lda clock
	sta input_timer
input_done
	.endm

.macro animate
	lda clock
	sec
	sbc anim_timer
	cmp #anim_speed
	bcc anim_done
	lda charset_a
	eor #$ff
	sta charset_a
	set_colors
	blit_screen()
	mva clock anim_timer
anim_done
	.endm

* --------------------------------------- *
* Proc: delay                             *
* Uses Real-time clock to delay x/60 secs *
* --------------------------------------- *
.proc delay (.byte x) .reg
start
	lda RTCLK2
wait
	cmp RTCLK2
	beq wait

	dex
	bne start

	rts
	.endp

* --------------------------------------- *
* Proc: setup_colors                      *
* Sets up colors                          *
* --------------------------------------- *
.proc setup_colors
	; Character Set Colors
	mva #white COLOR0 	; %01
	mva #red COLOR1  	; %10
	mva #blue COLOR2	; %11
	mva #gold COLOR3    ; %11 (inverse)
	mva #black COLOR4   ; %00

	; Player-Missile Colors
	; P0=hair, P1=face, P2=body
	; Arrow uses M2 which shares PCOLR2 with P2 (both will be red)
	mva #black PCOLR0       ; Hair color (Player 0)
	mva #peach PCOLR1       ; Face color (Player 1)
	mva #red PCOLR2         ; Body (P2) AND Arrow (M2) - both red
	mva #black PCOLR3

	rts
	.endp

* --------------------------------------- *
* Proc: clear_pmg                         *
* Clears memory for Player-Missile Gfx    *
* --------------------------------------- *
.proc clear_pmg
pmg_p0 = pmg + $200
pmg_p1 = pmg + $280
pmg_p2 = pmg + $300
pmg_p3 = pmg + $380

	ldx #$80
	lda #0
loop
	dex
	sta pmg_p0,x
	sta pmg_p1,x
	sta pmg_p2,x
	sta pmg_p3,x
	sta pmg_missiles,x      ; Also clear missiles
	bne loop
	rts
	.endp

* --------------------------------------- *
* Proc: load_pmg                          *
* Load PMG Graphics                       *
* --------------------------------------- *
.proc load_pmg
