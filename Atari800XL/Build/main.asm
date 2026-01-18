; EdVenture - An Adventure in Atari 8-Bit Assembly
; github.com/edsalisbury/edventure
; Mission: EdPossible
; youtube.com/MissionEdPossible
; Assemble in MADS: mads -l -t main.asm
; Episode 24 - Doors

; ATASCII Table: https://www.atariwiki.org/wiki/attach/Atari%20ATASCII%20Table/ascii_atascii_table.pdf
; ATASCII 0-31 Screen code 64-95
; ATASCII 32-95 Screen code 0-63
; ATASCII 96-127 Screen code 96-127

; NTSC Color Palette: https://atariage.com/forums/uploads/monthly_10_2015/post-6369-0-47505700-1443889945.png
; PAL Color Palette: https://atariage.com/forums/uploads/monthly_10_2015/post-6369-0-90255700-1443889950.png
; PMG Memory Map: https://www.atarimagazines.com/compute/issue64/atari_animation.gif

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
cur_char_colors_a		= $7380 ; Current character colors (16 bytes)
cur_char_colors_b		= $7390 ; Current character colors (16 bytes)
; free
pmg     			= $7400 ; Player Missle Data (1K)
cur_charset_a		= $7800 ; Current character set A (1K)
cur_charset_b		= $7c00 ; Current character set B (1K)

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
dlist				= $9800 ; 112 Bytes
; free
room_types			= $a000 ; 3600 Bytes
room_positions		= $ae10	; 128 bytes
room_pos_doors		= $ae90 ; 64 bytes
room_type_doors		= $aed0 ; 16 bytes
charset_dungeon_a_colors		= $aee0 ; 16 bytes
charset_dungeon_b_colors		= $aef0 ; 16 bytes
charset_outdoor_a_colors		= $af00 ; 16 bytes
charset_outdoor_b_colors		= $af10 ; 16 bytes
monsters_a_colors		= $af20 ; 51 bytes
monsters_b_colors		= $af53 ; 51 bytes

; free

; B000-BFFF (Code)

;stick_up    = %0001
;stick_down  = %0010 
;stick_left  = %0100
;stick_right = %1000

map_ptr 	= $92
screen_ptr 	= $94
player_x	= $96
player_y	= $97
tmp			= $98
up_tile		= $9a
down_tile	= $9b
left_tile	= $9c
right_tile	= $9d
on_tile		= $9e

tmp_addr1	= $a0
tmp_addr2   = $a2

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
starting_monster    = $c3
no_clip				= $c4
char_colors_ptr		= $c5 ; 16 bit

;stick_dir 			= $d8
stick_btn			= $d9
stick_action		= $da

player_ptr			= $de
dir_ptr				= $e0
tmp1 				= $e2
;tmp2 				= $e3

; Player stats
player_hp			= $e4
player_max_hp		= $e5
player_melee_dmg	= $e6
player_xp			= $e7

monster_hp     		= $f0  ; Grok Temp: current mon HP
monster_dmg			= $f1  ; Grok Temp: current mon DMG

; Colors
white = $0a
red = $32
black = $00
peach = $2c
blue = $92
gold = $2a

	mva #0 charset_a
	mva #>charset_outdoor_a CHBAS

	setup_screen()
	update_player_tiles()
	display_borders()
	update_ui()

	lda #16
	sta player_x
	sta player_y

	mva #123 rand
	mva #201 rand16

	mva #15 num_monsters
	mva #15 starting_monster

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

	setup_colors()
	
	clear_pmg()
	load_pmg()
	setup_pmg()

	; Charset testing
	; mwa #map map_ptr
	; mwa #screen screen_ptr
	; map_width  = 28
	; map_height = 28
	; lda #14
	; sta player_x
	; sta player_y
	lda #0
	sta no_clip
	sta stick_btn
	sta stick_action

	; Initialize player stats
	lda #100
	sta player_hp
	sta player_max_hp		; Max HP is also 100
	lda #10
	sta player_melee_dmg
	lda #0
	sta player_xp			; Start with 0 XP

	jmp skip_monster_tables	; Jump over the data tables

	; Grok Monster tables: index 0-11 = tile 44-55
	; Fodder(44-47): quick kills | Mid(48-51): endurance | Boss(52-55): epics
monster_hp_table
    .byte 10,10,10,10, 20,20,20,20, 50,50,50,50  ; 44-55
    .byte 60,60,60,60,70,70,70,70                      ; 56-63 BIG
monster_dmg_table
    .byte 3,3,3,3,  5,5,5,5,  8,8,8,8
    .byte 12,12,12,12,15,15,15,15                    ; BRUTAL

