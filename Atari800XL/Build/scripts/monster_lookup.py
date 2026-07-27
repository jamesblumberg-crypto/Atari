#!/usr/bin/env python3
"""
monster_lookup.py  -  Which chars/bytes make a given monster on a given floor?

Given a monster TYPE (0-7) and a FLOOR (1+), this prints the exact character
numbers and source-line ranges in monsters_a.asm / monsters_b.asm that the game
uses to draw that monster, and renders the on-screen character pair as an
enlarged PNG so you can see the art and the bytes together.

HOW THE GAME MAPS IT (traced from the source)
  * Map stores a monster as one tile byte, value 44..51  (type = tile - 44).
  * blit_tile draws every tile T as two side-by-side chars:
        left  char code = 2*T      = 88 + 2*type
        right char code = 2*T + 1  = 89 + 2*type
  * copy_monsters copies a 32-char "ribbon" from monsters_*.asm into char slot 88.
        ribbon R is picked by depth:  R = min(floor - 1, 3)
        source offset = R * 32 chars (R * 256 bytes)
  * So the file chars that draw the monster are:
        left  = R*32 + 2*type
        right = R*32 + 2*type + 1
  * charset A and charset B ($7800/$7c00) flip every frame for color; the same
    char numbers apply to both monsters_a.asm and monsters_b.asm.

USAGE
  python3 monster_lookup.py --type 0 --floor 1
  python3 monster_lookup.py --type 3 --floor 3 --dir /path/to/Build
  python3 monster_lookup.py --type 7 --ribbon 3 --scale 40 -o out.png

Requires Pillow only for the --render image (text report works without it).
"""

import argparse
import os
import re
import sys

# Ed's 5-color palette -> 2-bit codes (index order in the indexed PNG)
BLACK = (0, 0, 0)          # 00  COLBAK
WHITE = (228, 228, 228)    # 01  COLPF0
RED = (156, 36, 28)        # 10  COLPF1
BLUE = (28, 72, 144)       # 11  COLPF2  (high bit clear)
YELLOW = (252, 196, 28)    # 11  COLPF3  (high bit set)

CHAR_RE = re.compile(r";\s*char\s+(\d+)")
BYTE_RE = re.compile(r"\.byte\s+%([01]{8})")


def parse_color_bytes(path):
    """Flat list of every .byte %xxxxxxxx value in a *_colors.asm file, in order."""
    out = []
    if not os.path.exists(path):
        return out
    for ln in open(path):
        m = re.search(r"\.byte\s+%([01]{8})", ln)
        if m:
            out.append(int(m.group(1), 2))
    return out


def pf3_is_yellow(file_char, color_bytes):
    """Reproduce fix_color: does this char's '11' show as yellow (PF3) or blue (PF2)?
    ribbon = file_char // 32; charset slot = 88 + (file_char % 32);
    color byte = the (slot>>3)-11'th of the 3 bytes copied for that ribbon;
    bit tested = slot & 7."""
    R = file_char // 32
    slot = 88 + (file_char % 32)
    idx = (slot >> 3) - 11          # 0,1,2
    bit = slot & 7
    triple = color_bytes[3 * R:3 * R + 3]
    if idx < 0 or idx >= len(triple):
        return False                # no data -> default blue
    return bool((triple[idx] >> bit) & 1)


def parse_charset(path):
    """Return dict: char_number -> {'bytes': [8 ints], 'bits': [8 str], 'lines': (start,end)}"""
    chars = {}
    with open(path) as f:
        lines = f.readlines()
    i = 0
    while i < len(lines):
        m = CHAR_RE.search(lines[i])
        if m:
            n = int(m.group(1))
            bits, byts, ln = [], [], []
            j = i + 1
            while j < len(lines) and len(bits) < 8:
                bm = BYTE_RE.search(lines[j])
                if bm:
                    bits.append(bm.group(1))
                    byts.append(int(bm.group(1), 2))
                    ln.append(j + 1)          # 1-based line number
                elif CHAR_RE.search(lines[j]):
                    break
                j += 1
            if len(bits) == 8:
                chars[n] = {"bytes": byts, "bits": bits, "lines": (ln[0], ln[-1])}
            i = j
        else:
            i += 1
    return chars


def decode_row(bits):
    """8-bit string -> list of 4 two-bit codes, left to right."""
    return [bits[k:k + 2] for k in range(0, 8, 2)]


def print_char(title, path, n, ch):
    if ch is None:
        print(f"  {title}: char {n} NOT FOUND in {os.path.basename(path)}")
        return
    s, e = ch["lines"]
    print(f"  {title}: char {n}  ({os.path.basename(path)} lines {s}-{e})")
    for row, (bits, b) in enumerate(zip(ch["bits"], ch["bytes"])):
        pairs = " ".join(decode_row(bits))
        syms = "".join({"00": ".", "01": "W", "10": "R", "11": "B"}[p]
                       for p in decode_row(bits))
        print(f"      .byte %{bits}   ${b:02X}   {pairs}   {syms}")


