"""The 8 roster sprites, drawn from parts at native 32x32. Colours/shapes follow the reference art."""
import math
from pixel_core import *

def A(p):
    b = p.get('bob', 0); l = p.get('lean', 0)
    return dict(b=b, l=l, hx=16 + l, hy=10 + b, tx=16 + l * 0.5, sh=15 + b)

def tri(art, pts, color, shade=False):
    art.add(m_poly(pts), color, shade)

def leg(art, p, key, hipx, hipy, color, foot_color, w=3, foot=(3, 2), foot_dx=1):
    dx, lift = p.get(key, (0, 0))
    fx, fy = hipx + dx, 29 - lift
    art.add(m_line((hipx, hipy), (fx, fy - 1), w), color, False)
    art.add(m_ell(fx + foot_dx, fy, foot[0], foot[1]), foot_color, True)
    return fx, fy

def rot(pts, ang, cx, cy):
    r = math.radians(ang); c, s = math.cos(r), math.sin(r)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]

def eyes_x(art, x, y):
    for ox in (x - 3, x + 2):
        art.px(ox, y, (20, 14, 30)); art.px(ox + 1, y + 1, (20, 14, 30)); art.px(ox + 1, y - 1, (20, 14, 30))
        art.px(ox - 1, y - 1, (20, 14, 30)); art.px(ox - 1, y + 1, (20, 14, 30))

# ------------------------------------------------------------------ GENGAR
def gengar(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy']
    PUR, DK, MID = (112, 82, 168), (72, 48, 120), (140, 108, 196)
    art = Art((26, 14, 46))
    for k, yy in enumerate((13, 18, 23)):                      # back spikes
        tri(art, [(tx - 8, yy + b), (tx - 14 + k, yy - 3 + b), (tx - 8, yy + 4 + b)], DK, True)
    art.add(m_ell(tx - 6 + p.get('lb', (0, 0))[0] * .5, 28 - p.get('lb', (0, 0))[1], 3, 2), DK)
    art.add(m_ell(tx + 6 + p.get('lf', (0, 0))[0] * .5, 28 - p.get('lf', (0, 0))[1], 3, 2), DK)
    ab = p.get('ab', (-2, 5))
    art.add(m_line((tx - 7, 18 + b), (tx - 7 + ab[0], 18 + b + min(ab[1], 4)), 2), PUR, False)
    art.add(m_ell(tx, 21 + b, 10, 7), PUR)                     # body
    art.add(m_ell(hx, 14 + b, 10, 7), PUR)                     # head (merged)
    art.add(m_ell(tx + 2, 23 + b, 5, 3), MID, False)           # belly sheen
    tri(art, [(hx - 9, 11 + b), (hx - 8, 3 + b), (hx - 2, 8 + b)], PUR, True)    # ears
    tri(art, [(hx + 2, 8 + b), (hx + 8, 3 + b), (hx + 9, 11 + b)], PUR, True)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, 14 + b)
    else:
        for ex in (-6, 1):                                      # slanted red eyes
            art.add(m_poly([(hx + ex, 12 + b), (hx + ex + 5, 14 + b), (hx + ex + 5, 15 + b), (hx + ex, 14 + b)]), (24, 10, 36), False)
            art.add(m_poly([(hx + ex + 1, 13 + b), (hx + ex + 5, 14 + b), (hx + ex + 4, 15 + b), (hx + ex + 1, 14 + b)]), (240, 90, 110), False)
    art.add(m_ell(hx + 1, 19 + b, 7, 3), (46, 18, 50), False)   # grin
    for x in range(-5, 7, 2):
        art.px(hx + 1 + x, 17 + b, (255, 255, 255)); art.px(hx + 2 + x, 21 + b, (255, 255, 255))
    af = p.get('af', (2, 5))
    art.add(m_line((tx + 8, 19 + b), (tx + 8 + af[0] * .7, 19 + b + min(af[1], 5) * .8), 2), PUR, False)
    art.add(m_ell(tx + 8 + af[0] * .7, 19 + b + min(af[1], 5) * .8, 2, 2), MID, False)
    return art.render()

