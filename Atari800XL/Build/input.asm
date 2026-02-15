.proc read_joystick
    ; Temp vars used
    cur_btn = tmp1          ; Current button state
    
    mva STRIG0 cur_btn      ; Get current button state from HW register (1 = up, 0 = down)
    bne up                  ; If current button state is non-zero, the button is up

down                        ; The button is currently down
    lda stick_btn           ; Get the previous button state
    bne done                ; If previous button state is non-zero and current button state is zero, it was just pushed

held                        ; The button is held down
    lda stick_action        ; Get the action state
    bne done                ; If the action state is non-zero, don't do the action again
    read_direction()        ; Update the direction pointer
    player_action()         ; Do the action
    jmp done                ; Skip to done

up                          ; The button is currently up
    read_direction()        ; Update the direction pointer
    player_move()           ; Move the player
    clr stick_action        ; If the player is moving, we don't care about the action state so reset it                      

done
    mva cur_btn stick_btn   ; Set the stick button for next time
    rts
    .endp

; Get the direction from the joystick and update dir_ptr
; Does not support diagonal movement, and is processed in the following priority order: UP, DOWN, LEFT, RIGHT
.proc read_direction
    ; Temp vars used
    stick_dir = tmp2            ; Current stick direction
    
    ; Init
    mwa player_ptr dir_ptr      ; Copy the player pointer to the direction ptr as a base
    mva STICK0 stick_dir        ; Load stick bitmap from HW register

check_up
    and #STICK_UP               ; Check to see if it's pushed UP
    bne check_down              ; It's not pushed UP, so move to the next check
    sbw dir_ptr #map_width      ; It is pushed UP, so move the temp pointer up one line
    lda #NORTH                  ; Track direction for arrow aiming
    sta player_dir
    rts                         ; We're done updating the dir pointer (this will take priority)

check_down
    lda stick_dir               ; Re-copy non-mutated stick dir to A
    and #STICK_DOWN             ; Check to see if it's pushed DOWN
    bne check_left              ; It's not pushed DOWN, so move to the next check
    adw dir_ptr #map_width      ; It is pushed DOWN, so move the temp pointer down one line
    lda #SOUTH                  ; Track direction for arrow aiming
    sta player_dir
    rts

check_left
    lda stick_dir               ; Re-copy non-mutated stick dir to AA
    and #STICK_LEFT             ; Check to see if it's pushed LEFT
    bne check_right             ; It's not pushed LEFT, so move to the next check
    dec dir_ptr                 ; It is pushed LEFT, so move the temp pointer left one
    lda #WEST                   ; Track direction for arrow aiming
    sta player_dir
    rts

check_right
    lda stick_dir               ; Re-copy non-mutated stick dir to A
    and #STICK_RIGHT            ; Check to see if it's pushed RIGHT
    bne done                    ; If not, we're done checking
    inc dir_ptr                 ; It is pushed RIGHT, so move the temp pointer left one
    lda #EAST                   ; Track direction for arrow aiming
    sta player_dir

done
    rts
    .endp

.proc player_action()
    ; Always check for doors first, regardless of equipped weapon
    ldi dir_ptr                 ; Load in tile from direction

check_door
    cmp #MAP_DOOR               ; Check if it's a door
    bne check_doorway           ; Skip to next check
    open_door()                 ; Open the door
    rts

check_doorway
    cmp #MAP_DOORWAY            ; Check if it's a doorway
    bne check_weapon            ; Not a door, check weapon for attack
    close_door()                ; Close the door
    rts

check_weapon
    ; Not facing a door - check weapon for ranged/melee attack
    lda equipped_weapon
    beq do_melee_action         ; 0 = melee, do normal action

    ; Bow is equipped - try to fire arrow
    jsr fire_arrow
    rts

do_melee_action
    ; Nothing to do for melee action on empty tiles
    ; (monster combat is handled in player_move)
    rts
    .endp

.proc open_door
    lda #MAP_DOORWAY            ; Load in the doorway tile
    sti dir_ptr                 ; Swap door for doorway
    inc stick_action            ; Set the action flag
    rts
    .endp

