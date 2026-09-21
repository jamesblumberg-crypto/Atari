	sta pmg_missiles,x
	dex
	bpl clear_all_missiles

	mva #5 num_monsters         ; base pack size (0-8); floor 5 also gets a boss

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
	sta dungeon_floor        ; Start on floor 1 (prevents over-scaling from garbage RAM)

	; Initialize weapon system
	lda #0
	sta player_ranged_dmg   ; No ranged damage until bow acquired
	sta has_bow             ; Player starts without bow
	sta equipped_weapon     ; Start with melee equipped (0 = melee)
	sta arrow_active        ; No arrow in flight
	sta has_gems            ; No gems collected yet
	sta has_keys            ; No keys collected yet
	sta has_magic_key       ; Magic Key not formed yet
	sta kaybee_door_open
	sta kaybee_door_ptr
	sta kaybee_door_ptr+1
	sta keys_dropped_this_floor
	sta boss_alive          ; No floor-4 boss until floor 4
	lda #0
	sta monster_contact_cooldown ; Clears the value of monster_contact_cooldown to ensure monsters can damage immediately if player starts next to them
	lda #SOUTH              ; Default facing direction
	sta player_dir
	lda #BUTTON_UP          ; Trigger starts released (edge detect works on first press)
	sta stick_btn
	lda #0
	sta stick_action        ; Unused latch; keep zero for debug / future use
	
	mva #123 rand
	mva #201 rand16

	; Enable POKEY for the locked-door beep
	lda #3
	sta SKCTL
	lda #0
	sta AUDCTL
	
	mwa #powers_of_two pow2_ptr
	mwa #occupied_rooms occupied_rooms_ptr

	copy_data charset_dungeon_a cur_charset_a 4
	copy_data charset_dungeon_b cur_charset_b 4
	copy_bytes charset_dungeon_a_colors cur_char_colors_a 16
	copy_bytes charset_dungeon_b_colors cur_char_colors_b 16
	; Ribbon 0 (first monsters in PNG) for floor 1 -- easiest art + stats
	jsr setup_floor_monsters
	
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
	jsr place_gems              ; One gem for this floor (if not already collected)
	jsr place_floor_boss        ; Floor 5: extra tough guardian

	; Initialize variables that need starting values
	lda #0
	sta charset_a              ; Start with charset A
	sta anim_timer             ; Initialize animation timer
	lda RTCLK2
	sta input_timer            ; Initialize input timer
	mwa #cur_char_colors_a char_colors_ptr  ; Initialize color pointer

	; Draw initial screen before game loop
	blit_screen()
	jsr update_gem_display      ; Blank slots until gems are found
	jsr update_key_display	  ; Blank slots until keys are found

game
	mva RTCLK2 clock
	animate
	get_input                   ; Handle joystick input and update screen
	jsr read_keyboard           ; Check for weapon switching keys
	jsr update_arrow            ; Update arrow position and check collisions
	lda monster_contact_cooldown ; Check monster contact cooldown
	beq monster_contact_ready	; Skip monster update if cooldown active.
	dec monster_contact_cooldown ; Decrement cooldown.
monster_contact_ready:
	jsr update_monsters
	lda player_hp_dirty
	beq hp_bar_clean
	jsr update_hp_bar
	lda #0
	sta player_hp_dirty
hp_bar_clean:
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
; Update the HP bar display based on current player HP
	mwa #screen screen_ptr
	adw screen_ptr #28          ; Position at start of HP bar (column offset for HP bar)
; Side effects: Modifies screen memory and temporary variables.
.proc update_hp_bar
	mwa #screen screen_ptr
	adw screen_ptr #28          ; Position at start of HP bar

	; Calculate number of full segments (~17 HP each for 100 HP max)
	lda player_hp
	clc
	; Add a bias of 16 to achieve ceiling division, so 100 HP fills all 6 segments
	adc #16                    ; Bias so 100 HP gives 6 segments (ceil division)
	ldx #0                      ; X counts full segments
calc_segments
	cmp #17                     ; Is HP >= 17?
	bcc draw_bars               ; If less, start drawing
	sec                         ; Always set carry before SBC
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
