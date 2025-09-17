        ORG $2000                         ; Start address

MSG:    .BYTE $54,$48,$41,$4E,$4B         ; THANK
        .BYTE $20                         ; space
        .BYTE $59,$4F,$55                 ; YOU
        .BYTE $20                         ; space
        .BYTE $4D,$59                     ; MY
        .BYTE $20                         ; space
        .BYTE $42,$41,$52,$42,$41,$52     ; BARBAR
        .BYTE $49,$41,$4E                 ; IAN

        .BYTE $00                         ; Null terminator for end

        LDY #0                            ; Y=0, index in MSG
        LDX #0                            ; X=0, start of screen

DisplayLoop:
        LDA MSG,Y                         ; Get next byte
        BEQ Done                          ; If zero, end of message
        STA $1800,X                       ; Store to screen memory
        INY
        INX
        JMP DisplayLoop                   ; Repeat for next character

Done:
        RTS
