import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pixel_core import *
from pixel_characters import ROSTER
from PIL import Image
A_ = poses()
cols = [("idle", 0), ("idle", 2), ("run", 1), ("run", 4), ("jump", 0), ("dash", 0), ("attack", 1), ("attack", 2), ("hitstun", 0), ("ko", 0), ("ko", 2)]
ids = list(ROSTER)
W = Image.new('RGBA', (len(cols) * N, len(ids) * N), (70, 80, 104, 255))
for r, i in enumerate(ids):
    for c, (an, k) in enumerate(cols):
        fr = ROSTER[i](A_[an][k])
        if an == 'ko' and k >= 1: fr = seat_lying(fr)
        W.alpha_composite(fr, (c * N, r * N))
W.resize((W.width * 4, W.height * 4), Image.NEAREST).save(sys.argv[1])
