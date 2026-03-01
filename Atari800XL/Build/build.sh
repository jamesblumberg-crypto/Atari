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
"$MADS_CMD" main.asm -o:main.xex

echo "Build succeeded."

echo "Launching Altirra..."
ALTIRRA_PATH="${ALTIRRA_PATH:-/c/Tools/Altirra/altirra64.exe}"

if [ -f "$ALTIRRA_PATH" ]; then
    "$ALTIRRA_PATH" main.xex &
else
    echo "Altirra not found at: $ALTIRRA_PATH"
fi
