"""Pixel-art effects for the DOWN moves (needs Pillow). Writes assets/fx/down_*.png plus proj_quake.png / proj_quill.png.
Same style as generate_pixel_art.py: hard-edged colour bands, no anti-aliasing, authored at half resolution
(the game draws move strips at 2x - Fighter.FX_PIXEL - and traps / projectiles at their own scale).
Run from the project root:  python3 tools/generate_down_fx.py
Frame sizes are about half of the move's hitbox, so the art lines up with where it hits."""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from pixel_effects import PAL, new, strip, disc

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FX = os.path.join(ROOT, "assets", "fx")
os.makedirs(FX, exist_ok=True)
NF = 4

def dither_fade(img, k, nf=NF):
    """Last frame: checkerboard see-through, like every other strip."""
    if k == nf - 1:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if (x + y) % 2:
                    px[x, y] = (0, 0, 0, 0)
    return img

def paste_strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        out.paste(f, (k * w, 0))
    return out

# ------------------------------------------------------------------ melee strips (frame ~ hitbox / 2)
def rake(W, H, pal):
    """Scizor Low Claw: three claw lines raked along the floor, each a little behind the last."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load(); t = (k + 1) / NF
        for j, y in enumerate((H * 0.2, H * 0.5, H * 0.8)):
            y = int(y)
            length = int((W - 6) * min(1.0, max(0.0, t * 1.25 - j * 0.12)))
            for x in range(3, 3 + length):
                taper = 1.0 - 0.6 * (x - 3) / max(1, W - 6)
                px[x, y] = pal[3] + (255,)
                if taper > 0.55 and y + 1 < H:
                    px[x, y + 1] = pal[1] + (255,)
                if taper > 0.8 and y - 1 >= 0:
                    px[x, y - 1] = pal[2] + (255,)
            if length > 0 and 3 + length < W:
                px[2 + length, y] = pal[2] + (255,)
        frames.append(dither_fade(f, k))
    return paste_strip(frames)

def wheel(W, H, pal):
    """Blaziken Flame Wheel: a ring of fire with flame tongues that turns."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load()
        for y in range(H):
            for x in range(W):
                u, v = (x + .5 - W / 2) / (W / 2), (y + .5 - H / 2) / (H / 2)
                r = math.hypot(u, v); ang = math.atan2(v, u)
                tongue = (math.sin(3 * ang - k * 1.57) + 1) / 2
                outer = 0.82 + 0.18 * tongue
                if r > outer or r < 0.5:
                    continue
                g = (r - 0.5) / max(1e-6, outer - 0.5)
                col = pal[3] if g < 0.2 else pal[2] if g < 0.5 else pal[1] if g < 0.82 else pal[0]
                px[x, y] = col + (255,)
        d = ImageDraw.Draw(f)              # spokes
        for i in range(4):
            a = k * 0.5 + i * math.pi / 2
            d.line([W // 2, H // 2, W // 2 + int(math.cos(a) * W * 0.28), H // 2 + int(math.sin(a) * H * 0.28)], fill=pal[2] + (255,))
        frames.append(dither_fade(f, k))
    return paste_strip(frames)

def plunge(W, H, pal):
    """Blaziken Plunge Kick: a falling pillar of fire that ends in a pointed foot and an impact ring on the floor."""
    frames = []
    foot = H - 10
    for k in range(NF):
        f = new(W, H); px = f.load()
        for y in range(foot + 1):
            t = y / foot
            half = 2.5 + 8.5 * t ** 0.8 + math.sin(y * 0.55 + k * 2.1) * 0.9
            if y > foot - 6:
                half *= max(0.15, (foot - y + 1) / 6)
            for x in range(W):
                d = abs(x + .5 - W / 2) / max(0.6, half)
                if d > 1.0:
                    continue
                col = pal[3] if d < 0.28 else pal[2] if d < 0.58 else pal[1] if d < 0.86 else pal[0]
                px[x, y] = col + (255,)
        rx = (W / 2 - 1) * (0.55 + 0.45 * k / (NF - 1)); cy = H - 4
        for y in range(H - 8, H):
            for x in range(W):
                u, v = (x + .5 - W / 2) / rx, (y + .5 - cy) / 3.6
                r = math.hypot(u, v)
                if r <= 1.0:
                    px[x, y] = (pal[3] if r < 0.4 else pal[2] if r < 0.75 else pal[1] if r < 0.92 else pal[0]) + (255,)
        rng = random.Random(40 + k)
        for _ in range(6):
            sx, sy = rng.randint(2, W - 3), rng.randint(foot - 4, H - 6)
            if px[sx, sy][3] == 0:
                px[sx, sy] = pal[2] + (255,)
        frames.append(dither_fade(f, k))
    return paste_strip(frames)

def hand(W, H, pal):
    """Gengar Shadow Hand: a clawed shadow hand that reaches up out of the floor."""
    frames = []
    for k in range(NF):
        f = new(W, H); d = ImageDraw.Draw(f)
        g = (0.45, 0.78, 1.0, 1.0)[k]
        palm_y = H - 8
        d.ellipse([W // 2 - 10, palm_y - 6, W // 2 + 10, palm_y + 5], fill=pal[1] + (255,), outline=pal[0] + (255,))
        for i in range(4):
            bx = W // 2 - 7 + i * 5
            lean = (i - 1.5) * 1.8
            length = (14 - abs(i - 1.5) * 2.5) * g
            tx = bx + lean * (length / 6.0)
            ty = palm_y - 3 - length
            d.polygon([(bx - 3, palm_y - 2), (bx + 3, palm_y - 2), (round(tx) + 1, round(ty)), (round(tx) - 1, round(ty))], fill=pal[1] + (255,), outline=pal[0] + (255,))
            d.line([bx, palm_y - 3, round(tx), round(ty) + 2], fill=pal[2] + (255,))
            d.point((round(tx), round(ty)), fill=pal[3] + (255,))        # claw tip
        thumb_len = 8 * g
        d.polygon([(W // 2 - 8, palm_y), (W // 2 - 7, palm_y - 4), (W // 2 - 8 - round(thumb_len * 0.7), palm_y - 3 - round(thumb_len))],
                  fill=pal[1] + (255,), outline=pal[0] + (255,))
        d.polygon([(W // 2 - 10, H - 2), (W // 2 + 10, H - 2), (W // 2 + 7, H - 5), (W // 2 - 7, H - 5)], fill=pal[0] + (255,))   # floor crack
        frames.append(dither_fade(f, k))
    return paste_strip(frames)

# ------------------------------------------------------------------ projectiles
def quake_wave(W, H, pal):
    """Tinkaton Quake Smash shockwave: a crescent of cracked ground. Symmetric top / bottom (a left-going shot is drawn rotated 180)."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load()
        R_out = 12.5 + k * 0.5; thick = 5.5
        for y in range(H):
            for x in range(W):
                dx, dy = x + .5 - 2.0, y + .5 - H / 2
                r = math.hypot(dx, dy); ang = math.atan2(dy, dx)
                if abs(ang) > 1.05 or r > R_out or r < R_out - thick:
                    continue
                g = (R_out - r) / thick            # 0 = leading edge
                px[x, y] = (pal[3] if g < 0.22 else pal[2] if g < 0.5 else pal[1] if g < 0.8 else pal[0]) + (255,)
        rng = random.Random(7 + k)
        for _ in range(7):                          # flying rubble
            sx, sy = rng.randint(0, 6), rng.randint(2, H - 3)
            if px[sx, sy][3] == 0:
                px[sx, sy] = (pal[1] if rng.random() < 0.5 else pal[0]) + (255,)
        frames.append(f)
    return paste_strip(frames)

def quill(W, H, pal):
    """Decidueye Quill Sweep: a small leaf-green quill with a pale tip."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load(); m = H // 2
        for x in range(2, W - 2):
            px[x, m] = pal[2] + (255,); px[x, m - 1] = pal[1] + (255,)
        for x in range(0, 4):
            px[x, m - 2 + (x % 2)] = pal[0] + (255,); px[x, m + 1 - (x % 2)] = pal[0] + (255,)   # fletching
        px[W - 2, m] = pal[3] + (255,); px[W - 1, m] = pal[3] + (255,); px[W - 3, m - 1] = pal[2] + (255,)
        px[(4 + k * 3) % (W - 5) + 2, m - 1] = pal[3] + (255,)                                   # flicker
        frames.append(f)
    return paste_strip(frames)

# ------------------------------------------------------------------ traps (animated strips; trap.gd reads trap_frames / trap_marker)
def whirlpool(W, H, pal):
    """Greninja Whirlpool: a wide turning spiral of water."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load()
        for y in range(H):
            for x in range(W):
                u, v = (x + .5 - W / 2) / (W / 2 - 0.5), (y + .5 - H / 2) / (H / 2 - 0.5)
                r = math.hypot(u, v)
                if r > 1.0:
                    continue
                ang = math.atan2(v, u)
                s = (ang * 2 + r * 7 - k * math.pi / 2) % (2 * math.pi)
                if r > 0.9:
                    col = pal[3] if (x // 2 + k) % 3 else pal[2]
                elif r < 0.12:
                    col = pal[0]
                elif s < 1.3:
                    col = pal[2]
                elif s < 2.6:
                    col = pal[1]
                else:
                    col = pal[0]
                    if (x + y) % 2:
                        continue
                px[x, y] = col + (255,)
        frames.append(f)
    return paste_strip(frames)

def geyser(W, H, pal):
    """Gholdengo Gilded Geyser. Frame 0 = ground marker shown while the trap arms (trap_marker); frames 1-3 = the golden pillar."""
    frames = []
    coin_d, coin_l = (150, 98, 18), (255, 226, 110)
    for k in range(NF):
        f = new(W, H); px = f.load()
        if k == 0:
            cy = H - 5
            for y in range(H - 10, H):
                for x in range(W):
                    u, v = (x + .5 - W / 2) / (W / 2 - 1), (y + .5 - cy) / 4.6
                    r = math.hypot(u, v)
                    if r <= 1.0:
                        px[x, y] = (pal[2] if r < 0.55 else pal[1] if r < 0.85 else pal[0]) + (255,)
            for sx in (W // 2 - 9, W // 2 + 2, W // 2 + 11):
                px[sx, cy - 1] = pal[3] + (255,)
            frames.append(f)
            continue
        rng = random.Random(90 + k)
        for y in range(H - 6):
            t = y / H
            half = W * 0.5 * (0.40 + 0.52 * t) * (1 + 0.07 * math.sin(y * 0.33 + k * 1.7))
            if y < 16:
                half *= (y / 16) ** 0.55 + 0.1
            for x in range(W):
                d = abs(x + .5 - W / 2) / max(0.8, half)
                if d > 1.0:
                    continue
                band = 0 if d < 0.25 else 1 if d < 0.55 else 2 if d < 0.85 else 3
                if (y + k * 9) % 24 < 2 and band < 3:
                    band += 1
                px[x, y] = (pal[3], pal[2], pal[1], pal[0])[min(band, 3)] + (255,)
        cy = H - 5                                   # splash at the base
        for y in range(H - 9, H):
            for x in range(W):
                u, v = (x + .5 - W / 2) / (W / 2 - 0.5), (y + .5 - cy) / 4.4
                if math.hypot(u, v) <= 1.0 and px[x, y][3] == 0:
                    px[x, y] = (pal[1] if (x + k) % 3 else pal[2]) + (255,)
        for _ in range(7):                           # coins thrown up with the water
            cx, cyy = rng.randint(4, W - 5), rng.randint(6, H - 22)
            disc(px, W, H, cx, cyy, 2.4, 2.4, coin_d)
            disc(px, W, H, cx, cyy, 1.6, 1.6, coin_l)
        for _ in range(9):                           # spray
            sx, sy = rng.randint(1, W - 2), rng.randint(0, 22)
            if px[sx, sy][3] == 0:
                px[sx, sy] = pal[2] + (255,)
        frames.append(f)
    return paste_strip(frames)

def pit(W, H, pal):
    """Gengar Poison Pit: a small bubbling hole in the floor."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load()
        for y in range(H):
            for x in range(W):
                u, v = (x + .5 - W / 2) / (W / 2 - 0.5), (y + .5 - H * 0.6) / (H * 0.42)
                r = math.hypot(u, v)
                if r <= 1.0:
                    px[x, y] = (pal[0] if r < 0.8 else pal[2]) + (255,)
        for i, bx in enumerate((5, 11, 16)):
            by = H - 2 - ((k * 2 + i * 3) % 7)
            if 0 <= by < H - 1:
                disc(px, W, H, bx, by, 1.5, 1.5, pal[1]); px[bx, by - 1 if by > 0 else by] = pal[3] + (255,)
        frames.append(f)
    return paste_strip(frames)

def snare(W, H, pal):
    """Decidueye Underfoot Snare: a thorny ring of vines on the floor with curling tips."""
    frames = []
    for k in range(NF):
        f = new(W, H); px = f.load()
        cx, cy = W / 2, H * 0.62
        for i in range(60):
            a = i / 60 * 2 * math.pi
            x, y = round(cx + math.cos(a) * (W / 2 - 2)), round(cy + math.sin(a) * (H * 0.34))
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = (pal[1] if math.sin(a) > 0 else pal[2]) + (255,)
                if y + 1 < H:
                    px[x, y + 1] = pal[0] + (255,)
        for i, a in enumerate((0.3, 1.2, 2.0, 2.9, 3.9, 5.0, 5.8)):       # thorns that sway
            bx, by = round(cx + math.cos(a) * (W / 2 - 2)), round(cy + math.sin(a) * (H * 0.34))
            lift = 2 + (i + k) % 3
            for s in range(lift):
                x, y = bx + (1 if (s + k) % 2 else 0), by - 1 - s
                if 0 <= x < W and 0 <= y < H:
                    px[x, y] = (pal[3] if s == lift - 1 else pal[2]) + (255,)
        frames.append(f)
    return paste_strip(frames)

# ------------------------------------------------------------------ build
def save(img, name):
    img.save(os.path.join(FX, name))
    return name

def main():
    P = PAL
    out = {}
    # melee strips (name: (strip, frame w, frame h))
    out["down_tinkaton_basic.png"] = strip("slash", 75, 22, P["pink"], NF)
    out["down_tinkaton_special1.png"] = strip("burst", 35, 30, P["pink"], NF)
    out["down_tinkaton_special2.png"] = strip("spin", 75, 30, P["pink"], NF)
    out["down_marshadow_basic.png"] = strip("streak", 36, 13, P["shadow"], NF)
    out["down_marshadow_special1.png"] = strip("streak", 45, 15, P["venom"], NF)
    out["down_marshadow_special2.png"] = strip("column", 32, 55, P["venom"], NF)
    out["down_gholdengo_basic.png"] = strip("streak", 55, 13, P["gold"], NF)
    out["down_greninja_basic.png"] = strip("slash", 37, 12, P["water"], NF)
    out["down_scizor_basic.png"] = rake(39, 13, P["steel"])
    out["down_scizor_special1.png"] = strip("flurry", 23, 55, P["steel"], NF)
    out["down_scizor_special2.png"] = strip("xslash", 45, 40, P["crimson"], NF)
    out["down_blaziken_basic.png"] = strip("spin", 75, 14, P["fire"], NF)
    out["down_blaziken_special1.png"] = wheel(38, 26, P["fire"])
    out["down_blaziken_special2.png"] = plunge(48, 45, P["fire"])
    out["down_gengar_basic.png"] = hand(24, 35, P["venom"])
    # projectiles
    out["proj_quake.png"] = quake_wave(16, 16, P["pink"])
    out["proj_quill.png"] = quill(14, 6, P["leaf"])
    # traps
    out["trap_whirlpool.png"] = whirlpool(100, 18, P["water"])
    out["trap_geyser.png"] = geyser(45, 120, P["gold"])
    out["trap_pit.png"] = pit(22, 8, P["venom"])
    out["trap_snare.png"] = snare(32, 12, P["leaf"])
    for name, img in out.items():
        save(img, name)
    print("wrote %d down-move art files to assets/fx" % len(out))

if __name__ == "__main__":
    main()