def render(a_left, a_right, b_left, b_right, scale, out,
           left_n, right_n, a_colors, b_colors):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("\n(Pillow not installed; skipping image. "
              "pip3 install pillow --break-system-packages)")
        return

    def px(code, is_yellow_char):
        if code == "00":
            return BLACK
        if code == "01":
            return WHITE
        if code == "10":
            return RED
        return YELLOW if is_yellow_char else BLUE   # 11 = PF2/PF3

    def cell_img(left, right, colors):
        ly = pf3_is_yellow(left_n, colors)
        ry = pf3_is_yellow(right_n, colors)
        img = Image.new("RGB", (8, 8))
        for row in range(8):
            lcodes = decode_row(left["bits"][row])
            rcodes = decode_row(right["bits"][row])
            for x, c in enumerate(lcodes):
                img.putpixel((x, row), px(c, ly))
            for x, c in enumerate(rcodes):
                img.putpixel((x + 4, row), px(c, ry))
        return img.resize((8 * scale, 8 * scale), Image.NEAREST)

    def fnt(sz, b=False):
        p = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono%s.ttf" % ("-Bold" if b else "")
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            return ImageFont.load_default()

    frames = [("charset A  (monsters_a)", a_left, a_right, a_colors)]
    if b_left and b_right:
        frames.append(("charset B  (monsters_b)", b_left, b_right, b_colors))

    pad, gap, gridcol = 20, 60, (70, 72, 80)
    cw = 8 * scale
    W = pad * 2 + len(frames) * cw + (len(frames) - 1) * gap
    H = pad + 34 + cw + pad
    canvas = Image.new("RGB", (W, H), (24, 26, 32))
    d = ImageDraw.Draw(canvas)
    FB = fnt(24, True)
    x = pad
    for title, l, r, colors in frames:
        d.text((x, pad), title, font=FB, fill=(230, 230, 230))
        cimg = cell_img(l, r, colors)
        cy = pad + 34
        canvas.paste(cimg, (x, cy))
        # grid + center divider between the two chars
        for gx in range(0, 9):
            lw = 3 if gx == 4 else 1
            col = (255, 120, 120) if gx == 4 else gridcol
            d.line([x + gx * scale, cy, x + gx * scale, cy + cw], fill=col, width=lw)
        for gy in range(0, 9):
            d.line([x, cy + gy * scale, x + cw, cy + gy * scale], fill=gridcol, width=1)
        x += cw + gap
    canvas.save(out)
    print(f"\nRendered -> {out}")


