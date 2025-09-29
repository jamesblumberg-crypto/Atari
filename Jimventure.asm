; --- demo.asm  (assemble with ATasm or MADS into .XEX) ---
        .org    $2000          ; load address (any safe RAM is fine)

; --- constants (hardware) ---
DMACTL  = $D400                ; ANTIC DMA control
PMBASE  = $D407                ; ANTIC Player/Missile base (hi byte)
GRACTL  = $D01D                ; GTIA graphics control
HPOSP0  = $D000                ; Player0 horizontal position
COLPM0  = $D012                ; Player0 color/luma
TRIG0   = $D010                ; Fire button (0 = pressed)
PORTA   = $D300                ; Joystick directions (active low)

; PM memory (single-line): missiles +$300, P0 +$400, P1 +$500, P2 +$600, P3 +$700
PMBASE_PAGE = $30              ; -> $3000 (must be 2K-aligned for single-line)

; --- zero page ---
        .org    *              ; keep same segment
XPOS    .ds     1

; --- code ---
Start:
        sei
        cld

; Set Player/Missile base to $3000
        lda     #PMBASE_PAGE
        sta     PMBASE

; Clear the used 2KB PM area ($3000..$37FF)
        ldx     #$00
        lda     #$00
ClearPM:
        sta     $3000,x
        sta     $3100,x
        sta     $3200,x
        sta     $3300,x
        sta     $3400,x
        sta     $3500,x
        sta     $3600,x
        sta     $3700,x
        inx
        bne     ClearPM

; Install an 8x8 sprite for Player 0 at vertical offset ~100
; Player 0 page = $3000 + $400 = $3400
        ldy     #100           ; vertical position (scanline within PM page)
        ldx     #0
SpriteLoop:
        lda     SpriteData,x
        sta     $3400,y
        iny
        inx
        cpx     #8
        bne     SpriteLoop

; Color and initial X
        lda     #$4A           ; color/luma (pick something visible)
        sta     COLPM0
        lda     #80
        sta     XPOS
        sta     HPOSP0

; Enable players+missiles on GTIA, and ANTIC P/M DMA (single-line, normal width)
; DMACTL: bit5=1 (DL DMA), bit4=1 (single-line PM), bits3..2=11 (P+M), bits1..0=10 (normal width) => %00111110 = $3E
        lda     #$3E
        sta     DMACTL
        lda     #$03           ; GRACTL: bit1=players, bit0=missiles
        sta     GRACTL

        cli

MainLoop:
; --- read joystick 1 (PORTA bits 0..3: U D L R, active low) ---
        lda     PORTA
        and     #%00001111     ; only J1 bits
        eor     #%00001111     ; flip to active-high (1 means pressed)

        ldx     XPOS

; left?
        lda     PORTA
        and     #%00000100     ; bit2 was LEFT, active low
        beq     NotLeft
        dex
NotLeft:
; right?
        lda     PORTA
        and     #%00001000     ; bit3 was RIGHT, active low
        beq     NotRight
        inx
NotRight:
        stx     XPOS
        stx     HPOSP0

; fire changes color
        lda     TRIG0          ; 0 = pressed
        beq     FirePressed
        lda     #$4A
        bne     SetColor
FirePressed:
        lda     #$5C
SetColor:
        sta     COLPM0

        jmp     MainLoop

; 8x8 pattern (bits left-to-right). 1-bits are visible pixels.
SpriteData:
        .byte %00111100
        .byte %01111110
        .byte %11111111
        .byte %11100111
        .byte %11100111
        .byte %11111111
        .byte %01111110
        .byte %00111100