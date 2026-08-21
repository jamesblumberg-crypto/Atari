.macro get_room_type
    random8()
    and #15
    sta room_type
    .endm

.macro get_room_pos
    random8()
    and #63
    sta room_pos
    .endm

.proc new_map
    mva #0 num_rooms
    mva #8 max_rooms

    ; Re-bind door/occupancy pointers every level. Gameplay can clobber
    ; zero-page, and floor 2+ map gen depends on these base addresses.
    mwa #placed_doors placed_doors_ptr
    mwa #avail_doors avail_doors_ptr
    mwa #occupied_rooms occupied_rooms_ptr
    mwa #powers_of_two pow2_ptr

    clear_room_gen_state
    fill_map

first_room
    get_room_type
    get_room_pos
    copy_room
    place_special_tile #MAP_UP
    inc num_rooms
    jmp place

last_room
    place_special_tile #MAP_DOWN
    place_room
    jmp done

next_room
    get_room_type
    copy_room
    inc num_rooms

check_last
    lda num_rooms
    cmp max_rooms
    beq last_room

place
    place_room
    get_doors

    walk_room
    jmp next_room

done
    place_doors

    rts
    .endp

; Clears leftover door/occupancy bookkeeping from the previous level.
; Without this, stale placed_doors bits from the prior map cause
; place_doors() to draw doors at room slots the new layout never
; occupies, showing up as doors embedded in plain border wall.
.proc clear_room_gen_state
    lda #0
    ldy #0
loop
    sta placed_doors,y
    sta avail_doors,y
    iny
    cpy #64
    bne loop

    ldy #0
loop2
    sta occupied_rooms,y
    iny
    cpy #8
    bne loop2

    rts
    .endp

.proc fill_map
    mwa #map map_ptr        ; Reset map pointer
    lda #MAP_WALL           ; Load in wall tile

    ldy #0
    ldx #0
loop
    sta (map_ptr),y         ; Store tile
    iny                     ; Move one tile to the right
    cpy #map_width          ; Are we at the end of the line?
    bne loop                ; Nope, keep looping

    ldy #0                  ; Reset to the left edge
    adbw map_ptr #map_width ; Move to the next line
    lda #MAP_WALL           ; Re-load wall tile
    inx                     ; Advance the vertical line index
    cpx #map_height         ; Check to see if all of the lines have been copied
    bne loop                ; Nope, keep looping

    rts
    .endp

; Fill tmp_room with open floor.
; All shipped room templates were solid MAP_FLOOR, and storing 16*225 bytes at
; $A000 made the $9800 code segment (map_gen + input) collide with room_types
; in the XEX — later load of room data overwrote read_keyboard and crashed
; Atari800MacX right after the map drew.
.proc copy_room
    mwa #tmp_room tmp_addr1
    lda #MAP_FLOOR
    ldy #0
loop
    sta (tmp_addr1),y
    iny
    cpy #(room_width * room_height)
    bne loop

    rts
    .endp

.proc place_special_tile (.byte x) .reg
loop
    mwa #tmp_room tmp_addr1
    random8()
    cmp #(room_width * room_height)
    bcs loop

    adbw tmp_addr1 rand

    ldy #0
    lda (tmp_addr1),y
    cmp #MAP_FLOOR
    bne loop

    txa
    sta (tmp_addr1),y

    rts
    .endp

.proc place_room
    set_room_occupied room_pos
    lda room_pos
    asl                     ; Multiply by 2 because positions are 2 bytes wide
    tax                     ; Init X register

    lda room_positions,x    ; Load Y coordinate
    sta room_y              ; Save in room_y
    inx
    lda room_positions,x    ; Load X coordinate
    sta room_x              ; Save in room_x

    mva room_x tmp_x
    mva room_y tmp_y

    advance_ptr #map map_ptr #map_width room_y room_x
    mwa #tmp_room tmp_addr1

    ldx #0
    ldy #0
loop
    lda (tmp_addr1),y
    sta (map_ptr),y

    cmp #MAP_UP
    bne next
    mva tmp_x player_x
    mva tmp_y player_y
next
    inc tmp_x
    iny
    cpy #room_width
    bne loop

    ldy #0
    inc tmp_y
    mva room_x tmp_x
    adbw map_ptr #map_width
    adbw tmp_addr1 #room_width
    inx
    cpx #room_height
    bne loop

    rts
    .endp

