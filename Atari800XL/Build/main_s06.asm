	inc monster_tick_div
	lda monster_tick_div
	cmp #20  ; same speed constant as below (raise = slower)
	bcc um_boss_floor_idle
	lda #0
	sta monster_tick_div
	jsr move_floor4_boss
um_boss_floor_idle 
	rts
um_not_boss_floor
	lda RTCLK2
	cmp monster_tick
	bne update_monsters_tick_changed
	jmp done
	
update_monsters_tick_changed:
	sta monster_tick

	inc monster_tick_div
	lda monster_tick_div
	cmp #20						; speed of monster movement (Higher = slower)
	bcs update_monsters_div_ready
	jmp done
	
update_monsters_div_ready:
	lda #0
	sta monster_tick_div

	; Limit how many visible monsters can act per update.
	ldx #1
move_one:
	map_offset()
	lda #0
	sta tmp_x
	sta tmp_y
	lda #(playfield_width * playfield_height)
	sta monster_retries
	
find_monster:
	ldy #0
	lda (map_ptr),y
	cmp #44						; Monster tile range start
	bcs monster_lo_ok
	jmp retry_pick
monster_lo_ok:
	cmp #52						; monster tile range end
	bcc monster_hi_ok
	jmp retry_pick
monster_hi_ok:
	sta tmp						; save the monster's tile id

	jsr monster_adjacent_to_player
	bcc start_monster_chase
	jsr damage_player_from_monster
	jmp monster_action_done

start_monster_chase:
	jsr move_monster_toward_player
	bcc chase_failed
	jmp tile_is_clear
chase_failed:
	jmp retry_pick
tile_is_clear:

	; execute move
	ldy #0
	lda tmp
	sta (tmp_addr1),y				; place monster in new spot
	lda #MAP_FLOOR
	ldy #0
	sta (map_ptr),y					; clear old spot
	mwa map_ptr tmp_addr2
	stx tmp1
	blit_screen()
	ldx tmp1
	mwa tmp_addr2 map_ptr

monster_action_done:
	dex
	beq done
	dec monster_retries
	beq done
	jmp advance_scan
	
retry_pick:
	dec monster_retries
	beq retry_exhausted
advance_scan:
	inc tmp_x
	inc16 map_ptr
	lda tmp_x
	cmp #playfield_width
	bcs next_scan_row
	jmp find_monster
next_scan_row:
	lda #0
	sta tmp_x
	inc tmp_y
	lda tmp_y
	cmp #playfield_height
	bcs done
	adw map_ptr #(map_width - playfield_width)
	jmp find_monster
retry_exhausted:
	jmp done
	
done:
	rts
.endp

.proc monster_adjacent_to_player
	mwa map_ptr tmp_addr2
	inc16 tmp_addr2
	lda tmp_addr2
	cmp player_ptr
	bne check_adjacent_west
	lda tmp_addr2+1
	cmp player_ptr+1
	beq adjacent_found

check_adjacent_west:
	mwa map_ptr tmp_addr2
	dec16 tmp_addr2
	lda tmp_addr2
	cmp player_ptr
	bne check_adjacent_south
	lda tmp_addr2+1
	cmp player_ptr+1
	beq adjacent_found

check_adjacent_south:
	mwa map_ptr tmp_addr2
	adw tmp_addr2 #map_width
	lda tmp_addr2
	cmp player_ptr
	bne check_adjacent_north
	lda tmp_addr2+1
	cmp player_ptr+1
	beq adjacent_found

check_adjacent_north:
	mwa map_ptr tmp_addr2
	sbw tmp_addr2 #map_width
	lda tmp_addr2
	cmp player_ptr
	bne not_adjacent
	lda tmp_addr2+1
	cmp player_ptr+1
	beq adjacent_found

not_adjacent:
	clc
	rts

adjacent_found:
	sec
	rts
.endp
	
	; Pick destination direction.
	; mwa map_ptr tmp_addr1
	; random16  changed for the new code to move monsters
	; and #3
	; sta tmp2
	; NEW STALKING LOGIC thanks Gemini
	; Instead of random16, we compare monster pos (tmp_x, tmp_y) to player pos
	
	; Determine Horizontal Direction
