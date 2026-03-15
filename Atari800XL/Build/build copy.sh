#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Cleaning old build..."
rm -f main.xex

MADS_CMD="${MADS_CMD:-}"
if [ -z "$MADS_CMD" ]; then
    if command -v mads >/dev/null 2>&1; then
        MADS_CMD="mads"
    elif command -v mads.exe >/dev/null 2>&1; then
        MADS_CMD="mads.exe"
    else
        echo "MADS assembler not found in PATH. Set MADS_CMD or add mads/mads.exe to PATH."
        exit 127
    fi
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

echo "Launching Altirra..."
ALTIRRA_PATH="${ALTIRRA_PATH:-/c/Tools/Altirra/altirra64.exe}"

if [ -f "$ALTIRRA_PATH" ]; then
    "$ALTIRRA_PATH" main.xex &
else
    echo "Altirra not found at: $ALTIRRA_PATH"
fi