def render_sheet(chars, colors, R, floor, scale, out):
    """Contact sheet of the 8 spawnable monsters (tiles 44-51) for ribbon R."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("(Pillow not installed; cannot render sheet.)")
        return

    def px(code, is_yellow):
        if code == "00":
            return BLACK
        if code == "01":
            return WHITE
        if code == "10":
            return RED
        return YELLOW if is_yellow else BLUE

    def cell(l, r):
        ly, ry = pf3_is_yellow(l, colors), pf3_is_yellow(r, colors)
        img = Image.new("RGB", (8, 8))
        for row in range(8):
            lc = decode_row(chars[l]["bits"][row])
            rc = decode_row(chars[r]["bits"][row])
            for x, c in enumerate(lc):
                img.putpixel((x, row), px(c, ly))
            for x, c in enumerate(rc):
                img.putpixel((x + 4, row), px(c, ry))
        return img.resize((8 * scale, 8 * scale), Image.NEAREST)

    def fnt(sz, b=False):
        p = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono%s.ttf" % ("-Bold" if b else "")
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            return ImageFont.load_default()

    base = R * 32
    cw = 8 * scale
    pad, gapx, cols = 16, 24, 4
    colw = cw + gapx
    rowh = cw + 74
    W = pad * 2 + cols * colw
    H = 94 + 2 * rowh
    cv = Image.new("RGB", (W, H), (24, 26, 32))
    d = ImageDraw.Draw(cv)
    d.text((pad, 12), f"Floor {floor}  ->  ribbon {R}   (tiles 44-51, file chars {base}-{base+15})",
           font=fnt(24, True), fill=(240, 240, 240))
    d.text((pad, 46), "real PF3-resolved colors;  L/R tag = each half's 11 = Blue or Yellow",
           font=fnt(17), fill=(170, 170, 170))
    for t in range(8):
        l, r = base + 2 * t, base + 2 * t + 1
        if l not in chars or r not in chars:
            continue
        cx = pad + (t % 4) * colw
        cy = 90 + (t // 4) * rowh
        d.text((cx, cy - 24), f"type {t}  tile {44 + t}", font=fnt(17, True), fill=(230, 230, 230))
        d.text((cx, cy - 6), f"chars {l} & {r}", font=fnt(15), fill=(160, 160, 160))
        cv.paste(cell(l, r), (cx, cy + 14))
        yl, yr = pf3_is_yellow(l, colors), pf3_is_yellow(r, colors)
        d.text((cx, cy + 14 + cw + 3), f"L:{'Y' if yl else 'B'}  R:{'Y' if yr else 'B'}",
               font=fnt(15), fill=(200, 200, 120))
    cv.save(out)
    print(f"Rendered floor-{floor} sheet -> {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--type", type=int, help="monster type 0-7")
    ap.add_argument("--char", type=int, dest="char",
                    help="pull any char pair by number: renders char N (left) and N+1 (right)")
    ap.add_argument("--sheet", action="store_true",
                    help="render all 8 spawnable monsters for the given --floor/--ribbon")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--floor", type=int, default=1, help="dungeon floor (1+); ribbon = min(floor-1,3)")
    g.add_argument("--ribbon", type=int, help="ribbon 0-3 directly (overrides floor)")
    ap.add_argument("--dir", default=".", help="folder with monsters_a.asm / monsters_b.asm")
    ap.add_argument("--scale", type=int, default=40, help="pixels per art-pixel in the render")
    ap.add_argument("-o", "--out", default="monster_render.png")
    ap.add_argument("--no-render", action="store_true")
    args = ap.parse_args()

    if not args.sheet and args.char is None and args.type is None:
        sys.exit("give --sheet, --type 0-7, or --char N")

    a_path = os.path.join(args.dir, "monsters_a.asm")
    b_path = os.path.join(args.dir, "monsters_b.asm")
    a = parse_charset(a_path) if os.path.exists(a_path) else {}
    b = parse_charset(b_path) if os.path.exists(b_path) else {}
    a_colors = parse_color_bytes(os.path.join(args.dir, "monsters_a_colors.asm"))
    b_colors = parse_color_bytes(os.path.join(args.dir, "monsters_b_colors.asm"))

    if args.sheet:
        R = args.ribbon if args.ribbon is not None else min(args.floor - 1, 3)
        if not (0 <= R <= 3):
            sys.exit("ribbon must be 0-3")
        out = args.out if args.out != "monster_render.png" else f"sheet_floor{args.floor}.png"
        render_sheet(a, a_colors, R, args.floor, args.scale, out)
        for t in range(8):
            l = R * 32 + 2 * t
            yl = "Y" if pf3_is_yellow(l, a_colors) else "B"
            yr = "Y" if pf3_is_yellow(l + 1, a_colors) else "B"
            print(f"  type {t}  tile {44+t}  chars {l},{l+1}   L:{yl} R:{yr}")
        return

    if args.char is not None:
        left = args.char
        right = left + 1
        R = left // 32
        slot = 88 + (left % 32)
        print(f"Char pair {left} & {right}   (ribbon {R}, charset slots {slot} & {slot+1}, "
              f"map tile {slot // 2})")
    else:
        if not (0 <= args.type <= 7):
            sys.exit("monster type must be 0-7")
        R = args.ribbon if args.ribbon is not None else min(args.floor - 1, 3)
        if not (0 <= R <= 3):
            sys.exit("ribbon must be 0-3")
        left = R * 32 + 2 * args.type
        right = left + 1
        tile = 44 + args.type
        scr_l, scr_r = 2 * tile, 2 * tile + 1
        print(f"Monster type {args.type}  |  floor {args.floor}  ->  ribbon {R}")
        print(f"Map tile byte      : {tile}  (${tile:02X})")
        print(f"On-screen char codes: left {scr_l}, right {scr_r}  (charset slot 88 + 2*type)")
        print(f"Source chars in file: left {left}, right {right}   (ribbon*32 + 2*type)")

    # PF3 color resolution for these two chars
    la, ra = pf3_is_yellow(left, a_colors), pf3_is_yellow(right, a_colors)
    print(f"PF3 color (charset A): left char = {'YELLOW' if la else 'BLUE'}, "
          f"right char = {'YELLOW' if ra else 'BLUE'}")
    print()

    print("monsters_a.asm (charset A frame):")
    print_char("LEFT ", a_path, left, a.get(left))
    print_char("RIGHT", a_path, right, a.get(right))
    if b:
        print("\nmonsters_b.asm (charset B frame):")
        print_char("LEFT ", b_path, left, b.get(left))
        print_char("RIGHT", b_path, right, b.get(right))

    print("\nlegend:  . = black   W = white   R = red   B = blue/yellow(PF3)")

    if not args.no_render and a.get(left) and a.get(right):
        render(a.get(left), a.get(right), b.get(left), b.get(right), args.scale, args.out,
               left, right, a_colors, b_colors)


if __name__ == "__main__":
    main()
