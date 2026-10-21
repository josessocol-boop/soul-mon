"""Pokemon-themed move effects for Alakazam, Mewtwo, Lucario and Toxicroak (needs Pillow).

Writes assets/fx/*.png in the style of pixel_effects.py: hard-edged colour bands, no anti-aliasing.
Strips are frames side by side (4 frames; the Future Sight eye is one frame; Toxic Spikes is a 4-frame strip).
  proj_psybeam.png       Alakazam Psybeam: pink psychic rings with sparkles
  proj_psywave.png       Alakazam Psywave: a bouncing psychic ring with a yellow core
  trap_future_sight.png  Alakazam Future Sight: a glowing psychic eye on the floor (one frame)
  proj_mewtwo_ball.png   Mewtwo Shadow Ball: lilac shadow orb inside a psychic aura ring
  mewtwo_basic.png       Mewtwo Psycho Cut: purple slash with psychic sparkles
  proj_mega_psystorm.png Mega Mewtwo Y ultimate: large psychic orb with orbiting stars
  proj_aura_sphere.png   Lucario Aura Sphere: blue aura orb with spikes and pulse
  proj_max_aura.png      Lucario Max Aura: large aura orb with pulse rings
  lucario_basic.png      Lucario Bone Rush: a bone that sweeps through the hit
  proj_sludge.png        Toxicroak Sludge Bomb: sludge blob with bubbles
  toxicroak_basic.png    Toxicroak Poison Jab: venom slash with poison droplets
  trap_toxic_spikes.png  Toxicroak Toxic Spikes: poison spikes with bubbles
The three basic strips (mewtwo_basic, lucario_basic, toxicroak_basic) are sized to about 0.7 x their hit box,
because move strips draw at FX_PIXEL (2x): that gives the same ~1.4x of the hit box as the existing basics
(gengar_basic, greninja_basic). Each is a 4-frame strip, so the file width is 4 x the frame width.
Run from the project root:  python3 tools/generate_fighter_fx.py"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pixel_effects import PAL, new, strip, slash, disc, trap_strip

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FX = os.path.join(ROOT, "assets", "fx")
os.makedirs(FX, exist_ok=True)

PSY = ((120, 40, 110), (236, 96, 170), (255, 186, 226), (255, 246, 150))       # pink rings, yellow core
MEWTWO = ((58, 44, 92), (150, 120, 200), (208, 190, 240), (250, 246, 255))     # lilac shadow orb
AURA = ((18, 36, 84), (56, 120, 210), (140, 206, 255), (240, 250, 255))        # blue aura
BONE = ((110, 104, 112), (226, 220, 206), (250, 248, 240))                      # dark rim, bone, glint
TOXIC = ((60, 20, 96), (150, 72, 210), (232, 162, 255), (255, 236, 255))       # venom purple (= PAL venom)
GREEN = (120, 220, 90)
SPARK = (255, 250, 230)

def paste_strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        out.paste(f, (k * w, 0))
    return out

def put(px, W, H, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = col + (255,)

def sparkle(px, W, H, x, y, col=SPARK):
    """A four-point star: centre plus the four neighbours (the classic psychic twinkle)."""
    put(px, W, H, x, y, col)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        put(px, W, H, x + dx, y + dy, col)

def ring(px, W, H, cx, cy, r, col, gap_start, gap_len=60):
    """A circle outline with one gap that turns each frame."""
    for a in range(0, 360, 4):
        if (a - gap_start) % 360 < gap_len:
            continue
        put(px, W, H, cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)), col)

def capsule(px, W, H, p0, p1, r, col):
    (x0, y0), (x1, y1) = p0, p1
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        disc(px, W, H, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r, r, col)

def orb(W, H, pal, k):
    """Round orb with a pulse and a dark swirl (same recipe as pixel_effects.orb_strip, any size)."""
    img = new(W, H); px = img.load()
    pulse = (0, 0.5, 1, 0.5)[k % 4]
    cx, cy = (W - 1) / 2, (H - 1) / 2
    r = W / 2 - 0.6
    disc(px, W, H, cx, cy, r + pulse * .4, r + pulse * .4, pal[0])
    disc(px, W, H, cx, cy, r - 1.2 + pulse * .4, r - 1.2 + pulse * .4, pal[1])
    disc(px, W, H, cx - 1, cy - 1, (r - 1.2) / 2.2, (r - 1.2) / 2.2, pal[2])
    a0 = k * math.pi / 2
    for i in range(6):
        rr = (1 + i * 0.6) * W / 14
        put_ok = 0 <= cx + rr * math.cos(a0 + i * .8) < W and 0 <= cy + rr * math.sin(a0 + i * .8) < H
        if put_ok and px[int(round(cx + rr * math.cos(a0 + i * .8))), int(round(cy + rr * math.sin(a0 + i * .8)))][3]:
            put(px, W, H, cx + rr * math.cos(a0 + i * .8), cy + rr * math.sin(a0 + i * .8), pal[0])
    disc(px, W, H, cx - 2, cy - 2, max(1.0, W / 14), max(1.0, W / 14), pal[3])
    return img

def spikes(img, k, length, col):
    px = img.load(); W, H = img.size
    cx, cy = (W - 1) / 2, (H - 1) / 2
    for j in range(4):
        a = math.radians(k * 22.5 + j * 90)
        for t in range(int(length)):
            rr = W / 2 - 1 + t
            put(px, W, H, cx + rr * math.cos(a), cy + rr * math.sin(a), col)
    return img

# ---------------------------------------------------------------- Alakazam
def psybeam(k):
    W = H = 16; f = new(W, H); px = f.load(); c = 7.5
    ring(px, W, H, c, c, 7, PSY[1], gap_start=k * 90)
    ring(px, W, H, c, c, 5, PSY[2], gap_start=k * 90 + 180)
    disc(px, W, H, c, c, 2, 2, PSY[3])
    a = math.radians(k * 60 + 20)                       # a sparkle that circles the beam
    sparkle(px, W, H, c + 7.5 * math.cos(a), c + 7.5 * math.sin(a))
    return f

def psywave(k):
    W, H = 24, 14; f = new(W, H); px = f.load(); cx, cy = 11.5, 6.5
    for a in range(0, 360, 3):
        t = math.radians(a)
        wob = 0.9 * math.sin(3 * t + k * math.pi / 2)
        put(px, W, H, cx + (10.5 + wob * 0.5) * math.cos(t), cy + (5.5 + wob) * math.sin(t),
            PSY[2] if (a // 30 + k) % 2 else PSY[1])
    disc(px, W, H, cx, cy, 1.6, 1.6, PSY[3])            # yellow core
    sparkle(px, W, H, 2 + (k % 2), 2)
    return f

def future_sight():
    """A glowing psychic eye: almond outline, pink iris, yellow pupil, sparkles at the corners."""
    W, H = 40, 16; f = new(W, H); px = f.load(); cx, cy, a, ha = 19.5, 7.5, 17.0, 6.5
    def inside(x, y, h):
        dx = (x - cx) / a
        return abs(dx) <= 1 and abs(y - cy) <= h * math.sqrt(max(0.0, 1 - dx * dx))
    for y in range(H):
        for x in range(W):
            px_c = x + .5
            if inside(px_c, y + .5, ha):
                col = PSY[0] if not inside(px_c, y + .5, ha - 1.3) else PSY[1]
                px[x, y] = col + (255,)
    disc(px, W, H, cx, cy, 3.6, 3.2, PSY[2])            # iris
    disc(px, W, H, cx, cy, 1.5, 1.5, PSY[3])            # pupil
    sparkle(px, W, H, 3, 3); sparkle(px, W, H, 36, 12)
    return f

# ---------------------------------------------------------------- Mewtwo
def mewtwo_ball(k):
    W = H = 16; img = orb(W, H, MEWTWO, k); px = img.load()
    ring(px, W, H, 7.5, 7.5, 7.6, MEWTWO[2], gap_start=k * 120, gap_len=100)   # psychic aura ring
    sparkle(px, W, H, 13, 2 + (k % 2) * 2)
    return img

def psycho_cut(k):
    W, H = 48, 40                                          # 0.7 x the 66x56 hit box
    img = slash(W, H, PAL["shadow"], k, 4)
    px = img.load()
    for j in range(3):
        sparkle(px, W, H, 11 + j * 12 + k * 2, 9 + j * 9 - k // 2, SPARK)
    return img

def mega_psystorm(k):
    W = H = 32; img = orb(W, H, MEWTWO, k); px = img.load()
    ring(px, W, H, 15.5, 15.5, 13.5, MEWTWO[2], gap_start=0, gap_len=0)
    for j in range(6):                                  # stars orbiting the orb
        a = math.radians(k * 15 + j * 60)
        sparkle(px, W, H, 15.5 + 13.5 * math.cos(a), 15.5 + 13.5 * math.sin(a))
    return img

# ---------------------------------------------------------------- Lucario
def aura_sphere(k):
    img = spikes(orb(20, 20, AURA, k), k, 2, AURA[1]); px = img.load()
    ring(px, 20, 20, 9.5, 9.5, 8.4 + (k % 2) * 0.6, AURA[2], gap_start=k * 90, gap_len=50)   # pulse
    return img

def max_aura(k):
    img = spikes(orb(40, 40, AURA, k), k, 3, AURA[1]); px = img.load()
    ring(px, 40, 40, 19.5, 19.5, 17.5 - (k % 2) * 1.5, AURA[2], gap_start=k * 60, gap_len=90)
    ring(px, 40, 40, 19.5, 19.5, 12.5, AURA[3], gap_start=k * 60 + 180, gap_len=70)
    return img

def bone_rush(k):
    """Dog-bone shaped: a shaft with a knob at each end, swept through three angles, with a short trail."""
    W, H = 44, 30; f = new(W, H); px = f.load()
    c = (W / 2, H / 2)
    a = math.radians(-40 + k * 26)
    d = (math.cos(a), math.sin(a))
    L = 13
    e0 = (c[0] - L * d[0], c[1] - L * d[1]); e1 = (c[0] + L * d[0], c[1] + L * d[1])
    ta = a - math.radians(14)                            # trail: the previous angle, thin
    capsule(px, W, H, (c[0] - L * math.cos(ta), c[1] - L * math.sin(ta)),
            (c[0] + L * math.cos(ta), c[1] + L * math.sin(ta)), 0.6, (170, 176, 200))
    capsule(px, W, H, e0, e1, 2.0, BONE[0])              # outline
    for e in (e0, e1):
        disc(px, W, H, e[0], e[1], 3.0, 3.0, BONE[0])
    capsule(px, W, H, e0, e1, 1.3, BONE[1])              # bone
    for e in (e0, e1):
        disc(px, W, H, e[0], e[1], 2.2, 2.2, BONE[1])
        put(px, W, H, e[0] - 1, e[1] - 1, BONE[2])       # glint
    return f

# ---------------------------------------------------------------- Toxicroak
def sludge(k):
    W = H = 20; f = new(W, H); px = f.load(); cx, cy = 9.5, 9.0
    disc(px, W, H, cx, cy + 1, 8.3, 7.4, TOXIC[0])        # outline
    disc(px, W, H, cx, cy + 1, 7.3, 6.5, TOXIC[1])
    disc(px, W, H, cx - 1.5, cy - 0.5, 3.6, 3.0, TOXIC[2])
    for j, dx in enumerate((-4, 1, 5)):                   # dripping sludge
        for t in range(2 + ((j + k) % 3)):
            put(px, W, H, cx + dx, cy + 7 + t, GREEN)
    for j in range(3):                                    # rising bubbles
        disc(px, W, H, 5 + j * 4, 4 - ((j * 3 + k * 2) % 4), 1.2, 1.2, (190, 250, 150))
    return f

def poison_jab(k):
    W, H = 36, 22                                         # 0.7 x the 52x30 hit box
    img = slash(W, H, PAL["venom"], k, 4); px = img.load()
    for j in range(3):                                    # poison droplets along the slash
        disc(px, W, H, 9 + j * 8 + k, 11 - j * 3 + (k % 2), 1.0, 1.0, GREEN)
    return img

def toxic_spikes():
    base = trap_strip("venom"); px = base.load()
    for k in range(4):                                    # bubbles above each frame's spikes
        for j, bx in enumerate((7, 17, 25)):
            disc(px, 128, 12, k * 32 + bx, 2 + ((j + k) % 2), 1.1, 1.1, (190, 250, 150))
    return base

def generate():
    out = {}
    out["proj_psybeam.png"] = paste_strip([psybeam(k) for k in range(4)])
    out["proj_psywave.png"] = paste_strip([psywave(k) for k in range(4)])
    out["trap_future_sight.png"] = future_sight()
    out["proj_mewtwo_ball.png"] = paste_strip([mewtwo_ball(k) for k in range(4)])
    out["mewtwo_basic.png"] = paste_strip([psycho_cut(k) for k in range(4)])
    out["proj_mega_psystorm.png"] = paste_strip([mega_psystorm(k) for k in range(4)])
    out["proj_aura_sphere.png"] = paste_strip([aura_sphere(k) for k in range(4)])
    out["proj_max_aura.png"] = paste_strip([max_aura(k) for k in range(4)])
    out["lucario_basic.png"] = paste_strip([bone_rush(k) for k in range(4)])
    out["proj_sludge.png"] = paste_strip([sludge(k) for k in range(4)])
    out["toxicroak_basic.png"] = paste_strip([poison_jab(k) for k in range(4)])
    out["trap_toxic_spikes.png"] = toxic_spikes()
    for name, img in out.items():
        img.save(os.path.join(FX, name))
        print("wrote", name, img.size)

if __name__ == "__main__":
    generate()
