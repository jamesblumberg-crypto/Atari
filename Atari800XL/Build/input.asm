.proc read_joystick
    ; Temp vars used
    cur_btn = tmp1          ; Current button state
    
    mva STRIG0 cur_btn      ; Get current button state from HW register (1 = up, 0 = down)
    bne up                  ; If current button state is non-zero, the button is up

down                        ; The button is currently down
    lda stick_btn           ; Get the previous button state
    bne done                ; If previous button state is non-zero and current button state is zero, it was just pushed

held                        ; The button is held down
    lda stick_action        ; Get the action state
    bne done                ; If the action state is non-zero, don't do the action again
    read_direction()        ; Update the direction pointer
    player_action()         ; Do the action
    jmp done                ; Skip to done

up                          ; The button is currently up
    read_direction()        ; Update the direction pointer
    player_move()           ; Move the player
    clr stick_action        ; If the player is moving, we don't care about the action state so reset it                      

done
    mva cur_btn stick_btn   ; Set the stick button for next time
    rts
    .endp

; Get the direction from the joystick and update dir_ptr
; Does not support diagonal movement, and is processed in the following priority order: UP, DOWN, LEFT, RIGHT
.proc read_direction
    ; Temp vars used
    stick_dir = tmp2            ; Current stick direction
    
    ; Init
    mwa player_ptr dir_ptr      ; Copy the player pointer to the direction ptr as a base
    mva STICK0 stick_dir        ; Load stick bitmap from HW register

check_up
    and #STICK_UP               ; Check to see if it's pushed UP
    bne check_down              ; It's not pushed UP, so move to the next check
    sbw dir_ptr #map_width      ; It is pushed UP, so move the temp pointer up one line
    rts                         ; We're done updating the dir pointer (this will take priority)

check_down
    lda stick_dir               ; Re-copy non-mutated stick dir to A
    and #STICK_DOWN             ; Check to see if it's pushed DOWN
    bne check_left              ; It's not pushed DOWN, so move to the next check
    adw dir_ptr #map_width      ; It is pushed DOWN, so move the temp pointer down one line
    rts

check_left
    lda stick_dir               ; Re-copy non-mutated stick dir to AA
    and #STICK_LEFT             ; Check to see if it's pushed LEFT
    bne check_right             ; It's not pushed LEFT, so move to the next check
    dec dir_ptr                 ; It is pushed LEFT, so move the temp pointer left one
    rts

check_right
    lda stick_dir               ; Re-copy non-mutated stick dir to A
    and #STICK_RIGHT            ; Check to see if it's pushed RIGHT
    bne done                    ; If not, we're done checking
    inc dir_ptr                 ; It is pushed RIGHT, so move the temp pointer left one

done
    rts
    .endp

.proc player_action()
    ldi dir_ptr                 ; Load in tile from direction

check_door
    cmp #MAP_DOOR               ; Check if it's a door
    bne check_doorway           ; Skip to next check
    open_door()                 ; Open the door
    rts

check_doorway
    cmp #MAP_DOORWAY            ; Check if it's a doorway
    bne none                    ; Skip to next check
    close_door()                ; Close the door
    rts

none                            ; Nothing to do
    rts
    .endp

.proc open_door
    lda #MAP_DOORWAY            ; Load in the doorway tile
    sti dir_ptr                 ; Swap door for doorway
    inc stick_action            ; Set the action flag
    rts
    .endp

.proc close_door
    lda #MAP_DOOR               ; Load in the door tile
    sti dir_ptr                 ; Swap doorway for door
    inc stick_action            ; Set the action flag
    rts
    .endp

    
; Player Movement
.proc player_move
    ldi dir_ptr                 ; Dereference direction pointer
    beq blocked                 ; Not moving (dir_ptr == 0)

check_monster
    ; Check if target tile is a monster (tiles 44-51 for 8 monsters)
    cmp #44                     ; Is it >= monster start?
    bcc check_passable          ; No, check if passable
    cmp #52                     ; Is it < monster end (44 + 8)?
    bcs check_passable          ; No, check if passable
    jsr attack_monster          ; Yes, attack the monster!
    rts                         ; Don't move after attacking

check_passable
    is_passable()               ; Detect collision
    bcc blocked                 ; Carry flag == 0, so colliding
    mwa dir_ptr player_ptr      ; Move the player to the correct location

blocked                         ; We are blocked
    rts
    .endp

; Check to see if a tile is passable
; If carry flag is 0, collision
; If carry flag is 1, no collision
.proc is_passable
    lda no_clip                 ; Check to see if collision detection is active
    bne passable                ; If not, skip to passable
    ldi dir_ptr                 ; Dereference direction pointer to get tile
    cmp #PASSABLE_MIN           ; Is the tile passable
    bcc blocked                 ; Not passable

passable
    sec                         ; Tile is passable, so set the carry flag
    rts

blocked
    clc                         ; Tile is blocked, so clear the carry flag
    rts
    .endp

; Attack a monster at dir_ptr location
; Simple one-hit kill for now
; .proc attack_monster
;     ldy #0
;     lda #MAP_FLOOR              ; Replace monster with floor
;     sta (dir_ptr),y             ; Remove monster from map
;     rts
;     .endp
.proc attack_monster
    ldy #0
    lda (dir_ptr),y         ; Grab the monster tile (44-51 right now)
    sta tmp                 ; Save it briefly if needed later

    ; === YOU STRIKE FIRST ===
    lda #MAP_FLOOR
    sta (dir_ptr),y         ; Monster dies instantly (keep your one-hit for now)

    ; === MONSTER COUNTERS (the bite back) ===
    lda player_hp
    sec
    sbc #5                  ; Monster hits for 5 dmg — tweak this later for variety
    sta player_hp
    bcs no_death            ; Still alive?

    lda #0
    sta player_hp
    jmp player_death        ; Your death handler (add if not there yet)

no_death
    jsr update_hp_bar       ; Show the ouch! Bar drops visibly

    rts
.endp