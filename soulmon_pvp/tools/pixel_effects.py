"""Pixel-art move effects: animated strips (N frames side by side) with hard-edged colour bands."""
import math, random
from PIL import Image, ImageDraw
from pixel_core import R

# palettes: (dark rim, mid, light, core)
PAL = {
    "shadow": ((44, 14, 76), (122, 58, 192), (208, 152, 255), (252, 238, 255)),
    "gold":   ((150, 98, 18), (240, 190, 50), (255, 236, 130), (255, 252, 222)),
    "pink":   ((172, 52, 112), (246, 122, 172), (255, 204, 228), (255, 248, 252)),
    "water":  ((22, 66, 168), (60, 150, 240), (150, 222, 255), (240, 252, 255)),
    "steel":  ((78, 84, 110), (170, 180, 206), (232, 238, 250), (255, 255, 255)),
    "crimson": ((118, 20, 40), (222, 62, 72), (255, 152, 132), (255, 242, 222)),
    "leaf":   ((24, 82, 50), (72, 172, 92), (172, 236, 142), (242, 255, 222)),
    "fire":   ((150, 30, 20), (250, 100, 30), (255, 200, 60), (255, 250, 200)),
    "venom":  ((60, 20, 96), (150, 72, 210), (232, 162, 255), (255, 236, 255)),
}

def new(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))

def fade(k, nf):
    return nf >= 3 and k == nf - 1

def pick(pal, u):
    """u: 0 (core side) .. 1 (rim)"""
    if u < 0.18: return pal[3]
    if u < 0.5: return pal[2]
    if u < 0.82: return pal[1]
    return pal[0]

def slash(w, h, pal, k, nf, tilt=0.0, cx=None, cy=None, theta=66, thick=0.5, t_override=None):
    img = new(w, h); px = img.load()
    cx = -w * 0.28 if cx is None else cx
    cy = h / 2 if cy is None else cy
    th = math.radians(theta)
    rx = max(2.0, (w - cx - 1)); ry = max(2.0, (h / 2 - 0.3) / math.sin(th))
    t = ((k + 1) / nf) if t_override is None else t_override
    edge = -th + 2 * th * min(1.0, t)
    tl = math.radians(tilt); c, s = math.cos(tl), math.sin(tl)
    for y in range(h):
        for x in range(w):
            dx, dy = x + .5 - cx, y + .5 - cy
            ux, vy = (dx * c + dy * s) / rx, (-dx * s + dy * c) / ry
            r = math.hypot(ux, vy)
            if r > 1.0 or r < 0.2: continue
            ang = math.atan2(vy, ux)
            if ang < -th or ang > edge: continue
            inner = 1 - thick * max(0.0, 1 - (ang / th) ** 2) ** 0.8
            if r < inner: continue
            u = 1 - (r - inner) / max(1e-6, 1 - inner)        # 0 at rim? invert so core sits on the inner edge
            u = (r - inner) / max(1e-6, 1 - inner)
            col = pick(pal, u)
            if edge - ang < 0.14 and t < 1.0: col = pal[3]
            if fade(k, nf):
                if (x + y) % 2: continue
                col = pal[0] if u > 0.5 else pal[1]
            px[x, y] = col + (255,)
    return img

def burst(w, h, pal, k, nf, rays=8):
    img = new(w, h); px = img.load()
    t = (k + 1) / nf
    cx, cy = w / 2, h / 2
    rx, ry = w / 2 * (0.5 + 0.5 * t), h / 2 * (0.5 + 0.5 * t)
    for y in range(h):
        for x in range(w):
            u, v = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            r = math.hypot(u, v); ang = math.atan2(v, u)
            spike = abs(math.sin(ang * rays / 2 + k * 0.3))
            col = None
            if r < 0.62:
                col = pal[3] if k == 0 else (pal[2] if (x + y) % 2 == 0 else None)       # checker = see-through glow
            elif r <= 0.8:
                col = pal[2]
            elif r <= 0.95:
                col = pal[1]
            elif r <= 1.05:
                col = pal[0]
            if r > 0.9 and r <= 1.0 + 0.32 * (spike ** 6) * 1.0 and spike > 0.82:        # triangular spikes
                col = pal[2] if r < 1.12 else pal[1]
            if col is None: continue
            if fade(k, nf) and (x + y) % 2: continue
            px[x, y] = col + (255,)
    return img

