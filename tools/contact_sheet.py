#!/usr/bin/env python3
"""Tile studio/tour screenshots into labeled contact sheets.

The reviewer reads one sheet per map instead of a dozen full-res PNGs:
every shot becomes a thumbnail with its filename burned in, N shots per
sheet, several sheets per run. Flags:
  --dir DIR        shot directory (default /tmp/gold-tour)
  --out DIR        sheet output directory (default <dir>/sheets)
  --per-sheet N    thumbnails per sheet (default 12, 4 columns)
  --width W        thumbnail width in px (default 460; keeps texels legible)
  --glob PAT       only include files matching PAT (default: *.png, no sheets)

Usage:
  python3 tools/contact_sheet.py --dir /tmp/gold-tour
"""
from __future__ import annotations

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw

try:
    from tools.stamp import stamp_version  # noqa: F401  (repo convention)
except Exception:  # noqa: BLE001 - optional
    def stamp_version(im):
        return im


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="/tmp/gold-tour")
    ap.add_argument("--out", default=None)
    ap.add_argument("--per-sheet", type=int, default=12)
    ap.add_argument("--width", type=int, default=460)
    ap.add_argument("--glob", default=None)
    args = ap.parse_args()

    out_dir = args.out or os.path.join(args.dir, "sheets")
    os.makedirs(out_dir, exist_ok=True)

    names = sorted(f for f in os.listdir(args.dir)
                   if f.endswith(".png") and "sheet" not in f
                   and (not args.glob or args.glob in f))
    if not names:
        print("no shots in", args.dir)
        return 1

    label_h = 22
    cols = 4
    rows = math.ceil(args.per_sheet / cols)

    made = 0
    for start in range(0, len(names), args.per_sheet):
        batch = names[start:start + args.per_sheet]
        thumbs = []
        th = None
        for name in batch:
            im = Image.open(os.path.join(args.dir, name)).convert("RGB")
            tw = args.width
            tth = int(im.height * tw / im.width)
            thumbs.append((name, im.resize((tw, tth), Image.NEAREST)))
            th = max(th or 0, tth)
        sheet = Image.new("RGB", (cols * args.width,
                                  rows * (th + label_h)), (24, 24, 24))
        draw = ImageDraw.Draw(sheet)
        for i, (name, thumb) in enumerate(thumbs):
            cx = (i % cols) * args.width
            cy = (i // cols) * (th + label_h)
            sheet.paste(thumb, (cx, cy + label_h))
            draw.text((cx + 4, cy + 4), name, fill=(230, 230, 230))
        tag = args.glob or "all"
        out_path = os.path.join(
            out_dir, "sheet_%s_%02d.png" % (tag, start // args.per_sheet))
        sheet.save(out_path)
        made += 1
        print("wrote", out_path, "(%d thumbs)" % len(batch))
    print("%d sheets for %d shots" % (made, len(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
