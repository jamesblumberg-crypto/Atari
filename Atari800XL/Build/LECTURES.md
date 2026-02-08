# 6502 Assembly for Atari 800XL - Lecture Series

Based on your dungeon crawler game code. Each lecture uses examples from YOUR codebase.

---

## Lecture 1: The 6502 CPU Basics

### The Three Registers

The 6502 has only THREE main registers you work with:

| Register | Name | Size | Purpose |
|----------|------|------|---------|
| **A** | Accumulator | 8-bit | Main math/logic register |
| **X** | X Index | 8-bit | Counter, array index |
| **Y** | Y Index | 8-bit | Counter, array index |

**From your code** (`input.asm:31-37`):
```asm
.proc read_direction
    mwa player_ptr dir_ptr      ; Copy player pointer to direction ptr
    mva STICK0 stick_dir        ; Load stick bitmap into A, then store
```

The `mva` macro does: `lda STICK0` then `sta stick_dir` - load into A, store from A.

### The Status Register (Flags)

The CPU automatically sets FLAGS after most operations:

| Flag | Name | Set When... |
|------|------|-------------|
| **Z** | Zero | Result is 0 |
| **N** | Negative | Bit 7 of result is 1 |
| **C** | Carry | Addition overflowed, or subtraction didn't borrow |
| **V** | Overflow | Signed math overflowed |

**From your code** (`main.asm:281-287`):
```asm
calc_segments
    cmp #17                     ; Compare A with 17
    bcc draw_bars               ; Branch if Carry Clear (A < 17)
    sec
    sbc #17                     ; Subtract 17
    inx                         ; Increment X
    cpx #6                      ; Compare X with 6
    bcc calc_segments           ; Loop if X < 6
```

- `cmp #17` sets Carry if A >= 17, clears if A < 17
- `bcc` branches if Carry is Clear (meaning A was less than 17)

---

## Lecture 2: Memory and Addressing Modes

### The 6502 Memory Map

The 6502 can address 64KB of memory ($0000-$FFFF). Your game uses:

**From your code** (`main.asm:3-49`):
```asm
    org $b000                   ; Code starts at $B000 (ROM area)

map                 = $2000     ; Map data (RAM)
screen              = $7000     ; Screen buffer (RAM)
pmg                 = $7400     ; Player-Missile Graphics (RAM)
cur_charset_a       = $7800     ; Character set A (RAM)
dlist               = $9800     ; Display list
charset_dungeon_a   = $8000     ; Character graphics (ROM)
```

### Zero Page ($00-$FF) - The Fast Memory

Zero Page is special - instructions using it are 1 byte shorter and 1 cycle faster!

**From your code** (`main.asm:55-67`):
```asm
map_ptr             = $92       ; 16-bit pointer (2 bytes: $92-$93)
screen_ptr          = $94       ; 16-bit pointer
player_x            = $96       ; 8-bit value
player_y            = $97       ; 8-bit value
tmp                 = $98       ; Temporary storage
```

### Addressing Modes

**Immediate** - The value IS the operand:
```asm
lda #100            ; Load the NUMBER 100 into A
```

**Absolute** - The value is AT that address:
```asm
lda player_hp       ; Load whatever is stored at address player_hp
```

**Zero Page** - Same as absolute but for $00-$FF (faster):
```asm
lda player_x        ; player_x = $96, so load from $0096
```

**Indexed** - Add X or Y to the address:
```asm
lda monster_hp_table,x   ; Load from monster_hp_table + X
```

**Indirect Indexed** - For 16-bit pointers (VERY common in your code):
```asm
lda (map_ptr),y     ; Load from address stored in map_ptr, plus Y offset
```

**From your code** (`main.asm:700-703`):
```asm
.macro blit_tile
    lda (map_ptr),y         ; Load tile from address in map_ptr + Y
    asl                     ; Multiply by 2
    jsr fix_color           ; Call subroutine
    sta (screen_ptr),y      ; Store to address in screen_ptr + Y
```

---

## Lecture 3: Essential Instructions

### Loading and Storing

| Instruction | Meaning | Example |
|-------------|---------|---------|
| `lda` | Load A | `lda #5` or `lda player_hp` |
| `ldx` | Load X | `ldx #0` |
| `ldy` | Load Y | `ldy #10` |
| `sta` | Store A | `sta player_hp` |
| `stx` | Store X | `stx counter` |
| `sty` | Store Y | `sty index` |

