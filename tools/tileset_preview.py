#!/usr/bin/env python3
"""Colour-coded contact sheet for a generated tileset PNG, on the terminal.

Renders each 8x8 tile of a Gen 2 tileset sheet as a small swatch of
hue-classified characters so the profile can be hand-authored from colour:
roofs vs grass vs water are unmistakable in the art.  Sheet rows are 16
tiles wide, matching `tilesPerRow`.

    python3 tools/tileset_preview.py assets/generated/tilesets/johto.png

Colour keys:
    #  red/orange (roofs, brick)      ~  blue (water, sky)
    .  green (grass, trees)           g  yellow-green (leaves)
    =  cyan (water edges, ice)        +  yellow (sand, signs, highlights)
    /  grey/brown (stone, dirt)       @  very dark (shadows, void)
    _  near-white (snow, white walls)

With `--shade`, the same sheet at NATIVE RESOLUTION as four shade
characters instead of hue classes.  That is the mode for the Gen 2 cache
sheets, which are grayscale (the four DMG tones 255/170/85/0): structure
-- roofs, walls, trees -- survives the loss of colour, the hue classifier
does not.  `--names` appends the tileset header comment lines describing
the tile rows; the header offsets tell which tile ids sit in which row.
"""

import subprocess
import sys

RAMPS = (
    # (predicate, char)
    (lambda r, g, b: r < 30 and g < 30 and b < 30, "@"),
    (lambda r, g, b: r > 235 and g > 235 and b > 235, "_"),
    (lambda r, g, b: b > 150 and b > r + 30 and b > g + 30, "~"),
    (lambda r, g, b: g > 110 and b > 110 and g > r + 20, "="),
    (lambda r, g, b: r > 110 and r > b + 60 and g > 60 and g < 170, "#"),
    (lambda r, g, b: g > 90 and g > r - 10 and g > b + 20 and r > 120, "g"),
    (lambda r, g, b: g > 80 and g >= r and g >= b + 15, "."),
    (lambda r, g, b: r > 150 and g > 120 and b < 90, "+"),
    (lambda r, g, b: r > 150 and g > 150 and b < 110, "+"),
    (lambda r, g, b: True, "/"),
)

# The four DMG shades, brightest to darkest.
SHADES = ("#", "o", "+", ".")


def classify(r, g, b):
    for pred, ch in RAMPS:
        if pred(r, g, b):
            return ch
    return "/"


def shade(r, g, b):
    grey = (r + g + b) // 3
    for level, c in ((235, "#"), (170, "o"), (85, "+"), (0, ".")):
        if grey >= level:
            return c
    return "."


def read_pixels(path):
    out = subprocess.run(
        ["convert", path, "txt:-"], capture_output=True, text=True, check=True)
    pixels = {}
    w = h = 0
    for line in out.stdout.splitlines()[1:]:
        if not line.strip():
            continue
        pos, rest = line.split(":", 1)
        x, y = (int(v) for v in pos.split(","))
        vals = [int(v) for v in rest.split("(", 1)[1].split(")")[0].split(",")]
        # grey(alpha) / srgb(r,g,b[,a]) / rgba(...)
        r = g = b = vals[0]
        if len(vals) >= 3:
            r, g, b = vals[0], vals[1], vals[2]
        pixels[(x, y)] = (r, g, b)
        w = max(w, x + 1)
        h = max(h, y + 1)
    return pixels, w, h


def show_hue(pixels, w, h):
    tw = w // 8
    th = h // 8
    for trow in range(th):
        print("--- sheet row %d (tiles %d, %d)" % (trow, trow * tw, (trow + 1) * tw - 1))
        for sy in range(2):
            parts = []
            for tcol in range(tw):
                tile = trow * tw + tcol
                cell = []
                for cx in range(2):
                    x0 = (tcol * 8) + cx * 4
                    y0 = (trow * 8) + sy * 4
                    cs = [pixels[(x, y)] for x in range(x0, x0 + 4)
                          for y in range(y0, y0 + 4)]
                    ar = sum(p[0] for p in cs) // len(cs)
                    ag = sum(p[1] for p in cs) // len(cs)
                    ab = sum(p[2] for p in cs) // len(cs)
                    cell.append(classify(ar, ag, ab))
                parts.append("%02d:%s%s" % (tile, cell[0], cell[1]))
            print("  " + "  ".join(parts))
        print()


def show_shade(pixels, w, h):
    tw = w // 8
    th = h // 8
    for trow in range(th):
        print("--- sheet row %d (tiles %d, %d)" % (trow, trow * tw, (trow + 1) * tw - 1))
        for sy in range(8):
            parts = []
            for tcol in range(tw):
                tile = trow * tw + tcol
                parts.append("%02d %s" % (tile, "".join(
                    shade(*pixels[(tcol * 8 + cx, trow * 8 + sy)])
                    for cx in range(8))))
            print("  " + "  ".join(parts))
        print()


def main(path, shade_mode):
    pixels, w, h = read_pixels(path)
    if shade_mode:
        show_shade(pixels, w, h)
    else:
        show_hue(pixels, w, h)


if __name__ == "__main__":
    args = sys.argv[1:]
    shade_mode = "--shade" in args
    args = [a for a in args if a != "--shade"]
    main(args[0], shade_mode)