# ------------------------------------------------------------------ MARSHADOW
def marshadow(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy']
    TEAL, TEAL2, YEL = (40, 150, 150), (26, 104, 118), (246, 224, 120)
    GRAY, GRAY2 = (112, 112, 126), (66, 66, 82)
    art = Art((14, 20, 30))
    tri(art, [(tx - 4, 25 + b), (tx - 12, 21 + b), (tx - 9, 24 + b), (tx - 13, 27 + b), (tx - 5, 28 + b)], TEAL2)   # wisp tail
    art.px(tx - 11, 20 + b, YEL); art.px(tx - 12, 19 + b, YEL)
    ab = p.get('ab', (-2, 5))
    art.add(m_line((tx - 4, 20 + b), (tx - 4 + ab[0], 20 + b + min(ab[1], 5)), 2), GRAY2, False)
    art.add(m_ell(tx, 25 + b, 5, 5), GRAY2)                                    # lower body (dark)
    art.add(m_ell(tx, 21 + b, 5, 5), GRAY)                                     # upper body
    for fx_, key in ((-2, 'lb'), (3, 'lf')):
        dx, lift = p.get(key, (0, 0))
        art.add(m_ell(tx + fx_ + dx * .6, 29 - lift, 2, 1), GRAY2)
    art.add(m_ell(hx, hy + 1, 8, 6), TEAL)                                      # head
    art.add(m_ell(hx - 7, hy - 3, 3, 3), TEAL); art.add(m_ell(hx + 7, hy - 3, 3, 3), TEAL)    # hair lobes
    tri(art, [(hx - 9, hy - 5), (hx - 8, hy - 11), (hx - 5, hy - 6)], YEL)      # flame wisps
    tri(art, [(hx + 5, hy - 6), (hx + 8, hy - 11), (hx + 9, hy - 5)], YEL)
    art.add(m_ell(hx + 1, hy + 2, 6, 4), (18, 30, 42), False)                  # dark face
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, hy + 2)
    else:
        for ex in (-3, 2):
            art.add(m_rect(hx + ex, hy, hx + ex + 1, hy + 3), (244, 96, 40), False)
            art.px(hx + ex, hy + 2, (255, 214, 90))
    art.add(m_ell(hx, hy + 6, 6, 2), TEAL2)                                     # ruff
    af = p.get('af', (2, 5))
    art.add(m_line((tx + 4, 19 + b), (tx + 4 + af[0] * .7, 19 + b + af[1] * .7), 2), GRAY, False)
    art.add(m_ell(tx + 4 + af[0] * .7, 19 + b + af[1] * .7, 2, 2), GRAY, True)
    return art.render()

# ------------------------------------------------------------------ GHOLDENGO
def gholdengo(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 1
    GOLD = (240, 200, 70); BELT = (46, 36, 40); SIL = (205, 210, 222)
    art = Art((70, 46, 14))
    ab = p.get('ab', (-2, 5))
    bh = (tx - 4 + ab[0] * 1.2, 16 + b + ab[1] * 1.1)
    art.add(m_line((tx - 3, 15 + b), bh, 2), GOLD, False)
    art.add(m_poly([(bh[0] - 2, bh[1] - 1), (bh[0] + 1, bh[1] - 1), (bh[0] + 1, bh[1] + 2), (bh[0] - 2, bh[1] + 2)]), GOLD, True)
    leg(art, p, 'lb', tx - 2, 23 + b, GOLD, GOLD, 3, (3, 1), 0)
    for (x0, y0, x1, y1) in ((hx - 1, hy - 3, hx - 5, hy - 10), (hx + 1, hy - 3, hx - 2, hy - 11), (hx + 2, hy - 3, hx + 1, hy - 9)):
        art.add(m_line((x0, y0), (x1, y1), 2), GOLD, False)                                   # long head fronds
        art.add(m_ell(x1, y1, 1.5, 1.5), GOLD, False)
    art.add(m_rect(tx - 3, hy + 3, tx + 3, 23 + b), GOLD)                                     # tube torso
    art.add(m_rect(tx - 4, 21 + b, tx + 4, 25 + b), GOLD)                                     # pelvis
    art.add(m_rect(tx - 4, 22 + b, tx + 4, 23 + b), BELT, False)                              # belt
    art.add(m_rect(tx + 0, 22 + b, tx + 1, 23 + b), SIL, False)                               # buckle
    leg(art, p, 'lf', tx + 2, 24 + b, GOLD, GOLD, 3, (3, 1), 1)
    art.add(m_ell(hx, hy, 5, 4), GOLD)                                                         # head
    DK = (70, 46, 20)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, hy)
    else:
        art.px(hx - 1, hy - 1, DK); art.px(hx + 2, hy - 1, DK)                                 # smiling face
        art.px(hx - 2, hy + 1, DK); art.px(hx - 1, hy + 2, DK); art.px(hx, hy + 2, DK); art.px(hx + 1, hy + 2, DK); art.px(hx + 2, hy + 1, DK)
    af = p.get('af', (2, 5))
    hand = (tx + 4 + af[0] * 1.2, 16 + b + af[1] * 1.0)
    if 'wpn' in p:                                                                             # surfboard
        w = rot([(hand[0] - 3, hand[1] + 2), (hand[0] + 3, hand[1] + 2), (hand[0] + 4, hand[1] - 10), (hand[0], hand[1] - 15), (hand[0] - 4, hand[1] - 10)], p['wpn'], hand[0], hand[1])
        art.add(m_poly(w), (74, 200, 214), True)
        art.add(m_poly(rot([(hand[0] - 1, hand[1] - 1), (hand[0] + 1, hand[1] - 1), (hand[0] + 1, hand[1] - 12), (hand[0] - 1, hand[1] - 12)], p['wpn'], hand[0], hand[1])), (240, 250, 250), False)
    art.add(m_line((tx + 3, 15 + b), hand, 2), GOLD, False)
    art.add(m_poly([(hand[0] - 1, hand[1] - 2), (hand[0] + 3, hand[1] - 1), (hand[0] + 3, hand[1] + 2), (hand[0] - 1, hand[1] + 2)]), GOLD, True)
    art.px(hand[0] + 4, hand[1] - 1, GOLD); art.px(hand[0] + 4, hand[1] + 1, GOLD)               # fingers
    return art.render()