skip_monster_tables
	; Initialize the HP and XP bars to match player stats
	update_hp_bar()
	update_xp_bar()

	new_map()
	place_monsters #19 num_monsters

game
	mva RTCLK2 clock
	animate
	get_input
	jmp game

.macro set_colors
	lda charset_a
	beq use_charset_b
	mwa #cur_char_colors_b char_colors_ptr
	jmp done
use_charset_b
	mwa #cur_char_colors_a char_colors_ptr
done
.endm

.macro get_input
	lda clock
	cmp input_timer
	bne done
	read_joystick()
	blit_screen()
	lda clock
	add #input_speed
	sta input_timer
done
	.endm

.macro animate
	lda clock
	cmp anim_timer
	bne done
	lda charset_a
	eor #$ff
	sta charset_a
	blit_screen
	lda clock
	add #anim_speed
	sta anim_timer
done
	.endm

; .proc read_joystick
; 	lda STICK0
; 	and #stick_up
; 	beq check_up

; 	lda STICK0
; 	and #stick_down
; 	beq check_down

; 	lda STICK0
; 	and #stick_left
; 	beq check_left

; 	lda STICK0
; 	and #stick_right
; 	beq check_right

; 	jmp done

; check_up
; 	lda no_clip
; 	bne move_up
; 	lda up_tile
; 	cmp #WALKABLE_START
; 	bcc done
; move_up
; 	dec player_y
; 	update_player_tiles()
; 	jmp done

; check_down
; 	lda no_clip
; 	bne move_down
; 	lda down_tile
; 	cmp #WALKABLE_START
; 	bcc done
; move_down
; 	inc player_y
; 	update_player_tiles()
; 	jmp done

; check_left
; 	lda no_clip
; 	bne move_left
; 	lda left_tile
; 	cmp #WALKABLE_START
; 	bcc done
; move_left
; 	dec player_x
; 	update_player_tiles()
; 	jmp done

; check_right
; 	lda no_clip
; 	bne move_right
; 	lda right_tile
; 	cmp #WALKABLE_START
; 	bcc done
; move_right
; 	inc player_x
; 	update_player_tiles()
; 	jmp done

; done
; 	rts
; 	.endp

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
	mva #red PCOLR0
	mva #peach PCOLR1
	mva #blue PCOLR2
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
	lda #92
	sta HPOSP0
	sta HPOSP1
	sta HPOSP2
	sta HPOSP3
	rts
	.endp

* --------------------------------------- *
* Proc: fix_color                         *
* Fixes colors for a character if needed  *
* --------------------------------------- *
.macro fix_color
	; A = character index to fix color if needed
	sta tmp					; Save character to temp var
	tya
	pha
	lda tmp					; Reload the character
	and #$07				; Get last 3 bits
	add #1					; Add 1 so that we can shift correct number of times
	sta tmp2				; Store bit shift amount to tmp2
	lda tmp					; Reload char
	lsr						; Divide by 8 to get color index
	lsr						; 
	lsr						; 
	tay					; Store into x to be able to use as an offset
	lda (char_colors_ptr),y	; Get the color bits for this character

shift_bits
	lsr						; Shift until bit is in the carry flag
	dec tmp2				; Reduce shift counter
	bne shift_bits			; Keep looping if shift counter isn't 0

	bcc done				; If the carry flag is *not* set, we're done

add_color
	lda tmp					; Load character back into A
	add #128				; Add 128 to change to secondary color
	sta tmp					; Re-save back to tmp after adding

done
	pla						; Pull old X from the stack via A
	tay
	lda tmp					; Re-load character to A
	.endm

.macro blit_tile
	lda (map_ptr),y			; Load the tile from the map
	asl						; Multiply by two to get left character
	fix_color				; Fix the color if needed
	sta (screen_ptr),y		; Store the left character
	inc16 screen_ptr		; Advance the screen pointer
	lda (map_ptr),y			; Load the tile from the map
	asl						; Multiply by two to get left character
	add #1					; Add one to get right character
	fix_color				; Fix the color if needed
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

.proc map_offset
	mwa #map map_ptr
	mwa #screen screen_ptr

	; Shift vertically for player's y position
	lda player_y
	sub #(playfield_height / 2)
	tay
loop
	adw map_ptr #map_width
	dey
	bne loop

	; Shift horizontally for player's x position
	lda player_x
	sub #(playfield_width / 2)
	sta tmp
	lda #0
	sta tmp + 1
	adw map_ptr tmp

	rts
	.endp

.proc update_player_tiles
	mwa #map map_ptr

	ldy player_y