### Math Operations

| Instruction | Meaning | Notes |
|-------------|---------|-------|
| `adc` | Add with Carry | Must `clc` first for simple add |
| `sbc` | Subtract with Carry | Must `sec` first for simple subtract |
| `inc` | Increment memory | `inc player_x` adds 1 |
| `dec` | Decrement memory | `dec player_hp` subtracts 1 |
| `inx/iny` | Increment X/Y | |
| `dex/dey` | Decrement X/Y | |

**From your code** (`main.asm:1169-1172`):
```asm
    lda arrow_y
    sec                     ; Set Carry (required before subtraction!)
    sbc #12                 ; Subtract 12 from A
    sta arrow_y             ; Store result
```

**CRITICAL**: Always `sec` before `sbc`, always `clc` before `adc`!

### Comparison and Branching

| Instruction | Meaning |
|-------------|---------|
| `cmp` | Compare A with value (sets flags) |
| `cpx` | Compare X with value |
| `cpy` | Compare Y with value |

| Branch | Meaning | Use After |
|--------|---------|-----------|
| `beq` | Branch if Equal (Z=1) | `cmp`, `lda`, etc. when result is 0 |
| `bne` | Branch if Not Equal (Z=0) | When result is not 0 |
| `bcc` | Branch if Carry Clear | `cmp` when A < value |
| `bcs` | Branch if Carry Set | `cmp` when A >= value |
| `bmi` | Branch if Minus (N=1) | When result is negative |
| `bpl` | Branch if Plus (N=0) | When result is positive |

**From your code** (`input.asm:39-45`):
```asm
check_up
    and #STICK_UP           ; AND with joystick UP bit
    bne check_down          ; If result != 0, joystick NOT pushed up
    sbw dir_ptr #map_width  ; It IS pushed up, so adjust pointer
    lda #NORTH
    sta player_dir
    rts                     ; Return - we're done
```

---

## Lecture 4: Subroutines and the Stack

### The Stack

The 6502 stack lives at $0100-$01FF and grows DOWNWARD. It's used for:
1. Return addresses (from `jsr`)
2. Saving register values (`pha`, `php`)

### JSR and RTS

**From your code** (`main.asm:255-257`):
```asm
game
    mva RTCLK2 clock
    animate                 ; This is a macro (expands inline)
    get_input               ; This is a macro
    jsr read_keyboard       ; This CALLS a subroutine
    jsr update_arrow        ; Another subroutine call
    jmp game                ; Jump back (infinite loop)
```

When `jsr read_keyboard` executes:
1. Push return address onto stack (2 bytes)
2. Jump to `read_keyboard`
3. When `rts` is hit, pop address and return

### Saving Registers

**From your code** (`main.asm:663-667`):
```asm
.proc fix_color
    sta tmp         ; Save A to memory
    tya             ; Transfer Y to A
    pha             ; Push A (which is Y) onto stack
    lda tmp         ; Restore original A value
```

And at the end (`main.asm:694-697`):
```asm
done
    pla             ; Pull saved Y value from stack
    tay             ; Transfer A back to Y
    lda tmp         ; Restore original A value
    rts
```

This pattern **preserves the Y register** across the subroutine call.

---

## Lecture 5: 16-bit Operations

The 6502 is an 8-bit CPU, but addresses are 16-bit. You need special techniques.

### 16-bit Pointers

A 16-bit pointer uses 2 consecutive bytes (low byte first!):

```
map_ptr     = $92       ; Low byte at $92
map_ptr+1   = $93       ; High byte at $93

If map_ptr contains $2000:
    $92 contains $00 (low byte)
    $93 contains $20 (high byte)
```

### 16-bit Increment

**From your code** (`macros.asm:1-6`):
```asm
.macro inc16 addr
    inc :addr           ; Increment low byte
    bne skip_carry      ; If it didn't wrap to 0, we're done
    inc :addr + 1       ; It wrapped! Increment high byte
skip_carry
.endm
```

Example: If `map_ptr` = $20FF
1. `inc map_ptr` makes low byte $00 (wrapped from $FF)
2. `bne skip_carry` - Z flag IS set (result was 0), so we DON'T branch
3. `inc map_ptr+1` makes high byte $21
4. Result: $2100

