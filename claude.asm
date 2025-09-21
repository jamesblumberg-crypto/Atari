   ORG $3000        ; Start program at $3000
    
start:
    LDA #$46         ; Load color value
    STA $D01A        ; Store to border color register
    JMP start        ; Loop foreve