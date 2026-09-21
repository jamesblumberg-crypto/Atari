	cmp #MAP_KEY_GOLD
	bne apk_not_gold
	lda #KEY_GOLD
	jmp apk_or
apk_not_gold
	cmp #MAP_KEY_WHITE
	bne apk_not_white
	lda #KEY_WHITE
	jmp apk_or
apk_not_white
	; MAP_KEY_BLACK (or unknown -> black is safest no-op-ish for floor-3 art)
	lda #KEY_BLACK
apk_or
	ora has_keys
	sta has_keys
	jsr update_key_display
	jsr check_form_magic_key
	rts
	.endp

.proc check_form_magic_key
	lda has_magic_key
	bne cfm_done
	lda has_keys
	cmp #KEY_ALL
	bne cfm_done
	lda #1
	sta has_magic_key
	jsr update_key_display	; swap five icons for one Magic Key
	jsr show_status_magic
cfm_done
	rts
	.endp

; If dir_ptr is the KayBee door: show status, open with Magic Key or refuse.
; Carry set = handled (caller must not run normal open_door).
.proc try_kaybee_door
	lda kaybee_door_ptr
	ora kaybee_door_ptr+1
	beq tkd_not
	lda kaybee_door_ptr
	cmp dir_ptr
	bne tkd_not
	lda kaybee_door_ptr+1
	cmp dir_ptr+1
	bne tkd_not

	jsr show_status_kaybee
	lda has_magic_key
	beq tkd_locked
	ldy #0
	lda #MAP_DOORWAY
	sta (dir_ptr),y
	lda #1
	sta kaybee_door_open
	sec
	rts
tkd_locked
	jsr show_status_need
	jsr beep_locked
	sec
	rts
tkd_not
	clc
	rts
	.endp

.proc show_status_kaybee
	mwa #msg_kaybee tmp_addr1
	jmp show_status
	.endp

.proc show_status_need
	mwa #msg_need_key tmp_addr1
	jmp show_status
	.endp

.proc show_status_magic
	mwa #msg_magic_key tmp_addr1
	jmp show_status
	.endp

; Write 0-terminated-by-$FF string at status_line col 2. Cols 1-22 cleared to space.
.proc show_status
	lda #STATUS_CHAR_SPACE
	ldy #1
ss_fill
	sta status_line,y
	iny
	cpy #23
	bne ss_fill
	ldy #0
	ldx #2
ss_copy
	lda (tmp_addr1),y
	cmp #$FF
	beq ss_done
	sta status_line,x
	iny
	inx
	cpx #23
	bcc ss_copy
ss_done
	rts
	.endp

.proc beep_locked
	lda #3
	sta SKCTL
	lda #0
	sta AUDCTL
	lda #20
	sta AUDF1
	lda #$A8
	sta AUDC1
	ldx #8
	jsr delay
	lda #0
	sta AUDC1
	rts
	.endp

msg_kaybee
	.byte STATUS_CHAR_K, STATUS_CHAR_A, STATUS_CHAR_Y
	.byte STATUS_CHAR_B, STATUS_CHAR_E, STATUS_CHAR_E
	.byte STATUS_CHAR_SPACE
	.byte STATUS_CHAR_T, STATUS_CHAR_O, STATUS_CHAR_Y, STATUS_CHAR_S
	.byte $FF

msg_need_key
	.byte STATUS_CHAR_N, STATUS_CHAR_E, STATUS_CHAR_E, STATUS_CHAR_D
	.byte STATUS_CHAR_SPACE
	.byte STATUS_CHAR_M, STATUS_CHAR_A, STATUS_CHAR_G, STATUS_CHAR_I, STATUS_CHAR_C
	.byte STATUS_CHAR_SPACE
	.byte STATUS_CHAR_K, STATUS_CHAR_E, STATUS_CHAR_Y
	.byte $FF

msg_magic_key
	.byte STATUS_CHAR_M, STATUS_CHAR_A, STATUS_CHAR_G, STATUS_CHAR_I, STATUS_CHAR_C
	.byte STATUS_CHAR_SPACE
	.byte STATUS_CHAR_K, STATUS_CHAR_E, STATUS_CHAR_Y
	.byte $FF

MAIN_BANK_END_GUARD

