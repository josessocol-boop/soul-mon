"""Generates effect / arena placeholder art (needs Pillow). Run: python3 tools/generate_art.py
Add --sheets to also write simple stand-in character sheets (will overwrite assets/*_sheet.png!)."""
import math, random, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4  # supersampling
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
os.makedirs(OUT, exist_ok=True)
OL = (24, 16, 30, 255)

def new(w, h): return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
def fin(img, w, h): return img.resize((w, h), Image.LANCZOS)
def P(v): return int(round(v * S))

def ell(d, cx, cy, rx, ry, fill, outline=None, w=1.0):
    d.ellipse([P(cx - rx), P(cy - ry), P(cx + rx), P(cy + ry)], fill=fill,
              outline=outline, width=P(w) if outline else 0)

def rrect(d, x0, y0, x1, y1, r, fill, outline=None, w=1.0):
    d.rounded_rectangle([P(x0), P(y0), P(x1), P(y1)], radius=P(r), fill=fill,
                        outline=outline, width=P(w) if outline else 0)

def limb(d, x0, y0, x1, y1, t, col):
    for c, th in ((OL, t + 2.0), (col, t)):
        d.line([P(x0), P(y0), P(x1), P(y1)], fill=c, width=P(th))
        ell(d, x0, y0, th / 2, th / 2, c)
        ell(d, x1, y1, th / 2, th / 2, c)

def poly(d, pts, fill, outline=None):
    d.polygon([(P(x), P(y)) for x, y in pts], fill=fill)
    if outline:
        d.line([(P(x), P(y)) for x, y in pts + [pts[0]]], fill=outline, width=P(1.0))

# ------------------------------------------------------------------ creatures
# Simple stylised stand-in sprites (original placeholder drawings, colour-coded
# to each roster member). Swap in real art later via sheet_path.
WHITE = (255, 255, 255, 255)

def anch(p):
    b = p.get("bob", 0.0); l = p.get("lean", 0.0)
    return dict(b=b, l=l, hx=32 + l, hy=17 + b, tx=32 + l * 0.5, sh=31 + b, x0=32 + l * 0.25, y0=45 + b)

def rotpts(pts, ang, cx, cy):
    r = math.radians(ang); c, s_ = math.cos(r), math.sin(r)
    return [(cx + (x - cx) * c - (y - cy) * s_, cy + (x - cx) * s_ + (y - cy) * c) for x, y in pts]

def bar(d, x, y, ang, L, w, col):
    pts = [(x - w / 2, y), (x + w / 2, y), (x + w / 2, y - L), (x - w / 2, y - L)]
    poly(d, rotpts(pts, ang, x, y), col, OL)
    r = math.radians(ang)
    return x + math.sin(r) * L, y - math.cos(r) * L

def arm(d, a, p, key, back, t, col, hr, hcol=None):
    dx, dy = p.get(key, (0, 12))
    sx = a["tx"] + (-3 if back else 3)
    ex, ey = sx + dx, a["sh"] + dy
    limb(d, sx, a["sh"], ex, ey, t, col)
    if hr:
        ell(d, ex, ey, hr, hr, hcol or col, OL, 1.0)
    return ex, ey

def leg(d, a, p, key, t, col, shoe, sw=5.0, sh=2.6):
    fx, lift = p.get(key, (0, 0))
    limb(d, a["x0"], a["y0"], a["x0"] + fx, 59 - lift, t, col)
    ell(d, a["x0"] + fx + 2, 59.5 - lift, sw, sh, shoe, OL, 0.8)

def eyes(d, ex, ey, p, rx=1.7, ry=2.3, iris=OL):
    if p.get("eyes") == "x":
        for ox in (ex - 4, ex + 2.5):
            d.line([P(ox - 1.5), P(ey - 1.5), P(ox + 1.5), P(ey + 1.5)], fill=OL, width=P(1))
            d.line([P(ox - 1.5), P(ey + 1.5), P(ox + 1.5), P(ey - 1.5)], fill=OL, width=P(1))
        return
    for ox in (ex - 2.5, ex + 3.5):
        ell(d, ox, ey, rx, ry, WHITE, OL, 0.6)
        ell(d, ox + 0.7, ey, rx * 0.5, ry * 0.6, iris)

def streaks(d, p):
    if p.get("streaks"):
        for yy in (24, 34, 44):
            d.line([P(6 - p.get("lean", 0)), P(yy), P(18 - p.get("lean", 0) * 0.5), P(yy)], fill=(255, 255, 255, 150), width=P(1.2))