### 16-bit Addition

**From your code** (`macros.asm:16-23`):
```asm
.macro adbw src val
    lda :src            ; Load low byte
    add :val            ; Add value (MADS 'add' = clc + adc)
    sta :src            ; Store low byte
    bcc skip_carry      ; If no carry, we're done
    inc :src + 1        ; Carry occurred! Increment high byte
skip_carry
.endm
```

### The MWA Macro (Move Word to Address)

MADS provides `mwa` for 16-bit moves:

```asm
mwa #map map_ptr        ; Store $2000 into map_ptr
                        ; Expands to:
                        ;   lda #<map    ; Low byte
                        ;   sta map_ptr
                        ;   lda #>map    ; High byte
                        ;   sta map_ptr+1
```

---

## Lecture 6: Bit Manipulation

### Logical Operations

| Instruction | Operation | Use Case |
|-------------|-----------|----------|
| `and` | Bitwise AND | Mask off bits, check specific bits |
| `ora` | Bitwise OR | Set specific bits |
| `eor` | Bitwise XOR | Toggle bits, flip values |

**From your code** (`main.asm:547-549`):
```asm
    lda charset_a
    eor #$ff            ; XOR with $FF flips ALL bits
    sta charset_a       ; 0 becomes $FF, $FF becomes 0
```

This toggles between two character sets for animation!

### Shift Operations

| Instruction | Operation | Effect |
|-------------|-----------|--------|
| `asl` | Arithmetic Shift Left | Multiply by 2 |
| `lsr` | Logical Shift Right | Divide by 2 |
| `rol` | Rotate Left through Carry | |
| `ror` | Rotate Right through Carry | |

**From your code** (`main.asm:701-702`):
```asm
    lda (map_ptr),y     ; Load tile number (0-127)
    asl                 ; Multiply by 2 to get character index
```

Tiles are 2 characters wide, so tile 5 uses characters 10 and 11.

### Testing Bits

**From your code** (`input.asm:39-41`):
```asm
check_up
    and #STICK_UP       ; STICK_UP = %0001
    bne check_down      ; If result != 0, bit was set
```

The joystick returns inverted bits (0 = pressed). This code:
1. ANDs with %0001 to isolate the UP bit
2. If result is NOT zero, the bit was 1 (not pressed)
3. If result IS zero, the bit was 0 (pressed!)

---

## Lecture 7: The Atari Display System

### Display List (ANTIC)

The ANTIC chip reads a "display list" that tells it how to draw the screen.

**From your code** (`dlist.asm:30-36`):
```asm
dlist
    .byte blank8, blank8, blank8                    ; 24 blank scanlines
    .byte antic4 + lms + NMIEN_DLI, <status_line, >status_line
    .byte antic5 + lms, <screen, >screen            ; Mode 5 + load address
    .byte antic5, antic5, antic5, antic5, antic5    ; 5 more mode 5 lines
    .byte antic5, antic5, antic5, antic5, antic5 + NMIEN_DLI, antic4
    .byte jvb, <dlist, >dlist                       ; Jump and wait for VBlank
```

- `blank8` = 8 blank scanlines
- `antic4` = Text mode (40 chars, 8 scanlines tall)
- `antic5` = High-res graphics mode (40 chars, 16 scanlines)
- `lms` = Load Memory Scan (next 2 bytes are the screen address)
- `NMIEN_DLI` = Trigger Display List Interrupt on this line
- `jvb` = Jump and wait for Vertical Blank

### Display List Interrupts (DLI)

DLIs let you change graphics settings MID-SCREEN!

**From your code** (`dlist.asm:39-55`):
```asm
dli1
    pha                     ; Save A on stack
    lda #1
    sta WSYNC               ; Wait for horizontal sync
    lda charset_a
    bne use_charset_b
    mva #>cur_charset_a CHBASE  ; Use charset A
    jmp done
use_charset_b
    mva #>cur_charset_b CHBASE  ; Use charset B
done
    mwa #dli2 VDSLST        ; Set up next DLI
    set_colors
    pla                     ; Restore A
    rti                     ; Return from Interrupt
```

This changes the character set partway down the screen!

