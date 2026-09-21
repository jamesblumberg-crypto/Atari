	rts
	.endp

; Fire an arrow in the direction the player is facing
.proc fire_arrow
    lda arrow_active
    bne already_active

    lda #ARROW_START_X
    sta arrow_x
    lda #ARROW_START_Y
    sta arrow_y
    lda player_dir
    sta arrow_dir
    lda player_x
    sta arrow_map_x
    lda player_y
    sta arrow_map_y

    mwa player_ptr arrow_ptr

    lda #0
    sta arrow_subtile
    sta arrow_tick_div
    lda #1
    sta arrow_active
    jsr draw_arrow_missile
already_active
    rts
    .endp

; Update arrow position and check for collisions
.proc update_arrow
    lda RTCLK2
    cmp arrow_tick
    beq no_tick_advance
    sta arrow_tick
    inc arrow_tick_div
    lda arrow_tick_div
    cmp #1
    bcc no_tick_advance
    lda #0
    sta arrow_tick_div

    lda arrow_active
    bne arrow_is_active
no_tick_advance
    rts
arrow_is_active
    jsr clear_arrow_missile
    lda arrow_subtile
    clc
    adc #ARROW_SPEED
    sta arrow_subtile
    lda arrow_dir
    cmp #WEST
    beq check_horiz_step
    cmp #EAST
    beq check_horiz_step
    lda arrow_subtile
    cmp #ARROW_TILE_SIZE_V
    bcc move_screen_only
    jmp step_map
check_horiz_step
    lda arrow_subtile
    cmp #ARROW_TILE_SIZE_H
    bcc move_screen_only
step_map
    lda #0
    sta arrow_subtile
    lda arrow_dir
    cmp #NORTH
    bne not_north_map
    sbw arrow_ptr #map_width
    dec arrow_map_y
    jmp check_map_collision
not_north_map
    cmp #SOUTH
    bne not_south_map
    adw arrow_ptr #map_width
    inc arrow_map_y
    jmp check_map_collision
not_south_map
    cmp #WEST
    bne not_west_map
    dec16 arrow_ptr
    dec arrow_map_x
    jmp check_map_collision
not_west_map
    inc16 arrow_ptr
    inc arrow_map_x
check_map_collision
    jsr check_arrow_collision
    lda arrow_active
    bne move_screen_only
    rts
move_screen_only
    lda arrow_dir
    cmp #NORTH
    bne check_south
    lda arrow_y
    sec
    sbc #ARROW_SPEED
    sta arrow_y
    jmp check_bounds
check_south
    cmp #SOUTH
    bne check_west
    lda arrow_y
    clc
    adc #ARROW_SPEED
    sta arrow_y
    jmp check_bounds
check_west
    cmp #WEST
    bne check_east
    lda arrow_x
    sec
    sbc #ARROW_SPEED
    sta arrow_x
    jmp check_bounds
check_east
    lda arrow_x
    clc
    adc #ARROW_SPEED
    sta arrow_x
check_bounds
    lda arrow_y
    cmp #ARROW_MIN_Y
    bcc deactivate
    cmp #ARROW_MAX_Y
    bcs deactivate
    lda arrow_x
    cmp #ARROW_MIN_X
    bcc deactivate
    cmp #ARROW_MAX_X
    bcs deactivate
    jsr draw_arrow_missile
    rts
deactivate
    jsr deactivate_arrow
    rts
    .endp

; Check if arrow hit something
.proc check_arrow_collision
    mwa arrow_ptr map_ptr
    ldy #0
    lda (map_ptr),y
    cmp #44
    bcc check_horizontal_neighbors
    cmp #52
    bcs check_horizontal_neighbors
    jsr arrow_hit_monster
    jsr deactivate_arrow
    rts

check_horizontal_neighbors
    ; Horizontal shots can be visually between map rows, so probe one row above/below.
    lda arrow_dir
    cmp #WEST
    beq check_above
    cmp #EAST
    bne check_wall

check_above
    mwa map_ptr tmp_addr1
    sbw map_ptr #map_width
    lda (map_ptr),y
    cmp #44
    bcc check_below
    cmp #52
    bcs check_below
    jsr arrow_hit_monster
    jsr deactivate_arrow
    rts

check_below
    mwa tmp_addr1 map_ptr
    adw map_ptr #map_width
    lda (map_ptr),y
    cmp #44
    bcc restore_for_wall
    cmp #52
    bcs restore_for_wall
    jsr arrow_hit_monster
    jsr deactivate_arrow
    rts

restore_for_wall
    mwa tmp_addr1 map_ptr

check_wall
    lda (map_ptr),y
    cmp #PASSABLE_MIN
    bcs passable
    jsr deactivate_arrow
passable
    rts
    .endp

; arrow_hit_monster lives in map_gen.asm (keeps $6B80 under screen $7000)

; Deactivate the arrow
.proc deactivate_arrow
    lda #0
    sta arrow_active
    jsr clear_arrow_missile
    lda #0
    sta HPOSM2
    rts
    .endp

; Draw arrow missile at current position (using M2)
.proc draw_arrow_missile
    lda arrow_x
    sta HPOSM2
    lda arrow_y
    lsr                     ; PMG is in double-line mode: 2 scanlines per byte
    tax
    lda #%00110000
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x
    rts
    .endp

; Clear arrow missile (2 scanlines to match draw)
.proc clear_arrow_missile
    lda arrow_y
    lsr                     ; PMG is in double-line mode: 2 scanlines per byte
    tax
    lda #0
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x
    rts

.endp