def draw_gholdengo(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]
    GOLD, DK, SIL = (238, 192, 62, 255), (178, 128, 30, 255), (205, 210, 222, 255)
    sway = p.get("leg_f", (0, 0))[0] * 0.25
    arm(d, a, p, "arm_b", True, 2.4, SIL, 5.0, GOLD)
    poly(d, [(tx - 8, 38 + b), (tx + 8, 38 + b), (tx + 14 + sway, 59), (tx - 14 + sway, 59)], GOLD, OL)
    for yy in (47, 53):
        d.line([P(tx - 12 + sway * 0.6), P(yy), P(tx + 12 + sway * 0.6), P(yy)], fill=DK, width=P(1.6))
    ell(d, tx, 32 + b, 12, 11, GOLD, OL, 1.2)
    for i, yy in enumerate((28, 33, 38)):
        ell(d, tx, yy + b, 12.5 - i * 0.5, 2.0, DK)
    ell(d, tx, 24 + b, 9, 2.4, SIL, OL, 0.8)
    ell(d, a["hx"], a["hy"], 10.5, 10, GOLD, OL, 1.2)
    rrect(d, a["hx"] - 3, a["hy"] - 5, a["hx"] + 9, a["hy"] + 5, 3, (28, 28, 40, 255))
    ell(d, a["hx"] + 1, a["hy"] - 1, 1.6, 1.8, (140, 255, 190, 255)); ell(d, a["hx"] + 6, a["hy"] - 1, 1.6, 1.8, (140, 255, 190, 255))
    ell(d, a["hx"] - 1, a["hy"] - 11, 6.5, 2.6, SIL, OL, 0.8)
    hand = arm(d, a, p, "arm_f", False, 2.4, SIL, 5.5, GOLD)
    if "wpn" in p:   # surfboard
        bar(d, hand[0], hand[1], p["wpn"], 28, 9, (90, 205, 205, 255))
    streaks(d, p)
    return img