def beam(w, h, pal, k, nf):
    img = new(w, h); px = img.load()
    length = int(w * (0.55 if k == 0 else 1.0))
    cy = h / 2
    for x in range(length):
        wob = math.sin(x * 0.42 + k * 1.9) * 0.14
        half = h * 0.47 * (1 + wob)
        if x < h * 0.7: half *= 1 + (1 - x / (h * 0.7)) * 0.25
        if x > length - 5: half *= max(0.2, (length - x) / 5)
        for y in range(h):
            d = abs(y + .5 - cy)
            if d > half: continue
            f = d / max(1e-6, half)
            col = pal[3] if f < 0.28 else pal[2] if f < 0.55 else pal[1] if f < 0.82 else pal[0]
            if fade(k, nf) and (x + y) % 2: continue
            px[x, y] = col + (255,)
    return img

def streak(w, h, pal, k, nf):
    img = new(w, h); px = img.load()
    rng = random.Random(7)
    head = w * 0.80
    for y in range(h):
        for x in range(w):
            dy = abs(y + .5 - h / 2)
            if x < head:                                     # thin tapered tail
                half = h * 0.30 * (x / head) ** 1.5
                if dy <= half:
                    f = dy / max(1e-6, half)
                    px[x, y] = (pal[2] if f < 0.4 else pal[1] if f < 0.8 else pal[0]) + (255,)
            else:                                            # diamond head
                u = (x + .5 - head) / (w - head)
                if dy <= h * 0.42 * (1 - u):
                    f = dy / max(1e-6, h * 0.42 * (1 - u) + 0.01)
                    px[x, y] = (pal[3] if f < 0.35 else pal[2] if f < 0.7 else pal[1]) + (255,)
    for i in range(5):                                       # speed lines
        yy = rng.randint(1, h - 2); x0 = int((k * 6 + i * 8) % max(1, w * 0.55)); ln = rng.randint(5, 11)
        for x in range(x0, min(int(head), x0 + ln)):
            if px[x, yy][3] == 0: px[x, yy] = pal[1] + (255,)
    if fade(k, nf):
        for y in range(h):
            for x in range(w):
                if (x + y) % 2: px[x, y] = (0, 0, 0, 0)
    return img

def star(px, w, h, cx, cy, size, pal):
    cx, cy = R(cx), R(cy)
    pts = [(0, 0, pal[3])]
    for d in range(1, size + 1):
        for ox, oy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            pts.append((ox, oy, pal[2] if d < size else pal[1]))
    for ox, oy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        pts.append((ox, oy, pal[3]))
    if size >= 3:
        for ox, oy in ((2, 2), (-2, 2), (2, -2), (-2, -2)):
            pts.append((ox, oy, pal[1]))
    for ox, oy, col in pts:
        x, y = cx + ox, cy + oy
        if 0 <= x < w and 0 <= y < h: px[x, y] = col + (255,)

def flurry(w, h, pal, k, nf):
    img = new(w, h); px = img.load()
    rng = random.Random(100 + k * 13)
    for i in range(4):
        star(px, w, h, rng.uniform(.14 * w, .86 * w), rng.uniform(.22 * h, .78 * h), rng.choice((2, 3, 3)), pal)
    if fade(k, nf):
        for y in range(h):
            for x in range(w):
                if (x + y) % 2: px[x, y] = (0, 0, 0, 0)
    return img

def spin(w, h, pal, k, nf):
    img = new(w, h); px = img.load()
    a0 = k * math.radians(42)
    for y in range(h):
        for x in range(w):
            u, v = (x + .5 - w / 2) / (w / 2), (y + .5 - h / 2) / (h / 2)
            r = math.hypot(u, v)
            if not 0.6 <= r <= 1.0: continue
            ang = math.atan2(v, u)
            for base in (a0, a0 + math.pi):
                d = (ang - base + math.pi) % (2 * math.pi) - math.pi
                if -0.2 <= d <= 1.5:
                    f = (r - 0.6) / 0.4
                    col = pal[2] if f < 0.35 else pal[1] if f < 0.75 else pal[0]
                    if d > 1.25: col = pal[3]
                    if fade(k, nf) and (x + y) % 2: break
                    px[x, y] = col + (255,)
                    break
    return img