; Arrow routines moved to $6C00 to keep executable code below $C000.

	icl 'macros.asm'
	icl 'hardware.asm'
	icl 'labels.asm'
	icl 'dlist.asm'
	icl 'pmgdata.asm'
	icl 'map_gen.asm'
	icl 'input.asm'

	icl 'charset_dungeon_a.asm'
	icl 'charset_dungeon_b.asm'
	icl 'charset_outdoor_a.asm'
	icl 'charset_outdoor_b.asm'
	icl 'monsters_a.asm'
	icl 'monsters_b.asm'
	; room_types.asm intentionally not linked -- see copy_room in map_gen.asm
	icl 'room_positions.asm'
	icl 'room_pos_doors.asm'
	icl 'room_type_doors.asm'
	;icl 'test_map.asm'
	icl 'charset_dungeon_a_colors.asm'
	icl 'charset_dungeon_b_colors.asm'
	icl 'charset_outdoor_a_colors.asm'
	icl 'charset_outdoor_b_colors.asm'
	icl 'monsters_a_colors.asm'
	icl 'monsters_b_colors.asm'
powers_of_two
	.byte 1,2,4,8,16,32,64,128

; ============================================
; Arrow missile procedures (relocated to RAM)
; ============================================
	org $6b80

.proc move_monster_toward_player
	; Chase the player by favoring the axis with the larger distance from
	; the viewport center, then falling back to the other axis.
	lda tmp_x
	cmp #(playfield_width / 2)
	bcs horizontal_right_or_center
	lda #(playfield_width / 2)
	sec
	sbc tmp_x
	sta tmp1
	jmp have_horizontal_distance
horizontal_right_or_center:
	sec
	sbc #(playfield_width / 2)
	sta tmp1
have_horizontal_distance:
	lda tmp_y
	cmp #(playfield_height / 2)
	bcs vertical_below_or_center
	lda #(playfield_height / 2)
	sec
	sbc tmp_y
	sta tmp2
	jmp have_vertical_distance
vertical_below_or_center:
	sec
	sbc #(playfield_height / 2)
	sta tmp2
have_vertical_distance:

	lda tmp1
	cmp tmp2
	bcs horizontal_first
	jmp vertical_first

horizontal_first:
	lda tmp_x
	cmp #(playfield_width / 2)
	bcc horizontal_try_east
	beq horizontal_second_choice
	jsr try_move_west
	bcc horizontal_second_choice
	sec
	rts
horizontal_try_east:
	jsr try_move_east
	bcc horizontal_second_choice
	sec
	rts

horizontal_second_choice:
	lda tmp_y
	cmp #(playfield_height / 2)
	bcc horizontal_try_south
	beq horizontal_third_choice
	jsr try_move_north
	bcc horizontal_third_choice
	sec
	rts
horizontal_try_south:
	jsr try_move_south
	bcc horizontal_third_choice
	sec
	rts

horizontal_third_choice:
	lda tmp_x
	cmp #(playfield_width / 2)
	bcc horizontal_try_west
	beq horizontal_fourth_choice
	jsr try_move_east
	bcc horizontal_fourth_choice
	sec
	rts
horizontal_try_west:
	jsr try_move_west
	bcc horizontal_fourth_choice
	sec
	rts

horizontal_fourth_choice:
	lda tmp_y
	cmp #(playfield_height / 2)
	bcc horizontal_try_north
	beq move_monster_failed
	jsr try_move_south
	bcc move_monster_failed
	sec
	rts
horizontal_try_north:
	jsr try_move_north
	bcc move_monster_failed
	sec
	rts

vertical_first:
	lda tmp_y
	cmp #(playfield_height / 2)
	bcc vertical_try_south
	beq vertical_second_choice
	jsr try_move_north
	bcc vertical_second_choice
	sec
	rts
vertical_try_south:
	jsr try_move_south
	bcc vertical_second_choice
	sec
	rts

vertical_second_choice:
	lda tmp_x
	cmp #(playfield_width / 2)
	bcc vertical_try_east
	beq vertical_third_choice
	jsr try_move_west
	bcc vertical_third_choice
	sec
	rts
vertical_try_east:
	jsr try_move_east
	bcc vertical_third_choice
	sec
	rts

vertical_third_choice:
	lda tmp_y
	cmp #(playfield_height / 2)
	bcc vertical_try_north
	beq vertical_fourth_choice
	jsr try_move_south
	bcc vertical_fourth_choice
	sec
	rts
vertical_try_north:
	jsr try_move_north
	bcc vertical_fourth_choice
	sec
	rts

vertical_fourth_choice:
	lda tmp_x
