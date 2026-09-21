	cmp #(playfield_width / 2)
	bcc vertical_try_west
	beq move_monster_failed
	jsr try_move_east
	bcc move_monster_failed
	sec
	rts
vertical_try_west:
	jsr try_move_west
	bcc move_monster_failed
	sec
	rts

move_monster_failed:
	clc
	rts
.endp

.proc try_move_east
	lda tmp_x
	cmp #(playfield_width - 1)
	beq east_blocked
	mwa map_ptr tmp_addr1
	inc16 tmp_addr1
	lda tmp_addr1
	cmp player_ptr
	bne east_check_tile
	lda tmp_addr1+1
	cmp player_ptr+1
	beq east_blocked
east_check_tile:
	ldy #0
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	bne east_blocked
	sec
	rts
east_blocked:
	clc
	rts
.endp

.proc try_move_west
	lda tmp_x
	beq west_blocked
	mwa map_ptr tmp_addr1
	dec16 tmp_addr1
	lda tmp_addr1
	cmp player_ptr
	bne west_check_tile
	lda tmp_addr1+1
	cmp player_ptr+1
	beq west_blocked
west_check_tile:
	ldy #0
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	bne west_blocked
	sec
	rts
west_blocked:
	clc
	rts
.endp

.proc try_move_south
	lda tmp_y
	cmp #(playfield_height - 1)
	beq south_blocked
	mwa map_ptr tmp_addr1
	adw tmp_addr1 #map_width
	lda tmp_addr1
	cmp player_ptr
	bne south_check_tile
	lda tmp_addr1+1
	cmp player_ptr+1
	beq south_blocked
south_check_tile:
	ldy #0
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	bne south_blocked
	sec
	rts
south_blocked:
	clc
	rts
.endp

.proc try_move_north
	lda tmp_y
	beq north_blocked
	mwa map_ptr tmp_addr1
	sbw tmp_addr1 #map_width
	lda tmp_addr1
	cmp player_ptr
	bne north_check_tile
	lda tmp_addr1+1
	cmp player_ptr+1
	beq north_blocked
north_check_tile:
	ldy #0
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	bne north_blocked
	sec
	rts
north_blocked:
	clc
	rts
.endp

; Constants for arrow
ARROW_SPEED      = 2           ; Faster projectile travel for more responsive bow combat
ARROW_TILE_SIZE_V = 16         ; Vertical: map tile advances every 16 subtile steps
ARROW_TILE_SIZE_H = 8          ; Horizontal: map tile advances every 8 subtile steps
ARROW_START_Y    = 124         ; Starting scanline near player center in double-line PMG
ARROW_START_X    = 92          ; Starting X (same as player HPOS)
ARROW_MIN_Y      = ARROW_START_Y - ((playfield_height * 8) / 2) ; Dungeon viewport top
ARROW_MAX_Y      = ARROW_START_Y + ((playfield_height * 8) / 2) ; Dungeon viewport bottom
ARROW_MIN_X      = ARROW_START_X - ((playfield_width  * 8) / 2) ; Dungeon viewport left
ARROW_MAX_X      = ARROW_START_X + ((playfield_width  * 8) / 2) ; Dungeon viewport right
arrow_tick       .byte 0       ; Last RTCLK2 tick that advanced arrow
arrow_tick_div   .byte 0       ; Additional slowdown divider
monster_tick     .byte 0       ; Last RTCLK2 tick that advanced monsters
monster_tick_div .byte 0       ; Monster movement slowdown divider
monster_retries  .byte 0       ; Retry counter for find_monster

; Monster HP table - indexed by monster type (0-7)
; Monster tiles are 44-51, so subtract 44 to get index
monster_hp_table
	.byte 30, 45, 50, 60, 70, 80, 90, 100

; Monster damage table - indexed by monster type (0-7)
monster_dmg_table
	.byte 3, 5, 8, 10, 12, 15, 18, 20

; Monster XP reward table - indexed by monster type (0-7)
; XP rewards scale with monster difficulty (HP and damage)
monster_xp_table
	.byte 15, 20, 25, 30, 40, 45, 50, 60

; Place a bow item on a floor tile adjacent to player
.proc place_bow
	; Use player_ptr as our base - it's already set up by init_player_ptr
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1

	; Try right of player (add 1)
	inc16 map_ptr
	ldy #0
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try below player (add map_width from player position)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	adw map_ptr #map_width
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try left of player (subtract 1 from player)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	dec16 map_ptr
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try above player (subtract map_width)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	sbw map_ptr #map_width
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; No floor found adjacent - skip placing bow
	rts

found_floor
	lda #MAP_BOW
	sta (map_ptr),y
	rts
	.endp ; end of place_bow

; Pick monster ribbon from dungeon_floor and copy art into the live charset.
; Floor 1 -> ribbon 0 (first row of monsters_*.png, easiest)
; Floor 2 -> ribbon 1
; Floor 3 -> ribbon 2
; Floor 4+ -> ribbon 3 (bottom of sheet: large dragon art)
; .proc setup_floor_monsters
; 	lda dungeon_floor
; 	sec
; 	sbc #1                      ; 0-based
; 	cmp #4
; 	bcc ribbon_ok
; 	lda #3                      ; cap at hardest ribbon
; ribbon_ok
; 	sta starting_monster

; 	copy_monsters monsters_a cur_charset_a starting_monster
; 	copy_monsters monsters_b cur_charset_b starting_monster
; 	copy_monster_colors monsters_a_colors cur_char_colors_a starting_monster
; 	copy_monster_colors monsters_b_colors cur_char_colors_b starting_monster
; 	rts
; 	.endp

; ; Floor 5: place one type-7 monster as a boss guardian (uses ribbon-3 dragon art slot).
; ; True multi-tile dragons need a future multi-cell entity; this is a single-tile boss
; ; with the bottom-ribbon graphics and special combat stats.
; .proc place_floor_boss
; 	lda dungeon_floor
; 	cmp #5
; 	bne boss_done
; 	lda #51                     ; map tile for monster type 7
; 	jsr place_one_item
; boss_done
; 	rts
; 	.endp

; Advance to the next dungeon floor when stepping on a down ladder.
; Re-generates the map, swaps monster ribbon, re-places items, redraws.
.proc descend_to_next_level
	inc dungeon_floor
	lda #0
	sta arrow_active
	sta keys_dropped_this_floor
	sta kaybee_door_open
	sta kaybee_door_ptr
	sta kaybee_door_ptr+1

	new_map()
	jsr setup_floor_monsters    ; new ribbon for this depth
	lda dungeon_floor
	cmp #4
	beq skip_random_monsters    ; floor 4: boss only
	place_monsters num_monsters #8
skip_random_monsters
	init_player_ptr()
	lda has_bow
	bne skip_place_bow
	jsr place_bow
skip_place_bow
	jsr place_gems
	jsr place_floor_boss
	blit_screen()
	jsr update_gem_display
	jsr update_key_display

