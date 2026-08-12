# Endgame Storyboard

*Documented 2026-08-12 – concepts locked in for the Atari 800XL dungeon crawler*
*Expanded same day with KayBee door, wife PMG, and alligator layout details*

## Overview

After the random dungeon floors, the game shifts into a narrative endgame:

1. Collect the five gems → complete the amulet → power the bow.
2. Collect the five keys (one from Floor 4 boss, four from earlier floors) → form the Magic Key.
3. Open the special “KayBee Toys” locked door.
4. Rescue the wife (new PMG with long hair).
5. Transition outside into a tree maze.
6. Fight five alligators.
7. Reach the beach / water final screen.

---

## Phase 1 – Dungeon Climax (Floors 1-4)

### Gems / Amulet
- Already implemented: five colored gems in HUD (`has_gems` bitfield).
- Collecting all five (`GEM_ALL`) powers the bow.
- Visual: change missile color (and optionally damage/speed).

### Keys
- HUD already has icons for white, blue, red, gold, black keys.
- Floors 1-3: monsters drop the four non-blue keys (rare or guaranteed one each).
- Floor 4 boss death already spawns the well + **blue key**.
- Once all five keys are collected they combine into a single **Magic Key** (flag + HUD icon change).

### KayBee Toys Door (expanded)

**Placement**
- Fixed special room on Floor 4 (not random). Ideal after the boss room so the player has the blue key.
- Can be a short corridor or a small chamber whose only exit is the KayBee door.

**Visual treatment**
- Use existing door tiles (`MAP_DOOR` / doorway set) but tint or frame them differently if possible (color register or high-bit).
- Preferred: a 2-tile-wide or 3-tile-wide “storefront” door using custom charset glyphs if space allows, or simply the normal door with status-line text.
- When the player faces the door, the status line shows:

  `KAYBEE TOYS`

  (using the existing `status_chars.asm` letter mapping – K,A,Y,B,E,T,O,Y,S are all present).

**Logic**
- Door starts locked.
- Check for the Magic Key flag (all five individual keys collected and merged).
- If Magic Key present → open (play open sound, swap to open doorway tiles, set a “door_opened” flag).
- If missing any key → status line can flash `NEED MAGIC KEY` or just refuse with a short beep.
- Opening the door is the trigger that loads the rescue room / cutscene.

**Nostalgia note**
- KayBee Toys was the classic mall toy store of the 80s/90s. Perfect tone for this game – a little mundane magic in the middle of the dungeon.

---

## Phase 2 – Rescue (wife PMG expanded)

### Source art
- `Gfx/characters_missy.png` already exists – use this (or a cleaned version of it) as the visual reference for the long-hair wife.
- Style match: same height and width as the current player PMG in `pmgdata.asm` (8 bytes tall, multi-color via PCOLR0–3).

### PMG data layout (suggestion)

Current player uses four color planes:

```
PCOLR0 (Brown)  – hair / boots
PCOLR1 (Peach)  – skin
PCOLR2 (Blue)   – tunic / pants
PCOLR3 (Black)  – outline / details
```

Wife variant:
- Same structure, but longer hair (extra brown/black pixels in the top 2–3 rows that hang past the shoulders).
- Slightly different tunic color if desired (or keep blue for visual unity).
- Keep the same 8-row height so positioning math stays identical.

Add a second table:

```
wife_pmg
    ; same 32-byte layout as pmgdata but with long hair
```

### Runtime options (pick one that fits memory)

1. **Player 1** – Use the second player (P1) for the wife. Enable both during the outdoor sequence. Cleanest for side-by-side walking.
2. **Graphic swap** – During the short rescue cutscene only, temporarily point the player PMG to the wife data, then restore. Cheapest memory, less flexible outdoors.
3. **Missile / limited** – Possible but more constrained; prefer option 1 if PMG memory allows.

### Sequence
1. Open KayBee Toys door.
2. Enter small special room (or full-screen cutscene).
3. Wife PMG is already standing in the room.
4. Player walks up → set `wife_rescued` flag.
5. Short “together” pose (both PMGs side-by-side).
6. Fade / hard transition: both appear outside the dungeon entrance with outdoor charset active.

---

## Phase 3 – Outdoor Tree Maze + Alligator (expanded)

### Charset switch
- Already have `charset_outdoor_a/b.png` and matching `.asm` files.
- On exit from dungeon, point CHBASE to the outdoor set and rebuild the map with tree tiles forming the maze.

### Alligator ribbon layout

Current system (from `monster_lookup.py`):
- 4 ribbons (0–3), each 32 chars (16 left/right pairs).
- Map tiles 44–51 = monster types 0–7.
- Ribbon selected by floor: `R = min(floor-1, 3)`.

You currently have 3 ribbons populated and the monster PNG has blank spaces – perfect.

**Recommendation**
- Put the alligator in **ribbon 3** (the last one) as **type 0** (or any free type).
- That gives source chars:
  - left  = 3*32 + 0*2 = 96
  - right = 97
- Outdoor map can force ribbon 3 (or a dedicated outdoor ribbon) so only alligators appear.

**Art notes for the PNG (blank slots)**
- Alligator is low and horizontal – fill the 8×8 pair with a long body.
- Suggested silhouette (left + right char):
  - Head on the left half: open mouth with a couple of white/red teeth, eye.
  - Body + tail on the right half: low legs, textured back.
- Color usage (5-color limit):
  - Black outline
  - White teeth / eye highlight
  - Red inside mouth or tongue
  - Blue or yellow for the body (yellow reads as “muddy green” under many Atari palettes; blue works for a cooler gator).
- Keep the feet on the bottom 1–2 rows so it sits on the ground properly.

**Gameplay**
- Exactly five alligators placed in the tree maze (fixed positions or light random within safe open cells).
- Behavior can be simple: slow horizontal patrol or charge when player is on the same row.
- Killing all five (or reaching the far side of the maze) triggers the beach transition.

---

## Phase 4 – Beach Ending

- After the alligators are cleared (or the maze exit is reached).
- Switch to beach/water composition using outdoor tiles (or a dedicated final screen).
- Player PMG + wife PMG standing together facing the water.
- Status line or simple text: anything from silence to “YOU MADE IT” is fine.
- Music change if you have a second tune; otherwise just hold the image.

---

## Implementation Priority

1. Key drop logic + Magic Key flag + KayBee Toys door check + status text  
2. Amulet → powered bow (missile color)  
3. Wife PMG data (from characters_missy.png) + placement in rescue room  
4. Outdoor charset switch + tree maze map  
5. Alligator art in blank monster slots (ribbon 3) + 5 placements  
6. Beach / water ending screen  

---

## Notes

- All of this builds on existing systems (gems, keys, boss death, well, outdoor charset, PMG framework, status_chars).
- Keep memory and cycle budget tight – prefer flags and simple tile swaps over complex new engines.
- `characters_missy.png` and the blank spaces in the monster PNGs are already sitting in Gfx ready to be used.