# ------------------------------------------------------------------ TINKATON
def tinkaton(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 2
    PINK, LPINK, WHITE = (238, 118, 164), (252, 214, 230), (255, 245, 250)
    HAM, HAM2, CREAM = (128, 104, 176), (92, 72, 138), (248, 232, 190)
    art = Art((70, 24, 56))
    tri(art, [(hx - 5, hy - 3), (hx - 8, hy - 11), (hx - 4, hy - 11), (hx - 1, hy - 3)], PINK, True)   # ears
    tri(art, [(hx + 1, hy - 3), (hx + 3, hy - 12), (hx + 7, hy - 10), (hx + 5, hy - 3)], PINK, True)
    tri(art, [(hx - 8, hy - 11), (hx - 4, hy - 11), (hx - 6, hy - 8)], WHITE)
    tri(art, [(hx + 3, hy - 12), (hx + 7, hy - 10), (hx + 5, hy - 8)], WHITE)
    ab = p.get('ab', (-2, 5))
    art.add(m_line((tx - 3, 19 + b), (tx - 3 + ab[0], 19 + b + ab[1] * .8), 2), PINK, False)
    leg(art, p, 'lb', tx - 2, 24 + b, PINK, LPINK, 2, (2, 1), 0)
    art.add(m_ell(tx, 22 + b, 5, 4), PINK)
    art.add(m_ell(tx, 25 + b, 6, 3), LPINK)                                                          # fluffy skirt
    leg(art, p, 'lf', tx + 2, 25 + b, PINK, LPINK, 2, (2, 1), 1)
    art.add(m_ell(hx, hy, 6, 5), PINK)                                                               # head
    art.add(m_ell(hx + 2, hy + 2, 3, 2), WHITE, False)                                               # muzzle
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 2, hy)
    else:
        art.add(m_rect(hx, hy - 1, hx + 1, hy + 1), (40, 20, 50), False); art.add(m_rect(hx + 4, hy - 1, hx + 5, hy + 1), (40, 20, 50), False)
        art.px(hx, hy - 1, (255, 255, 255)); art.px(hx + 4, hy - 1, (255, 255, 255))
    af = p.get('af', (2, 5))
    hand = (tx + 5 + af[0] * .8, 21 + b + af[1] * .5)
    ang = p.get('wpn', 38)
    art.add(m_line((tx + 3, 20 + b), hand, 2), PINK, False)
    ex, ey = hand[0] + math.sin(math.radians(ang)) * 8, hand[1] - math.cos(math.radians(ang)) * 8
    art.add(m_line(hand, (ex, ey), 1), HAM2, False)
    head = rot([(ex - 5, ey - 4), (ex + 5, ey - 4), (ex + 5, ey + 4), (ex - 5, ey + 4)], ang, ex, ey)
    art.add(m_poly(head), HAM, True)
    art.add(m_poly(rot([(ex - 6, ey - 1), (ex + 6, ey - 1), (ex + 6, ey + 1), (ex - 6, ey + 1)], ang, ex, ey)), HAM2, False)
    art.add(m_poly(rot([(ex - 2, ey - 4), (ex + 2, ey - 4), (ex, ey - 8)], ang, ex, ey)), CREAM, False)
    art.add(m_ell(hand[0], hand[1], 2, 2), PINK, False)
    return art.render()