loop
	adw map_ptr #map_width
	dey
	bne loop

	adbw map_ptr player_x

	; Get the tile the player is on
	ldy #0
	lda (map_ptr),y
	sta on_tile

	; Get the tile to the left of the player
	dec16 map_ptr
	lda (map_ptr),y
	sta left_tile

	; Get the tile to the right of the player
	inc16 map_ptr
	inc16 map_ptr
	lda (map_ptr),y
	sta right_tile

	; Get the tile above the player
	dec16 map_ptr
	sbw map_ptr #map_width
	lda (map_ptr),y
	sta up_tile

	; Get the tile below the player
	adw map_ptr #(map_width * 2)
	lda (map_ptr),y
	sta down_tile

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

	; XP Bar
	blit_char #UI_XP_ICON_LEFT screen_ptr #25
	blit_char #UI_XP_ICON_RIGHT screen_ptr #26
	blit_char #UI_COLON screen_ptr #27
	blit_char #UI_BAR_LEFT screen_ptr #28
	blit_char #UI_XP_FULL screen_ptr #29
	blit_char #UI_XP_FULL screen_ptr #30
	blit_char #UI_XP_FULL screen_ptr #31
	blit_char #UI_XP_FULL screen_ptr #32
	blit_char #UI_XP_FULL screen_ptr #33
	blit_char #UI_XP_FULL screen_ptr #34
	blit_char #UI_XP_HALF screen_ptr #35
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

; Update the HP bar display based on current player HP
; HP bar has 6 segments, each represents ~16.67 HP
.proc update_hp_bar
	mwa #screen screen_ptr
	adw screen_ptr #28          ; Position at start of HP bar

	; Calculate number of full segments (HP / 17)
	; For simplicity: divide HP by 17 to get number of full bars
	lda player_hp
	ldx #0                      ; X will count full segments

count_segments
	cmp #17                     ; Is HP >= 17?
	bcc draw_bars               ; If less, start drawing
	sec
	sbc #17                     ; Subtract 17
	inx                         ; Increment segment counter
	cpx #6                      ; Max 6 segments
	bcc count_segments          ; Continue if less than 6

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
	; Fill remaining with empty segments
	lda tmp
fill_loop
	cmp #6
	bcs draw_right              ; If we've drawn 6 total, stop
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

; Update the XP bar display based on current player XP
; XP bar has 9 segments, each represents ~11 XP (100 XP to fill)
; Supports quarter, half, 3/4, and full bar segments
.proc update_xp_bar
	mwa #screen screen_ptr
	adw screen_ptr #(screen_char_width * 3)  ; Move to XP bar row
	adw screen_ptr #28                        ; Position at start of XP bar

	; Draw left border
	ldy #0
	lda #UI_BAR_LEFT
	sta (screen_ptr),y
	inc16 screen_ptr

	; We'll draw 9 segments total (positions 29-37)
	; Each full segment = 11 XP, with partial segments for finer detail
	ldx #0                                    ; X = segment counter (0-8)

draw_segment
	cpx #9                                    ; Have we drawn all 9 segments?
	bcs draw_right                            ; Yes, draw right border

	; Calculate XP threshold for this segment (segment * 11)
	; segment * 11 = segment * 8 + segment * 2 + segment
	txa
	asl                                       ; * 2
	asl                                       ; * 4
	asl                                       ; * 8
	sta tmp2                                  ; tmp2 = segment * 8
	txa
	asl                                       ; * 2
	clc
	adc tmp2                                  ; A = segment * 8 + segment * 2
	sta tmp2
	txa
	clc
	adc tmp2                                  ; A = segment * 8 + segment * 2 + segment
	sta tmp2                                  ; tmp2 = segment * 11

	; Compare player XP with threshold
	lda player_xp
	cmp tmp2
	bcc draw_empty_segment                    ; If XP < threshold, segment is empty

	; Calculate how much XP into this segment we are
	sec
	sbc tmp2                                  ; A = XP - (segment * 11)
	cmp #11
	bcs draw_full_segment                     ; If >= 11, segment is full

	; Partial segment (1-10 XP into segment)
	cmp #9
	bcs draw_3qtr_segment                     ; 9-10 XP = 3/4
	cmp #6
	bcs draw_half_segment                     ; 6-8 XP = 1/2
	jmp draw_qtr_segment                      ; 1-5 XP = 1/4

draw_full_segment
	lda #UI_XP_FULL
	jmp store_segment

draw_3qtr_segment
	lda #UI_XP_3_QTR
	jmp store_segment