def xslash(w, h, pal, k, nf):
    a = slash(w, h, pal, k, nf, tilt=24)
    b = slash(w, h, pal, k, nf, tilt=-24, t_override=max(0.05, ((k + 1) / nf - 0.25) / 0.75))
    out = new(w, h); out.alpha_composite(b); out.alpha_composite(a)
    return out

def column(w, h, pal, k, nf, down=False):
    img = slash(h, w, pal, k, nf, thick=0.55)          # horizontal arc on a transposed canvas
    img = img.transpose(Image.ROTATE_90)                # bulge points up
    return img.transpose(Image.FLIP_TOP_BOTTOM) if down else img

SHAPES = {"slash": slash, "burst": burst, "beam": beam, "streak": streak, "flurry": flurry,
          "spin": spin, "xslash": xslash, "column": column}

def strip(shape, w, h, pal, nf=4, **kw):
    fn = SHAPES[shape]
    out = Image.new('RGBA', (w * nf, h), (0, 0, 0, 0))
    for k in range(nf):
        out.paste(fn(w, h, pal, k, nf, **kw), (k * w, 0))
    return out

# ------------------------------------------------------------------ projectiles
def disc(px, W, H, cx, cy, rx, ry, col):
    for y in range(H):
        for x in range(W):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0: px[x, y] = col + (255,)

def coin_strip():
    W = H = 12; out = Image.new('RGBA', (W * 4, H), (0, 0, 0, 0))
    for k, wd in enumerate((5.5, 4.0, 1.5, 4.0)):
        f = new(W, H); px = f.load()
        disc(px, W, H, 6, 6, wd + 0.6, 5.6, (92, 56, 10))
        disc(px, W, H, 6, 6, wd, 5.0, (214, 160, 36))
        if wd > 2: disc(px, W, H, 6, 6, wd - 1.4, 3.6, (252, 214, 84))
        if wd > 3.5:
            disc(px, W, H, 5.5, 5.5, 1.2, 1.4, (255, 250, 200))
            for y in range(4, 8): px[6, y] = (200, 140, 30, 255)
        out.paste(f, (k * W, 0))
    return out

def shuriken_strip():
    W = H = 16; out = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    for k in range(2):
        f = new(W, H); d = ImageDraw.Draw(f)
        rot = k * math.pi / 4
        def star_pts(r_out, r_in):
            return [(8 + (r_out if i % 2 == 0 else r_in) * math.cos(rot + i * math.pi / 4 - math.pi / 2),
                     8 + (r_out if i % 2 == 0 else r_in) * math.sin(rot + i * math.pi / 4 - math.pi / 2)) for i in range(8)]
        d.polygon([(R(x), R(y)) for x, y in star_pts(7.6, 2.4)], fill=PAL["water"][0] + (255,))
        d.polygon([(R(x), R(y)) for x, y in star_pts(6.2, 2.0)], fill=PAL["water"][1] + (255,))
        d.polygon([(R(x), R(y)) for x, y in star_pts(4.4, 1.6)], fill=PAL["water"][2] + (255,))
        px = f.load(); disc(px, W, H, 8, 8, 1.6, 1.6, PAL["water"][3])
        out.paste(f, (k * W, 0))
    return out

def wave_strip():
    W = H = 20; out = Image.new('RGBA', (W * 3, H), (0, 0, 0, 0))
    pal = PAL["water"]
    for k in range(3):
        f = new(W, H); px = f.load()
        for x in range(W):
            crest = 9 - 7 * math.sin(math.pi * (x + .5) / W) ** 0.9 + math.sin(x * 0.9 + k * 2.1) * 1.2
            for y in range(H):
                if y >= crest:
                    depth = y - crest
                    col = pal[3] if depth < 1.2 else pal[2] if depth < 3.2 else pal[1] if depth < 8 else pal[0]
                    if x > W - 4 and y < crest + 3: col = pal[3]      # foam curl
                    px[x, y] = col + (255,)
        out.paste(f, (k * W, 0))
    return out

