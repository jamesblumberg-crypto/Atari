#!/bin/bash

echo "Cleaning old build..."
rm -f main.xex

echo "Assembling with MADS..."
mads main.asm -o:main.xex

if [ $? -eq 0 ]; then
    echo "Build succeeded."

    echo "Launching Altirra..."
    ALTIRRA_PATH="/c/Tools/Altirra/altirra64.exe"   # CHANGE THIS

    if [ -f "$ALTIRRA_PATH" ]; then
        "$ALTIRRA_PATH" main.xex &
    else
        echo "❌ Altirra not found at: $ALTIRRA_PATH"
    fi
else
    echo "❌ Build failed. Not launching emulator."
fi
