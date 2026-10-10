import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pixel_effects import *
from PIL import Image
rows = [strip("slash", 46, 22, PAL["gold"]), strip("burst", 64, 48, PAL["gold"]), strip("beam", 110, 14, PAL["water"]),
        strip("column", 32, 60, PAL["fire"]), strip("xslash", 52, 42, PAL["crimson"]), strip("flurry", 50, 34, PAL["steel"]),
        strip("streak", 60, 36, PAL["shadow"]), strip("spin", 64, 32, PAL["pink"]), coin_strip(), shuriken_strip(), wave_strip(),
        arrow_strip(), orb_strip(), trap_strip("leaf"), trap_strip("poison")]
H = sum(r.height + 4 for r in rows); W = max(r.width for r in rows)
im = Image.new('RGBA', (W, H), (60, 66, 92, 255)); y = 0
for r in rows:
    im.alpha_composite(r, (0, y)); y += r.height + 4
im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(sys.argv[1])
ic = Image.new('RGBA', (80, 24), (60, 66, 92, 255))
for i, n in enumerate(("burn", "slow", "poison")): ic.alpha_composite(icon(n), (i * 26, 0))
ic.resize((320, 96), Image.NEAREST).save(sys.argv[2])
