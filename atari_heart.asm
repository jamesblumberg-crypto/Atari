; Romantic 6502 Assembly Program for Atari 800XL
; Uses Atari OS ROM routines for screen output

```
    .org $0600          ; Safe user RAM area on Atari
```

; Atari OS equates
ICCOM   = $0342             ; I/O command
ICBAL   = $0344             ; Buffer address low
ICBAH   = $0345             ; Buffer address high
ICBLL   = $0348             ; Buffer length low
ICBLH   = $0349             ; Buffer length high
CIOV    = $E456             ; Central I/O vector

START:  
; Set up I/O Control Block for screen output
LDA #$09            ; PUT RECORD command
STA ICCOM

```
    ; Point to our romantic message
    LDA #<MESSAGE
    STA ICBAL
    LDA #>MESSAGE
    STA ICBAH
    
    ; Set message length
    LDA #MSGLEN
    STA ICBLL
    LDA #$00
    STA ICBLH
    
    ; Call Central I/O
    LDX #$00            ; Use IOCB #0 (screen)
    JSR CIOV
    
    ; Now display hearts
    LDA #<HEARTS
    STA ICBAL
    LDA #>HEARTS
    STA ICBAH
    
    LDA #HEARTLEN
    STA ICBLL
    LDA #$00
    STA ICBLH
    
    JSR CIOV
```

FOREVER:
JMP FOREVER         ; Eternal love loop!

; Message data (ATASCII format)
MESSAGE:
.byte “YOU COMPILE MY HEART!”, $9B  ; $9B is Atari EOL
MSGLEN  = * - MESSAGE

; Heart pattern
HEARTS:
.byte “   <3 <3 <3”, $9B
.byte “  I LOVE YOU!”, $9B
HEARTLEN = * - HEARTS

```
    .end START
```