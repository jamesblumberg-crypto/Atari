; Atari 800XL Assembly Source File
; Main program file
	org $b000
; RAM: $2000-7FFF - 24K
map     			= $2000 ; Map (16K+)
screen  			= $7000 ; Screen buffer (480 bytes)
status_line			= $71e0 ; Status Line (40 bytes)
tmp_room			= $7208 ; Temp room (225 bytes)
placed_doors		= $72e9 ; Doors that have been placed (64 bytes)
avail_doors			= $7329	; Doors that are available (64 bytes)
occupied_rooms		= $7369 ; Rooms that are occupied (8 bytes)
; free
cur_char_colors_a	= $7380 ; 16 bytes
cur_char_colors_b	= $7390	; 16 bytes
; free

pmg     			= $7400 ; Player Missile Data (1K)
pmg_missiles		= $7580 ; Missile data (128 bytes, double-line res)
cur_charset_a		= $7800 ; Current character set A (1K)
cur_charset_b		= $7c00 ; Current character set B (1K)
; free

; 16K Cartridge ROM: $8000-BFFF - 16K
; 8000-8FFF
charset_dungeon_a 	= $8000 ; Main character set (1K)
charset_dungeon_b 	= $8400 ; Main character set (1K)
charset_outdoor_a 	= $8800 ; Character Set for outdoors (1K)
charset_outdoor_b 	= $8c00 ; Character Set for outdoors (1K)

; 9000-9FFF
monsters_a          = $9000 ; Monster characters (1K)
monsters_b          = $9400 ; Monster characters (1K)
; free
dlist				= $9800
room_types			= $a000 ; 3600 Bytes
room_positions		= $ae10	; 128 bytes
room_pos_doors		= $ae90 ; 64 bytes
room_type_doors		= $aed0 ; 16 bytes
charset_dungeon_a_colors = $aee0 ; 16 bytes
charset_dungeon_b_colors = $aef0 ; 16 bytes
charset_outdoor_a_colors = $af00 ; 16 bytes
charset_outdoor_b_colors = $af10 ; 16 bytes
monsters_a_colors   = $af20 ; 51 bytes
monsters_b_colors   = $af53 ; 51 bytes

; free

; B000-BFFF (Code)

; stick_up    = %0001
; stick_down  = %0010 
; stick_left  = %0100
; stick_right = %1000

map_ptr 			= $92
screen_ptr 			= $94
player_x			= $96
player_y			= $97
tmp					= $98
up_tile				= $9a
down_tile			= $9b
left_tile			= $9c
right_tile			= $9d
on_tile				= $9e	
tmp_addr1			= $a0
tmp_addr2  			= $a2

screen_char_width 	= 40
screen_width 		= 19
screen_height 		= 11
border				= 6
room_width			= 15
room_height			= 15
map_width 			= room_width * 8 + 7 + border * 2
map_height 			= room_height * 8 + 7 + border * 2
map_room_columns	= 8
map_room_rows		= 8

playfield_width 	= 11
playfield_height 	= 11

input_speed 		= 5
anim_speed 			= 20

input_timer 		= $a4
status_ptr 			= $a5 ; 16 bit
rand				= $a7
room_type			= $a8
room_pos			= $a9
room_x				= $aa
room_y				= $ab
room_ptr			= $ac ; 16 bit
tmp_x				= $ae
tmp_y				= $af
num_rooms			= $b0
max_rooms			= $b1
placed_doors_ptr	= $b2 ; 16 bit
avail_doors_ptr		= $b4 ; 16 bit
room_col			= $b6
room_row			= $b7
pow2_ptr			= $b8 ; 16 bit
occupied_rooms_ptr  = $ba ; 16 bit
doors				= $bc
tmp2				= $bd
rand16				= $be
clock				= $bf
anim_timer			= $c0
charset_a			= $c1
num_monsters		= $c2
starting_monster	= $c3
no_clip				= $c4
char_colors_ptr		= $c5 ; 16 bit

	
;stick_dir    = $d8
stick_btn    		= $d9
stick_action 		= $da

player_ptr          = $de
dir_ptr             = $e0
tmp1 				= $e2
; tmp2 = $e3

; Combat variables
monster_hp           = $e3
player_melee_dmg     = $e4
monster_dmg          = $e5
player_hp            = $e6
player_max_hp        = $e7
player_xp            = $e8
player_level         = $e9

; Weapon system variables
player_ranged_dmg    = $ea  ; Ranged weapon damage (bow)
has_bow              = $eb  ; 0 = no bow, 1 = has bow
equipped_weapon      = $ec  ; 0 = melee, 1 = ranged (bow)