def arrow_strip():
    W, H = 24, 8; out = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    for k in range(2):
        f = new(W, H); px = f.load()
        for x in range(2, 20):
            px[x, 3] = (214, 255, 232, 255); px[x, 4] = (120, 238, 186, 255)
        for i, (x, ys) in enumerate(((20, (1, 6)), (21, (2, 5)), (22, (3, 4)), (23, (3, 4)))):
            for y in range(ys[0], ys[1] + 1): px[x, y] = (200, 255, 226, 255)
        for y in (2, 5): px[19, y] = (120, 238, 186, 255)
        for x, y in ((0, 1), (1, 2), (0, 6), (1, 5), (2, 1), (2, 6)): px[x, y] = (84, 196, 150, 255)
        for x in range(4 + k * 3, 17, 6):
            px[x, 2] = (150, 255, 230, 255); px[x, 5] = (150, 255, 230, 255)    # flickering spirit glow
        out.paste(f, (k * W, 0))
    return out

def orb_strip(pal_key="venom"):
    W = H = 14; out = Image.new('RGBA', (W * 4, H), (0, 0, 0, 0)); pal = PAL[pal_key]
    for k in range(4):
        f = new(W, H); px = f.load(); pulse = (0, 0.5, 1, 0.5)[k]
        disc(px, W, H, 7, 7, 6.6 + pulse * .4, 6.6 + pulse * .4, pal[0])
        disc(px, W, H, 7, 7, 5.4 + pulse * .4, 5.4 + pulse * .4, pal[1])
        disc(px, W, H, 6.4, 6.4, 3.4, 3.4, pal[2])
        a = k * math.pi / 2
        for i in range(6):                                  # dark swirl inside
            r = 1 + i * 0.6; px_, py_ = R(7 + r * math.cos(a + i * .8)), R(7 + r * math.sin(a + i * .8))
            if 0 <= px_ < W and 0 <= py_ < H and px[px_, py_][3]: px[px_, py_] = pal[0] + (255,)
        disc(px, W, H, 5, 5, 1.2, 1.2, pal[3])
        out.paste(f, (k * W, 0))
    return out