.proc get_doors
    ; Get possible doors for the room position
    ldy room_pos
    mwa #room_pos_doors tmp_addr1
    mwa #avail_doors tmp_addr2
    lda (tmp_addr1),y
    sta (tmp_addr2),y

    ; Get doors for the room type
    ldy room_type                   ; Set up Y for getting room type
    mwa #room_type_doors tmp_addr1  ; Set up pointer for indirect addressing
    lda (tmp_addr1),y               ; Load room type into accumulator
    sta tmp                         ; Store room type into temp var

    ldy room_pos                    ; Set up Y for getting room pos
    lda (tmp_addr2),y               ; Load in room doors for this position
    and tmp                         ; AND with room type
    sta (tmp_addr2),y               ; Store back into avail_doors

    rts
    .endp

.proc place_doors
    mva #0 room_pos
    mwa #placed_doors tmp_addr1

loop
    ldy #0                      ; Init Y
    lda (tmp_addr1),y           ; Load in current placed_door
    beq next_room               ; placed_doors is sparse, so keep scanning later room slots
    sta doors                   ; Store into doors var
    lda room_pos                ; Load room position
    asl                         ; Multiply by 2 because positions are 2 bytes wide
    tax                         ; Init X register

    lda room_positions,x        ; Load Y coordinate
    sta room_y                  ; Save in room_y
    inx
    lda room_positions,x        ; Load X coordinate
    sta room_x                  ; Save in room_x

    ; Draw every connection bit. Reciprocal rooms share the same seam tile
    ; (north of B == south of A), so double-draws are idempotent and protect
    ; against a one-sided graph entry after a bad walk.
check_north
    lda doors
    and #DOOR_NORTH
    beq check_south
    jsr place_north_door

check_south
    lda doors
    and #DOOR_SOUTH
    beq check_west
    jsr place_south_door

check_west
    lda doors
    and #DOOR_WEST
    beq check_east
    jsr place_west_door

check_east
    lda doors
    and #DOOR_EAST
    beq next_room
    jsr place_east_door
    
next_room
    inw tmp_addr1
    inc room_pos
    lda room_pos
    cmp #64                            ; scan every possible room slot, not just until the first zero entry
    bcc loop                           ; continue until all 64 room positions have been checked

done
    rts
    .endp

.proc place_north_door
    advance_ptr #map map_ptr #map_width room_y room_x
    sbw map_ptr #map_width
    adw map_ptr #(room_width / 2)
    lda #MAP_DOOR
    ldy #0
    sta (map_ptr),y
    rts
    .endp

.proc place_south_door
    advance_ptr #map map_ptr #map_width room_y room_x
    ldy #0
loop
    adw map_ptr #map_width
    iny
    cpy #room_height
    bne loop

    adw map_ptr #(room_width / 2)
    lda #MAP_DOOR
    ldy #0
    sta (map_ptr),y
    rts
    .endp

.proc place_west_door
    advance_ptr #map map_ptr #map_width room_y room_x
    dew map_ptr
    ldy #0
loop
    adw map_ptr #map_width
    iny
    cpy #(room_height / 2)
    bne loop

    lda #MAP_DOOR
    ldy #0
    sta (map_ptr),y
    rts
    .endp

.proc place_east_door
    advance_ptr #map map_ptr #map_width room_y room_x
    adw map_ptr #room_width
    ldy #0
loop
    adw map_ptr #map_width
    iny
    cpy #(room_height / 2)
    bne loop

    lda #MAP_DOOR
    ldy #0
    sta (map_ptr),y
    rts
    .endp

.proc get_room_occupied (.byte a) .reg
bitmap = occ_bitmap             ; Dedicated scratch — never reuse tmp (breaks place_one_item)
    ; Treat out-of-range room indices as occupied so walks never leave 0-63.
    ; A bad index would otherwise read past occupied_rooms into weapon RAM.
    cmp #64
    bcc in_range
    lda #1
    rts
in_range
    sta room_row
    and #7                      ; Mask the last 3 bits as the column (mod 8)
    sta room_col                ; Store column to a temp variable
    lda room_row
    lsr                         ; Divide by 8 to get the row
    lsr
    lsr
    sta room_row                ; Store the room row
    tay                         ; Copy the room row to Y (index of occupied_rooms)
    lda (occupied_rooms_ptr),y  ; Load in the correct byte for the row
    sta bitmap                  ; Store bitmap

    lda room_col                ; Load in the column
    tay                         ; Copy to Y register
    lda (pow2_ptr),y            ; Get the power of 2 for the column
    and bitmap                  ; AND with occupancy row to test this room's bit
    ; A contains the result

    rts
    .endp