### Character Sets

Characters are 8x8 pixel bitmaps. The Atari can point to any 1KB-aligned address.

**From your code** (`main.asm:166`):
```asm
mva #>charset_outdoor_a CHBAS   ; Set character base to high byte of address
```

`>charset_outdoor_a` gets the HIGH byte ($88 for $8800), which tells ANTIC where to find character graphics.

---

## Lecture 8: Player-Missile Graphics (Sprites)

### PMG Memory Layout

**From your code** (`main.asm:600-604`):
```asm
.proc clear_pmg
pmg_p0 = pmg + $200     ; Player 0 at PMBASE + $200
pmg_p1 = pmg + $280     ; Player 1 at PMBASE + $280
pmg_p2 = pmg + $300     ; Player 2 at PMBASE + $300
pmg_p3 = pmg + $380     ; Player 3 at PMBASE + $380
```

Each player is 128 bytes (one byte per scanline in double-line mode).

### Setting Up PMG

**From your code** (`main.asm:645-656`):
```asm
.proc setup_pmg
    mva #>pmg PMBASE        ; Tell ANTIC where PMG memory is
    mva #46 SDMCTL          ; Enable DMA, players, missiles
    mva #3 GRACTL           ; Enable player and missile graphics
    mva #1 GRPRIOR          ; Players have priority over playfield
    mva #%00110000 SIZEM    ; Missile 2 is double-width
    lda #92
    sta HPOSP0              ; Horizontal position of player 0
    sta HPOSP1              ; (all players at same X for now)
    sta HPOSP2
    sta HPOSP3
    rts
.endp
```

### Drawing Missiles

**From your code** (`main.asm:1327-1340`):
```asm
.proc draw_arrow_missile
    lda arrow_x
    sta HPOSM2              ; Set horizontal position
    lda arrow_y
    tax                     ; Use Y coordinate as index
    lda #%00110000          ; Bits 4-5 = Missile 2
    sta pmg_missiles,x      ; Draw 4 scanlines
    inx
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x
    inx
    sta pmg_missiles,x
    rts
.endp
```

The missile byte format:
- Bits 0-1: Missile 0
- Bits 2-3: Missile 1
- Bits 4-5: Missile 2 (used for arrow)
- Bits 6-7: Missile 3

---

## Lecture 9: Macros vs Procedures

### Macros (Inline Expansion)

Macros copy their code EVERYWHERE they're used.

**From your code** (`main.asm:531-541`):
```asm
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
```

Every time you write `get_input`, ALL this code is inserted. Good for:
- Small, frequently-used code
- Speed-critical code (no JSR/RTS overhead)

Bad for:
- Large code (wastes memory)
- Code with labels (can cause duplicates!)

### Procedures (Subroutines)

Procedures exist ONCE in memory and are CALLED.

**From your code** (`main.asm:662-698`):
```asm
.proc fix_color
    ; ... 35 lines of code ...
    rts
.endp
```

Called with `jsr fix_color`. Good for:
- Large code
- Code called from many places
- Code with internal labels (properly scoped)

### The Bug We Fixed

The `fix_color` was a MACRO, called twice inside `blit_tile`:
```asm
.macro blit_tile
    ...
    fix_color       ; First copy of all fix_color code
    ...
    fix_color       ; Second copy - DUPLICATE LABELS!
    ...
.endm
```

The `done` label existed TWICE, causing `bcc done` to jump to the WRONG one, skipping a `pla` and corrupting the stack!

**Fix**: Convert to `.proc` so labels are scoped and code exists only once.

---

## Lecture 10: Game Loop Structure

### The Main Loop

**From your code** (`main.asm:251-257`):
```asm
game
    mva RTCLK2 clock        ; Read real-time clock
    animate                 ; Toggle character set (if timer expired)
    get_input               ; Read joystick, move player (if timer expired)
    jsr read_keyboard       ; Check for key presses
    jsr update_arrow        ; Move arrow, check collisions
    jmp game                ; Loop forever
```

### Timer-Based Updates

**From your code** (`main.asm:531-540`):
```asm
.macro get_input
    lda clock
    cmp input_timer         ; Has enough time passed?
    bne input_done          ; No - skip input processing
    read_joystick()         ; Yes - read input
    blit_screen()           ; Redraw screen
    lda clock
    add #input_speed        ; input_speed = 5
    sta input_timer         ; Set next trigger time
input_done
.endm
```

