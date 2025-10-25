        org $2000
        .byte $FF, $FF        ; XEX header

        .INIT start           ; Entry point for initialization

start:
        lda #$00
        sta $D01A             ; Set background color to black
        rts

        .END