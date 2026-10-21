"""Turns a character sheet drawn on a GREEN background (any size, 6 columns x 7 rows of equal cells) into a game sheet
(384x448 = 64 px frames, ANIMS row order, transparent background). Needs Pillow + numpy.
 - keys out the green and removes the green cast from edge pixels
 - area-averages each cell down to 64x64 and reduces everything to a small flat palette (k-means)
 - rows are idle 4, run 6, jump 2, dash 2, attack 4, hitstun 2, ko 3 (extra frames in a row, such as a dropped item, are ignored)
Usage:  python3 tools/import_green_sheet.py source.png assets/<fighter>_sheet.png [colors=22]
Used for tinkaton_sheet.png on 2026-10-11."""
import sys
import numpy as np
from PIL import Image

FRAMES = [4, 6, 2, 2, 4, 2, 3]
COLS, ROWS = 6, 7

def convert(src, dst, colors=22):
    a = np.array(Image.open(src).convert("RGB")).astype(float)
    H, W, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = (np.clip((120 - (g - np.maximum(r, b))) / 60, 0, 1) > 0.5).astype(float)
    a[..., 1] = np.minimum(a[..., 1], np.maximum(r, b) + 8)           # despill
    pm = a * alpha[..., None]
    cw, ch = W / COLS, H / ROWS
    sheet = np.zeros((ROWS * 64, COLS * 64, 4), np.uint8)
    for row, n in enumerate(FRAMES):
        for col in range(n):
            box = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
            chans = [np.array(Image.fromarray(pm[..., c].astype(np.float32), "F").resize((64, 64), Image.BOX, box=box)) for c in range(3)]
            al = np.array(Image.fromarray(alpha.astype(np.float32), "F").resize((64, 64), Image.BOX, box=box))
            rgb = np.stack(chans, -1) / np.maximum(al[..., None], 1e-3)
            m = al >= 0.5
            blk = np.zeros((64, 64, 4), np.uint8)
            blk[..., :3] = np.where(m[..., None], np.clip(rgb, 0, 255), 0)
            blk[..., 3] = np.where(m, 255, 0)
            sheet[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64] = blk
    op = sheet[..., 3] > 0
    px = sheet[op][:, :3].astype(float)
    order = np.argsort(px.sum(1))
    cent = px[order[np.linspace(0, len(px) - 1, colors).astype(int)]].copy()
    for _ in range(30):
        lab = ((px[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(colors):
            if (lab == i).any():
                cent[i] = px[lab == i].mean(0)
    sheet[..., :3][op] = np.round(cent[lab]).astype(np.uint8)
    Image.fromarray(sheet, "RGBA").save(dst)
    print("wrote", dst, sheet.shape[1], "x", sheet.shape[0])

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 22)