# ------------------------------------------------------------------ traps / icons
def trap_strip(kind):
    W, H = 32, 12; out = Image.new('RGBA', (W * 4, H), (0, 0, 0, 0))
    for k in range(4):
        f = new(W, H); px = f.load()
        if kind == "leaf":
            base, mid, lite = (30, 92, 48), (74, 170, 92), (176, 236, 142)
            for x in range(W):
                for y in range(H - 3, H):
                    px[x, y] = (base if y == H - 1 else mid) + (255,)
            for i, x0 in enumerate(range(2, 30, 4)):
                hgt = 4 + ((i * 3 + k * 2) % 6)
                for dy in range(hgt):
                    y = H - 4 - dy
                    for dx in range(2 if dy < hgt - 2 else 1):
                        px[x0 + dx + (1 if (i + dy) % 5 == 0 else 0), y] = (lite if dy > hgt - 3 else mid) + (255,)
        else:
            dark, mid, lite = (52, 18, 84), (120, 56, 176), (206, 140, 255)
            for x in range(W):
                top = 7 + (1 if (x // 3 + k) % 4 == 0 else 0)
                for y in range(top, H):
                    px[x, y] = (dark if y >= H - 2 else mid) + (255,)
                if (x + k) % 5 == 0: px[x, top] = lite + (255,)
            for i, bx in enumerate((6, 14, 21, 27)):
                by = 6 - ((k * 2 + i * 3) % 7)
                if by >= 0:
                    disc(px, W, H, bx, by + 1, 1.8, 1.8, lite); px[bx, by] = (255, 240, 255, 255)
        out.paste(f, (k * W, 0))
    return out

def icon(name):
    f = new(12, 12); px = f.load(); d = ImageDraw.Draw(f)
    if name == "burn":
        d.polygon([(6, 0), (9, 4), (10, 8), (8, 11), (4, 11), (2, 8), (3, 4), (5, 6)], fill=(214, 60, 24, 255))
        d.polygon([(6, 4), (8, 8), (7, 10), (5, 10), (4, 8)], fill=(255, 190, 56, 255))
        px[6, 8] = (255, 250, 200, 255)
    elif name == "slow":
        disc(px, 12, 12, 6, 6, 5.6, 5.6, (24, 56, 140)); disc(px, 12, 12, 6, 6, 4.6, 4.6, (70, 150, 240))
        d.polygon([(3, 4), (8, 4), (5, 9)], fill=(236, 250, 255, 255)) if False else d.polygon([(3, 4), (9, 4), (6, 9)], fill=(236, 250, 255, 255))
    else:
        d.polygon([(6, 0), (10, 6), (10, 9), (8, 11), (4, 11), (2, 9), (2, 6)], fill=(120, 52, 170, 255))
        d.polygon([(6, 2), (8, 6), (8, 8), (6, 9), (4, 8), (4, 6)], fill=(180, 100, 236, 255))
        px[5, 6] = (255, 240, 255, 255); px[7, 6] = (255, 240, 255, 255); px[6, 8] = (255, 240, 255, 255)
    # 1px dark outline
    a = f.split()[3]; out = new(12, 12); op = out.load(); ap = a.load(); fp = f.load()
    for y in range(12):
        for x in range(12):
            if ap[x, y]: op[x, y] = fp[x, y]
            else:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= x + dx < 12 and 0 <= y + dy < 12 and ap[x + dx, y + dy]: op[x, y] = (20, 12, 26, 255); break
    return out.resize((24, 24), Image.NEAREST)

# ------------------------------------------------------------------ arena
def background():
    W, H = 320, 180
    img = Image.new('RGB', (W, H)); px = img.load()
    sky = [(14, 12, 40), (24, 18, 60), (40, 26, 84), (62, 36, 104), (92, 48, 116)]
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(H):
        t = y / H * (len(sky) - 1.001)
        i = int(t); frac = t - i
        for x in range(W):
            px[x, y] = sky[i + (1 if frac * 16 > bayer[y % 4][x % 4] else 0)]
    rng = random.Random(3)
    for _ in range(70):
        x, y = rng.randint(0, W - 1), rng.randint(0, 80); px[x, y] = (255, 250, 220) if rng.random() < .3 else (170, 170, 220)
    cx, cy = 262, 36                                                       # moon
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy)
            if d <= 14: px[x, y] = (252, 246, 224) if d < 12 else (214, 206, 190)
            if math.hypot(x - cx + 4, y - cy - 3) <= 3 and d <= 12: px[x, y] = (224, 216, 196)
            elif 14 < d <= 20 and (x + y) % 2 == 0: px[x, y] = tuple(min(255, c + 22) for c in px[x, y])
    for base, amp, col, ph in ((118, 22, (44, 34, 84), 0.0), (136, 16, (28, 24, 62), 2.0)):
        for x in range(W):
            top = int(base - amp * (0.5 + 0.5 * math.sin(x / 38 + ph)) - 8 * abs(math.sin(x / 11 + ph * 2)))
            for y in range(top, H): px[x, y] = col
    for x in range(8, W, 17):                                              # pine silhouettes
        h = 18 + (x * 7) % 14; y0 = 152
        for row in range(h):
            half = 1 + row // 3
            for xx in range(x - half, x + half + 1):
                if 0 <= xx < W: px[xx, y0 - h + row] = (14, 14, 32)
        for y in range(y0, y0 + 4): px[x, y] = (14, 14, 32)
    return img.resize((W * 4, H * 4), Image.NEAREST).convert('RGBA')

def stone_tile():
    f = Image.new('RGB', (16, 16), (36, 38, 54)); px = f.load()
    rng = random.Random(9)
    for row in range(4):
        off = 0 if row % 2 == 0 else 4
        for col in range(-1, 3):
            x0 = col * 8 + off
            base = rng.choice(((84, 88, 112), (92, 96, 122), (78, 82, 106)))
            for y in range(row * 4, row * 4 + 3):
                for x in range(x0, x0 + 7):
                    xx = x % 16
                    px[xx, y] = base
                    if y == row * 4: px[xx, y] = tuple(min(255, c + 22) for c in base)
                    if y == row * 4 + 2: px[xx, y] = tuple(c - 18 for c in base)
    return f.resize((64, 64), Image.NEAREST).convert('RGBA')

def grass_top():
    f = Image.new('RGBA', (16, 5), (0, 0, 0, 0)); px = f.load()
    for x in range(16):
        for y in range(2, 5): px[x, y] = ((62, 148, 76) if y < 4 else (34, 94, 54)) + (255,)
        px[x, 2] = (118, 206, 104, 255)
    for x in (1, 4, 6, 9, 12, 14):
        px[x, 1] = (118, 206, 104, 255)
        if x in (4, 12): px[x, 0] = (150, 226, 120, 255)
    return f.resize((64, 20), Image.NEAREST)
