## Quick context

This repository contains small Atari 8‑bit assembly programs assembled with MADS (Mads Assembler). It's a demo-style project (EdVenture) that manipulates the ANTIC display list, custom character sets, and produces XEX binaries that can be run in an Atari emulator.

Key files
- `main.asm`, `main4.asm` — demo programs. Look for the top-of-file comment: "Assemble in MADS: mads -l -t main.asm".
- `hello.asm` — minimal XEX example showing the XEX header and `.INIT` usage.
- `main.xex` — prebuilt binary artifact.

## Build & run (explicit)

- Preferred: use the included VS Code task "Build with MADS" (workspace task). It runs MADS and writes an `.xex` next to the source file.
- Manual (PowerShell example):

```powershell
mads -l -t .\main.asm
# or to control output location name:
mads .\main.asm -o:.\main.xex
```

- After assembling, load the produced `.xex` into your Atari emulator (Atari800, Altirra, etc.). The repo does not include an emulator; use your usual tooling.

## What to look for in the code (important patterns)

- Memory layout and ORG: sources use `org $2000` — code is placed at $2000 by convention here. Be careful when changing `org`.
- Display list and registers: constants like SDLSTL, CHBAS and several COLOR_* symbols are used to program ANTIC/GTIA. See `main.asm` / `main4.asm` — look for instructions that write the display list pointer to SDLSTL and move the charset address bytes into CHBAS (search for `mwa` / `mva` usages).
- Character set & screen: `charset = $3c00` and `screen = $4000` are hardcoded; the program copies `chars` and `scene` data into those addresses via `mva` loops. If you change sizes/labels, update the copy loops accordingly.
- Low-level MADS idioms: this codebase uses MADS pseudo-op macros like `mwa`/`mva` and familiar 6502 assembly constructs. Errors from MADS are surfaced in the listing produced with `-l`.
- XEX header pattern: `hello.asm` shows how to create a minimal XEX with `.byte $FF, $FF` and `.INIT start` — useful as a template for small tests.

## Conventions & small decisions to keep

- Keep listing (`-l`) enabled while editing to get helpful labels and diagnostics. The top comments in `main.asm` explicitly recommend `mads -l -t main.asm`.
- Use explicit little-endian splits for addresses when writing display list pointers (`<label, >label`).
- Data sections tend to be raw `.byte` lists (e.g., `chars`, `scene`) — change these in-place rather than introducing complex data loaders.

## Guidance for an AI coding agent

- When asked to modify visuals, inspect `chars` (custom characters) and `scene` (screen buffer) first — small changes here produce visible results.
- If changing memory layout or adding buffers, update copy loops and verify there are no overlaps with the XEX header or other fixed addresses.
- Always assemble with listing enabled and include the listing output when reporting errors. Use the VS Code task or `mads -l -t`.
- When suggesting fixes, point to specific lines/labels (for example: "update charset bytes under label `chars`" or "change `org $2000` to another address and adjust `screen` accordingly").

## No-op / out-of-scope notes

- The project does not include unit tests or CI; changes that require emulator screenshots or interactive testing should be verified locally by the developer.
- There are no external services or network integrations in this repo — only the MADS toolchain and an Atari emulator are required.

## Where to run/verify

- Build: use the workspace task "Build with MADS" or `mads -l -t <file>` in PowerShell.
- Verify: load the produced `.xex` into your emulator and run.

If any part of this doc is unclear or you want more examples (e.g., step-by-step on editing the display list or adding a new character), tell me which area and I will expand with concrete edit examples.