; Arrow missile variables
arrow_active         = $ed  ; 0 = no arrow, 1 = arrow in flight
arrow_x              = $ee  ; Arrow horizontal position (screen coords)
arrow_y              = $ef  ; Arrow vertical position (scanline)
arrow_dir            = $f0  ; Arrow direction (1=N, 2=S, 3=W, 4=E)
arrow_map_x          = $f1  ; Arrow map X coordinate
arrow_map_y          = $f2  ; Arrow map Y coordinate
player_dir           = $f3  ; Last direction player moved (for aiming)
arrow_subtile        = $f4  ; Sub-tile counter (0-7, update map coord when wraps)
arrow_ptr            = $f5  ; Arrow map pointer (16-bit)

; Colors
white 				= $0a
red 				= $32
black 				= $00
peach 				= $2c
blue 				= $92
gold 			= $2a
	
	mwa #map map_ptr

	debug
	setup_screen()
	
	;update_player_tiles()
	display_borders()
	
	update_ui()
	setup_colors()
	mva #>charset_outdoor_a CHBAS
	clear_pmg()
	load_pmg()
	setup_pmg()

	; Initialize ALL missiles off-screen and clear graphics
	lda #0
	sta HPOSM0
	sta HPOSM1
	sta HPOSM2
	sta HPOSM3
	sta arrow_active

	; Explicitly clear all missile graphics data
	ldx #127
clear_all_missiles
	sta pmg_missiles,x
	dex
	bpl clear_all_missiles

	;mva #16 starting_monster
	mva #24 starting_monster
	mva #4 num_monsters

	lda #16
	sta player_x
	sta player_y

	; Initialize player stats
	lda #100
	sta player_hp
	sta player_max_hp
	lda #15
	sta player_melee_dmg
	lda #0
	sta player_xp
	lda #1
	sta player_level

	; Initialize weapon system
	lda #0
	sta player_ranged_dmg   ; No ranged damage until bow acquired
	sta has_bow             ; Player starts without bow
	sta equipped_weapon     ; Start with melee equipped (0 = melee)
	sta arrow_active        ; No arrow in flight
	lda #SOUTH              ; Default facing direction
	sta player_dir
	
	mva #123 rand
	mva #201 rand16
	
	mwa #powers_of_two pow2_ptr
	mwa #occupied_rooms occupied_rooms_ptr

	copy_data charset_dungeon_a cur_charset_a 4
	copy_data charset_dungeon_b cur_charset_b 4
	copy_bytes charset_dungeon_a_colors cur_char_colors_a 16
	copy_bytes charset_dungeon_b_colors cur_char_colors_b 16
	copy_monsters monsters_a cur_charset_a starting_monster
	copy_monsters monsters_b cur_charset_b starting_monster
	copy_monster_colors monsters_a_colors cur_char_colors_a starting_monster
	copy_monster_colors monsters_b_colors cur_char_colors_b starting_monster
	
	new_map()

	; Initialize combat stats
	lda #15
	sta player_melee_dmg        ; Player does 15 damage per hit

	lda #100
	sta player_hp               ; Player starts with 100 HP
	sta player_max_hp           ; Max HP is also 100

	place_monsters num_monsters #8

skip_monster_tables
	; Initialize the HP and XP bars to match player stats
	jsr update_hp_bar
	jsr update_xp_bar
	jsr update_level_display
	jsr update_melee_display
	jsr update_ranged_display

	lda #0
	sta no_clip

	init_player_ptr()
	jsr place_bow               ; Place bow on floor adjacent to player

	; Initialize variables that need starting values
	lda #0
	sta charset_a              ; Start with charset A
	sta anim_timer             ; Initialize animation timer
	sta input_timer            ; Initialize input timer
	mwa #cur_char_colors_a char_colors_ptr  ; Initialize color pointer

	; Draw initial screen before game loop
	blit_screen()

game
	mva RTCLK2 clock
	animate                     ; Re-enabled after fix_color fix
	get_input                   ; Re-enabled to test
	jsr read_keyboard           ; Check for weapon switching keys
	jsr update_arrow            ; Update arrow position and check collisions
	jmp game

.macro set_colors
	lda charset_a
	beq sc_use_charset_a
	mwa #cur_char_colors_b char_colors_ptr
	jmp sc_done
sc_use_charset_a
	mwa #cur_char_colors_a char_colors_ptr
sc_done
.endm

; Update the HP bar display based on current player HP
; HP bar has 6 segments, each represents roughly 1/6 of max HP
.proc update_hp_bar
	mwa #screen screen_ptr
	adw screen_ptr #28          ; Position at start of HP bar

	; Calculate number of full segments (~17 HP each for 100 HP max)
	lda player_hp
	clc
	adc #16                    ; Bias so 100 HP gives 6 segments (ceil division)
	ldx #0                      ; X counts full segments
calc_segments
	cmp #17                     ; Is HP >= 17?
	bcc draw_bars               ; If less, start drawing
	sec
	sbc #17                     ; Subtract 17
	inx                         ; Increment segment counter
	cpx #6                      ; Max 6 segments
	bcc calc_segments

draw_bars
	stx tmp                     ; Save number of full segments

	; Draw left border
	ldy #0
	lda #UI_BAR_LEFT
	sta (screen_ptr),y
	inc16 screen_ptr

	; Draw full segments
	ldx tmp
