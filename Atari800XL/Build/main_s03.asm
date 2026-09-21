pmg_p0 = pmg + $200
pmg_p1 = pmg + $280
pmg_p2 = pmg + $300
pmg_p3 = pmg + $380

	ldx #0
loop
	mva pmgdata,x pmg_p0+60,x
	mva pmgdata+8,x pmg_p1+60,x
	mva pmgdata+16,x pmg_p2+60,x
	mva pmgdata+24,x pmg_p3+60,x
	inx
	cpx #8
	bne loop
	rts
	.endp

* --------------------------------------- *
* Proc: setup_pmg                         *
* Sets up Player-Missile Graphics System  *
* --------------------------------------- *
.proc setup_pmg
	mva #>pmg PMBASE
	mva #46 SDMCTL ; Single Line resolution
	mva #3 GRACTL  ; Enable PMG
	mva #1 GRPRIOR ; Give players priority
	mva #0 SIZEM         ; Normal width for all missiles (2 color clocks)
	lda #92
	sta HPOSP0
	sta HPOSP1
	sta HPOSP2
	sta HPOSP3
	rts
	.endp

; fix_color - Adjusts tile color based on char_colors_ptr table
; Input: A = tile character value
; Output: A = adjusted tile character (possibly with bit 7 set for gold color)
; Preserves: Y register
.proc fix_color
	; Save Y register
	sta tmp
	tya
	pha
	lda tmp

	; Get number of LSRs to perform (how many times to shift)
	and #$07
	add #1
	sta tmp2

	; Get color index
	lda tmp
	lsr
	lsr
	lsr
	tay
	lda (char_colors_ptr),y

	; Shift right as necessary to put the desired bit into the carry flag
shift_bits
	lsr
	dec tmp2
	bne shift_bits

	; Check the carry flag to see if it has a 1 - if so, it needs to be yellow, otherwise blue
	bcc done

add_color
	lda tmp
	add #128
	sta tmp

done
	; Restore the Y register
	pla
	tay
	lda tmp
	rts
.endp

.macro blit_tile
	; lda (map_ptr),y			; Load the tile from the map
	; asl						; Multiply by two to get left character
	; jsr fix_color			; Apply color adjustment (now a procedure)
	; sta (screen_ptr),y		; Store the left character
	; inc16 screen_ptr		; Advance the screen pointer
	; lda (map_ptr),y
	; asl
	; add #1
	; jsr fix_color			; Apply color adjustment (now a procedure)
	; sta (screen_ptr),y		; Store the right character
	; adw map_ptr #1			; Advance the map pointer
	; adw screen_ptr #1		; Advance the screen pointer
	jsr blit_one_tile
	.endm

; Draw one map tile as two screen chars.
; Keys cannot use plain asl pairs (shared teeth / black 2-char body).
.proc blit_one_tile
	lda (map_ptr),y			; map tile id (Y is 0 from blit_screen)
	cmp #MAP_KEY_BLUE
	beq draw_key_blue
	cmp #MAP_KEY_RED
	beq draw_key_red
	cmp #MAP_KEY_GOLD
	beq draw_key_gold
	cmp #MAP_KEY_WHITE
	beq draw_key_white
	cmp #MAP_KEY_BLACK
	beq draw_key_black

	; --- normal tiles: left = id*2, right = id*2+1 ---
	asl
	jsr fix_color
	sta (screen_ptr),y
	inc16 screen_ptr
	lda (map_ptr),y
	asl
	add #1
	jsr fix_color
	sta (screen_ptr),y
	jmp advance

draw_key_blue
	lda #UI_BLUE_KEY_ICON
	jmp key_left
draw_key_red
	lda #UI_RED_KEY_ICON
	jmp key_left
draw_key_gold
	lda #UI_GOLD_KEY_ICON		; already has +128 in labels.asm
	jmp key_left
draw_key_white
	lda #UI_WHITE_KEY_ICON
	; fall through

key_left
	jsr fix_color
	sta (screen_ptr),y
	inc16 screen_ptr
	lda #UI_KEY_ICON_RIGHT		; shared teeth for blue/red/gold/white
	jsr fix_color
	sta (screen_ptr),y
	jmp advance

