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
bitmap = tmp
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
    and bitmap                  ; AND with tmp to get the value of the bit position
    ; A contains the result

    rts
    .endp

.proc set_room_occupied (.byte a) .reg
bitmap = tmp
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
.proc place_one_item
    sta tmp
    ; ldx #40
    ldx #80   ; increased to double the amount of tries to find a good place
try
    random16
    cmp #map_width
    bcs try
    sta tmp_x
try_y
    random16
    cmp #map_height
    bcs try_y
    sta tmp_y

    ; reject if candidate is within 1 tile of the player (to avoid immediate pickup)
    ; including the player's own cell. chebyshev: max(|dx|, |dy|) <= 1
    ; why: gems/items shouldn't spawn underfoot or in the 8 neighboring cells, because the player will pick them up immediately and not see them on the map.
    ; around the up-ladder start. still only place on map_floor later
    ; | tmp_x - player_x | <= 1

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
    bcs near_ok   ; | dx | > 1, so not near the player
    ; | tmp_y - player_y | <= 1
    lda tmp_y
    sec
    sbc player_y
    bcs dy_pos
    eor #$FF
    clc
    adc #1
dy_pos
    cmp #2
    bcs near_ok   ; | dy | >= 2, far enough from the player
    ; both | dx | <= 1 and | dy | <= 1, so the candidate is too close to the player
    dex
    bne try
    rts
near_ok

    stx tmp1
    jsr fast_map_ptr
    ldx tmp1
    ldy #0
    lda (map_ptr),y
    cmp #MAP_FLOOR
    beq put         ; accepted floor cell, place the item
    dex
    bne try
    rts
put
    lda tmp
    sta (map_ptr),y
    rts
    .endp

; Scatter any gems the player has not collected yet onto the current floor.
.proc place_gems
    lda has_gems
    and #GEM_BLUE
    bne skip_blue
    lda #MAP_GEM_BLUE
    jsr place_one_item
skip_blue
    lda has_gems
    and #GEM_GOLD
    bne skip_gold
    lda #MAP_GEM_GOLD
    jsr place_one_item
skip_gold
    lda has_gems
    and #GEM_RED
    bne skip_red
    lda #MAP_GEM_RED
    jsr place_one_item
skip_red
    lda has_gems
    and #GEM_BLACK
    bne skip_black
    lda #MAP_GEM_BLACK
    jsr place_one_item
skip_black
    lda has_gems
    and #GEM_WHITE
    bne skip_white
    lda #MAP_GEM_WHITE
    jsr place_one_item
skip_white
    rts
    .endp
