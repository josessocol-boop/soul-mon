"""Side-profile sprites for Alakazam, Lucario, Mewtwo and Toxicroak, drawn with the same toolkit as
pixel_characters.py (flat parts -> auto shading -> 1px outline, 32px native, shown 2x).
Colours and silhouettes follow the reference art in assets/references/ (the Pokemon these fighters stand for).
Usage (project root):  python3 tools/pixel_new_four.py   -> writes assets/<id>_sheet.png for the four fighters."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_core import *
from pixel_characters import A, tri, leg, eyes_x

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# ------------------------------------------------------------------ ALAKAZAM
ALA_Y, ALA_BR, ALA_SP = (246, 206, 64), (128, 74, 36), (222, 228, 236)
def alakazam(p):
    a = A(p); b = a['b']; tx, hx = a['tx'], a['hx']
    art = Art((70, 40, 16))
    leg(art, p, 'lb', tx - 2, 25 + b, ALA_Y, ALA_BR, 2, (3, 2), 0)
    art.add(m_ell(tx, 20 + b, 6, 7), ALA_Y)                              # torso
    art.add(m_ell(tx, 24 + b, 6, 3), ALA_BR)                             # brown trunks
    leg(art, p, 'lf', tx + 1, 25 + b, ALA_Y, ALA_BR, 2, (3, 2), 1)
    # head: big crown-shaped hair
    tri(art, [(hx - 7, 9 + b), (hx - 5, 0 + b), (hx - 1, 7 + b)], ALA_Y, True)
    tri(art, [(hx - 1, 7 + b), (hx + 3, -1 + b), (hx + 6, 7 + b)], ALA_Y, True)
    art.add(m_ell(hx, 11 + b, 8, 7), ALA_Y)
    art.add(m_ell(hx, 16 + b, 4, 2), ALA_BR)                             # brown beard
    for ex in (-3, 3):
        art.px(hx + ex, 10 + b, (30, 20, 20)); art.px(hx + ex + 1, 9 + b, (255, 255, 255))
    art.px(hx - 1, 15 + b, (30, 20, 20))
    # arms with spoons
    af = p.get('af', (2, 5)); ab = p.get('ab', (-2, 5))
    art.add(m_line((tx + 4, 17 + b), (tx + 4 + af[0], 17 + b + af[1]), 2), ALA_Y, False)
    hx2, hy2 = tx + 4 + af[0], 17 + b + af[1]
    art.add(m_ell(hx2 + 1, hy2 - 1, 2, 3), ALA_SP, False)                # spoon bowl
    art.add(m_line((tx - 4, 17 + b), (tx - 4 + ab[0], 17 + b + ab[1]), 2), ALA_BR, False)
    art.add(m_ell(tx - 4 + ab[0] - 1, 17 + b + ab[1] - 1, 2, 2), ALA_SP, False)
    return art.render()

# ------------------------------------------------------------------ LUCARIO
LUC_B, LUC_K, LUC_C, LUC_R = (52, 110, 196), (34, 34, 44), (236, 216, 160), (224, 40, 44)
def lucario(p):
    a = A(p); b = a['b']; tx, hx = a['tx'], a['hx']
    art = Art((14, 18, 30))
    # tail with black tip
    art.add(m_line((tx - 6, 22 + b), (tx - 12, 17 + b), 3), LUC_B, True)
    art.px(tx - 12, 16 + b, LUC_K); art.px(tx - 13, 17 + b, LUC_K)
    leg(art, p, 'lb', tx - 2, 25 + b, LUC_B, LUC_K, 3, (3, 2), 0)
    art.add(m_ell(tx, 20 + b, 6, 7), LUC_B)                              # torso
    art.add(m_ell(tx + 1, 21 + b, 3, 5), LUC_C, False)                   # cream chest
    leg(art, p, 'lf', tx + 1, 25 + b, LUC_B, LUC_K, 3, (3, 2), 1)
    # head with black ears and mask
    tri(art, [(hx - 6, 7 + b), (hx - 9, -3 + b), (hx - 2, 5 + b)], LUC_K, True)
    tri(art, [(hx + 2, 5 + b), (hx + 6, -4 + b), (hx + 6, 6 + b)], LUC_K, True)
    art.add(m_ell(hx, 11 + b, 7, 6), LUC_B)
    art.add(m_poly([(hx - 7, 8 + b), (hx + 6, 8 + b), (hx + 4, 11 + b), (hx - 6, 11 + b)]), LUC_K, False)
    art.add(m_ell(hx + 2, 15 + b, 4, 3), LUC_C, False)                   # cream muzzle
    art.add(m_ell(hx + 1, 19 + b, 2, 1), LUC_K, False)                   # nose
    for ex in (-3, 3):
        art.px(hx + ex, 10 + b, LUC_R); art.px(hx + ex + 1, 10 + b, LUC_R)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, 10 + b)
    # arms with dark paws
    af = p.get('af', (2, 5)); ab = p.get('ab', (-2, 5))
    art.add(m_line((tx - 4, 17 + b), (tx - 4 + ab[0], 17 + b + ab[1]), 3), LUC_B, False)
    art.add(m_ell(tx - 4 + ab[0], 17 + b + ab[1], 2, 2), LUC_K, False)
    art.add(m_line((tx + 4, 17 + b), (tx + 4 + af[0], 17 + b + af[1]), 3), LUC_B, False)
    art.add(m_ell(tx + 4 + af[0], 17 + b + af[1], 2, 2), LUC_K, False)
    return art.render()

# ------------------------------------------------------------------ MEWTWO
MEW_L, MEW_P, MEW_D, MEW_R = (214, 206, 232), (118, 72, 168), (58, 36, 92), (220, 50, 80)
def mewtwo(p):
    a = A(p); b = a['b']; tx, hx = a['tx'], a['hx']
    art = Art((30, 16, 50))
    # long tail, purple tip
    art.add(m_line((tx - 5, 23 + b), (tx - 11, 27 + b), 2), MEW_P, True)
    art.add(m_line((tx - 11, 27 + b), (tx - 13, 20 + b), 2), MEW_P, True)
    art.add(m_ell(tx - 13, 18 + b, 2, 2), MEW_P, True)
    leg(art, p, 'lb', tx - 2, 25 + b, MEW_L, MEW_P, 2, (3, 2), 0)
    art.add(m_ell(tx, 20 + b, 6, 7), MEW_L)                              # torso
    art.add(m_ell(tx + 2, 23 + b, 3, 3), MEW_P, False)                   # purple belly shade
    leg(art, p, 'lf', tx + 1, 25 + b, MEW_L, MEW_P, 2, (3, 2), 1)
    # head with swept crest
    tri(art, [(hx - 3, 6 + b), (hx + 7, -2 + b), (hx + 5, 7 + b)], MEW_L, True)
    art.add(m_ell(hx, 11 + b, 7, 6), MEW_L)
    tri(art, [(hx - 6, 9 + b), (hx - 9, 2 + b), (hx - 3, 7 + b)], MEW_P, True)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, 11 + b)
    else:
        art.add(m_poly([(hx - 4, 10 + b), (hx + 3, 9 + b), (hx + 3, 11 + b), (hx - 4, 12 + b)]), MEW_D, False)
        art.px(hx - 1, 10 + b, MEW_R); art.px(hx + 1, 10 + b, MEW_R)
    art.add(m_ell(hx + 1, 17 + b, 3, 1), MEW_P, False)                   # mouth line
    # arms
    af = p.get('af', (2, 5)); ab = p.get('ab', (-2, 5))
    art.add(m_line((tx + 4, 17 + b), (tx + 4 + af[0], 17 + b + af[1]), 2), MEW_L, False)
    art.add(m_line((tx - 4, 17 + b), (tx - 4 + ab[0], 17 + b + ab[1]), 2), MEW_P, False)
    return art.render()

# ------------------------------------------------------------------ TOXICROAK
TOX_N, TOX_P, TOX_R, TOX_Y, TOX_W = (42, 62, 122), (104, 66, 160), (214, 46, 60), (246, 214, 70), (236, 236, 240)
def toxicroak(p):
    a = A(p); b = a['b']; tx, hx = a['tx'], a['hx']
    art = Art((14, 18, 40))
    leg(art, p, 'lb', tx - 3, 25 + b, TOX_N, TOX_W, 3, (4, 2), 0)
    art.add(m_ell(tx, 21 + b, 8, 6), TOX_N)                              # wide body
    art.add(m_ell(tx + 1, 22 + b, 4, 3), TOX_P, False)                   # purple belly
    leg(art, p, 'lf', tx + 2, 25 + b, TOX_N, TOX_W, 3, (4, 2), 1)
    tri(art, [(hx - 6, 7 + b), (hx - 8, 1 + b), (hx - 2, 6 + b)], TOX_P, True)     # head ridges
    tri(art, [(hx + 2, 6 + b), (hx + 6, 0 + b), (hx + 7, 7 + b)], TOX_P, True)
    art.add(m_ell(hx, 12 + b, 8, 6), TOX_N)                              # wide head
    for sx in (tx - 4, tx + 3):                                          # purple dorsal spots
        art.add(m_ell(sx, 19 + b, 1.6, 1.6), TOX_P, False)
    art.add(m_poly([(hx - 8, 9 + b), (hx + 8, 9 + b), (hx + 6, 11 + b), (hx - 6, 11 + b)]), (24, 34, 74), False)
    art.add(m_ell(hx, 17 + b, 4, 3), TOX_R)                              # red throat sac
    art.px(hx - 1, 16 + b, (255, 170, 170))
    for ex in (-4, 3):
        art.px(hx + ex, 10 + b, TOX_Y); art.px(hx + ex + 1, 10 + b, TOX_Y)
    if p.get('eyes') == 'x':
        eyes_x(art, hx + 1, 10 + b)
    # arms with white claws
    af = p.get('af', (2, 5)); ab = p.get('ab', (-2, 5))
    art.add(m_line((tx + 5, 17 + b), (tx + 5 + af[0], 17 + b + af[1]), 3), TOX_N, False)
    for k in (-1, 0, 1):
        art.px(tx + 6 + af[0] + k, 17 + b + af[1] + 1, TOX_W)
    art.add(m_line((tx - 5, 17 + b), (tx - 5 + ab[0], 17 + b + ab[1]), 3), TOX_N, False)
    for k in (-1, 0, 1):
        art.px(tx - 6 + ab[0] + k, 17 + b + ab[1] + 1, TOX_W)
    return art.render()

NEW = {"alakazam": alakazam, "lucario": lucario, "mewtwo": mewtwo, "toxicroak": toxicroak}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets")
    for fid, fn in NEW.items():
        make_sheet(fn, os.path.join(out, fid + "_sheet.png"))
        print("wrote", fid)