def draw_marshadow(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    DK, LT, YEL, RED = (62, 64, 82, 255), (196, 198, 212, 255), (242, 192, 60, 255), (214, 52, 52, 255)
    poly(d, [(hx - 4, hy + 6), (hx - 22, hy + 1), (hx - 15, hy + 9), (hx - 27, hy + 13), (hx - 9, hy + 12)], RED, OL)
    arm(d, a, p, "arm_b", True, 4.0, DK, 4.2, LT)
    leg(d, a, p, "leg_b", 4.5, DK, LT, 4.5, 2.4)
    rrect(d, tx - 7.5, 27 + b, tx + 7.5, 47 + b, 6, DK, OL, 1.2)
    ell(d, tx + 1, 35 + b, 4.5, 6.5, LT)
    rrect(d, tx - 8, 41 + b, tx + 8, 44 + b, 1.2, YEL)
    leg(d, a, p, "leg_f", 4.5, DK, LT, 4.5, 2.4)
    poly(d, [(hx - 6, hy - 6), (hx - 17, hy - 11), (hx - 10, hy - 3), (hx - 19, hy + 2), (hx - 8, hy + 3)], DK, OL)
    ell(d, hx, hy, 9.5, 9.5, DK, OL, 1.2)
    ell(d, hx + 3, hy + 2, 6.2, 5, LT)
    for ox in (hx + 1, hx + 7):
        ell(d, ox, hy - 0.5, 2.3, 1.7, RED, OL, 0.5)
    rrect(d, hx - 8, hy + 7, hx + 8, hy + 11, 2, RED, OL, 0.8)
    arm(d, a, p, "arm_f", False, 4.0, DK, 4.2, LT)
    streaks(d, p)
    return img

def draw_tinkaton(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    PK, DP = (246, 152, 184, 255), (212, 98, 140, 255)
    arm(d, a, p, "arm_b", True, 4.5, PK, 4.0, PK)
    leg(d, a, p, "leg_b", 5.5, PK, DP, 5.2, 2.6)
    ell(d, tx, 37 + b, 10, 11, PK, OL, 1.2)
    ell(d, tx + 1, 40 + b, 6, 7, (255, 232, 240, 255))
    leg(d, a, p, "leg_f", 5.5, PK, DP, 5.2, 2.6)
    ell(d, hx - 11, hy + 3, 5.5, 7, DP, OL, 1.0)
    poly(d, [(hx - 9, hy - 5), (hx - 8, hy - 16), (hx - 1, hy - 9)], PK, OL)
    poly(d, [(hx + 1, hy - 9), (hx + 8, hy - 16), (hx + 9, hy - 4)], PK, OL)
    ell(d, hx, hy, 10.5, 9.5, PK, OL, 1.2)
    ell(d, hx + 4, hy + 4, 5.5, 3.6, (255, 240, 244, 255))
    eyes(d, hx + 4, hy - 1, p, 2.0, 2.6, (60, 170, 180, 255))
    hand = arm(d, a, p, "arm_f", False, 4.5, PK, 4.0, PK)
    ang = p.get("wpn", 28)
    ex, ey = bar(d, hand[0], hand[1], ang, 26, 3.4, (126, 86, 60, 255))
    head = [(ex - 12, ey - 7), (ex + 12, ey - 7), (ex + 12, ey + 7), (ex - 12, ey + 7)]
    poly(d, rotpts(head, ang, ex, ey), (146, 154, 174, 255), OL)
    poly(d, rotpts([(ex - 12, ey - 2), (ex + 12, ey - 2), (ex + 12, ey + 2), (ex - 12, ey + 2)], ang, ex, ey), DP)
    streaks(d, p)
    return img

def draw_greninja(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    BL, DB, CR, PK = (50, 88, 176, 255), (28, 48, 112, 255), (238, 228, 204, 255), (232, 92, 124, 255)
    poly(d, [(hx - 2, hy + 8), (hx - 22, hy + 7), (hx - 16, hy + 13), (hx - 30, hy + 15), (hx - 8, hy + 16)], PK, OL)
    arm(d, a, p, "arm_b", True, 4.5, DB, 4.4, CR)
    leg(d, a, p, "leg_b", 6.0, DB, BL, 6.5, 2.8)
    ell(d, tx, 36 + b, 9, 11, BL, OL, 1.2)
    ell(d, tx + 1.5, 38 + b, 5, 7.5, CR)
    leg(d, a, p, "leg_f", 6.0, DB, BL, 6.5, 2.8)
    poly(d, [(hx - 4, hy - 7), (hx - 19, hy - 3), (hx - 6, hy + 3)], DB, OL)
    ell(d, hx, hy, 10, 9, BL, OL, 1.2)
    poly(d, [(hx + 6, hy + 4), (hx + 15, hy + 6), (hx + 8, hy + 9)], BL, OL)
    eyes(d, hx + 3, hy - 2, p, 3.4, 3.0, OL)
    poly(d, [(hx - 7, hy + 7), (hx + 7, hy + 7), (hx + 5, hy + 12), (hx - 5, hy + 12)], PK, OL)
    arm(d, a, p, "arm_f", False, 4.5, DB, 4.4, CR)
    streaks(d, p)
    return img

def claw(d, x, y, col, base):
    ell(d, x, y, 5, 5, base, OL, 0.9)
    poly(d, [(x - 2, y - 2), (x + 13, y - 6), (x + 4, y)], col, OL)
    poly(d, [(x - 2, y + 2), (x + 13, y + 6), (x + 4, y)], col, OL)

def draw_scizor(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    RD, DR, SV, GR = (204, 40, 44, 255), (124, 22, 34, 255), (214, 218, 228, 255), (72, 74, 88, 255)
    ell(d, tx - 9, 27 + b, 10, 4, (226, 234, 244, 140)); ell(d, tx - 7, 33 + b, 9, 3, (226, 234, 244, 110))
    bx, by = arm(d, a, p, "arm_b", True, 5.0, RD, 0)
    claw(d, bx, by, SV, RD)
    leg(d, a, p, "leg_b", 4.4, GR, DR, 5.0, 2.5)
    rrect(d, tx - 9, 26 + b, tx + 9, 48 + b, 6, RD, OL, 1.2)
    for yy in (33, 38, 43):
        d.line([P(tx - 8), P(yy + b), P(tx + 8), P(yy + b)], fill=DR, width=P(1.4))
    leg(d, a, p, "leg_f", 4.4, GR, DR, 5.0, 2.5)
    poly(d, [(hx - 8, hy - 6), (hx - 1, hy - 18), (hx + 7, hy - 6)], RD, OL)
    ell(d, hx, hy, 9.5, 9.5, RD, OL, 1.2)
    rrect(d, hx - 2, hy - 4, hx + 10, hy + 4, 2, (30, 28, 38, 255))
    ell(d, hx + 3, hy - 0.5, 1.5, 1.1, WHITE); ell(d, hx + 8, hy - 0.5, 1.5, 1.1, WHITE)
    fx, fy = arm(d, a, p, "arm_f", False, 5.0, RD, 0)
    claw(d, fx, fy, SV, RD)
    streaks(d, p)
    return img

def draw_decidueye(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    BR, CRM, GRN, DG = (92, 68, 54, 255), (238, 230, 208, 255), (74, 164, 84, 255), (38, 102, 58, 255)
    poly(d, [(tx - 15, 31 + b), (tx - 9, 19 + b), (tx, 24 + b), (tx + 9, 19 + b), (tx + 15, 31 + b)], GRN, OL)
    arm(d, a, p, "arm_b", True, 5.0, BR, 3.6, BR)
    leg(d, a, p, "leg_b", 3.6, (64, 60, 60, 255), (214, 168, 64, 255), 5.0, 2.2)
    ell(d, tx, 36 + b, 10, 12, BR, OL, 1.2)
    ell(d, tx + 2, 38 + b, 6, 8.5, CRM)
    leg(d, a, p, "leg_f", 3.6, (64, 60, 60, 255), (214, 168, 64, 255), 5.0, 2.2)
    ell(d, hx, hy, 10.5, 10, BR, OL, 1.2)
    poly(d, [(hx - 8, hy - 6), (hx - 6, hy - 15), (hx - 1, hy - 8)], GRN, OL)
    poly(d, [(hx - 1, hy - 8), (hx + 3, hy - 16), (hx + 8, hy - 6)], DG, OL)
    ell(d, hx + 3, hy + 1, 8, 6.5, CRM, OL, 0.8)
    eyes(d, hx + 3, hy, p, 1.6, 2.0, OL)
    poly(d, [(hx + 10, hy + 1), (hx + 16, hy + 4), (hx + 10, hy + 6)], (240, 150, 40, 255), OL)
    arm(d, a, p, "arm_f", False, 5.0, BR, 3.6, BR)
    streaks(d, p)
    return img

def draw_blaziken(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"]; tx = a["tx"]; hx, hy = a["hx"], a["hy"]
    RD, OR, YL, BK = (216, 62, 42, 255), (252, 152, 42, 255), (252, 218, 72, 255), (52, 46, 54, 255)
    bx, by = arm(d, a, p, "arm_b", True, 4.4, RD, 0)
    ell(d, bx, by, 6, 6, OR, OL, 0.8); ell(d, bx, by, 3, 3, (255, 246, 200, 255))
    leg(d, a, p, "leg_b", 5.0, BK, YL, 5.0, 2.4)
    ell(d, tx, 36 + b, 10, 12.5, RD, OL, 1.2)
    rrect(d, tx - 8, 36 + b, tx + 8, 45 + b, 3, YL)
    leg(d, a, p, "leg_f", 5.0, BK, YL, 5.0, 2.4)
    poly(d, [(hx - 8, hy - 4), (hx - 11, hy - 17), (hx - 4, hy - 10), (hx - 2, hy - 20), (hx + 3, hy - 10), (hx + 8, hy - 16), (hx + 8, hy - 4)], OR, OL)
    poly(d, [(hx - 5, hy - 5), (hx - 2, hy - 14), (hx + 2, hy - 7), (hx + 5, hy - 12), (hx + 5, hy - 5)], YL)
    ell(d, hx, hy, 9.5, 9.5, RD, OL, 1.2)
    poly(d, [(hx + 8, hy), (hx + 16, hy + 3), (hx + 8, hy + 6)], YL, OL)
    eyes(d, hx + 3, hy - 1, p, 1.6, 2.0, OL)
    fx, fy = arm(d, a, p, "arm_f", False, 4.4, RD, 0)
    ell(d, fx, fy, 6.5, 6.5, OR, OL, 0.8); ell(d, fx, fy, 3.4, 3.4, (255, 246, 200, 255))
    streaks(d, p)
    return img

def draw_gengar(p):
    img = new(64, 64); d = ImageDraw.Draw(img); a = anch(p); b = a["b"] - 2; tx = a["tx"]; hx, hy = a["hx"], a["hy"] - 2
    PU, DP, RED = (112, 62, 164, 255), (68, 34, 108, 255), (230, 40, 56, 255)
    for yy in (28, 36, 44):
        poly(d, [(tx - 12, yy + b), (tx - 22, yy - 6 + b), (tx - 10, yy + 7 + b)], DP, OL)
    arm(d, a, p, "arm_b", True, 5.5, PU, 4.2, PU)
    fb, fl = p.get("leg_b", (0, 0)); ff, fl2 = p.get("leg_f", (0, 0))
    ell(d, tx - 7 + fb * 0.5, 58 - fl, 6, 3, DP, OL, 0.8); ell(d, tx + 7 + ff * 0.5, 58 - fl2, 6, 3, DP, OL, 0.8)
    ell(d, tx, 41 + b, 14, 14, PU, OL, 1.2)
    ell(d, tx + 2, 44 + b, 8, 8, (150, 98, 200, 255))
    poly(d, [(hx - 11, hy - 3), (hx - 9, hy - 16), (hx - 2, hy - 8)], PU, OL)
    poly(d, [(hx + 2, hy - 8), (hx + 9, hy - 16), (hx + 11, hy - 3)], PU, OL)
    ell(d, hx, hy + 2, 13, 11, PU, OL, 1.2)
    if p.get("eyes") == "x":
        eyes(d, hx + 2, hy, p)
    else:
        for ox in (hx - 3, hx + 7):
            ell(d, ox, hy, 3.8, 2.8, RED, OL, 0.6); ell(d, ox + 1, hy - 0.8, 0.9, 0.9, WHITE)
    ell(d, hx + 2, hy + 7, 8, 3.4, (40, 16, 56, 255), OL, 0.6)
    for k in range(5):
        poly(d, [(hx - 4 + k * 3.2, hy + 5), (hx - 2.4 + k * 3.2, hy + 5), (hx - 3.2 + k * 3.2, hy + 8)], WHITE)
    arm(d, a, p, "arm_f", False, 5.5, PU, 4.2, PU)
    streaks(d, p)
    return img

# ------------------------------------------------------------------ poses
ROWS = ["idle", "run", "jump", "dash", "attack", "hitstun", "ko"]

def poses():
    A = {}
    A["idle"] = [dict(bob=b, arm_f=(5, 12 + b), arm_b=(-4, 12 - b)) for b in (0, -1, -1.5, -0.5)]
    run = []
    for i in range(6):
        ph = 2 * math.pi * i / 6
        s_, c = math.sin(ph), math.cos(ph)
        run.append(dict(bob=-abs(c) * 2, lean=4, leg_f=(s_ * 9, max(0, c) * 5), leg_b=(-s_ * 9, max(0, -c) * 5),
                        arm_f=(-s_ * 8, 10), arm_b=(s_ * 8, 10)))
    A["run"] = run
    A["jump"] = [dict(bob=-1, leg_f=(5, 7), leg_b=(-4, 9), arm_f=(8, -6), arm_b=(-8, -4)),
                 dict(bob=1, leg_f=(8, 2), leg_b=(-8, 3), arm_f=(10, 4), arm_b=(-10, 4))]
    A["dash"] = [dict(lean=9, bob=3, leg_f=(13, 2), leg_b=(-12, 4), arm_f=(-8, 6), arm_b=(-12, 4), streaks=True),
                 dict(lean=11, bob=4, leg_f=(14, 3), leg_b=(-13, 3), arm_f=(-9, 7), arm_b=(-13, 5), streaks=True)]
    A["attack"] = [dict(lean=-3, arm_f=(-9, -2), arm_b=(-6, 8), leg_f=(5, 0), leg_b=(-5, 0), wpn=-70),
                   dict(lean=4, bob=1, arm_f=(18, 0), arm_b=(-6, 8), leg_f=(8, 0), leg_b=(-7, 0), wpn=15),
                   dict(lean=6, bob=1, arm_f=(26, 1), arm_b=(-8, 6), leg_f=(10, 0), leg_b=(-8, 0), wpn=95),
                   dict(lean=2, arm_f=(14, 6), arm_b=(-5, 9), leg_f=(6, 0), leg_b=(-5, 0), wpn=60)]
    A["hitstun"] = [dict(lean=-7, bob=1, eyes="x", arm_f=(8, -9), arm_b=(-9, -6), leg_f=(6, 2), leg_b=(-3, 0), wpn=-30),
                    dict(lean=-9, bob=2, eyes="x", arm_f=(10, -6), arm_b=(-10, -9), leg_f=(8, 3), leg_b=(-2, 0), wpn=-40)]
    A["ko"] = [dict(lean=-9, bob=2, eyes="x", arm_f=(9, -9), arm_b=(-9, -8), wpn=-50),
               dict(lean=-4, eyes="x", arm_f=(8, 3), arm_b=(-8, 3), wpn=-20),
               dict(eyes="x", arm_f=(5, 10), arm_b=(-5, 10), wpn=0)]
    return A

def lying(img, angle):
    r = img.rotate(angle, resample=Image.BICUBIC, expand=True, center=(P(32), P(46)))
    bb = r.getbbox()
    out = new(64, 64)
    if not bb:
        return out
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    c = r.crop(bb)
    k = min(1.0, 56 * S / w)
    c = c.resize((int(w * k), int(h * k)), Image.LANCZOS)
    out.paste(c, (P(32) - c.width // 2, P(61) - c.height))
    return out

def shrink(img, k):
    if k >= 0.999:
        return img
    w, h = img.size
    sm = img.resize((int(w * k), int(h * k)), Image.LANCZOS)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(sm, ((w - sm.width) // 2, P(60) - int(P(60) * k)))
    return out

ROSTER = {  # id: (draw fn, size factor)
    "gholdengo": (draw_gholdengo, 1.0), "marshadow": (draw_marshadow, 0.92), "tinkaton": (draw_tinkaton, 0.9),
    "greninja": (draw_greninja, 1.0), "scizor": (draw_scizor, 1.0), "decidueye": (draw_decidueye, 1.0),
    "blaziken": (draw_blaziken, 1.0), "gengar": (draw_gengar, 0.95),
}

def make_sheet(fid):
    fn, k = ROSTER[fid]
    A = poses()
    sheet = Image.new("RGBA", (64 * 6, 64 * len(ROWS)), (0, 0, 0, 0))
    for row, anim in enumerate(ROWS):
        for col, pose in enumerate(A[anim]):
            fr = fn(pose)
            if anim == "ko":
                fr = lying(fr, [20, 60, 90][col])
            sheet.paste(fin(shrink(fr, k), 64, 64), (col * 64, row * 64))
    sheet.save(os.path.join(OUT, fid + "_sheet.png"))

# ------------------------------------------------------------------ effects
def glow_orb(path, size=32, core=(190, 240, 255), glow=(40, 130, 255)):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    for i in range(12, 0, -1):
        r = c * i / 12
        a = int(255 * (1 - i / 12) ** 0.6 * 0.55)
        ell(d, c, c, r, r, glow + (a,))
    ell(d, c, c, c * 0.45, c * 0.45, core + (255,), (255, 255, 255, 255), 0.5)
    ell(d, c * 0.85, c * 0.8, c * 0.12, c * 0.12, (255, 255, 255, 255))
    fin(img, size, size).save(os.path.join(OUT, path))

def crescent(path, w, h, layers, drops=None):
    img = new(w, h)
    for shrink, col in layers:
        m = Image.new("L", img.size, 0)
        md = ImageDraw.Draw(m)
        cx, cy = w * 0.36, h / 2
        ell(md, cx, cy, w * 0.60 - shrink * 1.2, h * 0.50 - shrink, 255)
        ell(md, w * 0.12, cy, w * 0.50 - shrink * 0.2, h * 0.58 - shrink * 0.4, 0)
        layer = Image.new("RGBA", img.size, col)
        img.paste(layer, (0, 0), m)
    if drops:
        d = ImageDraw.Draw(img)
        for x, y, r in drops:
            ell(d, x, y, r, r, (235, 250, 255, 255), (80, 170, 255, 255), 0.8)
    fin(img, w, h).filter(ImageFilter.GaussianBlur(0.4)).save(os.path.join(OUT, path))

def icon_burn(path):
    img = new(24, 24); d = ImageDraw.Draw(img)
    poly(d, [(12, 2), (18, 10), (20, 16), (16, 22), (8, 22), (4, 16), (6, 9), (10, 12)], (255, 120, 20, 255), OL)
    poly(d, [(12, 10), (16, 16), (14, 21), (10, 21), (8, 16)], (255, 220, 70, 255))
    fin(img, 24, 24).save(os.path.join(OUT, path))

def icon_slow(path):
    img = new(24, 24); d = ImageDraw.Draw(img)
    ell(d, 12, 12, 10, 10, (60, 140, 255, 255), OL, 1.2)
    poly(d, [(7, 9), (17, 9), (12, 18)], (230, 245, 255, 255))
    fin(img, 24, 24).save(os.path.join(OUT, path))

def trap(path):
    img = new(64, 24); d = ImageDraw.Draw(img)
    ell(d, 32, 19, 30, 5, (20, 60, 140, 255), OL, 1.0)
    ell(d, 32, 18, 26, 3.6, (60, 160, 255, 255))
    ell(d, 32, 18, 17, 2.2, (170, 230, 255, 255))
    for x in (10, 20, 32, 44, 54):
        h = 8 + (x % 7)
        poly(d, [(x - 3, 18), (x + 3, 18), (x, 18 - h)], (130, 215, 255, 255), OL)
    fin(img, 64, 24).save(os.path.join(OUT, path))

# ------------------------------------------------------------------ arena
def stone_tile(path):
    random.seed(7)
    img = Image.new("RGBA", (256, 256), (40, 42, 56, 255))  # 4x scale (64px tile)
    d = ImageDraw.Draw(img)
    for row in range(4):
        off = 0 if row % 2 == 0 else 32
        for col in range(-1, 3):
            x0 = col * 64 + off * 4 // 4 * 2 // 2
            x0 = col * 128 + off * 4 // 2 - (0 if off == 0 else 0)
            x0 = (col * 32 + off) * 4
            base = random.randint(78, 104)
            tint = (base, base + 4, base + 16, 255)
            for wrap in (-256, 0, 256):
                d.rectangle([x0 + wrap + 4, row * 64 + 4, x0 + wrap + 124, row * 64 + 60], fill=tint)
                d.line([x0 + wrap + 4, row * 64 + 5, x0 + wrap + 124, row * 64 + 5], fill=(base + 28, base + 30, base + 42, 255), width=4)
                d.line([x0 + wrap + 4, row * 64 + 59, x0 + wrap + 124, row * 64 + 59], fill=(base - 26, base - 24, base - 12, 255), width=4)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, path))

def grass_top(path):
    random.seed(3)
    img = new(64, 20); d = ImageDraw.Draw(img)
    rrect(d, -2, 9, 66, 24, 0, (58, 140, 70, 255))
    d.rectangle([0, P(9), P(64), P(12)], fill=(96, 190, 96, 255))
    d.rectangle([0, P(17), P(64), P(20)], fill=(36, 96, 54, 255))
    for x in range(0, 64, 4):
        h = random.randint(3, 7)
        for wrap in (-64, 0, 64):
            poly(d, [(x + wrap, 10), (x + wrap + 3, 10), (x + wrap + 1.5, 10 - h)], (110, 205, 100, 255))
    fin(img, 64, 20).save(os.path.join(OUT, path))

def background(path):
    W, H = 1280, 720
    img = Image.new("RGBA", (W, H))
    px = img.load()
    top, bot = (14, 16, 44), (92, 52, 110)
    for y in range(H):
        t = y / H
        c = tuple(int(top[i] + (bot[i] - top[i]) * t ** 1.3) for i in range(3)) + (255,)
        for x in range(W):
            px[x, y] = c
    d = ImageDraw.Draw(img)
    random.seed(11)
    for _ in range(140):
        x, y = random.randint(0, W), random.randint(0, 330)
        r = random.choice((1, 1, 1, 2))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 240, random.randint(120, 255)))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([930, 70, 1130, 270], fill=(255, 240, 200, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.ellipse([985, 125, 1075, 215], fill=(255, 248, 225, 255))
    d.ellipse([1010, 140, 1030, 160], fill=(235, 225, 200, 255))
    for base, amp, col, ph in ((470, 70, (44, 36, 78, 255), 0.0), (540, 55, (30, 26, 58, 255), 1.7)):
        pts = [(0, H)]
        for x in range(0, W + 8, 8):
            pts.append((x, base - amp * (0.5 + 0.5 * math.sin(x / 130 + ph)) - 28 * math.sin(x / 47 + ph * 2) ** 2))
        pts.append((W, H))
        d.polygon(pts, fill=col)
    for x in range(30, W, 70):  # pine silhouettes
        h = random.randint(60, 120)
        y0 = 610
        d.polygon([(x, y0 - h), (x - 22, y0), (x + 22, y0)], fill=(18, 18, 38, 255))
        d.polygon([(x, y0 - h - 18), (x - 15, y0 - h * 0.45), (x + 15, y0 - h * 0.45)], fill=(18, 18, 38, 255))
    img.save(os.path.join(OUT, path))


def coin(path):
    img = new(24, 24); d = ImageDraw.Draw(img)
    ell(d, 12, 12, 10, 10, (238, 192, 62, 255), OL, 1.2)
    ell(d, 12, 12, 6.5, 6.5, (200, 150, 30, 255))
    ell(d, 12, 12, 5, 5, (252, 226, 110, 255))
    d.line([P(12), P(8), P(12), P(16)], fill=(178, 128, 30, 255), width=P(1.6))
    fin(img, 24, 24).save(os.path.join(OUT, path))

def shuriken(path):
    img = new(28, 28); d = ImageDraw.Draw(img)
    pts = []
    for i in range(8):
        r = 13 if i % 2 == 0 else 4.5
        a = math.pi / 4 * i - math.pi / 2
        pts.append((14 + r * math.cos(a), 14 + r * math.sin(a)))
    poly(d, pts, (70, 160, 255, 255), OL)
    ell(d, 14, 14, 3.2, 3.2, (0, 0, 0, 0)); ell(d, 14, 14, 2.2, 2.2, (220, 245, 255, 255))
    fin(img, 28, 28).save(os.path.join(OUT, path))

def arrow(path):
    img = new(44, 14); d = ImageDraw.Draw(img)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
    gd.line([P(2), P(7), P(34), P(7)], fill=(120, 255, 190, 170), width=P(7))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(S * 1.6)))
    d = ImageDraw.Draw(img)
    d.line([P(4), P(7), P(34), P(7)], fill=(235, 255, 240, 255), width=P(2))
    poly(d, [(33, 2), (43, 7), (33, 12)], (150, 255, 200, 255), OL)
    poly(d, [(2, 7), (8, 2), (9, 7), (8, 12)], (90, 200, 140, 255))
    fin(img, 44, 14).save(os.path.join(OUT, path))

def pad(path, base, rim, spikes, bubbles=False):
    img = new(64, 24); d = ImageDraw.Draw(img)
    ell(d, 32, 19, 30, 5, base, OL, 1.0)
    ell(d, 32, 18, 26, 3.6, rim)
    for x in (10, 20, 32, 44, 54):
        poly(d, [(x - 3.5, 18), (x + 3.5, 18), (x + (x % 5) - 2, 18 - (9 + x % 7))], spikes, OL)
    if bubbles:
        for x, y, r in ((14, 12, 3), (30, 8, 4), (47, 11, 3), (38, 15, 2)):
            ell(d, x, y, r, r, (190, 120, 255, 200), OL, 0.6)
    fin(img, 64, 24).save(os.path.join(OUT, path))

def icon_poison(path):
    img = new(24, 24); d = ImageDraw.Draw(img)
    poly(d, [(12, 2), (19, 13), (17, 20), (7, 20), (5, 13)], (160, 70, 210, 255), OL)
    ell(d, 9, 14, 2, 2, (230, 200, 255, 255)); ell(d, 14, 16, 1.4, 1.4, (230, 200, 255, 255))
    fin(img, 24, 24).save(os.path.join(OUT, path))

if __name__ == "__main__":
    if "--sheets" in sys.argv:   # placeholder character sheets; OFF by default so the real roster art is never overwritten
        for fid in ROSTER:
            make_sheet(fid)
    glow_orb("water_orb.png")
    glow_orb("shadow_ball.png", 40, (236, 190, 255), (140, 60, 210))
    coin("coin.png"); shuriken("shuriken.png"); arrow("arrow.png")
    crescent("fire_slash.png", 96, 64, [(0, (200, 40, 20, 235)), (5, (255, 120, 20, 240)), (11, (255, 220, 80, 245))])
    crescent("water_splash.png", 96, 64, [(0, (40, 110, 230, 220)), (5, (110, 200, 255, 235)), (11, (240, 252, 255, 245))],
             drops=[(80, 10, 3), (88, 30, 2.5), (78, 54, 3), (60, 4, 2)])
    crescent("gold_slash.png", 96, 64, [(0, (180, 120, 20, 235)), (5, (240, 190, 50, 240)), (11, (255, 240, 150, 245))])
    crescent("shadow_slash.png", 96, 64, [(0, (40, 10, 70, 235)), (5, (120, 50, 190, 240)), (11, (220, 160, 255, 245))])
    crescent("pink_slash.png", 96, 64, [(0, (200, 70, 120, 235)), (5, (250, 140, 180, 240)), (11, (255, 230, 240, 245))])
    crescent("steel_slash.png", 96, 64, [(0, (90, 96, 116, 235)), (5, (180, 188, 206, 240)), (11, (250, 252, 255, 245))])
    crescent("leaf_slash.png", 96, 64, [(0, (30, 100, 50, 235)), (5, (80, 180, 90, 240)), (11, (200, 255, 190, 245))])
    icon_burn("icon_burn.png"); icon_slow("icon_slow.png"); icon_poison("icon_poison.png")
    trap("trap.png")
    pad("leaf_trap.png", (30, 90, 44, 255), (70, 160, 80, 255), (96, 200, 100, 255))
    pad("poison_trap.png", (60, 24, 90, 255), (130, 60, 180, 255), (170, 90, 220, 255), True)
    stone_tile("stone_tile.png")
    grass_top("grass_top.png")
    background("background.png")
    print("done")
