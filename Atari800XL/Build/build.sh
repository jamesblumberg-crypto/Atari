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

GUARD_HEX="$(awk '{ gsub(/\r/, "", $3); if ($3=="MAIN_BANK_END_GUARD") { print $2; exit } }' main_build.lab || true)"
if [ -z "${GUARD_HEX}" ]; then
    echo "Build guard label MAIN_BANK_END_GUARD not found in main_build.lab"
    exit 1
fi
if (( 16#$GUARD_HEX >= 16#C000 )); then
    echo "Build failed: MAIN_BANK_END_GUARD assembled at \$$GUARD_HEX (must stay below \$C000)."
    exit 1
fi

echo "Build succeeded."

echo "Launching emulator..."
open -a "Atari800MacX" main.xex