# ------------------------------------------------------------------ GRENINJA
def greninja(p):
    a = A(p); b = a['b'] + 1; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 1
    NAVY, DNAVY, PALE, PINK, YEL = (46, 70, 150), (28, 40, 100), (196, 214, 238), (228, 84, 120), (250, 226, 110)
    art = Art((12, 16, 44))
    tri(art, [(hx - 3, hy + 3), (hx - 9, hy + 1), (hx - 15, hy + 6), (hx - 12, hy + 9), (hx - 6, hy + 6), (hx - 1, hy + 7)], PINK, True)   # tongue scarf
    tri(art, [(hx - 3, hy - 2), (hx - 11, hy - 7), (hx - 5, hy + 2)], DNAVY, True)                                                           # head fins
    tri(art, [(hx - 2, hy - 3), (hx - 6, hy - 10), (hx, hy - 3)], DNAVY, True)
    ab = p.get('ab', (-2, 5))
    art.add(m_line((tx - 3, 17 + b), (tx - 3 + ab[0], 17 + b + ab[1] * .9), 2), DNAVY, False)
    art.add(m_ell(tx - 3 + ab[0], 17 + b + ab[1] * .9, 2, 2), PALE, False)
    leg(art, p, 'lb', tx - 2, 22 + b, DNAVY, PALE, 3, (3, 2), 0)
    art.add(m_ell(tx, 18 + b, 4, 6), NAVY)                                                                                                   # torso
    art.add(m_ell(tx + 1, 19 + b, 2, 4), PALE, False)
    leg(art, p, 'lf', tx + 1, 22 + b, NAVY, PALE, 3, (3, 2), 1)
    art.add(m_ell(hx, hy, 6, 5), NAVY)                                                                                                       # head
    art.add(m_ell(hx + 5, hy + 2, 2, 2), PALE, False)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 2, hy)
    else:
        art.add(m_poly([(hx, hy - 1), (hx + 6, hy - 2), (hx + 6, hy), (hx + 1, hy + 1)]), YEL, False)
        art.px(hx + 4, hy - 1, (20, 14, 30))
    art.add(m_poly([(hx - 2, hy + 4), (hx + 4, hy + 5), (hx + 3, hy + 7), (hx - 3, hy + 6)]), PINK, False)   # scarf front
    af = p.get('af', (2, 5))
    hand = (tx + 3 + af[0], 17 + b + af[1] * .9)
    art.add(m_line((tx + 3, 17 + b), hand, 2), NAVY, False)
    art.add(m_ell(hand[0], hand[1], 2, 2), PALE, False)
    art.px(tx + 3 + af[0] * .5, 17 + b + af[1] * .4 - 1, YEL)
    return art.render()

# ------------------------------------------------------------------ SCIZOR
def claw(art, x, y, scale=1.0, ang=0, main=(200, 50, 60)):
    def pts(lst):
        return rot([(x + px_ * scale, y + py_ * scale) for px_, py_ in lst], ang, x, y)
    art.add(m_poly(pts([(-2, -1), (9, -6), (11, -3), (3, 0)])), main, True)             # upper jaw
    art.add(m_poly(pts([(-2, 1), (9, 6), (11, 3), (3, 0)])), main, True)                # lower jaw
    art.add(m_poly(pts([(3, 0), (9, -3), (9, 3)])), (24, 14, 26), False)               # mouth
    art.add(m_ell(x, y, 3.5 * scale, 3.5 * scale), main, True)
    for k in (5, 8):
        art.add(m_poly(pts([(k, -3), (k + 1, -1), (k - 1, -1)])), (250, 240, 220), False)

