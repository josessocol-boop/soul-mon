# Recolour every edge pixel (opaque, touching transparent) to the darkest colour of the sheet's palette. Usage: in.png out.png
import sys, numpy as np
from collections import Counter
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = np.array(Image.open(src).convert('RGBA'))
op = im[..., 3] > 0
cols = Counter(map(tuple, im[..., :3][op])); total = int(op.sum())
pal = [c for c, n in cols.items() if n / total >= 0.002]
dark = min(pal, key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
# edge mask per 64px frame cell is not needed: transparency is the boundary of the whole sheet's silhouettes
pad = np.pad(op, 1, constant_values=False)
edge = op & (~pad[:-2, 1:-1] | ~pad[2:, 1:-1] | ~pad[1:-1, :-2] | ~pad[1:-1, 2:])
im[edge, :3] = dark
print('outline', '#%02x%02x%02x' % dark, 'edge px', int(edge.sum()))
Image.fromarray(im, 'RGBA').save(dst)
