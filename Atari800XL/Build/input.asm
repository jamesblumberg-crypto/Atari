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
    mwa player_ptr dir_ptr      ; copy the player  pointer to the direction ptr as a base
    mva STICK0 stick_dir        ; load stick bitmap from HW register
    rts
    .endp

.proc player_action()
    rts
    .endp

.proc player_move()
    rts
    .endp