draw_half_segment
	lda #UI_XP_HALF
	jmp store_segment

draw_qtr_segment
	lda #UI_XP_QTR
	jmp store_segment

draw_empty_segment
	lda #UI_BAR_EMPTY

store_segment
	sta (screen_ptr),y
	inc16 screen_ptr
	inx
	jmp draw_segment

draw_right
	lda #UI_BAR_RIGHT
	sta (screen_ptr),y

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

; Pick and place monsters
; x = max monster number
; a = quantity of monsters
.proc place_monsters (.byte x,a) .reg
; 44 = monster tile start
	sta tmp2				; Copy max monster num from a to tmp2
pick
	random16				; Get random number in A
	cmp tmp2				; Compare with max monster num
	bcs pick				; If the number is greater than max monster number, re-pick

	add #44					; Monster is good, so add 44 to move it to the proper character
	sta tmp					; Store monster num into tmp

	; Set retry counter to prevent infinite loops
	ldy #50					; Try 50 times to find a valid spot
place
	dey						; Decrement retry counter
	beq skip_monster		; If we've tried 50 times, skip this monster

	random16				; Get random number for X and store it in A
	cmp #map_width			; Verify that it's within the map horizontally
	bcs place				; If not, get another value
	sta tmp_x				; It's good, so store in tmp_x

	random16				; Get random number for Y and store it in A
	cmp #map_height			; Verify that it's within the map vertically
	bcs place				; If not, start over with getting X again
	sta tmp_y				; We have both valid X and Y, so store into tmp_y

	; Move the map to the location of the monster
	advance_ptr #map map_ptr #map_width tmp_y tmp_x
	sty tmp1				; Save Y (retry counter) to tmp1
	ldy #0
	lda (map_ptr),y			; Get the character at the current position
	cmp #MAP_FLOOR			; Verify that it's a floor tile (only place on floors)
	bne restore_and_retry	; If not floor, restore counter and try again

	; Check if there are monsters nearby (spacing check)
	; Disabled - causing infinite loop
	; TODO: Fix the spacing check logic
	;ldy tmp1				; Restore Y
	;sty tmp1				; Save Y again
	;jsr check_nearby_monsters
	;ldy tmp1				; Restore Y
	;cmp #0					; Check if monsters were found
	;bne place				; If monsters nearby (A != 0), find a new location

	lda tmp					; It must be a floor tile, so load in monster from tmp
	ldy #0
	sta (map_ptr),y			; Copy it to the map
	jmp skip_monster		; Done with this monster

restore_and_retry
	ldy tmp1				; Restore Y counter
	jmp place				; Try again

skip_monster
	dex						; Reduce x so that we can get another monster with the loop
	bne pick				; Get the next monster

	; Otherwise, we're done picking and placing monsters
	rts
	.endp

; Check if there are monsters in nearby tiles
; Input: map_ptr points to the location to check
; Output: A = 0 if no monsters nearby, A = 1 if monsters found
; Checks a 3x3 area (1 tile in each direction) to ensure good spacing
.proc check_nearby_monsters
	; Save current map pointer
	mwa map_ptr tmp_addr1

	; Move to top-left corner (1 row up, 1 column left)
	sbw map_ptr #map_width
	dec16 map_ptr

	; Check 3 rows
	ldx #3
row_loop
	; Save row start position
	mwa map_ptr tmp_addr2

	; Check 3 columns in this row
	ldy #0
	lda #3
	sta tmp2
col_loop
	lda (map_ptr),y
	cmp #44					; Monster tiles start at 44
	bcc next_col
	cmp #64					; Monster tiles end at 63
	bcs next_col
	jmp found_monster		; If 44 <= tile < 64, it's a monster

next_col
	inc16 map_ptr
	dec tmp2
	bne col_loop

	; Move to next row
	mwa tmp_addr2 map_ptr
	adw map_ptr #map_width
	dex
	bne row_loop

	; No monsters found nearby
	mwa tmp_addr1 map_ptr	; Restore map pointer
	lda #0					; Return 0 (no monsters)
	rts

found_monster
	mwa tmp_addr1 map_ptr	; Restore map pointer
	lda #1					; Return 1 (monster found)
	rts
	.endp


	icl 'macros.asm'
	icl 'hardware.asm'
	icl 'labels.asm'
	icl 'dlist.asm'
	icl 'pmgdata.asm'
	icl 'map_gen.asm'
	icl 'input.asm'

	icl 'charset_dungeon_a.asm'
	icl 'charset_dungeon_b.asm'
	icl 'charset_outdoor_a.asm'
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

bitmasks
	.byte $ff, $f7, $f0, $70