draw_full
	cpx #0
	beq draw_empty              ; No more full segments
	lda #UI_HP_FULL
	sta (screen_ptr),y
	inc16 screen_ptr
	dex
	jmp draw_full

draw_empty
	; Fill remaining with empty segments up to 6
	lda tmp
fill_loop
	cmp #6
	bcs draw_right              ; Already drew 6 slots
	lda #UI_BAR_EMPTY
	sta (screen_ptr),y
	inc16 screen_ptr
	lda tmp
	clc
	adc #1
	sta tmp
	jmp fill_loop

draw_right
	lda #UI_BAR_RIGHT
	sta (screen_ptr),y

	rts
.endp

; XP bar has 9 segments, each represents 10 XP (90 XP for full bar)
.proc update_xp_bar
	mwa #screen screen_ptr
	adw screen_ptr #(screen_char_width * 3 + 28)  ; Position at start of XP bar (row 3, col 28)

	; Calculate number of full segments (10 XP each)
	lda player_xp
	ldx #0                     ; X counts full segments
calc_segments
	cmp #10                    ; Is XP >= 10?
	bcc draw_bars              ; If less, start drawing
	sec
	sbc #10                    ; Subtract 10
	inx                        ; Increment segment counter
	cpx #9                     ; Max 9 segments
	bcc calc_segments

draw_bars
	stx tmp                    ; Save number of full segments

	; Draw left border
	ldy #0
	lda #UI_BAR_LEFT
	sta (screen_ptr),y
	inc16 screen_ptr

	; Draw full segments
	ldx tmp
draw_full
	cpx #0
	beq draw_empty             ; No more full segments
	lda #UI_XP_FULL
	sta (screen_ptr),y
	inc16 screen_ptr
	dex
	jmp draw_full

draw_empty
	; Fill remaining with empty segments up to 9
	lda tmp
fill_loop
	cmp #9
	bcs draw_right             ; Already drew 9 slots
	lda #UI_BAR_EMPTY
	sta (screen_ptr),y
	inc16 screen_ptr
	lda tmp
	clc
	adc #1
	sta tmp
	jmp fill_loop

draw_right
	lda #UI_BAR_RIGHT
	sta (screen_ptr),y

	rts
.endp

; Update the level display in the HUD (top right after HP bar)
; Displays level 1-9 as a single digit at position 38
.proc update_level_display
	mwa #screen screen_ptr
	adw screen_ptr #38         ; Position at level number (col 38)

	; Convert level to UI_NUMBER character
	; UI_NUMBER_0 = 44, so UI_NUMBER_0 + level = correct character
	lda player_level
	clc
	adc #UI_NUMBER_0           ; Add base offset to get UI_NUMBER_X
	ldy #0
	sta (screen_ptr),y

	rts
.endp

; Update the melee damage display in the HUD (row 1, positions 28-30)
; Displays 3-digit number (000-255)
.proc update_melee_display
    mwa #screen screen_ptr
    adw screen_ptr #(screen_char_width + 28)  ; Row 1, col 28

    ; Convert player_melee_dmg to 3 digits
    lda player_melee_dmg
    jsr display_3_digits

    rts
.endp

; Update the ranged damage display in the HUD (row 1, positions 35-37)
; Displays 3-digit number (000-255)
.proc update_ranged_display
    mwa #screen screen_ptr
    adw screen_ptr #(screen_char_width + 35)  ; Row 1, col 35

    ; Convert player_ranged_dmg to 3 digits
    lda player_ranged_dmg
    jsr display_3_digits

    rts
.endp

; Helper: Display a 3-digit number from A register at screen_ptr
; Destroys: A, X, Y, tmp, tmp2
.proc display_3_digits
    sta tmp                     ; Save value to convert

    ; Calculate hundreds digit
    ldx #0
hundreds_loop
    cmp #100
    bcc tens
    sec
    sbc #100
    inx
    jmp hundreds_loop

tens
    sta tmp2                    ; Save remainder for tens
    txa
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #0
    sta (screen_ptr),y          ; Display hundreds digit

    ; Calculate tens digit
    lda tmp2
    ldx #0
tens_loop
    cmp #10
    bcc ones
    sec
    sbc #10
    inx
    jmp tens_loop

ones
    sta tmp2                    ; Save remainder for ones
    txa
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #1
    sta (screen_ptr),y          ; Display tens digit

    ; Display ones digit
    lda tmp2
    clc
    adc #UI_NUMBER_0            ; Convert to UI character
    ldy #2
    sta (screen_ptr),y          ; Display ones digit

    rts
.endp

; Check if player has enough XP to level up
; If player_xp >= 90, level up:
;   - Increment player_level
;   - Reset player_xp (carry over excess)
;   - Restore player_hp to player_max_hp
;   - Increase player_melee_dmg by 25%
;   - Update HP and XP bars
.proc check_level_up
	lda player_xp
	cmp #90                    ; Check if XP >= 90
	bcc no_level_up            ; If less than 90, no level up

