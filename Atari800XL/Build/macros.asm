.macro inc16 addr
    inc :addr
    bne skip_carry
    inc :addr + 1
skip_carry
.endm

.macro dec16 addr
    lda :addr
    bne skip_borrow
    dec :addr + 1
skip_borrow
    dec :addr
.endm

.macro adbw src val
    lda :src
    add :val
    sta :src
    bcc skip_carry
    inc :src + 1
skip_carry
.endm

.macro advance_ptr data ptr width count offset
    mwa :data :ptr
    lda :count  ; Check to make sure it's not 0
    beq done    ; If it is, we're done

    ldy #0
loop
    adbw :ptr :width
    iny
    cpy :count
    bne loop

done
    adbw :ptr :offset
.endm

.macro copy_bytes src dest num_bytes
    mwa #:src tmp_addr1
    mwa #:dest tmp_addr2

    ldy #0
loop
    lda (tmp_addr1),y
    sta (tmp_addr2),y
    iny
    cpy #:num_bytes
    bne loop

.endm

.macro copy_data src dest num_pages
    mwa #:src tmp_addr1
    mwa #:dest tmp_addr2

    ldy #0
    ldx #0
loop
    lda (tmp_addr1),y
    sta (tmp_addr2),y
    iny
    bne loop
    inc tmp_addr1 + 1
    inc tmp_addr2 + 1
    inx
    cpx #:num_pages
    bne loop
.endm

.macro copy_monster_colors src dest start
    ; start = ribbon index 0-3 (matches setup_floor_monsters).
    ; Color file has 3 bytes per slot; ribbon R uses slot R.
    mwa #:src tmp_addr1

    lda :start
    asl
    add :start
    tay

    lda (tmp_addr1),y
    sta :dest + 11
    iny
    lda (tmp_addr1),y
    sta :dest + 12
    iny
    lda (tmp_addr1),y
    sta :dest + 13
.endm
; Copy one normal ribbon (16 chars = 128 bytes) into live charset chars 88-103
; your sheet: ribbons 0..2 are 8 monsters x 2 chars wide x 1 tall = 16 chars each
; offset = ribbon *128 bytes (char 0, 16, 32, 48, 64, 80, 96, 112)
; do not copy past char 111 (bow/ladders live at 112+)
.macro copy_monsters src dest start
    ; Characters are 8 bytes wide; map monster tiles are 2 characters wide.
    ; monsters_*.png is 4 ribbons of 8 monsters (each ~16x16 = 2x2 chars):
    ;   ribbon 0 = chars 0-31 (easiest), … ribbon 3 = 96-127 (dragons / hardest art)
    ; start = ribbon index 0-3; source offset = ribbon * 256 bytes.
    ; Copied into dungeon charset at character 88 (tiles 44-51 use 88-103).
    mwa #:src tmp_addr1
    mwa #:dest tmp_addr2

    adw tmp_addr2 #(88 * 8)
    ; removed this text - it was picking the wrong monster chars
    ; Add ribbon * 256 to source (high byte += ribbon)
    ; lda tmp_addr1 + 1
    ; clc
    ; adc :start
    ; sta tmp_addr1 + 1
; offseet = ribbon *128 (ribbon 0-0, 1-128, 2-256, 3-384)
    ; lda :start
    ; asl ; *2
    ; asl ; *4
    ; asl ; *8
    ; asl ; *16
    ; asl ; *32
    ; asl ; *64
    ; asl ; *128
    ; sta tmp ; low 8 bits of offset
    ; lda tmp_addr1
    ; clc
    ; adc tmp
    ; sta tmp_addr1
    ; lda tmp_addr1 + 1
    ; adc #0 ; add carry - high byte (e.g. ribbon 2 - +$0100)
    ; sta tmp_addr1 + 1
    lda :start
    asl          ;*2
    asl          ;*4
    asl          ;*8
    asl          ;*16
    asl          ;*32
    asl          ;*64
    asl          ;*128
    php          ; save that carry 
    sta tmp      ; low 8 bits ribbon 2- 0, ribbon 1-128
    lda tmp_addr1
    clc
    adc tmp
    sta tmp_addr1
    lda tmp_addr1 + 1
    plp          ; restore carry from *128
    adc #0       ; high byte += 1 when offsset >= 256
    sta tmp_addr1 + 1
    ldy #0
loop
    lda (tmp_addr1),y
    sta (tmp_addr2),y
    iny
    cpy #128             ; 24 chars - slots 88-111 only (leave 112+ for bow/ladders)
    bne loop                ; 256 bytes = full ribbon (32 chars)

.endm


.macro ldi addr
    ldy #0
    lda (:addr),y
.endm

.macro sti addr
    ldy #0
    sta (:addr),y
.endm

.macro clr addr
    mva #0 :addr
.endm

.macro debug
	;##TRACE "\nDEBUG:\n"
    ;##TRACE "player_x (0x%02X): 0x%02X (%03d)            player_y (0x%02X): 0x%02X (%03d)            player_ptr (0x%04X): 0x%04X (%05d)    map_ptr (0x%04X): 0x%04X (%05d)" player_x db(player_x) db(player_x) player_y db(player_y) db(player_y) player_ptr dw(player_ptr) dw(player_ptr) map_ptr dw(map_ptr) dw(map_ptr)
	;##TRACE "screen_ptr (0x%04X): 0x%04X (%05d)    status_ptr (0x%04X): 0x%04X (%05d)    input_timer (0x%02X): 0x%02X (%03d)         stick_btn (0x%02X): 0x%02X (%03d)" screen_ptr dw(screen_ptr) dw(screen_ptr) status_ptr dw(status_ptr) dw(status_ptr) input_timer db(input_timer) db(input_timer) stick_btn db(stick_btn) db(stick_btn)
	;##TRACE "stick_action (0x%02X): 0x%02X (%03d)        tmp (0x%02X): 0x%02X (%03d)                 tmp1 (0x%02X): 0x%02X (%03d)                tmp2 (0x%02X): 0x%02X (%03d)" stick_action db(stick_action) db(stick_action) tmp db(tmp) db(tmp) tmp1 db(tmp1) db(tmp1) tmp2 db(tmp2) db(tmp2)
	;##TRACE "tmp_x (0x%02X): 0x%02X (%03d)               tmp_y (0x%02X): 0x%02X (%03d)               rand (0x%02X): 0x%02X (%03d)                rand16 (0x%04X): 0x%04X (%05d)" tmp_x db(tmp_x) db(tmp_x) tmp_y db(tmp_y) db(tmp_y) rand db(rand) db(rand) rand16 dw(rand16) dw(rand16)
	;##TRACE "anim_timer (0x%02X): 0x%02X (%03d)          charset_a (0x%02X): 0x%02X (%03d)           no_clip (0x%02X): 0x%02X (%03d)             char_colors_ptr (0x%04X): 0x%04X (%05d)" anim_timer db(anim_timer) db(anim_timer) charset_a db(charset_a) db(charset_a) no_clip db(no_clip) db(no_clip) char_colors_ptr dw(char_colors_ptr) dw(char_colors_ptr)
	;##TRACE "room_ptr (0x%04X): 0x%04X (%05d)      room_col (0x%02X): 0x%02X (%03d)            room_row (0x%02X): 0x%02X (%03d)            doors (0x%02X): 0x%02X (%03d)" room_ptr dw(room_ptr) dw(room_ptr) room_col db(room_col) db(room_col) room_row db(room_row) db(room_row) doors db(doors) db(doors)
	;jmp $FFFF
.endm
