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
; $9800-$AE0F : runtime code chain (dlist, pmgdata, map_gen, input, ...)
; Must stay BELOW room_positions. Do not place a large data blob at $A000 --
; it will overwrite this code when the XEX loads (Atari800MacX hard crash
; after the map draws).
; room_types removed: templates were all floor; copy_room fills MAP_FLOOR.
room_positions		= $ae10	; 128 bytes
room_pos_doors		= $ae90 ; 64 bytes
room_type_doors		= $aed0 ; 16 bytes
charset_dungeon_a_colors = $aee0 ; 16 bytes
charset_dungeon_b_colors = $aef0 ; 16 bytes
monsters_a_colors   = $af20 ; 51 bytes
monsters_b_colors   = $af53 ; 51 bytes

; free $AF86-$AFFF

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

input_speed 		= 4
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

	
dungeon_floor		= $d8
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
has_gems             = $ea    ; bitfield: blue/gold/red/black/white (see GEM_* in labels.asm)
has_keys             = $f6	  ; bitfield: blue/red/gold/white/black keys
has_magic_key        = $f7    ; 1 = all five keys merged into Magic Key
kaybee_door_open     = $f8    ; 1 = KayBee door has been unlocked
kaybee_door_ptr      = $f9    ; 16-bit map address of the KayBee door (0 = none)
keys_dropped_this_floor = $fb ; monster key drops so far on this floor
item_tile            = $eb    ; Map tile id while place_one_item runs (must not share tmp)
occ_bitmap           = $ec    ; Scratch for get/set_room_occupied (must not share tmp)
boss_tl_ptr          = $f0    ; 16-bit map address of boss top-left cell
boss_hp              = $f2    ; Floor-4 boss hit points
boss_alive           = $f3    ; 0 = dead/absent, 1 = alive
boss_map_x		     = $f4    ; map column of boss top-left
boss_map_y           = $f5    ; map row of boss top-left


; Weapon system variables
player_ranged_dmg    = $7371  ; Ranged weapon damage (bow)
has_bow              = $7372  ; 0 = no bow, 1 = has bow
equipped_weapon      = $7373  ; 0 = melee, 1 = ranged (bow)

; Arrow missile variables
arrow_active         = $7374  ; 0 = no arrow, 1 = arrow in flight
arrow_x              = $7375  ; Arrow horizontal position (screen coords)
arrow_y              = $7376  ; Arrow vertical position (scanline)
arrow_dir            = $7377  ; Arrow direction (1=N, 2=S, 3=W, 4=E)
arrow_map_x          = $7378  ; Arrow map X coordinate
arrow_map_y          = $7379  ; Arrow map Y coordinate
player_dir           = $737A  ; Last direction player moved (for aiming)
arrow_subtile        = $737B  ; Sub-tile counter (0-7, update map coord when wraps)
arrow_ptr            = $737C  ; Arrow map pointer (16-bit)
monster_contact_cooldown = $737E ; Frames until monster can damage again
player_hp_dirty      = $737F  ; Nonzero when HUD HP bar needs refresh

; Colors
white 				= $0a
red 				= $32
black 				= $00
peach 				= $2c
blue 				= $92
gold 				= $2a

	icl 'status_chars.asm'
	
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
	; Clear 128 bytes of missile memory to ensure all missile graphics are off
clear_all_missiles
