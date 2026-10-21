"""Clean a 2x pixel-art sheet (JPEG, 384x448, white background) into a PNG with a tidy, unified palette.
 1. background: white removed (border-connected by default; --strict removes every pure-white region, tiny glints kept)
 2. palette: k-means in CIE Lab on the sheet's opaque pixels; each palette entry is the real pixel closest to its
    centre (not an average), so colours keep their saturation; entries closer than dE 7 are merged
 3. grid: the sheet is 2x native art aligned at (0,0); every 2x2 block takes the majority palette index
    (removes JPEG speckle and the stray pixels it leaves)
 4. output: the 2x2 blocks written back as 2x2 pixels, so the result is still 384x448 and crisp
Usage: palette_sheet.py in.jpg out.png [colors=12] [--strict]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def srgb_to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

def background(img, strict):
    if strict:
        white = (img.min(-1) >= 236) & (img.max(-1) - img.min(-1) <= 14)
        lab, _ = ndimage.label(white)
        small = np.bincount(lab.ravel()) <= 12
        small[0] = False
        return white & ~small[lab]
    mn, mx = img.min(-1), img.max(-1)
    lab, _ = ndimage.label((mn >= 225) & (mx - mn <= 30))
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))

def convert(src, dst, colors=12, strict=False):
    img = np.array(Image.open(src).convert("RGB")).astype(float)
    H, W, _ = img.shape
    opaque = ~background(img, strict)
    lab_px = srgb_to_lab(img)
    sel = lab_px[opaque]
    rng = np.random.default_rng(0)
    sub = sel[rng.choice(len(sel), min(len(sel), 100000), replace=False)]
    cent = sub[np.linspace(0, len(sub) - 1, colors).astype(int)].copy()
    for _ in range(30):
        lab = ((sub[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(colors):
            if (lab == i).any():
                cent[i] = sub[lab == i].mean(0)
    # medoid: the real pixel nearest each centre keeps the true colour
    pal_rgb = []
    for i in range(colors):
        members = sub[((sub[:, None] - cent[None]) ** 2).sum(-1).argmin(1) == i]
        if len(members) == 0:
            continue
        pick = members[((members - cent[i]) ** 2).sum(-1).argmin()]
        pal_rgb.append(pick)
    pal = np.array(pal_rgb)
    # merge near-duplicates (dE < 7)
    keep = []
    for c in pal:
        if all(np.sqrt(((c - k) ** 2).sum()) >= 7 for k in keep):
            keep.append(c)
    pal = np.array(keep)
    # palette back to sRGB for output
    rgb_pal = np.zeros((len(pal), 3))
    # brute inverse by nearest real pixel to each palette Lab (keeps true sRGB colours)
    flat = lab_px[opaque]; flat_rgb = img[opaque]
    for i, c in enumerate(pal):
        rgb_pal[i] = flat_rgb[((flat - c) ** 2).sum(-1).argmin()]
    idx = ((lab_px[..., None, :] - pal[None, None]) ** 2).sum(-1).argmin(-1)
    # 2x2 majority grid
    h, w = H // 2, W // 2
    m4 = opaque[:h * 2, :w * 2].reshape(h, 2, w, 2).transpose(0, 2, 1, 3).reshape(h, w, 4)
    i4 = idx[:h * 2, :w * 2].reshape(h, 2, w, 2).transpose(0, 2, 1, 3).reshape(h, w, 4)
    out_small = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            if m4[y, x].sum() < 2:
                continue
            v = i4[y, x][m4[y, x]]
            m = np.bincount(v, minlength=len(pal)).argmax()
            out_small[y, x, :3] = rgb_pal[m].round().astype(np.uint8)
            out_small[y, x, 3] = 255
    if "--drop-edge-white" in sys.argv:
        # white pixels on the silhouette edge are leftover background halo: make them transparent
        op = out_small[..., 3] > 0
        pad = np.pad(op, 1, constant_values=False)
        edge = op & (~pad[:-2, 1:-1] | ~pad[2:, 1:-1] | ~pad[1:-1, :-2] | ~pad[1:-1, 2:])
        whiteish = out_small[..., :3].min(-1) >= 200
        out_small[edge & whiteish, 3] = 0
    out = out_small.repeat(2, axis=0).repeat(2, axis=1)
    Image.fromarray(out, "RGBA").save(dst)
    print(dst, "palette", len(pal), "colours", ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in rgb_pal])

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    convert(args[0], args[1], int(args[2]) if len(args) > 2 else 12, strict="--strict" in sys.argv)
