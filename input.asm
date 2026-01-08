.proc read_joystick1
    ;Temp vars used
    cur_btn = tmp1        ; current button state

    mva STRIG0 cur_btn          ; get current button state from hw register (1 = up, 0 = down)
    bne up                      ; if current button state is non-zero, the button is up

down                            ; the button is down
    lda stick_btn               ; get previous button state
    bne done                    ; if previous button state is non-zero, button was already up

held                            ; the button is held down
    lda stick_action            ; get the action state
    bne done                    ; if action state is non-zero, action is already set
    read_direction()            ; update the joystick pointer
    player_action()             ; get the player action based on direction
    jmp done                    ; skip to done

up                              ; the button is up
    read_direction()            ; update the joystick pointer
    player_move()               ; move the player based on direction
    clr stick_action            ; clear the action state

done
    mva cur_btn stick_btn       ; set stick button for next time
    rts
    .endp 

.proc read_direction()
    rts
    .endp

.proc player_action()
    rts
    .endp

.proc player_move()
    rts 
    .endp

   