level_up
	; Subtract 90 from XP (carry over excess)
	lda player_xp
	sec
	sbc #90
	sta player_xp

	; Increment level
	inc player_level

	; Restore HP to max
	lda player_max_hp
	sta player_hp

	; Increase damage by 25% (new_dmg = old_dmg + old_dmg/4)
	lda player_melee_dmg
	sta tmp                    ; Save original damage
	lsr                        ; Divide by 2
	lsr                        ; Divide by 4 (now A = damage/4)
	clc
	adc tmp                    ; Add original damage (A = damage + damage/4 = 1.25 * damage)
	sta player_melee_dmg

	; Update all displays to reflect changes
	jsr update_hp_bar
	jsr update_xp_bar
	jsr update_level_display
	jsr update_melee_display

no_level_up
	rts
.endp


.macro get_input
	lda clock
	cmp input_timer
	bne input_done
	read_joystick()
	blit_screen()
	lda clock
	add #input_speed
	sta input_timer
input_done
	.endm

.macro animate
	lda clock
	cmp anim_timer
	bne anim_done
	lda charset_a
	eor #$ff
	sta charset_a
	set_colors
	blit_screen()
	lda clock
	add #anim_speed
	sta anim_timer
anim_done
	.endm

* --------------------------------------- *
* Proc: delay                             *
* Uses Real-time clock to delay x/60 secs *
* --------------------------------------- *
.proc delay (.byte x) .reg
start
	lda RTCLK2
wait
	cmp RTCLK2
	beq wait

	dex
	bne start

	rts
	.endp

* --------------------------------------- *
* Proc: setup_colors                      *
* Sets up colors                          *
* --------------------------------------- *
.proc setup_colors
	; Character Set Colors
	mva #white COLOR0 	; %01
	mva #red COLOR1  	; %10
	mva #blue COLOR2	; %11
	mva #gold COLOR3    ; %11 (inverse)
	mva #black COLOR4   ; %00

	; Player-Missile Colors
	; P0=hair, P1=face, P2=body
	; Arrow uses M2 which shares PCOLR2 with P2 (both will be red)
	mva #black PCOLR0       ; Hair color (Player 0)
	mva #peach PCOLR1       ; Face color (Player 1)
	mva #red PCOLR2         ; Body (P2) AND Arrow (M2) - both red
	mva #black PCOLR3

	rts
	.endp

* --------------------------------------- *
* Proc: clear_pmg                         *
* Clears memory for Player-Missile Gfx    *
* --------------------------------------- *
.proc clear_pmg
pmg_p0 = pmg + $200
pmg_p1 = pmg + $280
pmg_p2 = pmg + $300
pmg_p3 = pmg + $380

	ldx #$80
	lda #0
loop
	dex
	sta pmg_p0,x
	sta pmg_p1,x
	sta pmg_p2,x
	sta pmg_p3,x
	sta pmg_missiles,x      ; Also clear missiles
	bne loop
	rts
	.endp

* --------------------------------------- *
* Proc: load_pmg                          *
* Load PMG Graphics                       *
* --------------------------------------- *
.proc load_pmg
pmg_p0 = pmg + $200
pmg_p1 = pmg + $280
pmg_p2 = pmg + $300
pmg_p3 = pmg + $380

	ldx #0
loop
	mva pmgdata,x pmg_p0+60,x
	mva pmgdata+8,x pmg_p1+60,x
	mva pmgdata+16,x pmg_p2+60,x
	mva pmgdata+24,x pmg_p3+60,x
	inx
	cpx #8
	bne loop
	rts
	.endp

* --------------------------------------- *
* Proc: setup_pmg                         *
* Sets up Player-Missile Graphics System  *
* --------------------------------------- *
.proc setup_pmg
	mva #>pmg PMBASE
	mva #46 SDMCTL ; Single Line resolution
	mva #3 GRACTL  ; Enable PMG
	mva #1 GRPRIOR ; Give players priority
	mva #0 SIZEM         ; Normal width for all missiles (2 color clocks)
	lda #92
	sta HPOSP0
	sta HPOSP1
	sta HPOSP2
	sta HPOSP3
	rts
	.endp

; fix_color - Adjusts tile color based on char_colors_ptr table
; Input: A = tile character value
; Output: A = adjusted tile character (possibly with bit 7 set for gold color)
; Preserves: Y register
.proc fix_color
	; Save Y register
	sta tmp
	tya
	pha
	lda tmp

	; Get number of LSRs to perform (how many times to shift)
	and #$07
	add #1
	sta tmp2

	; Get color index
	lda tmp
	lsr
	lsr
	lsr
	tay
	lda (char_colors_ptr),y

	; Shift right as necessary to put the desired bit into the carry flag