def scizor(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 2
    RED, DRED, GRAY, PALE = (200, 48, 58), (132, 28, 44), (82, 82, 100), (200, 222, 240)
    art = Art((38, 10, 22))
    tri(art, [(tx - 1, 13 + b), (tx - 8, 6 + b), (tx - 8, 14 + b)], PALE, True)                # wing
    ab = p.get('ab', (-2, 5))
    bh = (tx - 6 + ab[0] * .5, 17 + b + ab[1] * .3)
    art.add(m_line((tx - 2, 15 + b), bh, 2), DRED, False)
    claw(art, bh[0], bh[1], 0.8, -25, DRED)                                                    # far claw
    leg(art, p, 'lb', tx - 1, 24 + b, DRED, GRAY, 2, (2, 1), 0)
    art.add(m_ell(tx, 24 + b, 3, 3), GRAY)                                                     # abdomen
    art.add(m_ell(tx, 18 + b, 4, 6), RED)                                                      # thorax
    art.add(m_ell(tx + 1, 18 + b, 2, 4), GRAY, False)
    leg(art, p, 'lf', tx + 1, 24 + b, RED, GRAY, 2, (2, 1), 1)
    tri(art, [(hx - 2, hy - 4), (hx + 1, hy - 9), (hx + 3, hy - 4)], RED, True)
    art.add(m_ell(hx, hy, 4, 5), RED)
    art.add(m_poly([(hx, hy - 2), (hx + 4, hy - 1), (hx + 4, hy + 3), (hx, hy + 3)]), (30, 24, 34), False)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 2, hy)
    else:
        art.px(hx + 2, hy, (255, 245, 150)); art.px(hx + 4, hy, (255, 245, 150))
    af = p.get('af', (2, 5))
    fh = (tx + 8 + af[0] * .9, 17 + b + af[1] * .5)
    art.add(m_line((tx + 3, 15 + b), fh, 2), RED, False)
    claw(art, fh[0], fh[1], 1.0, p.get('wpn', 0) * 0.25 - 5, RED)                              # main claw (forward)
    return art.render()

# ------------------------------------------------------------------ DECIDUEYE
def decidueye(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 1
    BROWN, DBROWN, GREEN, DGREEN = (170, 116, 72), (120, 76, 50), (62, 150, 92), (34, 98, 66)
    CREAM, ORANGE, TALON = (242, 234, 214), (236, 126, 44), (60, 56, 64)
    art = Art((32, 20, 18))
    art.add(m_poly([(tx - 3, 11 + b), (tx - 7, 4 + b), (tx - 11, 7 + b), (tx - 14, 12 + b), (tx - 15, 18 + b), (tx - 11, 24 + b), (tx - 4, 23 + b)]), BROWN, True)   # big back wing
    for k, (fx_, fy_) in enumerate(((-13, 9), (-14, 14), (-12, 19), (-8, 22))):
        art.px(tx + fx_, fy_ + b, CREAM); art.px(tx + fx_ + 1, fy_ + b, CREAM)                 # pale feather tips
    for k, (fx_, fy_) in enumerate(((-10, 8), (-11, 13), (-9, 18))):
        art.px(tx + fx_, fy_ + b, ORANGE)                                                      # orange wing marks
    leg(art, p, 'lb', tx - 2, 23 + b, CREAM, TALON, 2, (3, 1), 0)
    leg(art, p, 'lf', tx + 2, 23 + b, CREAM, TALON, 2, (3, 1), 1)
    art.add(m_ell(tx, 18 + b, 5, 7), GREEN)                                                    # leaf-cloak body
    art.add(m_ell(tx + 1, 19 + b, 3, 5), CREAM, False)
    for (ox, oy) in ((1, 16), (2, 17), (1, 18), (2, 19)):
        art.px(tx + ox, oy + b, ORANGE)                                                        # crossed-arrow chest mark
    tri(art, [(hx - 7, hy), (hx - 10, hy - 3), (hx - 5, hy - 4)], DGREEN, True)                # hood tail
    art.add(m_ell(hx, hy, 6, 5), GREEN)
    tri(art, [(hx - 1, hy - 4), (hx, hy - 9), (hx + 2, hy - 4)], CREAM)                        # white crest feather
    art.add(m_ell(hx + 2, hy + 1, 4, 3), (36, 26, 30), False)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 2, hy + 1)
    else:
        art.px(hx + 1, hy + 1, (255, 120, 60)); art.px(hx + 4, hy + 1, (255, 120, 60))
    af = p.get('af', (2, 5))
    hand = (tx + 4 + af[0] * 1.1, 15 + b + af[1] * .7)
    art.add(m_poly([(tx + 3, 13 + b), (hand[0], hand[1] - 2), (hand[0] + 2, hand[1] + 1), (tx + 3, 18 + b)]), BROWN, True)   # front wing-arm
    art.add(m_ell(hand[0], hand[1], 3, 2), CREAM, True)
    art.px(hand[0] - 2, hand[1], ORANGE)
    if 'wpn' in p and p['wpn'] > 0:                                                            # bowstring flourish
        art.add(m_line((hand[0] + 3, hand[1] - 6), (hand[0] + 3, hand[1] + 6), 1), (120, 255, 190), False)
    return art.render()

