"""Reference sheet (878x1024, 6 cols x 7 rows, white background) -> crisp game sheet (384x448).
 1. removes the background: near-white pixels connected to the image border
 2. one shared palette (k-means on the opaque pixels) so similar shades merge
 3. each frame is sampled on a 32x32 pixel grid by majority vote (no blending), then shown 2x nearest,
    the same native size as tools/generate_pixel_art.py (32px art, 2x in game)
 Rows follow ANIMS: idle 4, run 6, jump 2, dash 2, attack 4, hitstun 2, ko 3.
Usage: python3 import_reference_sheet.py source.png out.png [colors=16]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

FRAMES = [4, 6, 2, 2, 4, 2, 3]
COLS, ROWS = 6, 7
NATIVE = 32       # native frame size (shown 2x)
INSET = 6         # keeps grid lines out of each frame

def background_mask(a):
    mn, mx = a.min(-1), a.max(-1)
    near_white = (mn >= 222) & (mx - mn <= 34)
    lab, _ = ndimage.label(near_white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))

def kmeans(px, k, iters=25, seed=0):
    rng = np.random.default_rng(seed)
    sub = px[rng.choice(len(px), min(len(px), 120000), replace=False)]
    order = np.argsort(sub.sum(1))
    cent = sub[order[np.linspace(0, len(sub) - 1, k).astype(int)]].copy()
    for _ in range(iters):
        lab = ((sub[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            if (lab == i).any():
                cent[i] = sub[lab == i].mean(0)
    return cent

def convert(src, dst, colors=16):
    img = np.array(Image.open(src).convert("RGB")).astype(float)
    H, W, _ = img.shape
    opaque = ~background_mask(img)
    cent = kmeans(img[opaque], colors)
    lab = ((img[..., None, :] - cent[None, None]) ** 2).sum(-1).argmin(-1)   # palette index per source pixel
    cw, ch = W / COLS, H / ROWS
    sheet = np.zeros((ROWS * NATIVE * 2, COLS * NATIVE * 2, 4), np.uint8)
    for row, n in enumerate(FRAMES):
        for col in range(n):
            x0, y0 = int(round(col * cw)) + INSET, int(round(row * ch)) + INSET
            x1, y1 = int(round((col + 1) * cw)) - INSET, int(round((row + 1) * ch)) - INSET
            L = lab[y0:y1, x0:x1]; O = opaque[y0:y1, x0:x1]
            bh, bw = L.shape[0] / NATIVE, L.shape[1] / NATIVE
            small = np.zeros((NATIVE, NATIVE, 4), np.uint8)
            for j in range(NATIVE):
                for i in range(NATIVE):
                    ys, ye = int(j * bh), max(int((j + 1) * bh), int(j * bh) + 1)
                    xs, xe = int(i * bw), max(int((i + 1) * bw), int(i * bw) + 1)
                    o = O[ys:ye, xs:xe].ravel(); l = L[ys:ye, xs:xe].ravel()
                    if o.mean() < 0.5:
                        continue
                    vals = l[o]
                    m = np.bincount(vals, minlength=colors).argmax()
                    small[j, i, :3] = cent[m].round().astype(np.uint8)
                    small[j, i, 3] = 255
            big = small.repeat(2, axis=0).repeat(2, axis=1)
            y, x = row * NATIVE * 2, col * NATIVE * 2
            sheet[y:y + NATIVE * 2, x:x + NATIVE * 2] = big
    Image.fromarray(sheet, "RGBA").save(dst)
    print("wrote", dst, "colours", colors)

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 16)