shift_bits
	lsr
	dec tmp2
	bne shift_bits

	; Check the carry flag to see if it has a 1 - if so, it needs to be yellow, otherwise blue
	bcc done

add_color
	lda tmp
	add #128
	sta tmp

done
	; Restore the Y register
	pla
	tay
	lda tmp
	rts
.endp

.macro blit_tile
	lda (map_ptr),y			; Load the tile from the map
	asl						; Multiply by two to get left character
	jsr fix_color			; Apply color adjustment (now a procedure)
	sta (screen_ptr),y		; Store the left character
	inc16 screen_ptr		; Advance the screen pointer
	lda (map_ptr),y
	asl
	add #1
	jsr fix_color			; Apply color adjustment (now a procedure)
	sta (screen_ptr),y		; Store the right character
	adw map_ptr #1			; Advance the map pointer
	adw screen_ptr #1		; Advance the screen pointer
	.endm

.macro blit_circle_line body, map_space, screen_space
	mwa map_ptr tmp_addr1
	mwa screen_ptr tmp_addr2
	
	adw map_ptr #:map_space
	adw screen_ptr #:screen_space
	ldx #:body
loop
	blit_tile()
	dex
	bne loop

	mwa tmp_addr1 map_ptr
	mwa tmp_addr2 screen_ptr
	.endm

.proc init_player_ptr
	mwa #map map_ptr
	mwa map_ptr player_ptr			; Copy the map address to the player pointer

	; Shift player_y rows
    ldy player_y				; Load in Y starting location (number of rows)
loop
    adw player_ptr #map_width	; Add a row
    dey
    bne loop					; Keep going
    
	; Shift player_x columns
	adbw player_ptr player_x	; Add player_x number of columns
    rts
.endp

.proc map_offset
	mwa #screen screen_ptr
	mwa player_ptr map_ptr								; Copy player location to map location
	sbw map_ptr #(playfield_height / 2 * map_width)		; Subtract height
	sbw map_ptr #(playfield_width / 2)					; Subtract width
	rts
	.endp

.macro blit_char char addr pos
	lda :char
	ldy :pos
	sta (:addr),y
	.endm

.macro blit_char_row char addr start end
	lda :char
	ldy :start
loop
	sta (:addr),y
	iny
	cpy :end
	bcc loop
	.endm

.proc display_borders
	mwa #status_line status_ptr
	mwa #screen screen_ptr

	blit_char #UI_NW_BORDER status_ptr #0
	blit_char_row #UI_HORIZ_BORDER status_ptr #1 #23
	blit_char #UI_TOP_TEE status_ptr #23
	blit_char_row #UI_HORIZ_BORDER status_ptr #24 #39
	blit_char #UI_NE_BORDER status_ptr #39
	
	ldx #playfield_height
loop
	blit_char #UI_VERT_BORDER screen_ptr #0
	blit_char #UI_VERT_BORDER screen_ptr #23
	blit_char #UI_VERT_BORDER screen_ptr #39
	adw screen_ptr #screen_char_width
	dex
	bne loop

	blit_char #UI_SW_BORDER screen_ptr #0
	blit_char_row #UI_HORIZ_BORDER screen_ptr #1 #23
	blit_char #UI_BOTTOM_TEE screen_ptr #23
	blit_char_row #UI_HORIZ_BORDER screen_ptr #24 #39
	blit_char #UI_SE_BORDER screen_ptr #39
	
	rts
	.endp