.proc close_door
    lda #MAP_DOOR               ; Load in the door tile
    sti dir_ptr                 ; Swap doorway for door
    inc stick_action            ; Set the action flag
    rts
    .endp

    
; Player Movement
.proc player_move
    ldi dir_ptr                 ; Dereference direction pointer
    beq blocked                 ; Not moving (dir_ptr == 0)

check_monster
    ; Check if target tile is a monster (tiles 44-51 for 8 monsters)
    cmp #44                     ; Is it >= monster start?
    bcc check_item              ; No, check for items
    cmp #52                     ; Is it < monster end (44 + 8)?
    bcs check_item              ; No, check for items
    jsr attack_monster          ; Yes, attack the monster!
    rts                         ; Don't move after attacking

check_item
    ldi dir_ptr                 ; Re-load tile from direction
    cmp #MAP_BOW                ; Is it a bow pickup?
    bne check_passable          ; No, check if passable
    jsr pickup_bow              ; Yes, pick up the bow!
    ; Continue to move onto the tile after pickup

check_passable
    is_passable()               ; Detect collision
    bcc blocked                 ; Carry flag == 0, so colliding

    ; Check if current tile is a doorway - if so, close it after moving
    ldy #0
    lda (player_ptr),y          ; Load current tile (where player is standing)
    cmp #MAP_DOORWAY            ; Is it a doorway?
    bne move_player             ; No, just move

close_doorway
    ; Standing on doorway - save old position, move, then close the door
    mwa player_ptr tmp_addr1    ; Save old position in tmp_addr1
    mwa dir_ptr player_ptr      ; Move the player to the correct location
    lda #MAP_DOOR               ; Load door tile
    sta (tmp_addr1),y           ; Close the door at the old position
    rts

move_player
    mwa dir_ptr player_ptr      ; Move the player to the correct location

check_stairs
    ; If player stepped on a down ladder, generate the next dungeon floor
    ldy #0
    lda (player_ptr),y
    cmp #MAP_DOWN
    bne blocked
    jsr descend_to_next_level

blocked                         ; We are blocked
    rts
    .endp

; Check to see if a tile is passable
; If carry flag is 0, collision
; If carry flag is 1, no collision
.proc is_passable
    lda no_clip                 ; Check to see if collision detection is active
    bne passable                ; If not, skip to passable
    ldi dir_ptr                 ; Dereference direction pointer to get tile
    cmp #PASSABLE_MIN           ; Is the tile passable
    bcc blocked                 ; Not passable

passable
    sec                         ; Tile is passable, so set the carry flag
    rts

blocked
    clc                         ; Tile is blocked, so clear the carry flag
    rts
    .endp

; Attack a monster at dir_ptr location
.proc attack_monster
    ldy #0
    lda (dir_ptr),y             ; Load monster tile ID (44-51)
    sta tmp1                    ; Save tile ID for later XP calculation (use tmp1, not tmp!)
    sec
    sbc #44                     ; Convert tile 44-51 to index 0-7
    tax                         ; Use as index
    lda monster_hp_table,x      ; Load monster's base HP
    sta monster_hp              ; Store in monster_hp variable
    lda monster_dmg_table,x     ; Load monster's base damage
    sta monster_dmg             ; Store in monster_dmg variable

    ; Scale monster stats by floor depth.
    ; bonus = dungeon_floor / 2
    lda dungeon_floor
    sec
    sbc #1
    lsr
    sta tmp

    ; HP bonus = bonus * 4
    lda tmp
    asl
    asl
    clc
    adc monster_hp
    sta monster_hp

    ; Damage bonus = bonus
    lda monster_dmg
    clc
    adc tmp
    sta monster_dmg

combat_loop
    ; Player attacks monster - use equipped weapon's damage
    lda equipped_weapon         ; Check which weapon is equipped
    bne use_ranged_dmg          ; If non-zero, use ranged weapon

