"""Generate Marshadow art inspired by the supplied reference.
Run with: python tools/marshadow_test_art.py
Writes the production sheet plus separate preview/test images under assets/.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw

SCALE = 4
FRAME = 64
ROWS = [
    ("idle", 4),
    ("run", 6),
    ("jump", 2),
    ("dash", 2),
    ("attack", 4),
    ("hitstun", 2),
    ("ko", 3),
]
OUT = Path(__file__).resolve().parent.parent / "assets"

INK = (24, 25, 34, 255)
BODY = (91, 94, 106, 255)
BODY_LIGHT = (132, 135, 146, 255)
TEAL = (30, 143, 151, 255)
TEAL_LIGHT = (54, 181, 184, 255)
FLAME = (239, 226, 128, 255)
FLAME_LIGHT = (255, 244, 166, 255)
MASK = (35, 40, 51, 255)
ORANGE = (239, 111, 69, 255)
GOLD = (255, 225, 102, 255)


def xy(value):
    return int(round(value * SCALE))


def ellipse(draw, box, fill, outline=INK, width=1.4):
    bounds = tuple(xy(v) for v in box)
    draw.ellipse(bounds, fill=fill, outline=outline, width=xy(width) if outline else 1)


def polygon(draw, points, fill, outline=INK, width=1.3):
    points = [(xy(x), xy(y)) for x, y in points]
    draw.polygon(points, fill=fill)
    if outline:
        draw.line(points + [points[0]], fill=outline, width=xy(width), joint="curve")


def line(draw, points, fill, width=1.5):
    draw.line([(xy(x), xy(y)) for x, y in points], fill=fill, width=xy(width), joint="curve")


def make_frame(pose):
    image = Image.new("RGBA", (FRAME * SCALE, FRAME * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    bob = pose.get("bob", 0.0)
    lean = pose.get("lean", 0.0)
    crouch = pose.get("crouch", 0.0)
    cx = 32 + lean
    head_y = 28 + bob + crouch
    body_y = 45 + bob + crouch
    arm_f = pose.get("arm_f", (4, 0))
    arm_b = pose.get("arm_b", (-4, 1))
    leg_f = pose.get("leg_f", (3, 0))
    leg_b = pose.get("leg_b", (-3, 0))

    # Small flame-tipped tail behind the body.
    tail_x = cx + 12
    tail_y = body_y + 5
    line(d, [(cx + 7, body_y + 6), (tail_x + 4, tail_y + 3), (tail_x + 7, tail_y - 2)], BODY, 4.0)
    ellipse(d, (tail_x + 3, tail_y - 6, tail_x + 11, tail_y + 3), TEAL_LIGHT, width=1.0)
    polygon(d, [(tail_x + 5, tail_y - 5), (tail_x + 10, tail_y - 10),
                (tail_x + 9, tail_y - 3), (tail_x + 6, tail_y + 1)], FLAME, width=0.8)

    # Back arm and small feet; limbs stay stubby and ghost-like, not humanoid armor.
    bx, by = arm_b
    line(d, [(cx - 7, body_y - 1), (cx - 11 + bx, body_y + 2 + by)], BODY, 5.0)
    ellipse(d, (cx - 14 + bx, body_y - 1 + by, cx - 8 + bx, body_y + 5 + by), BODY_LIGHT, width=0.9)
    for dx, lift in (leg_b, leg_f):
        foot_x = cx + dx
        foot_y = body_y + 13 - lift
        line(d, [(foot_x, body_y + 7), (foot_x - 1, foot_y)], BODY, 5.0)
        ellipse(d, (foot_x - 4, foot_y - 2, foot_x + 3, foot_y + 2), BODY_LIGHT, width=0.8)

    # Rounded charcoal body with a soft lighter belly patch.
    ellipse(d, (cx - 10, body_y - 8, cx + 10, body_y + 13), BODY, width=1.5)
    ellipse(d, (cx - 5, body_y - 3, cx + 6, body_y + 11), BODY_LIGHT, outline=None)

    # Front arm and broad turquoise ghost-flame collar/ruff.
    fx, fy = arm_f
    line(d, [(cx + 7, body_y - 2), (cx + 12 + fx, body_y + fy)], BODY, 5.0)
    ellipse(d, (cx + 9 + fx, body_y - 3 + fy, cx + 16 + fx, body_y + 4 + fy), BODY_LIGHT, width=0.8)
    polygon(d, [(cx - 15, head_y + 8), (cx - 12, head_y + 14), (cx - 6, head_y + 11),
                (cx, head_y + 16), (cx + 7, head_y + 11), (cx + 13, head_y + 14),
                (cx + 16, head_y + 7), (cx + 9, head_y + 4), (cx - 8, head_y + 4)], TEAL, width=1.5)
    line(d, [(cx - 10, head_y + 11), (cx - 5, head_y + 8), (cx - 1, head_y + 11)], TEAL_LIGHT, 1.1)
    line(d, [(cx + 4, head_y + 11), (cx + 9, head_y + 8), (cx + 12, head_y + 10)], TEAL_LIGHT, 1.1)

    # Head/cloud silhouette: side curls and three flame wisps with pale tips.
    ellipse(d, (cx - 18, head_y - 10, cx - 7, head_y + 5), TEAL, width=1.5)
    ellipse(d, (cx + 7, head_y - 10, cx + 18, head_y + 5), TEAL, width=1.5)
    ellipse(d, (cx - 15, head_y - 13, cx + 15, head_y + 8), TEAL, width=1.5)
    line(d, [(cx - 14, head_y - 7), (cx - 18, head_y - 14), (cx - 15, head_y - 23),
             (cx - 10, head_y - 17), (cx - 7, head_y - 19)], FLAME, 5.2)
    line(d, [(cx - 14, head_y - 7), (cx - 18, head_y - 14), (cx - 15, head_y - 23)], TEAL, 3.0)
    line(d, [(cx + 13, head_y - 7), (cx + 18, head_y - 14), (cx + 15, head_y - 23),
             (cx + 10, head_y - 17), (cx + 7, head_y - 19)], FLAME, 5.2)
    line(d, [(cx + 13, head_y - 7), (cx + 18, head_y - 14), (cx + 15, head_y - 23)], TEAL, 3.0)
    line(d, [(cx - 5, head_y - 12), (cx - 6, head_y - 21), (cx - 2, head_y - 27),
             (cx + 2, head_y - 20), (cx + 7, head_y - 18)], FLAME_LIGHT, 5.0)
    line(d, [(cx - 5, head_y - 12), (cx - 6, head_y - 21), (cx - 2, head_y - 27)], TEAL, 2.8)
    # Repaint tip highlights for a luminous flame edge.
    line(d, [(cx - 17, head_y - 19), (cx - 15, head_y - 22)], FLAME_LIGHT, 1.7)
    line(d, [(cx + 17, head_y - 19), (cx + 15, head_y - 22)], FLAME_LIGHT, 1.7)

    # Face mask and large flame-colored eyes are the main recognition points.
    polygon(d, [(cx - 13, head_y - 1), (cx - 10, head_y - 9), (cx - 4, head_y - 11),
                (cx, head_y - 6), (cx + 4, head_y - 11), (cx + 10, head_y - 9),
                (cx + 13, head_y - 1), (cx + 9, head_y + 4), (cx, head_y + 5),
                (cx - 9, head_y + 4)], MASK, width=1.5)
    if pose.get("eyes_x"):
        for ex in (cx - 6, cx + 6):
            line(d, [(ex - 1.5, head_y - 4), (ex + 1.5, head_y - 1)], INK, 1.2)
            line(d, [(ex + 1.5, head_y - 4), (ex - 1.5, head_y - 1)], INK, 1.2)
    else:
        for ex in (cx - 6, cx + 6):
            ellipse(d, (ex - 3.1, head_y - 6, ex + 3.1, head_y + 1), ORANGE, width=0.8)
            ellipse(d, (ex - 1.7, head_y - 4.9, ex + 1.7, head_y - 0.2), GOLD, outline=None)
            ellipse(d, (ex - 0.7, head_y - 4.1, ex + 0.7, head_y - 1.4), FLAME_LIGHT, outline=None)
    # Red zig-zag brow marks echo the supplied reference.
    line(d, [(cx - 7, head_y - 11), (cx - 4, head_y - 8), (cx - 6, head_y - 6)], ORANGE, 1.8)
    line(d, [(cx + 7, head_y - 11), (cx + 4, head_y - 8), (cx + 6, head_y - 6)], ORANGE, 1.8)
    line(d, [(cx - 1, head_y + 6), (cx + 1, head_y + 5)], INK, 0.8)

    return image.resize((FRAME, FRAME), Image.Resampling.LANCZOS)


def build_poses():
    poses = {}
    poses["idle"] = [dict(bob=v) for v in (0, -0.6, -1, -0.4)]
    poses["run"] = []
    for i in range(6):
        phase = 2 * math.pi * i / 6
        poses["run"].append(dict(bob=-abs(math.cos(phase)), lean=2,
                                 leg_f=(math.sin(phase) * 3, max(0, math.cos(phase)) * 3),
                                 leg_b=(-math.sin(phase) * 3, max(0, -math.cos(phase)) * 3),
                                 arm_f=(0, math.sin(phase) * 2), arm_b=(0, -math.sin(phase) * 2)))
    poses["jump"] = [dict(bob=-2, leg_f=(4, 3), leg_b=(-4, 2), arm_f=(1, -2), arm_b=(-1, -2)),
                     dict(bob=0, leg_f=(4, 0), leg_b=(-4, 0), arm_f=(3, 1), arm_b=(-3, 1))]
    poses["dash"] = [dict(lean=4, bob=2, crouch=1, arm_f=(3, 0), arm_b=(-3, 0)),
                     dict(lean=5, bob=1, crouch=1, arm_f=(3, 1), arm_b=(-3, 1))]
    poses["attack"] = [dict(lean=-1, arm_f=(0, -1)),
                       dict(lean=1, arm_f=(4, -2), bob=-1),
                       dict(lean=2, arm_f=(7, -1), bob=-1),
                       dict(lean=0, arm_f=(2, 1))]
    poses["hitstun"] = [dict(lean=-3, bob=1, eyes_x=True, arm_f=(1, -4), arm_b=(-2, -4)),
                        dict(lean=-4, bob=2, eyes_x=True, arm_f=(2, -3), arm_b=(-2, -3))]
    poses["ko"] = [dict(lean=-3, bob=2, eyes_x=True),
                   dict(lean=-1, crouch=5, eyes_x=True),
                   dict(lean=0, crouch=8, eyes_x=True)]
    return poses


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    poses = build_poses()
    preview = make_frame(poses["idle"][0])
    preview.save(OUT / "marshadow_test_preview.png")

    sheet = Image.new("RGBA", (FRAME * 6, FRAME * len(ROWS)), (0, 0, 0, 0))
    for row, (anim, count) in enumerate(ROWS):
        for col, pose in enumerate(poses[anim][:count]):
            sheet.alpha_composite(make_frame(pose), (col * FRAME, row * FRAME))
    sheet.save(OUT / "marshadow_test_sheet.png")
    sheet.save(OUT / "marshadow_sheet.png")
    print(f"Wrote {OUT / 'marshadow_test_preview.png'}")
    print(f"Wrote {OUT / 'marshadow_test_sheet.png'} ({sheet.width}x{sheet.height})")
    print(f"Updated production sheet: {OUT / 'marshadow_sheet.png'}")


if __name__ == "__main__":
    main()
