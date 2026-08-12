# Endgame Storyboard

*Documented 2026-08-12 – concepts locked in for the Atari 800XL dungeon crawler*

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

### KayBee Toys Door
- Special locked door on Floor 4 (or a fixed room).
- Display text “KayBee Toys” (status line or custom door tiles).
- Only the completed Magic Key opens it.

---

## Phase 2 – Rescue

1. Open KayBee Toys door.
2. Small special room / cutscene screen.
3. New **wife PMG** appears (same size as player PMG, long hair version).
4. Approach → set rescue flag.
5. Transition: player + wife appear **outside** the dungeon.

---

## Phase 3 – Outdoor Tree Maze

- Switch to outdoor charset (already have matching PNGs in Gfx).
- Trees form a maze (fixed map or light procedural).
- New monster type: **Alligator** (new ribbon / tiles).
- Exactly five alligators placed in the maze.

---

## Phase 4 – Beach Ending

- After clearing the alligators (or reaching the end of the maze).
- Transition to beach + water graphics (new outdoor tiles or full-screen composition).
- Final image: player PMG + wife PMG standing together looking at the water.
- Simple “You made it” or pure visual + music change is enough.

---

## Implementation Priority

1. Key drop logic + Magic Key flag + KayBee Toys door check  
2. Amulet → powered bow (missile color)  
3. Wife PMG graphics + placement  
4. Outdoor charset switch + tree maze map  
5. Alligator monster  
6. Beach / water ending screen  

---

## Notes

- All of this builds on existing systems (gems, keys, boss death, well, outdoor charset, PMG framework).
- Keep memory and cycle budget tight – prefer flags and simple tile swaps over complex new engines.