# ------------------------------------------------------------------ BLAZIKEN
def blaziken(p):
    a = A(p); b = a['b']; tx, hx, hy = a['tx'], a['hx'], a['hy'] + 1
    RED, DRED, CREAM, YEL, ORG, GRAYC = (216, 66, 44), (150, 40, 38), (244, 230, 204), (252, 214, 80), (252, 150, 44), (84, 78, 90)
    art = Art((46, 14, 14))
    def flame_leg(key, hipx, w):
        dx, lift = p.get(key, (0, 0)); fx = hipx + dx; fy = 29 - lift
        art.add(m_line((hipx, 20 + b), (fx, fy - 4), w), RED, False)
        art.add(m_poly([(fx - 3, fy - 5), (fx - 4, fy - 1), (fx - 2, fy - 2), (fx - 1, fy + 1), (fx + 1, fy - 2), (fx + 3, fy + 1), (fx + 4, fy - 5)]), YEL, True)
        art.add(m_poly([(fx - 2, fy - 4), (fx, fy - 7), (fx + 2, fy - 4)]), ORG, False)
    flame_leg('lb', tx - 2, 3)
    ab = p.get('ab', (-2, 5))
    bh = (tx - 3 + ab[0], 15 + b + ab[1] * .9)
    art.add(m_line((tx - 3, 14 + b), bh, 2), DRED, False)
    art.add(m_ell(bh[0], bh[1], 2, 2), YEL, False)
    art.add(m_ell(tx, 16 + b, 4, 6), RED)                                                        # torso
    art.add(m_ell(tx + 1, 13 + b, 3, 3), CREAM, False)
    art.add(m_ell(tx + 1, 20 + b, 3, 2), YEL, False)
    flame_leg('lf', tx + 2, 3)
    tri(art, [(hx - 3, hy - 3), (hx - 11, hy - 6), (hx - 9, hy - 2), (hx - 13, hy + 1), (hx - 5, hy + 2)], CREAM, True)    # head plumes
    art.add(m_ell(hx, hy, 5, 4), CREAM)
    art.add(m_poly([(hx + 1, hy - 2), (hx + 5, hy - 1), (hx + 5, hy + 2), (hx + 1, hy + 3)]), RED, False)
    art.add(m_poly([(hx + 5, hy), (hx + 9, hy + 1), (hx + 5, hy + 3)]), YEL, False)             # beak
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 2, hy)
    else:
        art.px(hx + 3, hy, (30, 20, 24)); art.px(hx + 2, hy - 1, (252, 230, 130))
    af = p.get('af', (2, 5))
    hand = (tx + 3 + af[0], 14 + b + af[1] * .9)
    art.add(m_line((tx + 3, 14 + b), hand, 2), RED, False)
    art.add(m_ell(hand[0], hand[1], 2.5, 2.5), GRAYC, True)
    art.add(m_poly([(hand[0] - 2, hand[1] - 1), (hand[0], hand[1] - 5), (hand[0] + 2, hand[1] - 1)]), YEL, False)
    art.px(hand[0], hand[1] - 2, (255, 255, 230))
    return art.render()

ROSTER = {"gholdengo": gholdengo, "marshadow": marshadow, "tinkaton": tinkaton, "greninja": greninja,
          "scizor": scizor, "decidueye": decidueye, "blaziken": blaziken, "gengar": gengar}
