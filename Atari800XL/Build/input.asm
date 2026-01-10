.proc read_joystick
    ; temp vars used
    cur_btn = tmp_addr1         ; current button state

    mva STRIG0 cur_btn          ; Read joystick button state
    bne up                      ; If button not pressed, skip

down                            ; the button is currently down
    lda stick_btn               ; get the previous button state
    bne done                    ; if previous button state is non-zero, skip
