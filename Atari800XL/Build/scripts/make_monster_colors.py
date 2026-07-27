#!/usr/bin/env python3
"""
make_monster_colors.py  -  Generate correctly-packed monster color tables.

The game reads the color table like this:
  * copy_monster_colors copies 3 bytes at file offset (ribbon * 3) into the live
    color table at indices 11,12,13.
  * fix_color, drawing on-screen char code C, reads color_table[C >> 3] and tests
    bit (C & 7).  Monster char codes are 88..103, i.e. table indices 11,12 and
    bits 0..7 -> ribbon chars 0..15.

So the byte the game needs at (ribbon*3 + g) must have, in bit k, the yellow flag
of ribbon char (8*g + k) = PNG file char (32*ribbon + 8*g + k).  A char's flag is
1 (PF3 / yellow) if it contains any palette-index-1 pixel, else 0 (PF2 / blue).

tile_maker.py's --monsters mode produced an overlapping sliding-window layout that
does NOT match this, which scrambles every monster's blue/yellow assignment.
This script writes the layout the game actually reads.

USAGE
  python3 make_monster_colors.py monsters_a.png -o monsters_a_colors.asm --label monsters_a_colors
  python3 make_monster_colors.py monsters_b.png -o monsters_b_colors.asm --label monsters_b_colors
"""
import argparse
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("pip3 install pillow --break-system-packages")


def char_is_yellow(px, c):
    cx, cy = (c % 16) * 4, (c // 16) * 8
    return any(px[x, y] == 1 for y in range(cy, cy + 8) for x in range(cx, cx + 4))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("png")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--label", required=True, help="org label, e.g. monsters_a_colors")
    args = ap.parse_args()

    im = Image.open(args.png)
    if im.mode != "P":
        sys.exit(f"{args.png} must be an indexed PNG (Image > Mode > Indexed)")
    px = im.load()

    lines = [f"\torg {args.label}", ""]
    for R in range(4):
        lines.append(f"\t; ribbon {R} (floor {R + 1}) - 3 bytes, bit k of byte g = "
                     f"yellow-flag of ribbon char 8g+k")
        for g in range(3):
            b = 0
            for k in range(8):
                c = 16 * R + 8 * g + k
                if c < 128 and char_is_yellow(px, c):
                    b |= 1 << k
            lines.append(f"\t.byte %{b:08b}")
        lines.append("")

    with open(args.out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