.proc set_room_occupied (.byte a) .reg
bitmap = occ_bitmap             ; Same dedicated scratch as get_room_occupied
    cmp #64
    bcs skip
    sta room_row
    and #7                      ; Mask the last 3 bits as the column (mod 8)
    sta room_col                ; Store column to a temp variable
    lda room_row
    lsr                         ; Divide by 8 to get the row
    lsr
    lsr
    sta room_row                ; Save into row
    tay                         ; Copy the room row to Y (index of occupied_rooms)
    lda (occupied_rooms_ptr),y  ; Load in the correct byte for the row
    sta bitmap
    lda room_col                ; Load in the column
    tay                         ; Copy to Y register
    lda (pow2_ptr),y            ; Get the power of 2 for the column
    ora bitmap                  ; OR with bitmap to get the value of the bit position
    sta bitmap                  ; Save it back to the bitmap
    lda room_row                ; Load the room row
    tay                         ; Set Y to the room row index
    lda bitmap                  ; Load the bitmap back into the accumulator
    sta (occupied_rooms_ptr),y  ; Store the bitmap into occupied room for appropriate index
skip
    rts
    .endp

.proc walk_room
pick
    mwa #placed_doors placed_doors_ptr
    mwa #avail_doors avail_doors_ptr

    ldy room_pos
    lda (avail_doors_ptr),y
    sta doors

    random8
    and #15
    and doors
    sta doors

check_north
    check_north_door
    beq check_south
    walk_north room_pos
    jmp done

check_south
    check_south_door
    beq check_west
    walk_south room_pos
    jmp done

check_west
    check_west_door
    beq check_east
    walk_west room_pos
    jmp done

check_east
    check_east_door
    beq pick
    walk_east room_pos

done
    rts
    .endp

; Clear one door bit from avail_doors without arithmetic underflow.
; `sub #DOOR_*` corrupts the mask when the bit was already clear ($00-$08
; wraps to $F8+), which then poisons later walks via bogus high bits.
.macro clear_avail_bit bit
    lda (avail_doors_ptr),y
    and #($FF-:bit)
    sta (avail_doors_ptr),y
.endm

