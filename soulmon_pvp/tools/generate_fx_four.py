"""Pokemon-themed effect strips for Alakazam, Lucario, Mewtwo and Toxicroak (needs Pillow + numpy).
Every strip keeps the size and frame count the fighter scripts expect, so no script changes are needed,
except the two new files named in NEW_PATHS (Mewtwo ultimate and Mewtwo's awakened special1 down field).
Frames are drawn on the pixel grid with no anti-aliasing, then written as RGBA PNG.
Run from the project root:  python3 tools/generate_fx_four.py"""
import math, os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FX = os.path.join(ROOT, "assets", "fx")

# ------------------------------------------------------------------ palettes
PSY = dict(out=(44, 14, 74), dark=(96, 40, 160), mid=(170, 96, 232), light=(236, 170, 250), core=(255, 246, 255), pink=(246, 118, 214))
AURA = dict(out=(14, 26, 70), dark=(30, 76, 180), mid=(62, 140, 240), light=(150, 214, 255), core=(248, 252, 255), gold=(250, 210, 80))
POISON = dict(out=(40, 10, 60), dark=(104, 38, 150), mid=(164, 76, 206), light=(232, 146, 232), core=(246, 226, 255), green=(150, 230, 110))
BONE = dict(out=(40, 36, 46), dark=(170, 160, 150), mid=(236, 230, 214), light=(255, 252, 240))
SHADOW = dict(out=(22, 10, 40), dark=(60, 26, 110), mid=(110, 60, 170), light=(190, 150, 230), core=(240, 230, 255))

def disc(d, cx, cy, r, col):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

def orb(d, cx, cy, r, p):
    disc(d, cx, cy, r, p["out"])
    disc(d, cx, cy, r - 1, p["dark"])
    disc(d, cx, cy, r - 2, p["mid"])
    disc(d, cx - r * 0.3, cy - r * 0.3, max(1, r * 0.45), p["light"])
    disc(d, cx - r * 0.3, cy - r * 0.3, max(1, r * 0.2), p.get("core", p["light"]))

def arc_ring(d, cx, cy, rx, ry, col, width=1, a0=0, a1=360):
    d.arc([cx - rx, cy - ry, cx + rx, cy + ry], a0, a1, fill=col, width=width)

def streak(d, x0, y0, x1, y1, w0, col):
    """tapered streak from (x0,y0) (thick) to (x1,y1) (thin)"""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    d.polygon([(x0 + nx * w0, y0 + ny * w0), (x1, y1), (x0 - nx * w0, y0 - ny * w0)], fill=col)

def strip(n, w, h, draw_frame):
    out = Image.new("RGBA", (w * n, h), (0, 0, 0, 0))
    for i in range(n):
        f = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(f)
        draw_frame(d, i / n, w, h, i)
        out.paste(f, (i * w, 0))
    return out

# ------------------------------------------------------------------ projectiles
def aura_sphere(p, big=False):
    def f(d, t, w, h, i):
        cx, cy = w / 2, h / 2
        r = (h * 0.30 if not big else h * 0.28) + (1 if i % 2 else 0)
        for k in range(3):                                   # aura halo, spinning ticks
            a = t * 2 * math.pi + k * 2.1
            ring = r + 2 + k * 1.5
            for s in range(6):
                ang = a + s * math.pi / 3
                d.point((cx + math.cos(ang) * ring, cy + math.sin(ang) * ring * 0.9), fill=AURA["light"])
        orb(d, cx, cy, r, AURA)
        if big:
            d.line([cx - r * 0.9, cy, cx + r * 0.9, cy], fill=AURA["gold"])
        if big:
            for s in range(8):                                # spikes around max aura
                ang = s * math.pi / 4 + t * 0.5
                d.polygon([(cx + math.cos(ang) * (r + 1), cy + math.sin(ang) * (r + 1)),
                           (cx + math.cos(ang + 0.2) * (r + 6), cy + math.sin(ang + 0.2) * (r + 6)),
                           (cx + math.cos(ang - 0.2) * (r + 6), cy + math.sin(ang - 0.2) * (r + 6))], fill=AURA["mid"])
    return f

