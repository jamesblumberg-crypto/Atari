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
    beq handle_up               ; If pressed (bit is 0), handle it

check_down
    lda stick_dir
    and #STICK_DOWN
    beq handle_down

check_left
    lda stick_dir
    and #STICK_LEFT
    beq handle_left

check_right
    lda stick_dir
    and #STICK_RIGHT
    beq handle_right
    jmp done                    ; No direction pressed

handle_up
    sbw dir_ptr #map_width      ; Move pointer up one row
    rts

handle_down
    adw dir_ptr #map_width      ; Move pointer down one row
    rts

handle_left
    dec16 dir_ptr               ; Move pointer left one column
    rts

handle_right
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

    ; Check if target tile is a special tile (stairs, doors)
    ldy #0
    lda (dir_ptr),y             ; Load the tile at the direction pointer
    cmp #MAP_UP                 ; Is it up stairs (121)?
    beq check_walkable          ; Yes, treat as walkable
    cmp #MAP_DOWN               ; Is it down stairs (120)?
    beq check_walkable          ; Yes, treat as walkable
    cmp #MAP_DOORWAY            ; Is it an open doorway (123)?
    beq check_walkable          ; Yes, treat as walkable

    ; Check if target tile is a monster
    cmp #88                     ; Is it >= monster start (88)?
    bcc check_walkable          ; If < 88, check if walkable
    cmp #112                    ; Is it < monster end (112)?
    bcs check_walkable          ; If >= 112, check if walkable
    jmp attack_monster          ; It's a monster (88-111), attack it!

check_walkable
    lda (dir_ptr),y             ; Reload the tile
    cmp #WALKABLE_START         ; Compare with walkable threshold
    bcs do_move                 ; If >= walkable start, allow movement
    rts                         ; Otherwise don't move, just return

do_move
    ; Determine which direction and move player
    lda STICK0
    and #STICK_UP
    beq move_up

    lda STICK0
    and #STICK_DOWN
    beq move_down

    lda STICK0
    and #STICK_LEFT
    beq move_left

    lda STICK0
    and #STICK_RIGHT
    beq move_right
    rts                         ; No direction pressed

move_up
    check_and_close_door()      ; Close door at current position if standing on one
    dec player_y                ; Move up
    update_player_tiles()
    rts

move_down
    check_and_close_door()      ; Close door at current position if standing on one
    inc player_y                ; Move down
    update_player_tiles()
    rts

move_left
    check_and_close_door()      ; Close door at current position if standing on one
    dec player_x                ; Move left
    update_player_tiles()
    rts

move_right
    check_and_close_door()      ; Close door at current position if standing on one
    inc player_x                ; Move right
    update_player_tiles()
    rts

; Grok attack_monster
attack_monster
    ldy #0
    lda (dir_ptr),y         ; Grab monster tile ID (44-55)
    sta tmp                 ; Save ID

    sec
    sbc #44                 ; Index 0-11
    tax
    lda monster_hp_table,x
    sta monster_hp          ; Load mon HP
    lda monster_dmg_table,x
    sta monster_dmg         ; Load mon DMG

combat_loop
    ; === YOU STRIKE FIRST ===
    lda monster_hp
    sec
    sbc player_melee_dmg    ; Your blade (starts @10)
    sta monster_hp
    bcs both_alive          ; Mon survives? Counter time

    ; === MONSTER DIES === (metaphor slayed!)
    lda #MAP_FLOOR
    sta (dir_ptr),y
    lda player_xp
    clc
    adc #10                 ; XP drop
    sta player_xp
    jsr update_hp_bar       ; Refresh your bar (glow-up)
    jsr update_xp_bar       ; Show XP gain!
    jmp combat_end

both_alive
    ; === MONSTER COUNTERS ===
    lda player_hp
    sec
    sbc monster_dmg
    bcc player_died         ; HP went negative, you died
    sta player_hp
    jsr update_hp_bar       ; Show the hit (drama!)
    jmp combat_loop         ; You survived, fight again!

player_died
    ; === YOU FALL ===
    lda #0
    sta player_hp
    jsr update_hp_bar       ; Show 0 HP
    jmp player_death

combat_end
    rts
    
; attack_monster
;     ; Player attacks the monster at dir_ptr
;     ; Monster attacks back, then dies

;     ; Monster counter-attacks! Deal damage to player
;     lda player_hp
;     sec
;     sbc #5                      ; Monster does 5 damage
;     sta player_hp
;     bcs monster_died            ; If carry set, HP didn't go negative

;     ; Player HP went below 0, set to 0
;     lda #0
;     sta player_hp

; monster_died
;     ; Give player XP (10 XP per monster)
;     lda player_xp
;     clc
;     adc #10
;     sta player_xp

;     ; Remove monster from map
;     ldy #0
;     lda #MAP_FLOOR              ; Replace monster with floor tile
;     sta (dir_ptr),y

;     ; Update the HP bar display
;     update_hp_bar()

;     ; Update the XP bar display
;     update_xp_bar()

;     ; Check if player died
;     lda player_hp
;     bne still_alive
;     jmp player_death            ; Player HP is 0, game over

; still_alive
;     rts

done
    rts
    .endp

; Check if player is standing on a doorway and close it behind them
.proc check_and_close_door
    ; Calculate current player position in map
    mwa #map player_ptr

    ldy player_y
    beq check_x
calc_y
    adw player_ptr #map_width
    dey
    bne calc_y

check_x
    adbw player_ptr player_x

    ; Check if current tile is a doorway
    ldy #0
    lda (player_ptr),y
    cmp #MAP_DOORWAY            ; Is it an open doorway?
    bne done                    ; If not, we're done

close_door
    lda #MAP_DOOR               ; Change doorway back to closed door
    sta (player_ptr),y

done
    rts
    .endp

; Player death - flash screen and freeze
.proc player_death
    ; Flash the screen by changing background color
    lda #$32                    ; Red
    sta COLOR4

    ; Small delay
    ldx #60
delay_loop
    lda RTCLK2
wait_tick
    cmp RTCLK2
    beq wait_tick
    dex
    bne delay_loop

    ; Back to black
    lda #$00
    sta COLOR4

    ; Another delay
    ldx #60
delay_loop2
    lda RTCLK2
wait_tick2
    cmp RTCLK2
    beq wait_tick2
    dex
    bne delay_loop2

death_loop
    jmp death_loop              ; Freeze the game
    .endp

