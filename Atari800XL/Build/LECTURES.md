# 6502 Assembly for Atari 800XL
## A Guide for BASIC Programmers

*Written for someone who grew up with an Atari 800, programmed in BASIC, but never understood what was happening "under the hood."*

---

# Part 1: The Big Picture

## What Assembly Really Is

Remember in BASIC when you typed:

```basic
10 A = 5
20 B = 10
30 C = A + B
40 PRINT C
```

When you hit RUN, BASIC had to figure out what you meant. It read "A = 5", looked up where variable A was stored, converted "5" to a number, and put it there. This translation takes time.

**Assembly is different.** Instead of telling the computer WHAT you want, you tell it exactly HOW to do it, step by step. You're speaking directly to the CPU chip.

```asm
    lda #5          ; Put the number 5 into the A register
    sta $96         ; Store that 5 at memory location $96
    lda #10         ; Put 10 into A
    clc             ; Clear the carry flag (prepare for addition)
    adc $96         ; Add whatever is at $96 (the 5) to A
                    ; A now contains 15
```

This code does the same thing as `C = 5 + 10`, but:
- You control exactly WHERE the numbers go
- You control exactly WHICH operations happen
- There's no translation - this IS what the CPU does

## Why Did People Use Assembly?

The Atari 800 had a 1.79 MHz CPU. That sounds fast, but BASIC was SLOW:

| Task | BASIC | Assembly |
|------|-------|----------|
| Fill screen with a character | ~2 seconds | ~1/60 second |
| Move a sprite smoothly | Jerky | Butter smooth |
| Read joystick + update screen | Laggy | Instant |

Your game needs to update 60 times per second to feel smooth. BASIC simply couldn't keep up.

## The Memory Map: Your Computer's Address Book

Think of memory like a giant apartment building with 65,536 units (numbered $0000 to $FFFF in hex).

```
$0000-$00FF : "Zero Page" - The penthouse! Super fast access.
$0100-$01FF : The Stack - Where the CPU takes notes
$2000-$7FFF : RAM - Your stuff goes here
$8000-$BFFF : Cartridge ROM - Your game code
$C000-$CFFF : OS ROM or RAM
$D000-$D7FF : Hardware registers - The MAGIC addresses!
$D800-$FFFF : OS ROM
```

**The hardware registers ($D000-$D7FF) are special.** These aren't storage - they're control panels!

In BASIC, you used PEEK and POKE:
```basic
POKE 712, 148    ' Change background color
X = PEEK(632)    ' Read joystick
```

Those numbers (712, 632) are memory addresses. POKE 712 doesn't store 148 somewhere - it TELLS THE ANTIC CHIP to change the background color!

In assembly:
```asm
    mva #148 $02C8      ; Same as POKE 712, 148
    lda $0278           ; Same as X = PEEK(632)
```

---

# Part 2: The CPU - Your New Best Friend

## The Three Registers

The 6502 CPU has three "hands" called registers:

| Register | Name | What It's For |
|----------|------|---------------|
| **A** | Accumulator | Math, loading, storing - the main workhorse |
| **X** | X Index | Counting loops, accessing arrays |
| **Y** | Y Index | Same as X, but independent |

**They're only 8 bits!** That means 0-255, just like BASIC variables after you POKE'd them.

**From your game** (`main.asm`):
```asm
    lda #100            ; A = 100
    sta player_hp       ; player_hp = A (which is 100)
    lda #15
    sta player_melee_dmg
```

This is like:
```basic
100 HP = 100
110 DMG = 15
```

## The Status Register: How the CPU "Feels"

After most operations, the CPU sets FLAGS that tell you what happened:

| Flag | Name | When It's Set |
|------|------|---------------|
| **Z** | Zero | The result was zero |
| **N** | Negative | Bit 7 of result is 1 (it's "negative" in signed math) |
| **C** | Carry | Addition overflowed past 255, OR subtraction didn't need to borrow |

**Why does this matter?** Because this is how decisions work!

In BASIC:
```basic
100 IF HP = 0 THEN GOTO 500
```

In assembly:
```asm
    lda player_hp       ; Load HP into A
    beq player_dead     ; "Branch if Equal to zero" - if Z flag is set
```

The `lda` instruction automatically sets the Z flag if the value was 0!

**From your game** (`input.asm:126-132`):
```asm
check_monster
    cmp #44             ; Compare A with 44
    bcc check_item      ; Branch if A < 44 (Carry Clear)
    cmp #52             ; Compare A with 52
    bcs check_item      ; Branch if A >= 52 (Carry Set)
    jsr attack_monster  ; If we got here, 44 <= A < 52 (it's a monster!)
```

This is like:
```basic
100 IF TILE < 44 THEN GOTO check_item
110 IF TILE >= 52 THEN GOTO check_item
120 GOSUB attack_monster
```

---

# Part 3: Instructions You'll Use Constantly

## Loading and Storing

| Instruction | BASIC Equivalent | Example |
|-------------|------------------|---------|
| `lda #5` | A = 5 | Load immediate value |
| `lda player_x` | A = PEEK(player_x) | Load from memory |
| `sta player_x` | POKE player_x, A | Store to memory |
| `ldx #10` | X = 10 | Load X register |
| `ldy #0` | Y = 0 | Load Y register |

The `#` symbol means "use this NUMBER." Without it, it means "use the ADDRESS."

```asm
    lda #$50        ; A = $50 (the number 80)
    lda $50         ; A = whatever is stored at address $0050
```

## Math

The 6502 can only ADD and SUBTRACT. No multiply, no divide!

```asm
    clc             ; ALWAYS clear carry before adding!
    lda player_x
    adc #5          ; A = A + 5 + Carry
    sta player_x   ; player_x = player_x + 5
```

**CRITICAL: Always CLC before ADC, always SEC before SBC!**

```asm
    sec             ; ALWAYS set carry before subtracting!
    lda player_hp
    sbc #10         ; A = A - 10 - (1-Carry)
    sta player_hp   ; player_hp = player_hp - 10
```

Why? The carry flag is used for multi-byte math. If you forget, you'll get wrong answers!

**Shortcuts:**
```asm
    inc player_x    ; player_x = player_x + 1 (no need for clc/adc)
    dec player_hp   ; player_hp = player_hp - 1
    inx             ; X = X + 1
    dey             ; Y = Y - 1
```

## Comparison and Branching

| Instruction | What It Does |
|-------------|--------------|
| `cmp #10` | Compare A with 10, set flags |
| `cpx #5` | Compare X with 5, set flags |
| `cpy #0` | Compare Y with 0, set flags |

| Branch | Meaning | Use After CMP When... |
|--------|---------|----------------------|
| `beq` | Branch if Equal | A was equal to the value |
| `bne` | Branch if Not Equal | A was not equal |
| `bcc` | Branch if Carry Clear | A was LESS than the value |
| `bcs` | Branch if Carry Set | A was GREATER OR EQUAL |
| `bmi` | Branch if Minus | Result had bit 7 set |
| `bpl` | Branch if Plus | Result had bit 7 clear |

**From your game** (`main.asm:281-287`) - HP bar calculation:
```asm
calc_segments
    cmp #17             ; Is A >= 17?
    bcc draw_bars       ; If A < 17, we're done counting
    sec
    sbc #17             ; A = A - 17
    inx                 ; X counts how many 17s fit in the HP
    cpx #6              ; Did we count 6 segments?
    bcc calc_segments   ; No? Keep going
```

This calculates how many full HP segments to draw!

---

# Part 4: Memory - Going Beyond 255

## The Problem

Registers are 8-bit. Memory addresses are 16-bit (0-65535). How do we work with big numbers?

**Answer: Use TWO bytes!**

```
Address $92 = low byte
Address $93 = high byte

If we want to store $2000:
    $92 = $00 (low byte)
    $93 = $20 (high byte)

The number is stored "backwards" - low byte first!
This is called "little endian."
```

**From your game** (`main.asm:55-56`):
```asm
map_ptr         = $92       ; This is actually TWO bytes: $92 and $93
screen_ptr      = $94       ; Two bytes: $94 and $95
```

## 16-Bit Addition

To add to a 16-bit number, add the low byte first, then the high byte (carrying if needed):

**From your game** (`macros.asm:1-6`):
```asm
.macro inc16 addr
    inc :addr           ; Add 1 to low byte
    bne skip_carry      ; If it didn't wrap to 0, we're done
    inc :addr + 1       ; It wrapped! Add 1 to high byte too
skip_carry
.endm
```

Example: If map_ptr = $20FF
1. `inc map_ptr` → $00 (wrapped from $FF, Z flag set!)
2. `bne skip_carry` → Z is set, so we DON'T branch
3. `inc map_ptr+1` → $21

Result: $2100

## Indirect Addressing - The Power Move

This is how your game navigates the map. Watch carefully:

```asm
    ldy #0
    lda (map_ptr),y     ; Load from THE ADDRESS STORED IN map_ptr
```

If `map_ptr` contains $2800, this loads the byte at address $2800.

It's like pointers in C, or like PEEK(PEEK(low) + 256*PEEK(high)) in BASIC!

**From your game** (`macros.asm:127-130`):
```asm
.macro ldi addr         ; "Load Indirect"
    ldy #0
    lda (:addr),y       ; Load the byte that addr POINTS TO
.endm
```

Your game uses this to read map tiles:
```asm
    ldi player_ptr      ; What tile is the player standing on?
```

---

# Part 5: The Atari's Custom Chips

## The Atari Advantage

The Atari 800 wasn't just a CPU. It had THREE custom chips:

| Chip | Job | What It Does |
|------|-----|--------------|
| **ANTIC** | Display | Reads memory and creates the TV signal |
| **GTIA** | Graphics | Colors and player-missile graphics |
| **POKEY** | I/O + Sound | Keyboard, joystick, sound, serial I/O |

These chips work INDEPENDENTLY of the CPU! While your code runs, ANTIC is reading screen memory and drawing. You just update memory, and the display changes automatically.

## Memory-Mapped I/O

In BASIC, you used:
```basic
POKE 712, 148   ' Change background color
```

Address 712 (=$02C8) isn't RAM - it's connected to GTIA! When you write there, GTIA sees the value and changes the color.

**From your game** (`hardware.asm`):
```asm
COLOR0 = $02C4  ; These are "shadow registers"
COLOR1 = $02C5  ; The OS copies them to GTIA
COLOR2 = $02C6  ; during vertical blank
COLOR3 = $02C7
COLOR4 = $02C8  ; Background color

STICK0 = $0278  ; Read joystick direction
STRIG0 = $0284  ; Read fire button
```

**From your game** (`main.asm:579-591`):
```asm
.proc setup_colors
    mva #white COLOR0   ; Set color for %01 bit pattern
    mva #red COLOR1     ; Set color for %10 bit pattern
    mva #blue COLOR2    ; Set color for %11 bit pattern
    mva #gold COLOR3    ; Set color for inverse %11
    mva #black COLOR4   ; Set background color

    mva #red PCOLR0     ; Player 0 color
    mva #peach PCOLR1   ; Player 1 color
    mva #white PCOLR2   ; Player 2 / Missile 2 color (arrow!)
    mva #black PCOLR3   ; Player 3 color
    rts
.endp
```

## The Display List - ANTIC's Program

Remember GRAPHICS 0, GRAPHICS 7, etc.? Those set up a "display list" that tells ANTIC what to draw.

In assembly, YOU create the display list!

**From your game** (`dlist.asm:30-36`):
```asm
dlist
    .byte blank8, blank8, blank8    ; 24 blank scanlines
    .byte antic4 + lms + NMIEN_DLI, <status_line, >status_line
    .byte antic5 + lms, <screen, >screen
    .byte antic5, antic5, antic5, antic5, antic5
    .byte antic5, antic5, antic5, antic5, antic5 + NMIEN_DLI, antic4
    .byte jvb, <dlist, >dlist
```

Each byte is an instruction to ANTIC:
- `blank8` = "draw 8 blank lines"
- `antic4` = "draw one line of 40-column text"
- `antic5` = "draw one line of hi-res graphics"
- `lms` = "load memory scan - next 2 bytes are the address to read from"
- `jvb` = "jump to start and wait for vertical blank"

This is why Atari games had such creative displays - you could mix modes, scroll parts of the screen, and do things BASIC never allowed!

## Display List Interrupts - Changing Mid-Screen!

See that `NMIEN_DLI` in the display list? That tells ANTIC to interrupt the CPU when it reaches that line!

**From your game** (`dlist.asm:39-55`):
```asm
dli1
    pha                         ; Save A on stack
    lda #1
    sta WSYNC                   ; Wait for horizontal sync
    lda charset_a               ; Which charset are we using?
    bne use_charset_b
    mva #>cur_charset_a CHBASE  ; Use charset A
    jmp done
use_charset_b
    mva #>cur_charset_b CHBASE  ; Use charset B
done
    mwa #dli2 VDSLST            ; Set up next DLI handler
    set_colors
    pla                         ; Restore A
    rti                         ; Return from Interrupt
```

This changes the character set PARTWAY DOWN THE SCREEN! The status bar uses one charset, the dungeon uses another. This was impossible in BASIC!

---

# Part 6: Player-Missile Graphics

## What Are Player-Missile Graphics?

Remember the PLAYER() and MISSILE() commands in BASIC? Those were hardware sprites!

Unlike characters (which are locked to an 8x8 grid), players can be at ANY horizontal position and move smoothly.

**How it works:**
1. Set PMBASE to tell hardware where sprite data lives
2. Write the sprite shape into that memory (one byte = one scanline)
3. Set HPOSP0-3 to position the sprite horizontally
4. The hardware draws it automatically!

**From your game** (`main.asm:645-656`):
```asm
.proc setup_pmg
    mva #>pmg PMBASE        ; Sprite data is at $7400
    mva #46 SDMCTL          ; Enable player/missile DMA
    mva #3 GRACTL           ; Turn on players and missiles
    mva #1 GRPRIOR          ; Players appear in front of playfield
    mva #%00110000 SIZEM    ; Missile 2 is double-width
    lda #92
    sta HPOSP0              ; Horizontal position
    sta HPOSP1
    sta HPOSP2
    sta HPOSP3
    rts
.endp
```

## Drawing a Missile

Missiles share one memory area. Each scanline has one byte with 2 bits per missile:

```
Bit 7-6: Missile 3
Bit 5-4: Missile 2 (the arrow!)
Bit 3-2: Missile 1
Bit 1-0: Missile 0
```

**From your game** (`main.asm:1367-1390`):
```asm
.proc draw_arrow_missile
    lda arrow_x
    sta HPOSM2              ; Set horizontal position
    lda arrow_y
    tax                     ; X = Y coordinate (index into memory)
    lda #%00110000          ; Bits 5-4 set = Missile 2 visible
    sta pmg_missiles,x      ; Draw 8 scanlines
    inx
    sta pmg_missiles,x
    ; ... (repeats 8 times total)
    rts
.endp
```

---

# Part 7: The Game Loop

## How Games Work

Every game does the same thing, 60 times per second:

1. **Read input** (joystick, keyboard)
2. **Update game state** (move player, check collisions)
3. **Draw** (update screen memory)
4. **Wait for next frame**

**From your game** (`main.asm:251-257`):
```asm
game
    mva RTCLK2 clock        ; Read the 60Hz clock
    animate                 ; Toggle charset for animation
    get_input               ; Read joystick, move player
    jsr read_keyboard       ; Check for key presses
    jsr update_arrow        ; Update arrow position
    jmp game                ; Loop forever!
```

## Timing with the Real-Time Clock

The OS increments RTCLK2 sixty times per second. Your game uses this for timing:

**From your game** (`main.asm:531-540`):
```asm
.macro get_input
    lda clock
    cmp input_timer         ; Time for input?
    bne input_done          ; Not yet
    read_joystick()         ; Yes! Read input
    blit_screen()           ; Update display
    lda clock
    add #input_speed        ; input_speed = 5
    sta input_timer         ; Next input in 5 ticks (1/12 second)
input_done
.endm
```

This reads input every 5/60 = 0.083 seconds, giving smooth but not too twitchy control.

---

# Part 8: Macros vs Procedures

## Macros: Copy-Paste at Assembly Time

A macro is like a text replacement. Every time you use it, the assembler COPIES the entire code:

```asm
.macro clr addr
    mva #0 :addr            ; Store 0 at the address
.endm

; When you write:
    clr player_hp

; The assembler sees:
    mva #0 player_hp
```

**Pros:** Fast (no JSR/RTS overhead)
**Cons:** Uses more memory if used many times

## Procedures: One Copy, Many Calls

A procedure exists once in memory. You CALL it with JSR:

```asm
.proc clear_arrow_missile
    lda arrow_y
    tax
    lda #0
    sta pmg_missiles,x
    ; ... more code ...
    rts                     ; Return to caller
.endp

; Every call just does:
    jsr clear_arrow_missile ; 3 bytes, jumps to the one copy
```

**Pros:** Saves memory
**Cons:** Slightly slower (6 cycles for JSR + 6 for RTS)

## The Bug We Fixed!

The original `fix_color` was a MACRO that was used TWICE inside `blit_tile`:

```asm
.macro blit_tile
    ...
    fix_color       ; First copy - has labels: shift_bits, done
    ...
    fix_color       ; Second copy - SAME labels!
    ...
.endm
```

Both copies had a label called `done`. When the first copy said `bcc done`, it sometimes jumped to the SECOND copy's `done`!

This skipped a `pla` instruction, leaving garbage on the stack. After drawing many tiles, the stack got corrupted and the game crashed.

**Fix:** Convert to `.proc` so labels are properly contained:

```asm
.proc fix_color
    ; Labels here are PRIVATE to this procedure
    ...
done
    pla
    tay
    lda tmp
    rts             ; Now there's only ONE copy of this code
.endp
```

---

# Part 9: Reading the Joystick

## How Joystick Input Works

STICK0 ($0278) returns a 4-bit value with ACTIVE-LOW bits:

| Bit | Direction | Pressed = 0, Released = 1 |
|-----|-----------|---------------------------|
| 0 | Up | |
| 1 | Down | |
| 2 | Left | |
| 3 | Right | |

If nothing is pressed: STICK0 = %1111 = 15
If Up is pressed: STICK0 = %1110 = 14
If Up+Left: STICK0 = %1010 = 10

**From your game** (`input.asm:39-45`):
```asm
check_up
    and #STICK_UP           ; STICK_UP = %0001
    bne check_down          ; If result != 0, NOT pushed up
    ; (If result = 0, the bit was 0, meaning PRESSED!)
    sbw dir_ptr #map_width  ; Move direction pointer up
    lda #NORTH
    sta player_dir
    rts
```

The logic is tricky because the bits are INVERTED!

## Button Debouncing

Buttons bounce - they flicker on/off rapidly when pressed. The code handles this:

**From your game** (`input.asm:1-27`):
```asm
.proc read_joystick
    mva STRIG0 cur_btn      ; Read current button (0=pressed, 1=released)
    bne up                  ; If not 0, button is up

down                        ; Button is currently pressed
    lda stick_btn           ; What was it LAST frame?
    bne done                ; If it was UP, button was JUST pressed - wait

held                        ; Button was already down - it's being held
    lda stick_action        ; Did we already do the action?
    bne done                ; Yes, don't repeat
    read_direction()
    player_action()         ; Do the action!
    jmp done

up                          ; Button is released
    read_direction()
    player_move()
    clr stick_action        ; Reset action flag

done
    mva cur_btn stick_btn   ; Remember for next frame
    rts
.endp
```

---

# Quick Reference

## Common Patterns

**Is A equal to a value?**
```asm
    cmp #value
    beq yes_equal
    ; not equal
yes_equal:
```

**Is A less than a value?**
```asm
    cmp #value
    bcc yes_less        ; Carry Clear = Less than
    ; A >= value
yes_less:
```

**Loop 10 times:**
```asm
    ldx #10
loop
    ; do something
    dex
    bne loop            ; Loop until X = 0
```

**Save and restore A:**
```asm
    pha                 ; Push A onto stack
    ; ... do stuff that changes A ...
    pla                 ; Pull A back from stack
```

**Add two 8-bit numbers:**
```asm
    clc                 ; ALWAYS clear carry first!
    lda first_num
    adc second_num
    sta result
```

**Subtract:**
```asm
    sec                 ; ALWAYS set carry first!
    lda first_num
    sbc second_num
    sta result
```

---

# Exercises

1. **Trace `read_direction`** - What happens when you push UP+LEFT?

2. **Find the HP calculation** - How does `update_hp_bar` know how many segments to draw?

3. **Modify a color** - Change `gold` to another value and see what happens

4. **Slow down the game** - Change `input_speed` from 5 to 20

5. **Use Altirra's debugger** - Set a breakpoint at `attack_monster` and watch the registers

---

*You learned BASIC. Now you understand the machine.*