def psybeam(d, t, w, h, i):
    cy = h / 2
    L = w * (0.55 + 0.15 * math.sin(t * 2 * math.pi))
    x1 = w * 0.9
    streak(d, x1 - L, cy, x1, cy, h * 0.42, PSY["dark"])
    streak(d, x1 - L + 2, cy, x1 - 1, cy, h * 0.28, PSY["mid"])
    streak(d, x1 - L + 4, cy, x1 - 2, cy, h * 0.12, PSY["core"])
    for k in range(4):                                       # trailing motes
        d.point((x1 - L * (0.25 + k * 0.2) + i, cy + (k % 2) * 2 - 1), fill=PSY["light"])
    disc(d, x1, cy, 3, PSY["out"]); disc(d, x1, cy, 2, PSY["light"])

def psywave(d, t, w, h, i):
    cy = h / 2
    for k, col in enumerate([PSY["dark"], PSY["pink"], PSY["light"]]):
        off = (k - 1) * 2
        xs = []
        for x in range(0, w):
            y = cy + off + math.sin((x / w) * 2 * math.pi * 1.5 + t * 2 * math.pi) * (h * 0.28)
            xs.append((x, y))
        d.line(xs, fill=col, width=2 if k != 2 else 1)

def psystrike(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    r = h * 0.32 + (1 if i % 2 else 0)
    orb(d, cx, cy, r, SHADOW)
    for s in range(3):
        a = t * 2 * math.pi + s * 2.1
        d.arc([cx - r - 4, cy - r * 0.6 - 3, cx + r + 4, cy + r * 0.6 + 3], math.degrees(a), math.degrees(a) + 90,
              fill=PSY["pink"], width=2)
    for s in range(5):
        ang = t * 2 * math.pi + s * 2 * math.pi / 5
        d.point((cx + math.cos(ang) * (r + 6), cy + math.sin(ang) * (r + 6)), fill=PSY["light"])

def psystorm(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    for k in range(3):
        a = t * 2 * math.pi + k * 2.094
        for s in range(20):
            ang = a + s * 0.25
            rr = 4 + s * 0.6
            d.point((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.8), fill=[PSY["mid"], PSY["pink"], PSY["light"]][k])
    orb(d, cx, cy, 4, PSY)
    for s in range(4):
        ang = s * math.pi / 2 + t * math.pi
        d.point((cx + math.cos(ang) * (w * 0.42), cy + math.sin(ang) * (h * 0.42)), fill=PSY["core"])

def mewtwo_ball(p):
    def f(d, t, w, h, i):
        cx, cy = w / 2, h / 2
        r = h * 0.30 + (1 if i % 2 else 0)
        orb(d, cx, cy, r, p)
        arc_ring(d, cx, cy, r + 2, r * 0.45, p["light"], 1, math.degrees(t * 2 * math.pi), math.degrees(t * 2 * math.pi) + 200)
    return f

def poison_bolt(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    r = h * 0.30 + (1 if i % 2 else 0)
    orb(d, cx, cy, r, POISON)
    for k, (bx, by) in enumerate([(-3, -r - 2), (4, -r - 4), (0, r + 1)]):
        disc(d, cx + bx, cy + by + (i % 2), 1, POISON["light"])

# ------------------------------------------------------------------ melee / down strips
def bone_rush(d, t, w, h, i):
    for k in range(2):
        off = k * 4
        ph = (t * 6 + k) % 2
        x = w * (0.15 + 0.35 * ph) + off
        y = h * 0.5 + (k - 0.5) * 8
        streak(d, x, y, x + w * 0.45, y - h * 0.2, 2, BONE["dark"])
        disc(d, x + w * 0.45, y - h * 0.2, 2, BONE["mid"])
        disc(d, x, y, 2, BONE["mid"])
    for k in range(3):
        arc_ring(d, w * 0.5, h * 0.5, w * 0.45 - k * 3, h * 0.4 - k * 2, AURA["mid"], 1, 200 + k * 10, 320)

def down_bone_sweep(d, t, w, h, i):
    y = h * 0.6 + math.sin(t * math.pi) * -2
    for k in range(3):
        x0 = w * (0.1 + 0.3 * k) + t * w * 0.2
        streak(d, x0, y, x0 + w * 0.3, y - h * 0.25, 2, BONE["dark"])
        disc(d, x0 + w * 0.3, y - h * 0.25, 1, BONE["mid"])
    d.line([0, h - 2, w, h - 2], fill=AURA["light"])

def aura_power(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    for k in range(4):
        a = t * 2 * math.pi + k * math.pi / 2
        rx = w * (0.30 + 0.04 * k)
        ry = h * (0.30 + 0.04 * k)
        arc_ring(d, cx, cy, rx, ry, [AURA["mid"], AURA["light"], AURA["dark"], AURA["light"]][k], 2,
                 math.degrees(a), math.degrees(a) + 110)
    for s in range(6):
        ang = t * 2 * math.pi + s * math.pi / 3
        d.point((cx + math.cos(ang) * w * 0.42, cy + math.sin(ang) * h * 0.42), fill=AURA["core"])

def extreme_speed(d, t, w, h, i):
    for k in range(4):
        y = 4 + k * (h - 8) / 3
        x0 = (t * w * 1.4 + k * 9) % (w + 20) - 20
        streak(d, x0, y, x0 - w * 0.5, y + (1 if k % 2 else -1), 2, AURA["mid"])
        d.line([x0 - 2, y, x0 - w * 0.2, y], fill=AURA["core"])

def psycho_cut(d, t, w, h, i):
    cx, cy = w * 0.45, h * 0.5
    for k in range(2):
        r = w * (0.25 + 0.12 * t) + k * 3
        d.arc([cx - r, cy - r, cx + r, cy + r], -70 + k * 6, 40 + k * 6, fill=PSY["pink"], width=3)
        d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], -66 + k * 6, 36 + k * 6, fill=PSY["light"], width=1)
    d.point((cx + w * 0.3, cy - h * 0.2), fill=PSY["core"])

def psychic_low_sweep(d, t, w, h, i):
    """Ground Wave: a low psychic arc swept along the floor, with a bright leading edge."""
    base = h - 3
    x = w * (0.05 + 0.5 * t)
    for k in range(3):
        r = w * (0.20 + 0.08 * k)
        d.arc([x - r, base - r * 0.6, x + r, base + r * 0.6], 200, 340, fill=PSY["dark"] if k == 0 else PSY["mid"], width=2)
    d.arc([x - w * 0.18, base - w * 0.11, x + w * 0.18, base + w * 0.11], 205, 335, fill=PSY["light"], width=1)
    d.line([0, base + 1, w, base + 1], fill=PSY["pink"])
    d.point((x, base - h * 0.35), fill=PSY["core"])

def psychic_big_wave(d, t, w, h, i):
    """Psychic Wave (awakened Ground Wave): a taller shockwave with a pink crest, rolling along the floor."""
    base = h - 3
    x = w * (0.04 + 0.45 * t)
    for k in range(4):
        r = w * (0.16 + 0.07 * k)
        col = [PSY["out"], PSY["dark"], PSY["mid"], PSY["light"]][k]
        d.arc([x - r, base - r * 0.9, x + r, base + r * 0.5], 200, 340, fill=col, width=3 if k < 2 else 2)
    d.arc([x - w * 0.14, base - w * 0.12, x + w * 0.14, base + w * 0.05], 210, 330, fill=PSY["pink"], width=1)
    d.line([0, base + 1, w, base + 1], fill=PSY["light"])
    d.point((x, base - h * 0.55), fill=PSY["core"])

def disable_lock(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    r = min(w, h) * 0.36
    arc_ring(d, cx, cy, r, r, PSY["mid"], 2, t * 360, t * 360 + 260)
    arc_ring(d, cx, cy, r - 3, r - 3, PSY["light"], 1, t * 360 + 180, t * 360 + 300)
    d.line([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=PSY["dark"], width=2)
    d.line([cx + r * 0.5, cy - r * 0.5, cx - r * 0.5, cy + r * 0.5], fill=PSY["dark"], width=2)

def amnesia_blink(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    s = (1 + math.sin(t * 2 * math.pi)) * 0.5
    r = min(w, h) * (0.18 + 0.12 * s)
    for k in range(4):
        a = k * math.pi / 2
        d.polygon([(cx + math.cos(a) * r * 2, cy + math.sin(a) * r * 2),
                   (cx + math.cos(a + 0.35) * r * 0.5, cy + math.sin(a + 0.35) * r * 0.5),
                   (cx + math.cos(a - 0.35) * r * 0.5, cy + math.sin(a - 0.35) * r * 0.5)], fill=PSY["pink"])
    disc(d, cx, cy, max(2, r * 0.6), PSY["light"])
    disc(d, cx, cy, max(1, r * 0.3), PSY["core"])

def psychic_column(d, t, w, h, i):
    for k in range(3):
        y = (t * h * 1.6 + k * h / 3) % (h + 6) - 6
        arc_ring(d, w / 2, y, w * (0.25 + 0.1 * k), 3, [PSY["dark"], PSY["mid"], PSY["light"]][k], 2, 0, 180)
    d.line([w / 2, 0, w / 2, h], fill=PSY["core"])

def psychic_floor(d, t, w, h, i):
    for k in range(3):
        rx = w * (0.2 + 0.2 * ((t + k / 3) % 1))
        ry = h * (0.3 + 0.3 * ((t + k / 3) % 1))
        arc_ring(d, w / 2, h * 0.9, rx, ry, [PSY["light"], PSY["mid"], PSY["dark"]][k], 2, 180, 360)

def disable_down(d, t, w, h, i):
    cx = w / 2
    for k in range(4):
        y = 3 + k * (h - 6) / 3
        d.line([cx - w * 0.4 + t * 2, y, cx + w * 0.4 - t * 2, y], fill=PSY["mid"] if k % 2 else PSY["light"], width=1)
    arc_ring(d, cx, h / 2, w * 0.36, h * 0.44, PSY["dark"], 2, t * 360, t * 360 + 240)

def psychic_field(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    for k in range(4):
        rx = w * (0.14 + 0.1 * k) + (2 if i % 2 else 0)
        ry = h * (0.3 + 0.12 * k)
        arc_ring(d, cx, cy, rx, ry, [PSY["light"], PSY["mid"], PSY["dark"], PSY["mid"]][k], 1, 0, 360)
    for s in range(6):
        ang = t * 2 * math.pi + s * math.pi / 3
        d.point((cx + math.cos(ang) * w * 0.42, cy + math.sin(ang) * h * 0.4), fill=PSY["core"])

def sucker_slash(d, t, w, h, i):
    cx, cy = w * 0.5, h * 0.5
    r = w * (0.36 + 0.06 * t)
    d.arc([cx - r, cy - r, cx + r, cy + r], -80, 30, fill=SHADOW["out"], width=4)
    d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], -76, 26, fill=SHADOW["mid"], width=2)
    d.arc([cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3], -60, 0, fill=SHADOW["light"], width=1)

def sucker_down(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    for k in range(3):
        rr = (k + 1 + t * 3) % 3 + 1
        arc_ring(d, cx, cy, w * 0.14 * rr, h * 0.22 * rr, [SHADOW["dark"], SHADOW["mid"], SHADOW["light"]][k], 2, 40, 300)
    for s in range(5):
        ang = t * 2 * math.pi + s * 1.26
        streak(d, cx + math.cos(ang) * w * 0.2, cy + math.sin(ang) * h * 0.2,
               cx + math.cos(ang) * w * 0.44, cy + math.sin(ang) * h * 0.44, 1, SHADOW["mid"])

def jab(d, t, w, h, i):
    y = h * 0.5
    x = w * (0.2 + 0.5 * t)
    streak(d, x - w * 0.4, y, x, y, 3, POISON["dark"])
    d.polygon([(x, y - 3), (x + 4, y), (x, y + 3)], fill=POISON["out"])
    d.polygon([(x - 2, y - 1), (x + 2, y), (x - 2, y + 1)], fill=POISON["light"])
    for k in range(3):
        disc(d, x - w * 0.2 + k * 5, y - 5 + (k % 2) * 3 - (t * 4 % 3), 1, POISON["green"])

def down_jab(d, t, w, h, i):
    y = h * 0.55
    x = w * (0.1 + 0.6 * t)
    streak(d, x - w * 0.35, y, x, y, 2, POISON["dark"])
    d.polygon([(x, y - 2), (x + 3, y), (x, y + 2)], fill=POISON["out"])
    disc(d, x - 4, y - 4 + (i % 2), 1, POISON["green"])

def sludge_glob(d, t, w, h, i):
    cx, cy = w / 2, h / 2
    r = h * 0.3 + (1 if i % 2 else 0)
    disc(d, cx, cy, r + 1, POISON["out"])
    disc(d, cx, cy, r, POISON["dark"])
    disc(d, cx - 1, cy - 1, r - 2, POISON["mid"])
    disc(d, cx - r * 0.4, cy - r * 0.4, 1, POISON["light"])
    for k in range(3):
        bx = cx + (k - 1) * 4
        by = cy + r + 1 + ((t * 4 + k) % 3)
        disc(d, bx, by, 1, POISON["green"])

def toxic_spikes(d, t, w, h, i):
    n = 4
    for k in range(n):
        x = (k + 0.5) * w / n
        d.polygon([(x - 3, h - 1), (x, 1 + (i % 2)), (x + 3, h - 1)], fill=POISON["dark"])
        d.line([x, 2 + (i % 2), x, h - 2], fill=POISON["light"])
    d.line([0, h - 1, w, h - 1], fill=POISON["out"])

# ------------------------------------------------------------------ table: name -> (frames, w, h, draw)
SPECS = {
    # Alakazam
    "proj_psybeam.png": (4, 64, 16, psybeam),
    "proj_psywave.png": (4, 96, 14, psywave),
    "alakazam_special2.png": (4, 2520, 49, lambda d, t, w, h, i: psychic_floor(d, t, w, h, i)),
    "alakazam_ultimate.png": (4, 2520, 49, lambda d, t, w, h, i: psychic_column(d, t, w, h, i)),
    "down_alakazam_basic.png": (4, 168, 31, lambda d, t, w, h, i: amnesia_blink(d, t, w, h, i)),
    "down_alakazam_special2.png": (4, 252, 35, lambda d, t, w, h, i: psychic_floor(d, t, w, h, i)),
    "trap_future_sight.png": (4, 160, 16, None),
    # Lucario
    "lucario_basic.png": (4, 176, 30, bone_rush),
    "down_lucario_basic.png": (4, 196, 18, down_bone_sweep),
    "lucario_special2.png": (4, 192, 40, aura_power),
    "down_lucario_special2.png": (4, 224, 35, extreme_speed),
    "proj_aura_sphere.png": (4, 80, 20, aura_sphere(AURA)),
    "proj_max_aura.png": (4, 160, 40, aura_sphere(AURA, big=True)),
    # Mewtwo
    "mewtwo_basic.png": (4, 192, 40, psycho_cut),
    "mewtwo_special2.png": (4, 196, 35, disable_lock),
    "mewtwo_awakened_special2.png": (4, 192, 40, amnesia_blink),
    "down_mewtwo_awakened_special2.png": (4, 180, 49, psychic_column),
    "proj_mewtwo_ball.png": (4, 64, 16, mewtwo_ball(SHADOW)),
    "proj_mega_psystorm.png": (4, 128, 32, psystorm),
    "proj_psystrike.png": (4, 160, 40, psystrike),
    "down_mewtwo_special1.png": (4, 252, 42, psychic_floor),
    "down_mewtwo_special2.png": (4, 156, 45, disable_down),
    "down_mewtwo_basic.png": (4, 192, 32, psychic_low_sweep),
    "down_mewtwo_awakened_basic.png": (4, 192, 40, psychic_big_wave),
    "mega_ball.png": (4, 64, 16, mewtwo_ball(PSY)),
    "trap_psychic_field.png": (4, 400, 18, psychic_field),
    # Toxicroak
    "toxicroak_basic.png": (4, 144, 22, jab),
    "down_toxicroak_basic.png": (4, 196, 15, down_jab),
    "toxicroak_special2.png": (4, 168, 28, sucker_slash),
    "down_toxicroak_special2.png": (4, 336, 35, sucker_down),
    "proj_sludge.png": (4, 80, 20, sludge_glob),
    "trap_toxic_spikes.png": (4, 128, 12, toxic_spikes),
}

FS_EDGE = (22, 46, 92)
FS_DK = (74, 140, 212)
FS_MD = (150, 210, 244)
FS_LT = (224, 246, 255)
FS_GEM = (34, 48, 110)
FS_SPARK = (255, 255, 255)

def _fs_blade(d, tip, hilt, half_w, shimmer):
    """Pale-blue crystal blade: tapered diamond from tip to hilt, dark gem core, light/dark facets."""
    (x0, y0), (x1, y1) = tip, hilt
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    cx, cy = x0 + ux * L * 0.38, y0 + uy * L * 0.38          # widest point of the blade
    d.polygon([(x0, y0), (cx + nx * half_w, cy + ny * half_w), (x1, y1), (cx - nx * half_w, cy - ny * half_w)], fill=FS_EDGE)
    w = half_w - 1
    d.polygon([(x0 + ux, y0 + uy), (cx + nx * w, cy + ny * w), (x1 - ux, y1 - uy), (cx - nx * w, cy - ny * w)], fill=FS_MD)
    d.line([(x0 + ux * 2 + nx, y0 + uy * 2 + ny), (x1 - ux * 3 + nx, y1 - uy * 3 + ny)], fill=FS_LT)
    d.line([(x0 + ux * 3 - nx, y0 + uy * 3 - ny), (x1 - ux * 4 - nx, y1 - uy * 4 - ny)], fill=FS_DK)
    d.point((x0 + ux * L * 0.55, y0 + uy * L * 0.55), fill=FS_GEM)   # dark diamond core
    if shimmer is not None:
        d.point((x0 + ux * L * shimmer, y0 + uy * L * shimmer), fill=FS_SPARK)

def trap_future_sight(i):
    """Future Sight: two crossed pale-blue crystal swords (40x16 frame); frame i moves a glint down each blade."""
    img = Image.new("RGBA", (40, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = (i / 4.0)
    _fs_blade(d, (4, 1), (30, 15), 3, s)
    _fs_blade(d, (36, 1), (10, 15), 3, s)
    return img

def main():
    os.makedirs(FX, exist_ok=True)
    for name, (n, w, h, fn) in SPECS.items():
        if fn is None:
            strip_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            for k in range(n):
                strip_img.paste(trap_future_sight(k), (k * (w // n), 0))
            img = strip_img
        else:
            img = strip(n, w // n, h, fn)
        img.save(os.path.join(FX, name))
        print("wrote", name, img.size)

if __name__ == "__main__":
    main()
