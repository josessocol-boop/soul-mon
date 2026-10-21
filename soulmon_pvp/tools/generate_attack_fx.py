"""Attack effects for the moves that had none: Alakazam, Lucario, Mewtwo (base and awakened) and Toxicroak.

Writes assets/fx/*.png, 4 frames side by side. Frame size is about 0.7 x the move's hit box, because move strips
are drawn at FX_PIXEL (2x) centred on the hit box (core/fighter.gd _update_visuals). The shapes come from
pixel_effects.py; Reflect, Gravity Pull and Amnesia Blink have their own frames here.
Run from the project root:  python3 tools/generate_attack_fx.py   (needs Pillow)"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pixel_effects import PAL, slash, streak, burst, beam, spin, xslash, column

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FX = os.path.join(ROOT, "assets", "fx")

PSY = ((120, 40, 110), (236, 96, 170), (255, 186, 226), (255, 246, 150))   # Alakazam: pink rings, yellow core
MEWTWO = ((58, 44, 92), (150, 120, 200), (208, 190, 240), (250, 246, 255)) # lilac, as the Mewtwo Psycho Cut
AURA = ((18, 36, 84), (56, 120, 210), (140, 206, 255), (240, 250, 255))    # Lucario blue aura
STEEL = PAL["steel"]
WATER = PAL["water"]
VENOM = PAL["venom"]
PINK = PAL["pink"]
SPARK = (255, 250, 230)

def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def put(px, W, H, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = tuple(col) + (255,)

def paste_strip(frames):
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for k, f in enumerate(frames):
        out.paste(f, (k * w, 0))
    return out

# ---- custom frames -------------------------------------------------------------------------
def reflect_frame(w, h, k, nf):
    """A psychic barrier across the hit box: a few shimmering vertical lines that slide, with sparkles."""
    img = new(w, h); px = img.load()
    for x in range(2, w - 2, 9):
        off = (k * 3 + x) % h
        for y in range(h):
            if (y + off) % 6 < 4:
                put(px, w, h, x, y, PSY[2] if (y + off) % 12 < 6 else PSY[1])
                put(px, w, h, x + 1, y, PSY[1])
    for s in range(6):
        sx = (s * 97 + k * 31) % max(1, w - 4) + 2
        sy = (s * 53 + k * 17) % max(1, h - 4) + 2
        put(px, w, h, sx, sy, SPARK)
        put(px, w, h, sx + 1, sy, SPARK)
    return img

def gravity_frame(w, h, k, nf):
    """Concentric rings shrinking toward the centre (the target is pulled in), each frame one step tighter."""
    img = new(w, h); px = img.load()
    cx, cy = w / 2.0, h / 2.0
    maxr = min(w, h) / 2.0
    for ring_i in range(3):
        r = maxr * (1.0 - ((k + ring_i * 0.33) % nf) / nf)
        if r < 2:
            continue
        for a in range(0, 360, 3):
            t = math.radians(a)
            col = PSY[2] if ring_i == 0 else PSY[1]
            put(px, w, h, cx + r * math.cos(t) * (w / maxr / 2.0 if maxr else 1), cy + r * math.sin(t), col)
    put(px, w, h, cx, cy, PSY[3]); put(px, w, h, cx + 1, cy, PSY[3])
    return img

def blink_frame(w, h, k, nf):
    """Afterimages: three fading copies of a tapered body trailing behind the teleporting core."""
    img = new(w, h); px = img.load()
    head = (k + 1) * w / (nf + 1)
    for trail in range(3):
        cx = head - trail * w * 0.24
        col = MEWTWO[2] if trail == 0 else (MEWTWO[1] if trail == 1 else MEWTWO[0])
        half = (h * 0.42) * (1.0 - trail * 0.25)
        for y in range(int(h / 2 - half), int(h / 2 + half) + 1):
            depth = abs(y - h / 2) / max(1.0, half)          # thinner toward the top and bottom
            span = int(7 * (1.0 - depth * 0.6))
            for x in range(int(cx - span), int(cx + span)):
                put(px, w, h, x, y, col)
    return img

# ---- the moves -----------------------------------------------------------------------------
def frames(fn, w, h):
    return [fn(w, h, k, 4) for k in range(4)]

SPECS = {
    # file: (builder, frame width, frame height, extra)
    "alakazam_special2.png":        ("custom", reflect_frame, 630, 49),       # Reflect: 900x70 hit box
    "alakazam_ultimate.png":        ("shape", beam, 630, 49, PSY),            # Mind Blast: 900x70 hit box
    "down_alakazam_basic.png":      ("shape", streak, 42, 31, PSY),           # Teleport Strike: 60x44
    "down_alakazam_special2.png":   ("shape", spin, 63, 35, PSY),             # Kinesis: 90x50
    "lucario_special2.png":         ("shape", burst, 48, 40, AURA),           # Swords Dance: buff aura, no hit box
    "down_lucario_basic.png":       ("shape", streak, 49, 18, STEEL),         # Low Kick: 70x26
    "down_lucario_special2.png":    ("shape", streak, 56, 35, WATER),         # Extreme Speed: 80x50
    "mewtwo_special2.png":          ("shape", xslash, 49, 35, MEWTWO),        # Disable: 70x50
    "down_mewtwo_special1.png":     ("custom", gravity_frame, 63, 42),        # Gravity Pull: 90x60
    "down_mewtwo_special2.png":     ("shape", column, 39, 45, MEWTWO),        # Psystrike dive: 56x64 (down=True below)
    "mewtwo_awakened_special2.png": ("custom", blink_frame, 48, 40),          # Amnesia Blink: teleport, no damage
    "down_mewtwo_awakened_special2.png": ("shape", column, 45, 49, PINK),     # Meteor Dive: 64x70
    "toxicroak_special2.png":       ("shape", slash, 42, 28, VENOM),          # Sucker Punch: 60x40
    "down_toxicroak_basic.png":     ("shape", streak, 49, 15, VENOM),         # Sludge Sweep: 70x22
    "down_toxicroak_special2.png":  ("shape", streak, 84, 35, VENOM),         # Venom Drag: 120x50
}

def build(name, spec):
    kind = spec[0]
    if kind == "custom":
        _, fn, w, h = spec
        return paste_strip(frames(fn, w, h))
    _, fn, w, h, pal = spec
    if fn is column:          # the dives fall downward
        return paste_strip([column(w, h, pal, k, 4, down=True) for k in range(4)])
    return paste_strip([fn(w, h, pal, k, 4) for k in range(4)])

if __name__ == "__main__":
    os.makedirs(FX, exist_ok=True)
    for name, spec in SPECS.items():
        img = build(name, spec)
        img.save(os.path.join(FX, name))
        print("wrote", name, img.size)