use_melee_dmg
    lda player_melee_dmg        ; Load melee damage
    jmp do_attack

use_ranged_dmg
    lda player_ranged_dmg       ; Load ranged (bow) damage

do_attack
    sta tmp2                    ; Store damage amount temporarily (tmp1 has monster tile ID!)
    lda monster_hp
    sec
    sbc tmp2                    ; Subtract player's damage
    sta monster_hp              ; Update monster HP
    bmi monster_dead            ; If negative, monster is dead
    beq monster_dead            ; If zero, monster is dead

monster_counter
    ; Monster survived - it counter-attacks!
    lda player_hp
    sec
    sbc monster_dmg             ; Subtract monster's damage
    sta player_hp               ; Update player HP

    ; Check if player died (must check before calling subroutines)
    bmi player_dead             ; If negative, player died
    beq player_dead             ; If zero, player died

    ; Update the HP bar to show damage
    jsr update_hp_bar

    rts                         ; One combat exchange per contact

monster_dead
    ; Monster died - award XP based on monster type
    lda tmp1                    ; Recall monster tile ID we saved earlier (in tmp1, not tmp)
    sec
    sbc #44                     ; Convert tile 44-51 to index 0-7
    tax
    lda monster_xp_table,x      ; Load XP reward from table
    clc
    adc player_xp               ; Add to current XP
    sta player_xp               ; Update player XP

    ; Update XP bar to show new XP
    jsr update_xp_bar

    ; Check if player leveled up
    jsr check_level_up

    ; Remove monster from map
    ldy #0
    lda #MAP_FLOOR
    sta (dir_ptr),y
    rts

player_dead
    ; Player died - set HP to 0
    lda #0
    sta player_hp               ; Ensure HP is exactly 0

    ; Update HP bar to show 0 HP
    jsr update_hp_bar

    ; Death animation - flash screen red 5 times
    lda #5                      ; Number of flashes
    sta tmp2                    ; Save flash counter
death_flash
    ; Save current colors
    lda COLOR0
    sta tmp1

    ; Flash to red
    lda #red
    sta COLOR0
    sta COLOR1
    sta COLOR2
    sta COLOR4

    ; Delay
    ldx #10
    jsr delay

    ; Restore colors
    lda tmp1
    sta COLOR0
    mva #red COLOR1
    mva #blue COLOR2
    mva #black COLOR4

    ; Delay
    ldx #10
    jsr delay

    dec tmp2
    bne death_flash

    ; Final effect - turn everything dark red
    lda #$32                    ; Dark red
    sta COLOR0
    sta COLOR1
    sta COLOR2
    sta COLOR4

death_loop
    ; Game over - infinite loop freezes the game
    jmp death_loop
    .endp

; Pick up a bow item at dir_ptr location
.proc pickup_bow
    ; Set has_bow flag
    lda #1
    sta has_bow

    ; Give the bow 10 damage (can be upgraded)
    lda #18
    sta player_ranged_dmg

    ; Remove bow from map (replace with floor)
    ldy #0
    lda #MAP_FLOOR
    sta (dir_ptr),y

    ; Update the ranged damage display on HUD
    jsr update_ranged_display

    rts
    .endp

; Read keyboard for weapon switching
; Called from main game loop
.proc read_keyboard
    lda CH                      ; Read keyboard character code
    cmp #CH_NONE                ; No key pressed?
    beq done                    ; Yes, exit

check_bow_key
    cmp #KEY_B                  ; 'B' key pressed?
    bne check_melee_key         ; No, check next key
    lda has_bow                 ; Do we have a bow?
    beq done                    ; No bow, can't equip it
    lda #1                      ; Yes, equip ranged weapon
    sta equipped_weapon
    lda #CH_NONE                ; Clear the key press
    sta CH
    rts

check_melee_key
    cmp #KEY_M                  ; 'M' key pressed?
    bne done                    ; No, exit
    lda #0                      ; Equip melee weapon
    sta equipped_weapon
    lda #CH_NONE                ; Clear the key press
    sta CH

done
    rts
    .endp



