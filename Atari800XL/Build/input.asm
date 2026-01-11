.proc read_joystick
    ; temp vars used
    cur_btn = tmp_addr1         ; current button state

    mva STRIG0 cur_btn          ; Read joystick button state
    bne up                      ; If button not pressed, skip

down                            ; the button is currently down
    lda stick_btn               ; get the previous button state
    bne done                    ; if previous button state is non-zero, skip

held
    lda stick_action            ; get the action state
    bne done                    ; if the action state is non-zero, don't do the action again
    read_direction()            ; update the direction pointer
    player_action()             ; perform the action
    jmp done ; skip to done

up                              ; the button is currently up
    read_direction()            ; update the direction pointer
    player_move()               ; move the player
    clr stick_action            ; if the player is moving, we don't care about the action state so reset it

done
    mva cur_btn stick_btn       ; save current button state for next time
    rts
    .endp 

; Get the direction from the joystick and store it in dir_ptr
; does not support diagonal movement, and is processed in the following priority order: up, down, left, right
.proc read_direction
    ; temp vars used
    stick_dir = tmp2            ; current joystick direction

    ;Init
    mwa #map player_ptr         ; Initialize player pointer to map base
    mva STICK0 stick_dir        ; load stick bitmap from HW register

    ; Calculate player position in map
    ; player_ptr = map + (player_y * map_width) + player_x
    ldy player_y
    beq calc_x                  ; If y is 0, skip to x calculation
calc_y
    adw player_ptr #map_width
    dey
    bne calc_y

calc_x
    adbw player_ptr player_x

    ; Now calculate direction pointer based on joystick
    mwa player_ptr dir_ptr      ; Start with player position

check_up
    lda stick_dir
    and #STICK_UP
    bne check_down              ; If not pressed, check next
    sbw dir_ptr #map_width      ; Move pointer up one row
    rts

check_down
    lda stick_dir
    and #STICK_DOWN
    bne check_left
    adw dir_ptr #map_width      ; Move pointer down one row
    rts

check_left
    lda stick_dir
    and #STICK_LEFT
    bne check_right
    dec16 dir_ptr               ; Move pointer left one column
    rts

check_right
    lda stick_dir
    and #STICK_RIGHT
    bne done
    inc16 dir_ptr               ; Move pointer right one column
    rts

done
    rts
    .endp

.proc player_action()
    ; Check if the tile in the direction player is facing is a door
    ldy #0
    lda (dir_ptr),y             ; Load the tile at direction pointer
    cmp #MAP_DOOR               ; Is it a door?
    bne done                    ; If not a door, we're done

open_door
    lda #MAP_DOORWAY            ; Load doorway tile
    sta (dir_ptr),y             ; Replace door with doorway
    lda #1                      ; Set action flag to prevent repeated triggers
    sta stick_action

done
    rts
    .endp

.proc player_move()
    ; Check if no_clip mode is enabled
    lda no_clip
    bne do_move                 ; If no_clip enabled, skip collision check

    ; Check if target tile is walkable
    ldy #0
    lda (dir_ptr),y             ; Load the tile at the direction pointer
    cmp #WALKABLE_START         ; Compare with walkable threshold
    bcc done                    ; If less than walkable start, don't move

do_move
    ; Determine which direction and move player
    lda STICK0
    and #STICK_UP
    bne check_move_down
    dec player_y                ; Move up
    update_player_tiles()
    rts

check_move_down
    lda STICK0
    and #STICK_DOWN
    bne check_move_left
    inc player_y                ; Move down
    update_player_tiles()
    rts

check_move_left
    lda STICK0
    and #STICK_LEFT
    bne check_move_right
    dec player_x                ; Move left
    update_player_tiles()
    rts

check_move_right
    lda STICK0
    and #STICK_RIGHT
    bne done
    inc player_x                ; Move right
    update_player_tiles()
    rts

done
    rts
    .endp