.proc update_ui
	mwa #screen screen_ptr
	; HP Bar
	blit_char #UI_HP_ICON_LEFT screen_ptr #25
	blit_char #UI_HP_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_BAR_LEFT screen_ptr #28
	blit_char #UI_HP_FULL screen_ptr #29
	blit_char #UI_HP_FULL screen_ptr #30
	blit_char #UI_HP_FULL screen_ptr #31
	blit_char #UI_HP_FULL screen_ptr #32
	blit_char #UI_HP_FULL screen_ptr #33
	blit_char #UI_HP_3_QTR screen_ptr #34
	blit_char #UI_BAR_RIGHT screen_ptr #35

	; Level display (LV:X format)
	blit_char #UI_COLON screen_ptr #37
	blit_char #UI_NUMBER_1 screen_ptr #38

	adw screen_ptr #screen_char_width

	; Skills
	blit_char #UI_MELEE_ICON_LEFT screen_ptr #25
	blit_char #UI_MELEE_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_RANGED_ICON_LEFT screen_ptr #32
	blit_char #UI_RANGED_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width

	blit_char #UI_DEFENSE_ICON_LEFT screen_ptr #25
	blit_char #UI_DEFENSE_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_FORTITUDE_ICON_LEFT screen_ptr #32
	blit_char #UI_FORTITUDE_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width

	; XP Bar (start empty - player has 0 XP initially)
	blit_char #UI_XP_ICON_LEFT screen_ptr #25
	blit_char #UI_XP_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_BAR_LEFT screen_ptr #28
	blit_char #UI_BAR_EMPTY screen_ptr #29
	blit_char #UI_BAR_EMPTY screen_ptr #30
	blit_char #UI_BAR_EMPTY screen_ptr #31
	blit_char #UI_BAR_EMPTY screen_ptr #32
	blit_char #UI_BAR_EMPTY screen_ptr #33
	blit_char #UI_BAR_EMPTY screen_ptr #34
	blit_char #UI_BAR_EMPTY screen_ptr #35
	blit_char #UI_BAR_EMPTY screen_ptr #36
	blit_char #UI_BAR_EMPTY screen_ptr #37
	blit_char #UI_BAR_RIGHT screen_ptr #38

	adw screen_ptr #screen_char_width

	; Inventory
	blit_char #UI_TORCH_ICON_LEFT screen_ptr #25
	blit_char #UI_TORCH_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30

	blit_char #UI_POTION_ICON_LEFT screen_ptr #32
	blit_char #UI_POTION_ICON_RIGHT screen_ptr #33
	blit_char #UI_COLON screen_ptr #34
	blit_char #UI_NUMBER_0 screen_ptr #35
	blit_char #UI_NUMBER_0 screen_ptr #36
	blit_char #UI_NUMBER_0 screen_ptr #37

	adw screen_ptr #screen_char_width
	blit_char #UI_COIN_ICON_LEFT screen_ptr #25
	blit_char #UI_COIN_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_NUMBER_0 screen_ptr #28
	blit_char #UI_NUMBER_0 screen_ptr #29
	blit_char #UI_NUMBER_0 screen_ptr #30
	blit_char #UI_NUMBER_0 screen_ptr #31
	blit_char #UI_NUMBER_0 screen_ptr #32

	; Amulet
	adw screen_ptr #screen_char_width
	adw screen_ptr #screen_char_width
	blit_char #UI_AMULET_NW_ICON_LEFT screen_ptr #29
	blit_char #UI_AMULET_NW_ICON_RIGHT screen_ptr #30
	blit_char #UI_BLACK_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_BLACK_GEM_ICON_RIGHT screen_ptr #32
	blit_char #UI_AMULET_NE_ICON_LEFT screen_ptr #33
	blit_char #UI_AMULET_NE_ICON_RIGHT screen_ptr #34

	adw screen_ptr #screen_char_width
	blit_char #UI_BLUE_GEM_ICON_LEFT screen_ptr #29
	blit_char #UI_BLUE_GEM_ICON_RIGHT screen_ptr #30
	blit_char #UI_WHITE_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_WHITE_GEM_ICON_RIGHT screen_ptr #32
	blit_char #UI_RED_GEM_ICON_LEFT screen_ptr #33
	blit_char #UI_RED_GEM_ICON_RIGHT screen_ptr #34

	adw screen_ptr #screen_char_width
	blit_char #UI_AMULET_SW_ICON_LEFT screen_ptr #29
	blit_char #UI_AMULET_SW_ICON_RIGHT screen_ptr #30
	blit_char #UI_GOLD_GEM_ICON_LEFT screen_ptr #31
	blit_char #UI_GOLD_GEM_ICON_RIGHT screen_ptr #32
	blit_char #UI_AMULET_SE_ICON_LEFT screen_ptr #33
	blit_char #UI_AMULET_SE_ICON_RIGHT screen_ptr #34

	; Keys
	sbw screen_ptr #(screen_char_width * 2)
	blit_char #UI_BLUE_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27

	blit_char #UI_BLACK_KEY_CAP_LEFT screen_ptr #35
	blit_char #UI_BLACK_KEY_ICON_LEFT screen_ptr #36
	blit_char #UI_BLACK_KEY_ICON_RIGHT screen_ptr #37
	blit_char #UI_BLACK_KEY_CAP_RIGHT screen_ptr #38

	adw screen_ptr #screen_char_width
	blit_char #UI_RED_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27
	blit_char #UI_WHITE_KEY_ICON screen_ptr #36
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #37

	adw screen_ptr #screen_char_width
	blit_char #UI_GOLD_KEY_ICON screen_ptr #26
	blit_char #UI_KEY_ICON_RIGHT screen_ptr #27

	rts
	.endp


.proc blit_screen
	map_offset()

	ldy #0
	; Line #1
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 5, 3, 7

	; Line #2
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 7, 2, 5

	; Line #3
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #4
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #5
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #6
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #7
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 9, 1, 3

	; Line #8
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 7, 2, 5

	; Line #9
	adw screen_ptr #screen_char_width
	adw map_ptr #map_width
	blit_circle_line 5, 3, 7

	rts
	.endp

; Uses a linear-feedback shift register (LFSR) to generate 8-bit pseudo-random numbers
; More info: https://en.wikipedia.org/wiki/Linear-feedback_shift_register
; Also here: https://forums.atariage.com/topic/159268-random-numbers/#comment-1958751
; Also here: https://github.com/bbbradsmith/prng_6502
.proc random8
	lda rand				; Load in seed or last number generated
	lsr						; Shift 1 place to the right
	bcc no_eor				; Carry flag contains the last bit prior to shifting - if 0, skip XOR
	eor #$b4				; XOR with feedback value that produces a good sequence
