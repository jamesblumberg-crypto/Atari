#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Cleaning old build..."
rm -f main.xex main_build.lab

MADS_CMD="${MADS_CMD:-/Users/jimblumberg/Tools/Atari/MADS/mads}"

if [ ! -x "$MADS_CMD" ]; then
    echo "MADS assembler not found or not executable at:"
    echo "  $MADS_CMD"
    exit 127
fi

echo "Assembling with MADS (${MADS_CMD})..."
"$MADS_CMD" main.asm -o:main.xex -t:main_build.lab

# mads -t lab format: bank<TAB>address<TAB>name
GUARD_HEX="$(awk -F'\t' '{ gsub(/\r/, "", $3); if ($3=="MAIN_BANK_END_GUARD") { print $2; exit } }' main_build.lab || true)"
if [ -z "${GUARD_HEX}" ]; then
    echo "Build guard label MAIN_BANK_END_GUARD not found in main_build.lab"
    exit 1
fi
if (( 16#$GUARD_HEX >= 16#C000 )); then
    echo "Build failed: MAIN_BANK_END_GUARD assembled at \$$GUARD_HEX (must stay below \$C000)."
    exit 1
fi

# Code chained from dlist ($9800) must not reach room_positions ($AE10).
# If it does, the next XEX data segment overwrites live code and Atari800MacX
# dies right after the map appears (game loop jumps into garbage).
ROOM_POS_HEX="$(awk -F'\t' '{ gsub(/\r/, "", $3); if ($3=="ROOM_POSITIONS") { print $2; exit } }' main_build.lab || true)"
# Tail of input.asm — last routine in the $9800 code chain before data orgs.
CODE9800_END_HEX="$(awk -F'\t' '{ gsub(/\r/, "", $3); if ($3=="READ_KEYBOARD") { print $2; exit } }' main_build.lab || true)"
if [ -n "${ROOM_POS_HEX}" ] && [ -n "${CODE9800_END_HEX}" ]; then
    if (( 16#$CODE9800_END_HEX >= 16#$ROOM_POS_HEX )); then
        echo "Build failed: code at \$$CODE9800_END_HEX collides with ROOM_POSITIONS at \$$ROOM_POS_HEX."
        echo "  Shrink map_gen/input or move data — this crash shows up after the map draws."
        exit 1
    fi
fi

# Detect overlapping XEX load segments + RAM collisions with screen/map.
python3 - "$SCRIPT_DIR/main.xex" <<'PY' || exit 1
import sys
data = open(sys.argv[1], "rb").read()
i, segs = 0, []
while i < len(data):
    if i + 1 < len(data) and data[i] == 0xFF and data[i + 1] == 0xFF:
        i += 2
        continue
    if i + 4 > len(data):
        break
    start = data[i] | (data[i + 1] << 8)
    end = data[i + 2] | (data[i + 3] << 8)
    i += 4 + (end - start + 1)
    segs.append((start, end))
for a, (s1, e1) in enumerate(segs):
    for s2, e2 in segs[a + 1 :]:
        if s1 <= e2 and s2 <= e1:
            print(
                f"Build failed: XEX segments overlap "
                f"${s1:04X}-${e1:04X} and ${s2:04X}-${e2:04X}."
            )
            sys.exit(1)
# $6B80 RAM code must stay below screen ($7000)
for s, e in segs:
    if s < 0x7000 <= e:
        print(f"Build failed: segment ${s:04X}-${e:04X} invades screen at $7000.")
        sys.exit(1)
    if s < 0xAE10 <= e and s >= 0x9800:
        print(f"Build failed: segment ${s:04X}-${e:04X} invades room data at $AE10.")
        sys.exit(1)
print("XEX segments: " + ", ".join(f"${s:04X}-${e:04X}" for s, e in segs))
PY

echo "Build succeeded."

echo "Launching emulator..."
open -a "Atari800MacX" main.xex