.proc check_north_door
    ; walk_room masks doors to a random subset; require an exact single-bit
    ; hit so each free direction is equally likely (re-roll multi-bit results).
    lda doors
    cmp #DOOR_NORTH
    bne false

    ; Top row has no northern neighbor (don't let room_pos wrap under).
    lda room_pos
    cmp #8
    bcc reject

    ; Make sure the room isn't occupied
    sub #8
    sta tmp
    get_room_occupied tmp
    beq true

reject
    ; Neighbor occupied or out of bounds — drop this direction from avail
    ldy room_pos
    clear_avail_bit DOOR_NORTH
    jmp false
true
    lda #1
    rts

false
    lda #0
    rts
    .endp

.proc check_south_door
    lda doors
    cmp #DOOR_SOUTH
    bne false

    ; Bottom row has no southern neighbor
    lda room_pos
    cmp #56
    bcs reject

    add #8
    sta tmp
    get_room_occupied tmp
    beq true
reject
    ldy room_pos
    clear_avail_bit DOOR_SOUTH
    jmp false

true
    lda #1
    rts
false
    lda #0
    rts
    .endp

.proc check_west_door
    lda doors
    cmp #DOOR_WEST
    bne false

    ; Left column has no western neighbor
    lda room_pos
    and #7
    beq reject

    lda room_pos
    sub #1
    sta tmp
    get_room_occupied tmp
    beq true
reject
    ldy room_pos
    clear_avail_bit DOOR_WEST
    jmp false

true
    lda #1
    rts
false
    lda #0
    rts
    .endp

.proc check_east_door
    lda doors
    cmp #DOOR_EAST
    bne false

    ; Right column has no eastern neighbor
    lda room_pos
    and #7
    cmp #7
    beq reject

    lda room_pos
    add #1
    sta tmp
    get_room_occupied tmp
    beq true
reject
    ldy room_pos
    clear_avail_bit DOOR_EAST
    jmp false

true
    lda #1
    rts
false
    lda #0
    rts
    .endp

; Walk north
; Input Registers:
; Y = room position
; Updates current avail and placed doors
; Moves room position to new room
; Updates new available doors to prevent backtracking
.proc walk_north (.byte y) .reg
    ; Add door to placed rooms in current room.
    lda (placed_doors_ptr),y
    ora #DOOR_NORTH
    sta (placed_doors_ptr),y

    ; Remove door from available doors in current room
    clear_avail_bit DOOR_NORTH

    ; Move the room position
    lda room_pos
    sub #map_room_columns
    sta room_pos

    get_doors()

    ; Block reverse walk and record reciprocal seam on destination
    ldy room_pos
    clear_avail_bit DOOR_SOUTH
    lda (placed_doors_ptr),y
    ora #DOOR_SOUTH
    sta (placed_doors_ptr),y
    
    rts
    .endp

; Walk south
; Input Registers:
; Y = room position
; Updates current avail and placed doors
; Moves room position to new room
; Updates new available doors to prevent backtracking
.proc walk_south (.byte y) .reg
    lda (placed_doors_ptr),y
    ora #DOOR_SOUTH
    sta (placed_doors_ptr),y

    clear_avail_bit DOOR_SOUTH

    lda room_pos
    add #map_room_columns
    sta room_pos
    
    get_doors()

    ldy room_pos
    clear_avail_bit DOOR_NORTH
    lda (placed_doors_ptr),y
    ora #DOOR_NORTH
    sta (placed_doors_ptr),y
    
    rts
    .endp

; Walk west
; Input Registers:
; Y = room position
; Updates current avail and placed doors
; Moves room position to new room
; Updates new available doors to prevent backtracking
.proc walk_west (.byte y) .reg
    lda (placed_doors_ptr),y
    ora #DOOR_WEST
    sta (placed_doors_ptr),y

    clear_avail_bit DOOR_WEST

    dec room_pos
    
    get_doors()

    ldy room_pos
    clear_avail_bit DOOR_EAST
    lda (placed_doors_ptr),y
    ora #DOOR_EAST
    sta (placed_doors_ptr),y

    rts
    .endp

; Walk east
; Input Registers:
; Y = room position
; Updates current avail and placed doors
; Moves room position to new room
; Updates new available doors to prevent backtracking
.proc walk_east (.byte y) .reg
    lda (placed_doors_ptr),y
    ora #DOOR_EAST
    sta (placed_doors_ptr),y

    clear_avail_bit DOOR_EAST

    inc room_pos

    get_doors()

    ldy room_pos
    clear_avail_bit DOOR_WEST
    lda (placed_doors_ptr),y
    ora #DOOR_WEST
    sta (placed_doors_ptr),y
    
    rts
    .endp

; Place one map item (tile id in A) on a random floor cell. Retries a few times.
; Lives in the $9800 code chain so the $6B80 arrow/monster RAM block stays
; under the screen buffer at $7000.
; Tile id is kept in item_tile — never in tmp (get_room_occupied used to
; stomp tmp and place occupancy bitfields as "gems": bows, doors, junk).
.proc place_one_item
    sta item_tile
    ; ldx #40
    ldx #80   ; increased to double the amount of tries to find a good place
try
    ; pick room slot 0...63
    random8
    and #63
    sta room_pos

    ; must be a real room (map gen put one here)
    get_room_occupied room_pos
    beq try_again   ; A=0 then empty slot

    ; must not already have a gem
    ldy room_pos
    lda avail_doors,y
    bne try_again  ; nonzero - already used

    ; room top-left from ROM table (Y, X pairs)
    lda room_pos
    asl             ; *2 for word index
    tax
    lda room_positions,x ; y of room
    sta room_y
    inx
    lda room_positions,x ; x of room
    sta room_x

    ; random cell inside room: offset 0...14
pick_ox
    random8
    and #15
    cmp #15
    beq pick_ox ; 15 not allowed (only 0...14)
    clc
    adc room_x
    sta tmp_x

pick_oy
    random8
    and #15
    cmp #15
    beq pick_oy
    clc
    adc room_y
    sta tmp_y

; still keep start clear (same idea as your near player check)
    lda tmp_x
    sec
    sbc player_x
    bcs dx_pos
    eor #$FF
    clc
    adc #1
dx_pos
    sta tmp2
    cmp #2
    bcs near_ok

    lda tmp_y
    sec
    sbc player_y
    bcs dy_pos
    eor #$FF
    clc
    adc #1
dy_pos
    cmp #2
    bcs near_ok

    ; too close to player 
    jmp try_again
near_ok

    ; must be floor (not door gap, ladder, bow, monster, other gem)
    stx tmp1
    jsr fast_map_ptr
    ldx tmp1
    ldy #0
    lda (map_ptr),y
    cmp #MAP_FLOOR
    bne try_again

    ; Place the real item tile (gem id), not occupancy garbage
    lda item_tile
    sta (map_ptr),y

    ; mark this room as used
    ldy room_pos
    lda #1
    sta avail_doors,y
    rts

try_again
    dex
    beq give_up
    jmp try
give_up
    rts ; give up this gem after too many tries
    .endp

;     random16
;     cmp #map_width
;     bcs try
;     sta tmp_x
; try_y
;     random16
;     cmp #map_height
;     bcs try_y
;     sta tmp_y

;     ; reject if candidate is within 1 tile of the player (to avoid immediate pickup)
;     ; including the player's own cell. chebyshev: max(|dx|, |dy|) <= 1
;     ; why: gems/items shouldn't spawn underfoot or in the 8 neighboring cells, because the player will pick them up immediately and not see them on the map.
;     ; around the up-ladder start. still only place on map_floor later
;     ; | tmp_x - player_x | <= 1

;     lda tmp_x
;     sec
;     sbc player_x
;     bcs dx_pos
;     eor #$FF
;     clc
;     adc #1
; dx_pos
;     sta tmp2
;     cmp #2
;     bcs near_ok   ; | dx | > 1, so not near the player
;     ; | tmp_y - player_y | <= 1
;     lda tmp_y
;     sec
;     sbc player_y
;     bcs dy_pos
;     eor #$FF
;     clc
;     adc #1
; dy_pos
;     cmp #2
;     bcs near_ok   ; | dy | >= 2, far enough from the player
;     ; both | dx | <= 1 and | dy | <= 1, so the candidate is too close to the player
;     dex
;     bne try
;     rts
; near_ok

;     stx tmp1
;     jsr fast_map_ptr
;     ldx tmp1
;     ldy #0
;     lda (map_ptr),y
;     cmp #MAP_FLOOR
;     beq put         ; accepted floor cell, place the item
;     dex
;     bne try
;     rts
; put
;     lda tmp
;     sta (map_ptr),y
;     rts
    ; .endp

; Place exactly one gem for this dungeon floor (floors 1-5).
; Floor 1 = blue, 2 = gold, 3 = red, 4 = black, 5 = white.
; Skips if that gem is already in has_gems. Floors 6+ place nothing.
.proc place_gems
    lda #0
    ldy #0
clear_gem_rooms
    sta avail_doors,y
    iny
    cpy #64
    bne clear_gem_rooms

    lda dungeon_floor
    beq gems_done               ; safety: floor 0
    cmp #6
    bcs gems_done               ; only floors 1-5 have a gem
    tax
    dex                         ; 0-4 index

    lda floor_gem_bit,x
    and has_gems
    bne gems_done               ; already collected

    lda floor_gem_tile,x
    jsr place_one_item

gems_done
    rts

; Map tile ids for floors 1-5
floor_gem_tile
    .byte MAP_GEM_BLUE, MAP_GEM_GOLD, MAP_GEM_RED, MAP_GEM_BLACK, MAP_GEM_WHITE
; Matching has_gems bits
floor_gem_bit
    .byte GEM_BLUE, GEM_GOLD, GEM_RED, GEM_BLACK, GEM_WHITE
    .endp
; Removed to .endp - moved from main.asm to here to prevent memory buffer overload
; Pick monster ribbon from dungeon_floor and copy art into the live charset.
; Floor 1 → ribbon 0 (first row of monsters_*.png, easiest)
; Floor 2 → ribbon 1
; Floor 3 → ribbon 2
; Floor 4+ → ribbon 3 (bottom of sheet: large dragon art)
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
; floors 1-6 only
; 1 - ribbon 0 (my ribbon 1)
; 2 - ribbon 1 (my ribbon 2)
; 3 - ribbon 2 (my ribbon 3)
; 4 - ribbon 3 (my ribbon 4 / 2x2 boss band - one of the dragons)
; 5 - ribbon 0 (my ribbon 1 again)
; 6 - ribbon 1 (my ribbon 2; KayBee + Missy Later)
.proc setup_floor_monsters
    lda dungeon_floor
    cmp #1
    beq use_r0
    cmp #2
    beq use_r1
    cmp #3
    beq use_r2
    cmp #4
    beq use_r3
    cmp #5
    beq use_r0 ; same as floor 1
    cmp #6
    beq use_r1 ; same as floor 2
    ; safety if floor > 6 or 0
    lda #0
    jmp store_ribbon

use_r0
    lda #0
    jmp store_ribbon
use_r1
    lda #1
    jmp store_ribbon
use_r2
    lda #2
    jmp store_ribbon
use_r3
    lda #3

store_ribbon
    sta starting_monster

    copy_monsters monsters_a cur_charset_a starting_monster
    copy_monsters monsters_b cur_charset_b starting_monster
    copy_monster_colors monsters_a_colors cur_char_colors_a starting_monster
    copy_monster_colors monsters_b_colors cur_char_colors_b starting_monster
    rts
    .endp

; Floor 4 only: stationary 2x2 boss dragon (sheet 52-55 tops, 68-71 bottoms)
; live 88-95 as MAP_BOSS_TL/TR/BL/BR. Kill places well (dungeon chars 22-25).
.proc place_floor_boss
	lda dungeon_floor
	cmp #4
	beq do_floor4_boss
	lda #0
	sta boss_alive
	rts

do_floor4_boss
	jsr load_boss_dragon_gfx

	ldx #80
try_boss_spot
	random8
	and #63
	sta room_pos
	get_room_occupied room_pos
	bne boss_room_ok
	jmp try_boss_again
boss_room_ok
	lda room_pos
	asl
	tay
	lda room_positions,y
	sta room_y
	iny
	lda room_positions,y
	sta room_x

pick_bx
	random8
	and #15
	cmp #13
	bcs pick_bx
	clc
	adc room_x
	sta tmp_x
pick_by
	random8
	and #15
	cmp #13
	bcs pick_by
	clc
	adc room_y
	sta tmp_y

	lda tmp_x
	sec
	sbc player_x
	bcs bx_pos
	eor #$ff
	clc
	adc #1
bx_pos
	cmp #3
	bcs boss_dx_ok
	jmp try_boss_again
boss_dx_ok
	lda tmp_y
	sec
	sbc player_y
	bcs by_pos
	eor #$ff
	clc
	adc #1
by_pos
	cmp #3
	bcs boss_dy_ok
	jmp try_boss_again
boss_dy_ok
	jsr fast_map_ptr
	ldy #0
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq boss_tl_ok
	jmp try_boss_again
boss_tl_ok
	lda map_ptr
	clc
	adc #1
	sta tmp_addr1
	lda map_ptr+1
	adc #0
	sta tmp_addr1+1
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	beq boss_tr_ok
	jmp try_boss_again
boss_tr_ok
	lda map_ptr
	clc
	adc #<map_width
	sta tmp_addr1
	lda map_ptr+1
	adc #>map_width
	sta tmp_addr1+1
	lda (tmp_addr1),y
	cmp #MAP_FLOOR
	beq boss_bl_ok
	jmp try_boss_again
boss_bl_ok
	lda tmp_addr1
	clc
	adc #1
	sta tmp_addr2
	lda tmp_addr1+1
	adc #0
	sta tmp_addr2+1
	lda (tmp_addr2),y
	cmp #MAP_FLOOR
	beq boss_place_tiles
	jmp try_boss_again

boss_place_tiles
	mwa map_ptr boss_tl_ptr
    lda tmp_x
    sta boss_map_x
    lda tmp_y
    sta boss_map_y
	lda #MAP_BOSS_TL
	sta (map_ptr),y
	lda map_ptr
	clc
	adc #1
	sta tmp_addr1
	lda map_ptr+1
	adc #0
	sta tmp_addr1+1
	lda #MAP_BOSS_TR
	sta (tmp_addr1),y
	lda boss_tl_ptr
	clc
	adc #<map_width
	sta tmp_addr1
	lda boss_tl_ptr+1
	adc #>map_width
	sta tmp_addr1+1
	lda #MAP_BOSS_BL
	sta (tmp_addr1),y
	lda tmp_addr1
	clc
	adc #1
	sta tmp_addr2
	lda tmp_addr1+1
	adc #0
	sta tmp_addr2+1
	lda #MAP_BOSS_BR
	sta (tmp_addr2),y

	lda #1
	sta boss_alive
	lda #220
	sta boss_hp
	rts

try_boss_again
	dex
	beq boss_give_up
	jmp try_boss_spot
boss_give_up
	lda #0
	sta boss_alive
	rts
	.endp

; Second big dragon into live 88-95 (A and B). Tops 52-55, bottoms 68-71.
.proc load_boss_dragon_gfx
	mwa #monsters_a tmp_addr1
	adw tmp_addr1 #(52 * 8)
	mwa #cur_charset_a tmp_addr2
	adw tmp_addr2 #(88 * 8)
	jsr copy_n_bytes_32
	mwa #monsters_a tmp_addr1
	adw tmp_addr1 #(68 * 8)
	mwa #cur_charset_a tmp_addr2
	adw tmp_addr2 #(92 * 8)
	jsr copy_n_bytes_32
	mwa #monsters_b tmp_addr1
	adw tmp_addr1 #(52 * 8)
	mwa #cur_charset_b tmp_addr2
	adw tmp_addr2 #(88 * 8)
	jsr copy_n_bytes_32
	mwa #monsters_b tmp_addr1
	adw tmp_addr1 #(68 * 8)
	mwa #cur_charset_b tmp_addr2
	adw tmp_addr2 #(92 * 8)
	jsr copy_n_bytes_32
	rts
	.endp

.proc copy_n_bytes_32
	ldy #0
c32_loop
	lda (tmp_addr1),y
	sta (tmp_addr2),y
	iny
	cpy #32
	bne c32_loop
	rts
	.endp

; After boss dies: well on top row (tiles 11-12 / chars 22-25), floor below.
.proc kill_boss_place_well
	lda #0
	sta boss_alive
	ldy #0
	lda #MAP_WELL_L
	sta (boss_tl_ptr),y
	lda boss_tl_ptr
	clc
	adc #1
	sta map_ptr
	lda boss_tl_ptr+1
	adc #0
	sta map_ptr+1
	lda #MAP_WELL_R
	sta (map_ptr),y
	lda boss_tl_ptr
	clc
	adc #<map_width
	sta map_ptr
	lda boss_tl_ptr+1
	adc #>map_width
	sta map_ptr+1
	lda #MAP_KEY_BLUE   ; key beside the well
	sta (map_ptr),y
	lda map_ptr
	clc
	adc #1
	sta map_ptr
	lda map_ptr+1
	adc #0
	sta map_ptr+1
	lda #MAP_FLOOR      ; still floor tile
	sta (map_ptr),y

	lda player_xp
	clc
	adc #80
	sta player_xp
	jsr update_xp_bar
	jsr check_level_up
	rts
	.endp

; move the 2x2 boss one step toward the player (N/S/E/W)
; uses boss_tl_ptr as top-left map address. prefers larger axis gap.
.proc move_floor4_boss
    lda boss_alive
    bne mfb_go
    rts
mfb_go
    ; rebuild boss map x,y from boss_tl_ptr into tmp_x / tmp_y
    ; (simple: store boss_x / boss_y when placing - see optional Step C)
    ; for now assume you add boss_map_x / boss_map_y (see Step C)
    
    lda boss_map_x
    cmp player_x
    beq mfb_check_y
    bcc mfb_want_east
    ; boss x > player x - try west
    jsr boss_try_west
    bcs mfb_moved
    ; fall through try other axes
mfb_want_east
    jsr boss_try_east
    bcs mfb_moved
mfb_check_y
    lda boss_map_y
    cmp player_y
    beq mfb_done
    bcc mfb_want_south
    jsr boss_try_north
    bcs mfb_moved
    jmp mfb_done
mfb_want_south
    jsr boss_try_south
mfb_moved
    ; carry set if a try_* succeeded (they blit)
mfb_done
    rts
    .endp

; IN: tmp_x, tmp_y = cell to test
; Out: carry set = ok (floor or already part of boss)
.proc boss_cell_ok
    jsr fast_map_ptr
    ldy #0
    lda (map_ptr),y
    cmp #MAP_FLOOR
    beq bco_yes
    cmp #MAP_BOSS_TL
    beq bco_yes
    cmp #MAP_BOSS_TR
    beq bco_yes
    cmp #MAP_BOSS_BL
    beq bco_yes
    cmp #MAP_BOSS_BR
    beq bco_yes
    clc
    rts
bco_yes
    sec
    rts
    .endp

.proc boss_clear_footprint
    ldy #0
    lda #MAP_FLOOR
    sta (boss_tl_ptr),y        ; TL
    lda boss_tl_ptr
    clc
    adc #1
    sta map_ptr
    lda boss_tl_ptr+1
    adc #0
    sta map_ptr+1
    lda #MAP_FLOOR
    sta (map_ptr),y            ; TR
    lda boss_tl_ptr
    clc
    adc #<map_width
    sta map_ptr
    lda boss_tl_ptr+1
    adc #>map_width
    sta map_ptr+1
    lda #MAP_FLOOR
    sta (map_ptr),y            ; BL
    lda map_ptr
    clc
    adc #1
    sta map_ptr
    lda map_ptr+1
    adc #0
    sta map_ptr+1
    lda #MAP_FLOOR
    sta (map_ptr),y            ; BR
    rts
    .endp

.proc boss_write_footprint
    jsr fast_map_ptr
    mwa map_ptr boss_tl_ptr
    ldy #0
    lda #MAP_BOSS_TL
    sta (map_ptr),y
    lda map_ptr
    clc
    adc #1
    sta tmp_addr1
    lda map_ptr+1
    adc #0
    sta tmp_addr1+1
    lda #MAP_BOSS_TR
    sta (tmp_addr1),y
    lda boss_tl_ptr
    clc
    adc #<map_width
    sta tmp_addr1
    lda boss_tl_ptr+1
    adc #>map_width
    sta tmp_addr1+1
    lda #MAP_BOSS_BL
    sta (tmp_addr1),y
    lda tmp_addr1
    clc
    adc #1
    sta tmp_addr2
    lda tmp_addr1+1
    adc #0
    sta tmp_addr2+1
    lda #MAP_BOSS_BR
    sta (tmp_addr2),y
    lda tmp_x
    sta boss_map_x
    lda tmp_y
    sta boss_map_y
    rts
    .endp

.proc boss_try_east
    lda boss_map_x
    clc
    adc #1
    sta tmp_x
    lda boss_map_y
    sta tmp_y
    jsr boss_cell_ok
    bcc bte_no
    inc tmp_x
    jsr boss_cell_ok
    bcc bte_no
    dec tmp_x
    inc tmp_y
    jsr boss_cell_ok
    bcc bte_no
    inc tmp_x
    jsr boss_cell_ok
    bcc bte_no
    lda boss_map_x
    clc
    adc #1
    sta tmp_x
    lda boss_map_y
    sta tmp_y
    jsr boss_clear_footprint
    jsr boss_write_footprint
    blit_screen()
    sec
    rts
bte_no
    clc
    rts
    .endp

.proc boss_try_west
    lda boss_map_x
    beq btw_no            ; already at left edge
    sec
    sbc #1
    sta tmp_x
    lda boss_map_y
    sta tmp_y
    jsr boss_cell_ok
    bcc btw_no
    inc tmp_x
    jsr boss_cell_ok
    bcc btw_no
    dec tmp_x
    inc tmp_y
    jsr boss_cell_ok
    bcc btw_no
    inc tmp_x
    jsr boss_cell_ok
    bcc btw_no
    lda boss_map_x
    sec
    sbc #1
    sta tmp_x
    lda boss_map_y
    sta tmp_y
    jsr boss_clear_footprint
    jsr boss_write_footprint
    blit_screen()
    sec
    rts
btw_no
    clc
    rts
    .endp

.proc boss_try_south
    lda boss_map_x
    sta tmp_x
    lda boss_map_y
    clc
    adc #1
    sta tmp_y
    jsr boss_cell_ok
    bcc bts_no
    inc tmp_x
    jsr boss_cell_ok
    bcc bts_no
    dec tmp_x
    inc tmp_y
    jsr boss_cell_ok
    bcc bts_no
    inc tmp_x
    jsr boss_cell_ok
    bcc bts_no
    lda boss_map_x
    sta tmp_x
    lda boss_map_y
    clc
    adc #1
    sta tmp_y
    jsr boss_clear_footprint
    jsr boss_write_footprint
    blit_screen()
    sec
    rts
bts_no
    clc
    rts
    .endp

.proc boss_try_north
    lda boss_map_y
    beq btn_no            ; already at top
    lda boss_map_x
    sta tmp_x
    lda boss_map_y
    sec
    sbc #1
    sta tmp_y
    jsr boss_cell_ok
    bcc btn_no
    inc tmp_x
    jsr boss_cell_ok
    bcc btn_no
    dec tmp_x
    inc tmp_y
    jsr boss_cell_ok
    bcc btn_no
    inc tmp_x
    jsr boss_cell_ok
    bcc btn_no
    lda boss_map_x
    sta tmp_x
    lda boss_map_y
    sec
    sbc #1
    sta tmp_y
    jsr boss_clear_footprint
    jsr boss_write_footprint
    blit_screen()
    sec
    rts
btn_no
    clc
    rts
    .endp    

; Handle arrow hitting a monster (relocated from $6B80 block)
.proc arrow_hit_monster
    ldy #0
    lda (map_ptr),y
    sta tmp1

    lda dungeon_floor
    cmp #4
    bne arrow_normal_mon
    lda tmp1
    cmp #MAP_BOSS_TL
    bcc arrow_normal_mon
    cmp #(MAP_BOSS_BR + 1)
    bcs arrow_normal_mon
    lda boss_alive
    beq arrow_boss_done
    lda player_ranged_dmg
    sta tmp2
    lda boss_hp
    sec
    sbc tmp2
    sta boss_hp
    bmi arrow_boss_kill
    beq arrow_boss_kill
arrow_boss_done
    rts
arrow_boss_kill
    jsr kill_boss_place_well
    blit_screen()
    rts

arrow_normal_mon
    lda tmp1
    sec
    sbc #44
    tax
    lda monster_hp_table,x
    sta monster_hp
    lda #0
    sta monster_dmg
    jsr scale_monster_stats
    lda player_ranged_dmg
    sta tmp2
    asl
    clc
    adc tmp2
    cmp monster_hp
    bcs kill_monster
    jsr random16
    and #3
    bne survived
kill_monster
    lda monster_xp_table,x
    clc
    adc player_xp
    sta player_xp
    jsr update_xp_bar
    jsr check_level_up
    ldy #0
    lda #MAP_FLOOR
    sta (map_ptr),y
survived
    rts
    .endp