no_eor
	sta rand				; Store the random number
	rts
	.endp

.proc random16
	lda rand				; Load in seed or last number generated
	lsr						; Shift 1 place to the right
	rol rand16
	bcc no_eor				; Carry flag contains the last bit prior to shifting - if 0, skip XOR
	eor #$b4				; XOR with feedback value that produces a good sequence
no_eor
	sta rand				; Store the random number
	eor rand16
	rts
	.endp

.proc place_monsters (.byte x,a) .reg
	sta tmp2
pick
	random16
	cmp tmp2
	bcs pick

	add #44
	sta tmp

place
	random16
	cmp #map_width
	bcs place
	sta tmp_x

	random16
	cmp #map_height
	bcs place
	sta tmp_y

	advance_ptr #map map_ptr #map_width tmp_y tmp_x
	ldy #0
	lda (map_ptr),y
	cmp #MAP_FLOOR
	bne place
	lda tmp
	sta (map_ptr),y
	dex
	bne pick

	rts
	.endp

; Place a bow item on a floor tile adjacent to player
.proc place_bow
	; Use player_ptr as our base - it's already set up by init_player_ptr
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1

	; Try right of player (add 1)
	inc16 map_ptr
	ldy #0
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try below player (add map_width from player position)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	adw map_ptr #map_width
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try left of player (subtract 1 from player)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	dec16 map_ptr
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; Try above player (subtract map_width)
	lda player_ptr
	sta map_ptr
	lda player_ptr+1
	sta map_ptr+1
	sbw map_ptr #map_width
	lda (map_ptr),y
	cmp #MAP_FLOOR
	beq found_floor

	; No floor found adjacent - skip placing bow
	rts

found_floor
	lda #MAP_BOW
	sta (map_ptr),y
	rts
	.endp

; Monster HP table - indexed by monster type (0-7)
; Monster tiles are 44-51, so subtract 44 to get index
monster_hp_table
	.byte 10, 20, 20, 30, 30, 40, 40, 50

; Monster damage table - indexed by monster type (0-7)
monster_dmg_table
	.byte 3, 5, 7, 9, 11, 13, 15, 17

; Monster XP reward table - indexed by monster type (0-7)
; XP rewards scale with monster difficulty (HP and damage)
; Format: HP/Damage -> XP reward
monster_xp_table
	.byte 10, 15, 20, 25, 30, 35, 40, 50
	; 10HP/3dmg->10XP, 20HP/5dmg->15XP, 20HP/7dmg->20XP, 30HP/9dmg->25XP,
	; 30HP/11dmg->30XP, 40HP/13dmg->35XP, 40HP/15dmg->40XP, 50HP/17dmg->50XP

; ============================================
; Arrow missile procedures (in main code area)
; ============================================

; Constants for arrow
ARROW_SPEED      = 1           ; Pixels per update (very slow for visibility)
ARROW_TILE_SIZE  = 8           ; Advance map tile less often so shot can travel
ARROW_START_Y    = 64          ; Starting scanline (center of player area)
ARROW_START_X    = 92          ; Starting X (same as player HPOS)
ARROW_MIN_Y      = 8           ; Top boundary of dungeon viewport
ARROW_MAX_Y      = 216         ; Bottom boundary of dungeon viewport
ARROW_MIN_X      = 16          ; Left boundary
ARROW_MAX_X      = 176         ; Right boundary (stop before HUD panel)
arrow_tick       .byte 0       ; Last RTCLK2 tick that advanced arrow
arrow_tick_div   .byte 0       ; Additional slowdown divider

; Fire an arrow in the direction the player is facing
.proc fire_arrow
    lda arrow_active
    bne already_active

    ; Set base position
    lda #ARROW_START_X
    sta arrow_x
    lda #ARROW_START_Y
    sta arrow_y
    lda player_dir
    sta arrow_dir
    lda player_x
    sta arrow_map_x
    lda player_y
    sta arrow_map_y

    ; Initialize arrow_ptr to player's map position
    mwa player_ptr arrow_ptr

    lda #0
    sta arrow_subtile
    sta arrow_tick_div
    lda #1
    sta arrow_active
    inc stick_action
    jsr draw_arrow_missile
already_active
    rts
    .endp

; Update arrow position and check for collisions
.proc update_arrow
    ; Throttle to clock ticks so the missile remains visible.
    lda RTCLK2
    cmp arrow_tick
    beq no_tick_advance
    sta arrow_tick
    inc arrow_tick_div
    lda arrow_tick_div
    cmp #3                  ; Move every 3 ticks (~20 updates/sec)
    bcc no_tick_advance
    lda #0
    sta arrow_tick_div

    lda arrow_active
    bne arrow_is_active
