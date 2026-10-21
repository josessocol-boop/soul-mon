#!/usr/bin/env python3
"""Report colour and outline drift in a Soul-Mon sprite sheet. READ-ONLY: writes nothing but the report.

Usage:
  python3 sprite_consistency_check.py SHEET.png [--frame 64] [--rows 4,6,2,2,4,2,3]
                                      [--names idle,run,jump,dash,attack,hitstun,ko]

Defaults match fighter.gd ANIMS (7 rows, 4/6/2/2/4/2/3 frames). Frames are read left to right,
top to bottom; each row uses the cells that its count says are filled.

What it checks:
  1. Palette drift: colours used by a frame that are not in the sheet's shared palette
     (colours present in at least --palette-min of the sheet's opaque pixels).
  2. Outline drift: the outline colour (most common colour on the silhouette edge) and the
     outline thickness (median run of outline-coloured pixels from the edge inward) per frame,
     compared with the sheet's most common values.
"""
import argparse
from collections import Counter

import numpy as np
from PIL import Image

DEFAULT_ROWS = [4, 6, 2, 2, 4, 2, 3]
DEFAULT_NAMES = ["idle", "run", "jump", "dash", "attack", "hitstun", "ko"]


def cells(sheet: np.ndarray, frame: int, rows: list[int]):
    """Yield (row_index, frame_index, cell_rgba) for every filled cell."""
    for r, count in enumerate(rows):
        for c in range(count):
            y, x = r * frame, c * frame
            if y + frame > sheet.shape[0] or x + frame > sheet.shape[1]:
                raise SystemExit(f"Sheet too small for row {r} frame {c} at {frame}px cells.")
            yield r, c, sheet[y:y + frame, x:x + frame]


def edge_mask(alpha: np.ndarray) -> np.ndarray:
    """Opaque pixels that touch a transparent pixel (4-neighbour)."""
    op = alpha > 0
    padded = np.pad(op, 1, constant_values=False)
    inside = padded[1:-1, 1:-1]
    touches_clear = (~padded[:-2, 1:-1]) | (~padded[2:, 1:-1]) | (~padded[1:-1, :-2]) | (~padded[1:-1, 2:])
    return inside & touches_clear


def outline_stats(cell: np.ndarray, outline_rgb: tuple | None):
    """Return (outline_rgb, median_thickness) for one frame. outline_rgb None = take the frame's own."""
    alpha = cell[..., 3]
    edge = edge_mask(alpha)
    if not edge.any():
        return None, 0
    rgb = cell[..., :3]
    colours = Counter(map(tuple, rgb[edge]))
    own = colours.most_common(1)[0][0]
    ref = outline_rgb or own
    # Thickness: along each row, count outline-coloured pixels from each silhouette edge inward.
    runs = []
    for y in range(cell.shape[0]):
        xs = np.flatnonzero(alpha[y] > 0)
        if xs.size == 0:
            continue
        for start, step in ((xs[0], 1), (xs[-1], -1)):
            n, x = 0, start
            while 0 <= x < cell.shape[1] and alpha[y, x] > 0 and tuple(rgb[y, x]) == ref:
                n += 1
                x += step
            if n:
                runs.append(n)
    thick = int(np.median(runs)) if runs else 0
    return own, thick


def hex_(rgb) -> str:
    return "#%02x%02x%02x" % tuple(int(v) for v in rgb)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("--frame", type=int, default=64)
    ap.add_argument("--rows", default=",".join(map(str, DEFAULT_ROWS)))
    ap.add_argument("--names", default=",".join(DEFAULT_NAMES))
    ap.add_argument("--palette-min", type=float, default=0.002,
                    help="fraction of opaque pixels a colour needs to count as shared palette (default 0.2%%)")
    args = ap.parse_args()

    rows = [int(v) for v in args.rows.split(",")]
    names = args.names.split(",")
    if len(names) != len(rows):
        raise SystemExit("--names must have one entry per row")
    sheet = np.array(Image.open(args.sheet).convert("RGBA"))

    # Pass 1: shared palette and the sheet's common outline colour / thickness.
    all_cells = list(cells(sheet, args.frame, rows))
    total_px = Counter()
    for _, _, cell in all_cells:
        op = cell[cell[..., 3] > 0][:, :3]
        total_px.update(map(tuple, op))
    opaque_total = sum(total_px.values())
    palette = {c for c, n in total_px.items() if n / opaque_total >= args.palette_min}

    stats = []
    for r, c, cell in all_cells:
        stats.append((r, c, cell, *outline_stats(cell, None)))
    sheet_outline = Counter(o for _, _, _, o, _ in stats if o is not None).most_common(1)
    ref_outline = sheet_outline[0][0] if sheet_outline else None
    sheet_thick = Counter(t for _, _, _, _, t in stats if t > 0).most_common(1)
    ref_thick = sheet_thick[0][0] if sheet_thick else 0

    print(f"Sheet: {args.sheet}  ({sheet.shape[1]}x{sheet.shape[0]}, {args.frame}px cells, {len(all_cells)} frames)")
    print(f"Shared palette: {len(palette)} colours (>= {args.palette_min:.1%} of opaque pixels)")
    print(f"Reference outline: {hex_(ref_outline) if ref_outline else 'none'}, thickness {ref_thick}px\n")

    problems = 0
    for r, c, cell, outline, thick in stats:
        colours = set(map(tuple, cell[cell[..., 3] > 0][:, :3]))
        stray = colours - palette
        notes = []
        if stray:
            notes.append(f"{len(stray)} off-palette colour(s), e.g. {', '.join(hex_(s) for s in list(stray)[:3])}")
        if outline and ref_outline and outline != ref_outline:
            notes.append(f"outline {hex_(outline)} (sheet uses {hex_(ref_outline)})")
        if thick and ref_thick and abs(thick - ref_thick) >= 1:
            notes.append(f"outline {thick}px (sheet uses {ref_thick}px)")
        if notes:
            problems += 1
            print(f"  {names[r]:<8} frame {c}: " + "; ".join(notes))
    if problems == 0:
        print("No palette or outline drift found.")
    else:
        print(f"\n{problems} frame(s) differ from the sheet's shared palette or outline.")


if __name__ == "__main__":
    main()
