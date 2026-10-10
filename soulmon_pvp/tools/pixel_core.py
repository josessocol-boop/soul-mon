"""Tiny pixel-art toolkit: flat parts -> auto cel-shading -> 1px outline. No anti-aliasing anywhere."""
from PIL import Image, ImageDraw
import math

N = 32          # native frame size (rendered 2x -> 64px game frames)
R = lambda v: int(round(v))

def lerp(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def tones(base):
    """(base, highlight, shadow): highlight warms up, shadow cools down - classic pixel-art hue shift."""
    return base, lerp(base, (255, 245, 205), 0.38), lerp(base, (34, 20, 74), 0.42)

def blank(size=N):
    return Image.new('L', (size, size), 0)

def m_ell(cx, cy, rx, ry, size=N):
    m = blank(size); px = m.load()
    for y in range(size):
        for x in range(size):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                px[x, y] = 255
    return m

def m_poly(pts, size=N):
    m = blank(size)
    ImageDraw.Draw(m).polygon([(R(x), R(y)) for x, y in pts], fill=255)
    return m

def m_line(p0, p1, w=1, size=N):
    m = blank(size)
    ImageDraw.Draw(m).line([R(p0[0]), R(p0[1]), R(p1[0]), R(p1[1])], fill=255, width=w)
    return m

def m_rect(x0, y0, x1, y1, size=N):
    m = blank(size)
    ImageDraw.Draw(m).rectangle([R(x0), R(y0), R(x1), R(y1)], fill=255)
    return m

def _max(a, b):
    from PIL import ImageChops
    return ImageChops.lighter(a, b)

def _sub(a, b):
    from PIL import ImageChops
    return ImageChops.subtract(a, b)

def shift(m, dx, dy):
    o = Image.new('L', m.size, 0)
    o.paste(m, (dx, dy))
    return o

def area(m):
    return sum(1 for v in m.getdata() if v)

class Art:
    """Collects parts in draw order; render() shades each part and adds the outline."""
    def __init__(self, outline=(20, 14, 32)):
        self.parts = []
        self.outline = outline

    def add(self, mask, color, shade=True, hi=None, lo=None):
        self.parts.append((mask, color, shade, hi, lo))
        return self

    def px(self, x, y, color):
        m = blank(); 
        if 0 <= R(x) < N and 0 <= R(y) < N:
            m.putpixel((R(x), R(y)), 255)
        return self.add(m, color, shade=False)

    def render(self, outline=True, size=N):
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        for mask, color, shade, hi, lo in self.parts:
            base, h, l = tones(color)
            out.paste(base + (255,), (0, 0), mask)
            if shade and area(mask) >= 14:
                top_left = _sub(mask, shift(mask, 1, 1))          # lit edge
                bot_right = _sub(mask, shift(mask, -1, -1))       # shadow edge
                bot_right = _sub(bot_right, top_left)
                out.paste((hi or h) + (255,), (0, 0), top_left)
                out.paste((lo or l) + (255,), (0, 0), bot_right)
        if outline:
            a = out.split()[3].point(lambda v: 255 if v else 0)
            ring = _max(_max(shift(a, 1, 0), shift(a, -1, 0)), _max(shift(a, 0, 1), shift(a, 0, -1)))
            ring = _sub(ring, a)
            out.paste(self.outline + (255,), (0, 0), ring)
        return out

def upscale(img, k=2):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)

# ----------------------------------------------------------------- poses
ROWS = ["idle", "run", "jump", "dash", "attack", "hitstun", "ko"]

def poses():
    A = {}
    A["idle"] = [dict(bob=b, af=(2, 5), ab=(-2, 5)) for b in (0, 0, 1, 1)]
    run = []
    for i in range(6):
        ph = 2 * math.pi * i / 6
        s_, c = math.sin(ph), math.cos(ph)
        run.append(dict(bob=1 if i % 3 == 1 else 0, lean=2, lf=(s_ * 4, max(0, c) * 2), lb=(-s_ * 4, max(0, -c) * 2),
                        af=(-s_ * 4, 4), ab=(s_ * 4, 4)))
    A["run"] = run
    A["jump"] = [dict(bob=-1, lf=(2, 3), lb=(-2, 4), af=(4, -3), ab=(-4, -2)),
                 dict(bob=0, lf=(4, 1), lb=(-4, 1), af=(5, 2), ab=(-5, 2), mouth=1)]
    A["dash"] = [dict(lean=4, bob=1, lf=(6, 1), lb=(-6, 2), af=(-4, 3), ab=(-6, 2), streak=1),
                 dict(lean=5, bob=2, lf=(7, 1), lb=(-7, 1), af=(-5, 3), ab=(-7, 2), streak=1)]
    A["attack"] = [dict(lean=-2, af=(-4, -1), ab=(-3, 4), lf=(2, 0), lb=(-2, 0), wpn=-70),
                   dict(lean=2, af=(8, 0), ab=(-3, 4), lf=(4, 0), lb=(-3, 0), wpn=15),
                   dict(lean=3, bob=1, af=(12, 1), ab=(-4, 3), lf=(5, 0), lb=(-4, 0), wpn=95, mouth=1),
                   dict(lean=1, af=(7, 3), ab=(-3, 4), lf=(3, 0), lb=(-2, 0), wpn=60)]
    A["hitstun"] = [dict(lean=-3, bob=1, eyes="x", af=(4, -4), ab=(-4, -3), lf=(3, 1), lb=(-1, 0), wpn=-30, mouth=1),
                    dict(lean=-4, bob=1, eyes="x", af=(5, -3), ab=(-5, -4), lf=(4, 1), lb=(-1, 0), wpn=-40, mouth=1)]
    A["ko"] = [dict(lean=-5, bob=1, eyes="x", af=(4, -4), ab=(-4, -3), lf=(4, 3), lb=(-2, 3), wpn=-50, mouth=1),
               dict(lean=0, eyes="x", af=(4, 2), ab=(-4, 2), wpn=-10),
               dict(lean=0, eyes="x", af=(3, 4), ab=(-3, 4), wpn=0)]
    return A

def seat_lying(img):
    """rotate 90deg CCW (head to the left) and re-seat on the ground line."""
    r = img.transpose(Image.ROTATE_90)
    bb = r.getbbox()
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    if bb:
        c = r.crop(bb)
        out.paste(c, (img.width // 2 - c.width // 2, 30 - c.height))
    return out

def make_sheet(draw_fn, path, extra=None):
    A = poses()
    sheet = Image.new('RGBA', (64 * 6, 64 * len(ROWS)), (0, 0, 0, 0))
    for row, anim in enumerate(ROWS):
        for col, pose in enumerate(A[anim]):
            fr = draw_fn(pose)
            if anim == "ko" and col >= 1:
                fr = seat_lying(fr)
            if pose.get("streak"):
                fr = add_streaks(fr)
            sheet.paste(upscale(fr), (col * 64, row * 64))
    sheet.save(path)
    return sheet

def add_streaks(img):
    d = ImageDraw.Draw(img)
    for y in (12, 18, 24):
        d.line([0, y, 5, y], fill=(255, 255, 255, 200))
    return img