;	lda player_x
;	cmp tmp_x
;	beq check_vertical			; if X is same, just check Y
;	bcs move_east				; if player_x > monster_x, fo East
	
;move_west:
;	lda #3						; 3 = East in your direction labels
;	sta tmp2
;	jmp direction_picked 
	
;check_vertical:
;	lda player_y
;	cmp tmp_y
;	beq retry_pick				; if same spot (impossible? pick another
;	bcs move_south				; if player_y> monster_y, go south
	
;move_north:
;	lda #0						; 0 = North
;	sta tmp2
;	jmp direction_picked
	
;move_south:
;	lda #1						; 1 = South
;	sta tmp2
	
;direction_picked:
	; now tmp2 contains "best" direction to reach the player
	; the rest of your existing locking (check_dest, check_tile)
	; will ensure they don't walk through walls! Gemini					

;	lda tmp2
;	beq try_north
;	cmp #1
;	beq try_south
;	cmp #2
;	beq try_west

;try_east
;	lda tmp_x
;	cmp #(map_width - 1)
;	beq retry_pick
;	inc16 tmp_addr1
;	jmp check_dest

;try_north
;	lda tmp_y
;	beq retry_pick
;	sbw tmp_addr1 #map_width
;	jmp check_dest

;try_south
;	lda tmp_y
;	cmp #(map_height - 1)
;	beq retry_pick
;	adw tmp_addr1 #map_width
;	jmp check_dest

;try_west
;	lda tmp_x
;	beq retry_pick
;	dec16 tmp_addr1

;check_dest
	; Never move onto the player tile.
;	lda tmp_addr1
;	cmp player_ptr
;	bne check_tile
;	lda tmp_addr1+1
;	cmp player_ptr+1
;	beq retry_pick

;check_tile
;	ldy #0
;	lda (tmp_addr1),y
;	cmp #MAP_FLOOR
;	bne retry_pick
;
;	; Execute move.
;	lda tmp
;	sta (tmp_addr1),y
;	lda #MAP_FLOOR
;	ldy #0
;	sta (map_ptr),y

;next_monster
;	dex
;	beq done
;	jmp move_one
;	jmp done

;retry_pick
;	dec monster_retries
;	beq retry_exhausted
;	jmp find_monster
;retry_exhausted
;	dex
;	beq done
;	jmp move_one

;done
;	rts
;	.endp

; Build guard: this must remain below $C000 (OS ROM area).

; ---------------------------------------
; Endgame step 1: keys, Magic Key, KayBee
; ---------------------------------------

; IN: map_ptr = cell just cleared to MAP_FLOOR (monster death).
; Floors 1-2: first kill drops a key. Floor 3: first two kills.
; Floor 4+ : no monster drops (blue key comes from the boss well).
.proc try_drop_floor_key
	lda dungeon_floor
	beq tdfk_no
	cmp #4
	bcs tdfk_no
	cmp #3
	beq tdfk_floor3
	lda keys_dropped_this_floor
	bne tdfk_no
	jmp tdfk_drop
tdfk_floor3
	lda keys_dropped_this_floor
	cmp #2
	bcs tdfk_no
tdfk_drop
	ldy #0
	lda dungeon_floor
	cmp #1
	bne tdfk_not1
	lda #MAP_KEY_WHITE
	jmp tdfk_place
tdfk_not1
	cmp #2
	bne tdfk_not2
	lda #MAP_KEY_RED
	jmp tdfk_place
tdfk_not2
	; floor 3: first drop gold, second black
	lda keys_dropped_this_floor
	bne tdfk_black
	lda #MAP_KEY_GOLD
	jmp tdfk_place
tdfk_black
	lda #MAP_KEY_BLACK
tdfk_place
	sta (map_ptr),y
	inc keys_dropped_this_floor
tdfk_no
	rts
	.endp

; Pickup: A = MAP_KEY_* tile. Map tile -> KEY_* bit (not dungeon_floor).
; Floor art already chose gold vs black via MAP_KEY_GOLD / MAP_KEY_BLACK.
.proc apply_picked_key
	cmp #MAP_KEY_BLUE
	bne apk_not_blue
	lda #KEY_BLUE
	jmp apk_or
apk_not_blue
	cmp #MAP_KEY_RED
	bne apk_not_red
	lda #KEY_RED
	jmp apk_or
apk_not_red
