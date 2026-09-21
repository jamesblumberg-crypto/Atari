	mwa #(screen + 7 * screen_char_width) screen_ptr
	blit_char #0 screen_ptr #26
	blit_char #0 screen_ptr #27
	blit_char #0 screen_ptr #35
	blit_char #0 screen_ptr #36
	blit_char #0 screen_ptr #37
	blit_char #0 screen_ptr #38
	mwa #(screen + 8 * screen_char_width) screen_ptr
	blit_char #0 screen_ptr #26
	blit_char #0 screen_ptr #27
	blit_char #0 screen_ptr #36
	blit_char #0 screen_ptr #37
	mwa #(screen + 9 * screen_char_width) screen_ptr
	blit_char #UI_MAGIC_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	rts

ukd_individual
    ; --- row 7: blue + black ---
	mwa #(screen + 7 * screen_char_width) screen_ptr

	lda has_keys
	and #KEY_BLUE
	beq blue_blank
	blit_char #UI_BLUE_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	jmp black_slot
blue_blank
	blit_char #0 screen_ptr #26
	blit_char #0 screen_ptr #27

black_slot
	lda has_keys
	and #KEY_BLACK
	beq black_blank
	blit_char #UI_BLACK_KEY_CAP_LEFT screen_ptr #35
	blit_char #UI_BLACK_KEY_ICON_LEFT screen_ptr #36
	blit_char #UI_BLACK_KEY_ICON_RIGHT screen_ptr #37
	blit_char #UI_BLACK_KEY_CAP_RIGHT screen_ptr #38
	jmp row8
black_blank
	blit_char #0 screen_ptr #35
	blit_char #0 screen_ptr #36
	blit_char #0 screen_ptr #37
	blit_char #0 screen_ptr #38

row8
	mwa #(screen + 8 * screen_char_width) screen_ptr

	lda has_keys
	and #KEY_RED
	beq red_blank
	blit_char #UI_RED_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	jmp white_slot
red_blank
	blit_char #0 screen_ptr #26
	blit_char #0 screen_ptr #27

white_slot
	lda has_keys
	and #KEY_WHITE
	beq white_blank
	blit_char #UI_WHITE_KEY_ICON screen_ptr #36
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #37
	jmp row9
white_blank
	blit_char #0 screen_ptr #36
	blit_char #0 screen_ptr #37

row9
	mwa #(screen + 9 * screen_char_width) screen_ptr

	lda has_keys
	and #KEY_GOLD
	beq gold_blank
	blit_char #UI_GOLD_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	rts
gold_blank
	blit_char #0 screen_ptr #26
	blit_char #0 screen_ptr #27
	rts
	.endp

.proc blit_screen
	map_offset()

	ldy #0
	; Line #1
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 5, 3, 7

	; Line #2
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 7, 2, 5

	; Line #3
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #4
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #5
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #6
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #7
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #8
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 7, 2, 5

	; Line #9
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 5, 3, 7

	rts
	.endp

; Uses a linear-feedback shift register (LFSR) to generate 8-bit pseudo-random numbers
; More info: https://en.wikipedia.org/wiki/Linear-feedback_shift_register
; Also here: https://forums.atariage.com/topic/159268-random-numbers/#comment-1958751
; Also here: https://github.com/bbbradsmith/prng_6502
.proc random8
	lda rand				; Load in seed or last number generated
	lsr						; Shift 1 place to the right
	bcc no_eor				; Carry flag contains the last bit prior to shifting - if 0, skip XOR
	eor #$b4				; XOR with feedback value that produces a good sequence
no_eor
	sta rand				; Store the random number
	rts
	.endp

.proc random16
	lda rand				; Load in seed or last number generated
	lsr						; Shift 1 place to the right
	rol rand16
	bcc no_eor				; Carry flag contains the last bit prior to shifting - if 0, skip XOR
	eor #$b4				; XOR with feedback value that produces a good sequence
no_eor
	sta rand				; Store the random number
	eor rand16
	rts
	.endp

.proc place_monsters (.byte x,a) .reg
	sta tmp2
pick
	random16
	cmp tmp2
	bcs pick

	add #44
	sta tmp

place
	random16
	cmp #map_width
	bcs place
	sta tmp_x

	random16
	cmp #map_height
	bcs place
	sta tmp_y

	stx tmp1                   ; Save X (monster count)
	jsr fast_map_ptr           ; map_ptr = map + tmp_y * 139 + tmp_x
	ldx tmp1                   ; Restore X
	ldy #0
	lda (map_ptr),y
	cmp #MAP_FLOOR
	bne place
	lda tmp
	sta (map_ptr),y
	dex
	bne pick

	rts
	.endp

; Fast map pointer calculation: map_ptr = map + tmp_y * 139 + tmp_x
; Uses shift-and-add instead of looping. 139 = 128 + 8 + 2 + 1
.proc fast_map_ptr
	; Start: tmp_addr2 = tmp_y (16-bit)
	lda tmp_y
	sta tmp_addr2
	lda #0
	sta tmp_addr2+1

	; map_ptr = tmp_addr2 (x1)
	lda tmp_addr2
	sta map_ptr
	lda tmp_addr2+1
	sta map_ptr+1

	; tmp_addr2 <<= 1 (x2)
	asl tmp_addr2
	rol tmp_addr2+1

	; map_ptr += tmp_addr2 (x1 + x2 = x3)
	lda map_ptr
	clc
	adc tmp_addr2
	sta map_ptr
	lda map_ptr+1
	adc tmp_addr2+1
	sta map_ptr+1

	; tmp_addr2 <<= 2 (x8)
	asl tmp_addr2
	rol tmp_addr2+1
	asl tmp_addr2
	rol tmp_addr2+1

	; map_ptr += tmp_addr2 (x3 + x8 = x11)
	lda map_ptr
	clc
	adc tmp_addr2
	sta map_ptr
	lda map_ptr+1
	adc tmp_addr2+1
	sta map_ptr+1

	; tmp_addr2 <<= 4 (x128)
	asl tmp_addr2
	rol tmp_addr2+1
	asl tmp_addr2
	rol tmp_addr2+1
	asl tmp_addr2
	rol tmp_addr2+1
	asl tmp_addr2
	rol tmp_addr2+1

	; map_ptr += tmp_addr2 (x11 + x128 = x139)
	lda map_ptr
	clc
	adc tmp_addr2
	sta map_ptr
	lda map_ptr+1
	adc tmp_addr2+1
	sta map_ptr+1

	; Add tmp_x
	lda map_ptr
	clc
	adc tmp_x
	sta map_ptr
	lda map_ptr+1
	adc #0
	sta map_ptr+1

	; Add base address of map
	lda map_ptr
	clc
	adc #<map
	sta map_ptr
	lda map_ptr+1
	adc #>map
	sta map_ptr+1

	rts
	.endp

; Gemini Move a small subset of monsters each update tick (lightweight).
.proc update_monsters
	; Floor 4: only the 2x2 boss acts (no normal monster pack)
	lda dungeon_floor
	cmp #4
	bne um_not_boss_floor
	lda boss_alive
	beq um_boss_floor_idle
	; same timing as normal monsters
	lda RTCLK2
	cmp monster_tick
	beq um_boss_floor_idle
	sta monster_tick
