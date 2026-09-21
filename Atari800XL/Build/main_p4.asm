ow_x
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