draw_key_black
	lda #UI_BLACK_KEY_ICON_LEFT
	jsr fix_color
	sta (screen_ptr),y
	inc16 screen_ptr
	lda #UI_BLACK_KEY_ICON_RIGHT
	jsr fix_color
	sta (screen_ptr),y

advance
	adw map_ptr #1
	adw screen_ptr #1
	rts
	.endp

.macro blit_circle_line body, map_space, screen_space
	mwa map_ptr tmp_addr1
	mwa screen_ptr tmp_addr2
	
	adw map_ptr #:map_space
	adw screen_ptr #:screen_space
	ldx #:body
loop
	blit_tile()
	dex
	bne loop

	mwa tmp_addr1 map_ptr
	mwa tmp_addr2 screen_ptr
	.endm

.proc init_player_ptr
	mwa #map map_ptr
	mwa map_ptr player_ptr			; Copy the map address to the player pointer

	; Shift player_y rows
    ldy player_y				; Load in Y starting location (number of rows)
loop
    adw player_ptr #map_width	; Add a row
    dey
    bne loop					; Keep going
    
	; Shift player_x columns
	adbw player_ptr player_x	; Add player_x number of columns
    rts
.endp

.proc map_offset
	mwa #screen screen_ptr
	mwa player_ptr map_ptr								; Copy player location to map location
	sbw map_ptr #(playfield_height / 2 * map_width)		; Subtract height
	sbw map_ptr #(playfield_width / 2)					; Subtract width
	rts
	.endp

.macro blit_char char addr pos
	lda :char
	ldy :pos
	sta (:addr),y
	.endm

.macro blit_char_row char addr start end
	lda :char
	ldy :start
loop
	sta (:addr),y
	iny
	cpy :end
	bcc loop
	.endm

.proc display_borders
	mwa #status_line status_ptr
	mwa #screen screen_ptr

	; Top frame on status_line -- outdoor CHBASE until dli1. Corners 10-15.
	blit_char #UI_NW_BORDER status_ptr #0
	blit_char_row #UI_HORIZ_BORDER status_ptr #1 #23
	blit_char #UI_TOP_TEE status_ptr #23
	blit_char_row #UI_HORIZ_BORDER status_ptr #24 #39
	blit_char #UI_NE_BORDER status_ptr #39
	
	ldx #playfield_height
loop
	blit_char #UI_VERT_BORDER screen_ptr #0
	blit_char #UI_VERT_BORDER screen_ptr #23
	blit_char #UI_VERT_BORDER screen_ptr #39
	adw screen_ptr #screen_char_width
	dex
	bne loop

	; Bottom frame is trailing antic4 AFTER dli2 (outdoor CHBASE again).
	blit_char #UI_SW_BORDER_OUT screen_ptr #0
	blit_char_row #UI_HORIZ_BORDER screen_ptr #1 #23
	blit_char #UI_BOTTOM_TEE_OUT screen_ptr #23
	blit_char_row #UI_HORIZ_BORDER screen_ptr #24 #39
	blit_char #UI_SE_BORDER_OUT screen_ptr #39
	
	rts
	.endp

.proc update_ui
	mwa #screen screen_ptr
	; HP Bar
	blit_char #UI_HP_ICON_LEFT screen_ptr #25
	blit_char #UI_HP_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_BAR_LEFT screen_ptr #28
	blit_char #UI_HP_FULL screen_ptr #29
	blit_char #UI_HP_FULL screen_ptr #30
	blit_char #UI_HP_FULL screen_ptr #31
	blit_char #UI_HP_FULL screen_ptr #32
	blit_char #UI_HP_FULL screen_ptr #33
	blit_char #UI_HP_3_QTR screen_ptr #34
	blit_char #UI_BAR_RIGHT screen_ptr #35

	; Level display (LV:X format)
	blit_char #UI_COLON screen_ptr #37
	blit_char #UI_NUMBER_1 screen_ptr #38

	adw screen_ptr #screen_char_width

	; Skills
	blit_char #UI_MELEE_ICON_LEFT screen_ptr #25
	blit_char #UI_MELEE_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
