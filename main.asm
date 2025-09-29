; Jimventure - An Adventure in Atari 8-bit assembly
; github.com

    org $2000

SAVSMC = $0058 ; SCREEN MEMORY ADDRESS
sdstl  = $0230 ; START OF DISPLAY LIST

screen = $4000  ; Screen buffer location
blank8 = $70    ; 8 blank lines
antic2 = 2      ; ANTIC mode 2 (text mode 0)
lms = $40       ; Load Memory Start
jvb = $41       ; Jump to Vertical Blank   

antic3 = 3      ; ANTIC mode 3 (text mode 1)
antic4 = 4      ; ANTIC mode 4 (text mode 2)
antic5 = 5      ; ANTIC mode 5 (text mode 3)
antic6 = 6      ; ANTIC mode 6 (text mode 4)
antic7 = 7      ; ANTIC mode 7 (text mode 5)

; Set up the display list and screen memory
    LDA #<dlist
    STA sdstl
    LDA #>dlist
    STA sdstl+1
 
 ; main loop
    LDY #0
    ; Load the address of the string into the zero page pointer for screen memory

loop
    LDA hello,Y
    sta screen,Y       ; Store address of string in screen memory address
    INY
    CPY #12
    BNE loop

    JMP *               ; Infinite loop

; display list
dlist
    .byte blank8, blank8, blank8 
    .byte antic5 + lms, <screen, >screen
    .byte antic5, antic5, antic5, antic5, antic5, antic5
    .byte antic5, antic5, antic5, antic5, antic5
    
    .byte jvb, <dlist, >dlist


; Data
hello
    .BYTE "HELLO ATARI!"
