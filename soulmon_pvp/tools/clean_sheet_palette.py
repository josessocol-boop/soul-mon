"""Cleans a character sprite sheet (needs Pillow + numpy): removes green chroma-key fringe on the outline and
reduces the sheet to a small flat palette, quantised per colour class (body shades / reds / whites / darks) so small
details such as red eyes and white teeth keep their colour.
Usage:  python3 tools/clean_sheet_palette.py assets/gengar_sheet.png [out.png]     (overwrites the input if no output given)
Used on gengar_sheet.png on 2026-10-11 (986 green pixels, ~hundreds of near-identical purples -> 14 colours)."""
import sys, colorsys
import numpy as np
from PIL import Image

def kmeans(px, k, iters=25):
    px = px.astype(float)
    order = np.argsort(px.sum(1))
    cent = px[order[np.linspace(0, len(px) - 1, k).astype(int)]].copy()
    for _ in range(iters):
        lab = ((px[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            if (lab == i).any():
                cent[i] = px[lab == i].mean(0)
    return np.round(cent).astype(int), lab

def clean(src, dst, body_k=7, red_k=3, white_k=2, dark_k=2):
    a = np.array(Image.open(src).convert("RGBA")).astype(np.int32)
    H, W, _ = a.shape
    rgb, alpha = a[..., :3], a[..., 3]
    hsv = np.array([[colorsys.rgb_to_hsv(*(rgb[y, x] / 255)) for x in range(W)] for y in range(H)])
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    mn = rgb.min(-1)
    opaque = alpha > 0
    green = opaque & (h > 0.2) & (h < 0.5) & (s > 0.15)
    red = opaque & ~green & ((h < 0.05) | (h > 0.9)) & (s > 0.35) & (rgb[..., 0] > rgb[..., 2] + 30)
    white = opaque & ~green & ~red & (mn > 170) & (s < 0.2)
    dark = opaque & ~green & ~red & ~white & (v < 0.30)
    body = opaque & ~green & ~red & ~white & ~dark
    out = a.copy()
    for mask, k in ((body, body_k), (red, red_k), (white, white_k)):
        if mask.any():
            cent, lab = kmeans(rgb[mask], k)
            out[..., :3][mask] = cent[lab]
    dmask = dark & ~green
    dc, dl = kmeans(rgb[dmask], dark_k)
    out[..., :3][dmask] = dc[dl]
    out[..., :3][green] = dc[dc.sum(1).argmin()]      # the green fringe sits on the outline: make it outline-coloured
    Image.fromarray(out.astype(np.uint8), "RGBA").save(dst)
    print("%s: %d green px removed, %d colours" % (dst, int(green.sum()), len(set(map(tuple, out[opaque][:, :3])))))

if __name__ == "__main__":
    clean(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1])
