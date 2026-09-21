	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_RANGED_ICON_LEFT screen_ptr #32
	blit_char #UI_RANGED_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width

	blit_char #UI_DEFENSE_ICON_LEFT screen_ptr #25
	blit_char #UI_DEFENSE_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_FORTITUDE_ICON_LEFT screen_ptr #32
	blit_char #UI_FORTITUDE_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width

	; XP Bar (start empty - player has 0 XP initially)
	blit_char #UI_XP_ICON_LEFT screen_ptr #25
	blit_char #UI_XP_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_BAR_LEFT screen_ptr #28
	blit_char #UI_BAR_EMPTY screen_ptr #29
	blit_char #UI_BAR_EMPTY screen_ptr #30
	blit_char #UI_BAR_EMPTY screen_ptr #31
	blit_char #UI_BAR_EMPTY screen_ptr #32
	blit_char #UI_BAR_EMPTY screen_ptr #33
	blit_char #UI_BAR_EMPTY screen_ptr #34
	blit_char #UI_BAR_EMPTY screen_ptr #35
	blit_char #UI_BAR_EMPTY screen_ptr #36
	blit_char #UI_BAR_EMPTY screen_ptr #37
	blit_char #UI_BAR_RIGHT screen_ptr #38

	adw screen_ptr #screen_char_width

	; Inventory
	blit_char #UI_TORCH_ICON_LEFT screen_ptr #25
	blit_char #UI_TORCH_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_POTION_ICON_LEFT screen_ptr #32
	blit_char #UI_POTION_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width
	blit_char #UI_COIN_ICON_LEFT screen_ptr #25
	blit_char #UI_COIN_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30
	blit_char #UI_NUMBER_0 screen_ptr #31
	blit_char #UI_NUMBER_0 screen_ptr #32

	; Amulet frame + gem sockets (gems filled by update_gem_display)
	adw screen_ptr #screen_char_width
	adw screen_ptr #screen_char_width
	blit_char #UI_AMULET_NW_ICON_LEFT screen_ptr #29
	blit_char #UI_AMULET_NW_ICON_RIGHT screen_ptr #30
	blit_char #UI_AMULET_NE_ICON_LEFT screen_ptr #33
	blit_char #UI_AMULET_NE_ICON_RIGHT screen_ptr #34

	adw screen_ptr #screen_char_width

	adw screen_ptr #screen_char_width
	blit_char #UI_AMULET_SW_ICON_LEFT screen_ptr #29
	blit_char #UI_AMULET_SW_ICON_RIGHT screen_ptr #30
	blit_char #UI_AMULET_SE_ICON_LEFT screen_ptr #33
	blit_char #UI_AMULET_SE_ICON_RIGHT screen_ptr #34

	; Keys
	; sbw screen_ptr #(screen_char_width * 2)
	; blit_char #UI_BLUE_KEY_ICON screen_ptr #26
	; blit_char #UI_KEY_ICON_RIGHT screen_ptr #27

	; blit_char #UI_BLACK_KEY_CAP_LEFT screen_ptr #35
	; blit_char #UI_BLACK_KEY_ICON_LEFT screen_ptr #36
	; blit_char #UI_BLACK_KEY_ICON_RIGHT screen_ptr #37
	; blit_char #UI_BLACK_KEY_CAP_RIGHT screen_ptr #38

	; adw screen_ptr #screen_char_width
	; blit_char #UI_RED_KEY_ICON screen_ptr #26
	; blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	; blit_char #UI_WHITE_KEY_ICON screen_ptr #36
	; blit_char #UI_KEY_ICON_RIGHT screen_ptr #37

	; adw screen_ptr #screen_char_width
	; blit_char #UI_GOLD_KEY_ICON screen_ptr #26
	; blit_char #UI_KEY_ICON_RIGHT screen_ptr #27

	rts
	.endp

; Refresh the five amulet gem sockets from has_gems.
; Layout (cols 29-34 on the right HUD panel):
;   row top:    .  BLACK  .
;   row mid:  BLUE WHITE RED
;   row bot:    .  GOLD   .
.proc update_gem_display
	; --- top row: black ---
	mwa #(screen + 7 * screen_char_width) screen_ptr
	lda has_gems
	and #GEM_BLACK
	beq black_blank
	blit_char #UI_BLACK_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_BLACK_GEM_ICON_RIGHT screen_ptr #32
	jmp mid_row
black_blank
	blit_char #UI_BLANK_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_BLANK_GEM_ICON_RIGHT screen_ptr #32

mid_row
	mwa #(screen + 8 * screen_char_width) screen_ptr
	; blue
	lda has_gems
	and #GEM_BLUE
	beq blue_blank
	blit_char #UI_BLUE_GEM_ICON_LEFT screen_ptr #29
	blit_char #UI_BLUE_GEM_ICON_RIGHT screen_ptr #30
	jmp white_slot
blue_blank
	blit_char #UI_BLANK_GEM_ICON_LEFT screen_ptr #29
	blit_char #UI_BLANK_GEM_ICON_RIGHT screen_ptr #30
white_slot
	lda has_gems
	and #GEM_WHITE
	beq white_blank
	blit_char #UI_WHITE_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_WHITE_GEM_ICON_RIGHT screen_ptr #32
	jmp red_slot
white_blank
	blit_char #UI_BLANK_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_BLANK_GEM_ICON_RIGHT screen_ptr #32
red_slot
	lda has_gems
	and #GEM_RED
	beq red_blank
	blit_char #UI_RED_GEM_ICON_LEFT screen_ptr #33
	blit_char #UI_RED_GEM_ICON_RIGHT screen_ptr #34
	jmp bot_row
red_blank
	blit_char #UI_BLANK_GEM_ICON_LEFT screen_ptr #33
	blit_char #UI_BLANK_GEM_ICON_RIGHT screen_ptr #34

bot_row
	mwa #(screen + 9 * screen_char_width) screen_ptr
	lda has_gems
	and #GEM_GOLD
	beq gold_blank
	blit_char #UI_GOLD_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_GOLD_GEM_ICON_RIGHT screen_ptr #32
	rts
gold_blank
	blit_char #UI_BLANK_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_BLANK_GEM_ICON_RIGHT screen_ptr #32
	rts
	.endp

; Refresh key icons from has_keys (rows 7-9, left + right of amulet)
; Layout:
;    row 7: blue (26-27), black (35-38)
;    row 8: red (26-27), white (36-37)
;    row 9: gold (26-27)
; When has_magic_key: clear all five slots, show one Magic Key at gold slot.
.proc update_key_display
	lda has_magic_key
	beq ukd_individual

	; Blank every key slot, then one Magic Key glyph at row 9 cols 26-27