no_tick_advance
    rts
arrow_is_active
    jsr clear_arrow_missile
    lda arrow_subtile
    clc
    adc #ARROW_SPEED
    sta arrow_subtile
    cmp #ARROW_TILE_SIZE
    bcc move_screen_only
    lda #0
    sta arrow_subtile
    lda arrow_dir
    cmp #NORTH
    bne not_north_map
    sbw arrow_ptr #map_width
    dec arrow_map_y
    jmp check_map_collision
not_north_map
    cmp #SOUTH
    bne not_south_map
    adw arrow_ptr #map_width
    inc arrow_map_y
    jmp check_map_collision
not_south_map
    cmp #WEST
    bne not_west_map
    dec arrow_ptr
    dec arrow_map_x
    jmp check_map_collision
not_west_map
    inc arrow_ptr
    inc arrow_map_x
check_map_collision
    jsr check_arrow_collision
    lda arrow_active
    bne move_screen_only
    rts
move_screen_only
    lda arrow_dir
    cmp #NORTH
    bne check_south
    lda arrow_y
    sec
    sbc #ARROW_SPEED
    sta arrow_y
    jmp check_bounds
check_south
    cmp #SOUTH
    bne check_west
    lda arrow_y
    clc
    adc #ARROW_SPEED
    sta arrow_y
    jmp check_bounds
check_west
    cmp #WEST
    bne check_east
    lda arrow_x
    sec
    sbc #ARROW_SPEED
    sta arrow_x
    jmp check_bounds
check_east
    lda arrow_x
    clc
    adc #ARROW_SPEED
    sta arrow_x
check_bounds
    lda arrow_y
    cmp #ARROW_MIN_Y
    bcc deactivate
    cmp #ARROW_MAX_Y
    bcs deactivate
    lda arrow_x
    cmp #ARROW_MIN_X
    bcc deactivate
    cmp #ARROW_MAX_X
    bcs deactivate
    jsr draw_arrow_missile
    rts
deactivate
    jsr deactivate_arrow
    rts
    .endp

; Check if arrow hit something
.proc check_arrow_collision
    mwa arrow_ptr map_ptr
    ldy #0
    lda (map_ptr),y
    cmp #44
    bcc check_wall
    cmp #52
    bcs check_wall
    jsr arrow_hit_monster
    jsr deactivate_arrow
    rts
check_wall
    cmp #PASSABLE_MIN
    bcs passable
    jsr deactivate_arrow
passable
    rts
    .endp

; Handle arrow hitting a monster
.proc arrow_hit_monster
    ldy #0
    lda (map_ptr),y
    sta tmp1

    ; Monsters on the map do not keep persistent per-tile HP state.
    ; Resolve ranged hit immediately by removing the monster tile.
    lda tmp1
    sec
    sbc #44
    tax
    lda monster_xp_table,x
    clc
    adc player_xp
    sta player_xp
    jsr update_xp_bar
    jsr check_level_up
    ldy #0
    lda #MAP_FLOOR
    sta (map_ptr),y
    rts
    .endp

; Deactivate the arrow
.proc deactivate_arrow
    lda #0
    sta arrow_active
    jsr clear_arrow_missile
    lda #0
    sta HPOSM2              ; M2 position off-screen
    rts
    .endp

; Draw arrow missile at current position (using M2)
; M2 uses PCOLR2 color (white), bits 4-5 in missile byte
.proc draw_arrow_missile
    lda arrow_x
    sta HPOSM2              ; Set horizontal position for M2
    lda arrow_y
    tax
    ; M2 = bits 4-5, value %00110000 = visible
    lda #%00110000
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x      ; 2 scanlines total (small arrow)
    rts
    .endp

; Clear arrow missile (2 scanlines to match draw)
.proc clear_arrow_missile
    lda arrow_y
    tax
    lda #0
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x
    rts
    .endp

	icl 'macros.asm'
	icl 'hardware.asm'
	icl 'labels.asm'
	icl 'dlist.asm'
	icl 'pmgdata.asm'
	icl 'map_gen.asm'
	icl 'input.asm'
	icl 'status_chars.asm'

	icl 'charset_dungeon_a.asm'
	icl 'charset_dungeon_b.asm'
	icl 'charset_outdoor_a.asm'
	icl 'charset_outdoor_b.asm'
	icl 'monsters_a.asm'
	icl 'monsters_b.asm'
	icl 'room_types.asm'
	icl 'room_positions.asm'
	icl 'room_pos_doors'
	icl 'room_type_doors'
	;icl 'test_map.asm'
	icl 'charset_dungeon_a_colors.asm'
	icl 'charset_dungeon_b_colors.asm'
	icl 'charset_outdoor_a_colors.asm'
	icl 'charset_outdoor_b_colors.asm'
	icl 'monsters_a_colors.asm'
	icl 'monsters_b_colors.asm'
powers_of_two
	.byte 1,2,4,8,16,32,64,128
	
