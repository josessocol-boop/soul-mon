"""Uploaded pixel sheet (JPEG, 384x448, white background) -> PNG with transparent background and one palette.
No resampling: every pixel keeps its place; only the background is removed and colours are mapped to the palette.
Usage: clean_uploaded_sheet.py in.jpg out.png [colors=16] [--strict]
--strict: remove every pure-white pixel (holes and gaps too); default removes only white connected to the border."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def kmeans(px, k, iters=25, seed=0):
    rng = np.random.default_rng(seed)
    sub = px[rng.choice(len(px), min(len(px), 150000), replace=False)]
    order = np.argsort(sub.sum(1))
    cent = sub[order[np.linspace(0, len(sub) - 1, k).astype(int)]].copy()
    for _ in range(iters):
        lab = ((sub[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            if (lab == i).any():
                cent[i] = sub[lab == i].mean(0)
    return cent

def convert(src, dst, colors=16, strict=False):
    img = np.array(Image.open(src).convert("RGB")).astype(float)
    mn, mx = img.min(-1), img.max(-1)
    if strict:
        # every pure-white region is background, also holes and gaps inside the figure
        white = (mn >= 236) & (mx - mn <= 14)
        lab, n = ndimage.label(white)
        sizes = np.bincount(lab.ravel())
        small = sizes <= 12                  # eye glints and other tiny highlights stay as art
        small[0] = False
        bg = white & ~small[lab]
    else:
        near_white = (mn >= 225) & (mx - mn <= 30)
        lab, _ = ndimage.label(near_white)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        bg = np.isin(lab, list(border))
    opaque = ~bg
    cent = kmeans(img[opaque], colors)
    idx = ((img[..., None, :] - cent[None, None]) ** 2).sum(-1).argmin(-1)
    # drop light palette colours left as a halo next to the background
    light = cent.mean(1) > 232
    halo = opaque & light[idx] & ndimage.binary_dilation(bg, iterations=1)
    opaque = opaque & ~halo
    out = np.zeros(img.shape[:2] + (4,), np.uint8)
    out[..., :3] = cent[idx].round().astype(np.uint8)
    out[..., 3] = opaque * 255
    Image.fromarray(out, "RGBA").save(dst)
    used = len(np.unique(out[opaque][:, :3], axis=0))
    print(dst, "size", img.shape[1], img.shape[0], "colours used", used, "opaque", int(opaque.sum()))

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 16,
            strict="--strict" in sys.argv)