The Atari's RTCLK2 increments 60 times per second. By comparing with a timer value, you control update speed:
- `input_speed = 5` means input is processed every 5/60 = 0.083 seconds
- `anim_speed = 20` means animation every 20/60 = 0.33 seconds

---

## Lecture 11: Indirect Addressing Deep Dive

### The Power of Pointers

Your game uses pointers extensively for map navigation:

**From your code** (`input.asm:121-164`):
```asm
.proc player_move
    ldi dir_ptr             ; Load tile from where we want to move
    beq blocked             ; If 0, we're not moving

check_monster
    cmp #44                 ; Monster tiles are 44-51
    bcc check_item          ; Less than 44? Not a monster
    cmp #52
    bcs check_item          ; Greater than 51? Not a monster
    jsr attack_monster      ; It's a monster! Attack!
    rts

check_passable
    is_passable()           ; Check if we can walk there
    bcc blocked             ; Carry clear = blocked

move_player
    mwa dir_ptr player_ptr  ; Update player position
blocked
    rts
.endp
```

### How Pointers Work

```asm
player_ptr = $DE            ; 2-byte pointer at $DE-$DF

; If player is at map position (16, 16):
; player_ptr contains $2000 + (16 * 139) + 16 = $28C0
; $DE = $C0 (low byte)
; $DF = $28 (high byte)

ldy #0
lda (player_ptr),y          ; Load tile at player's position
```

### The LDI and STI Macros

**From your code** (`macros.asm:127-135`):
```asm
.macro ldi addr             ; Load Indirect
    ldy #0
    lda (:addr),y           ; Load from address stored in 'addr'
.endm

.macro sti addr             ; Store Indirect
    ldy #0
    sta (:addr),y           ; Store to address stored in 'addr'
.endm
```

These simplify common pointer operations.

---

## Lecture 12: Putting It All Together

### A Complete Feature: The Arrow System

1. **Fire the arrow** (`main.asm:1143-1204`):
   - Check if arrow already active
   - Set starting position (offset from player)
   - Set direction from player_dir
   - Draw initial missile graphics

2. **Update each frame** (`main.asm:1207-1248`):
   - Clear old missile position
   - Move arrow (screen coordinates)
   - Every 8 pixels, move map coordinates
   - Check for collisions
   - Check bounds
   - Draw new position

3. **Handle collisions** (`main.asm:1251-1314`):
   - Calculate map address from arrow_map_x/y
   - Check if tile is a monster (44-51)
   - Check if tile is passable
   - Deactivate arrow if it hits something

### Key Concepts Used

- **Zero page pointers** for map navigation
- **Indexed addressing** for PMG graphics
- **Bit manipulation** for missile data
- **Comparison and branching** for game logic
- **Subroutines** for organized code
- **Hardware registers** for display

---

## Quick Reference Card

### Common Patterns

**Check if A equals a value:**
```asm
    cmp #value
    beq is_equal
    ; not equal
is_equal:
```

**Check if A is less than a value:**
```asm
    cmp #value
    bcc is_less
    ; A >= value
is_less:
```

**Loop X times:**
```asm
    ldx #count
loop:
    ; do something
    dex
    bne loop
```

**16-bit pointer access:**
```asm
    ldy #0
    lda (pointer),y     ; Load from pointer + 0
    ldy #5
    lda (pointer),y     ; Load from pointer + 5
```

**Save and restore registers:**
```asm
    pha             ; Save A
    txa
    pha             ; Save X
    tya
    pha             ; Save Y
    ; ... do work ...
    pla
    tay             ; Restore Y
    pla
    tax             ; Restore X
    pla             ; Restore A
```

---

## Exercises

1. **Trace through `read_direction`** - Draw out what happens when joystick is pushed UP

2. **Understand `blit_tile`** - Why does it multiply by 2? Why two stores?

3. **Modify arrow speed** - Change ARROW_SPEED and see the effect

4. **Add a new item** - Create a health potion pickup like MAP_BOW

5. **Debug with Altirra** - Set breakpoints, watch memory, single-step

---

*Created from your Atari 800XL dungeon crawler codebase*
