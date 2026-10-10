"""Generate character-specific roster sheets without touching effects or arena art.
Run from the project root: python tools/generate_roster_art.py
The approved Marshadow sheet is intentionally not generated here.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"
S = 4
FRAME = 64
SHEET_ROWS = (("idle", 4), ("run", 6), ("jump", 2), ("dash", 2),
              ("attack", 4), ("hitstun", 2), ("ko", 3))
INK = (27, 25, 35, 255)
WHITE = (246, 239, 218, 255)


def p(v):
    return int(round(v * S))


def ellipse(d, box, color, outline=INK, width=1.3):
    box = tuple(p(v) for v in box)
    d.ellipse(box, fill=color, outline=outline, width=p(width) if outline else 1)


def rect(d, box, color, outline=INK, width=1.2):
    box = tuple(p(v) for v in box)
    d.rectangle(box, fill=color, outline=outline, width=p(width) if outline else 1)


def roundrect(d, box, radius, color, outline=INK, width=1.2):
    box = tuple(p(v) for v in box)
    d.rounded_rectangle(box, radius=p(radius), fill=color, outline=outline,
                        width=p(width) if outline else 1)


def polygon(d, points, color, outline=INK, width=1.3):
    pts = [(p(x), p(y)) for x, y in points]
    d.polygon(pts, fill=color)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=p(width), joint="curve")


def line(d, points, color, width=1.5):
    d.line([(p(x), p(y)) for x, y in points], fill=color, width=p(width), joint="curve")


def base_pose(anim, index):
    if anim == "idle":
        return {"bob": (0, -0.6, -1, -0.4)[index], "phase": index / 4}
    if anim == "run":
        phase = index * math.tau / 6
        return {"bob": -abs(math.cos(phase)) * 1.5, "stride": math.sin(phase),
                "phase": index / 6, "lean": 1.5}
    if anim == "jump":
        return {"bob": -2 if index == 0 else 0, "air": True,
                "stride": -0.65 if index == 0 else 0.65, "phase": index / 2}
    if anim == "dash":
        return {"bob": 1.5, "lean": 4.0 + index, "dash": True,
                "phase": index / 2}
    if anim == "attack":
        return {"lean": (-1, 1, 2, 0)[index], "swing": (0, 0.6, 1, 0.35)[index],
                "phase": index / 4, "attack": True}
    if anim == "hitstun":
        return {"lean": -2.5 - index, "bob": 1, "hit": True, "phase": index / 2}
    return {"lean": (-2, -0.5, 0)[index], "bob": 1, "ko": True,
            "phase": index / 3}


def limb(d, start, end, color, width=4.0, glove=None):
    line(d, [start, end], INK, width + 2.0)
    line(d, [start, end], color, width)
    if glove:
        ellipse(d, (end[0] - 2.6, end[1] - 2.6, end[0] + 2.6, end[1] + 2.6), glove, width=0.8)


def draw_gholdengo(pose):
    im = Image.new("RGBA", (FRAME * S, FRAME * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    bob, lean, swing = pose.get("bob", 0), pose.get("lean", 0), pose.get("swing", 0)
    x, y = 32 + lean, 36 + bob
    gold, light, shade, dark = (244, 190, 37, 255), (255, 221, 91, 255), (183, 126, 21, 255), (70, 55, 52, 255)
    # Loose metallic locks and curled tips create the tall, unmistakable silhouette.
    for pts in ([ (25,20),(20,13),(17,7),(20,3),(24,8),(25,15) ],
                [ (30,17),(29,9),(31,3),(35,2),(35,7),(33,12),(36,18) ],
                [ (37,19),(40,12),(45,8),(48,10),(44,14),(42,21) ]):
        shifted = [(a + lean, b + bob * 0.35) for a,b in pts]
        line(d, shifted, shade, 4.5); line(d, shifted, gold, 2.6)
    # Arms, tapered head, long tube-like body and bell-shaped lower half.
    limb(d, (x-8,y+1), (x-15-swing*2,y+6), gold, 3.0)
    limb(d, (x+8,y+1), (x+14+swing*9,y+3-swing*4), gold, 3.0)
    ellipse(d, (x-8,y-17,x+8,y-2), gold, width=1.2)
    ellipse(d, (x-5,y-14,x-1,y-10), dark, outline=None); ellipse(d, (x+1,y-14,x+5,y-10), dark, outline=None)
    line(d, [(x-2,y-6),(x,y-5),(x+2,y-6)], dark, 0.8)
    polygon(d, [(x-7,y-2),(x+7,y-2),(x+7,y+10),(x+13,y+19),(x+10,y+23),
                 (x-10,y+23),(x-13,y+19),(x-7,y+10)], gold, width=1.5)
    polygon(d, [(x-7,y+5),(x+7,y+2),(x+10,y+17),(x-9,y+19)], light, outline=None)
    # Dark diagonal sash, silver buckle and dangling hip charm.
    line(d, [(x-9,y+14),(x+9,y+4)], dark, 3.0)
    roundrect(d, (x-1.5,y+7,x+3.5,y+12), 1, (203,207,210,255), INK, 0.8)
    ellipse(d, (x+8,y+18,x+11,y+21), (161,170,181,255), width=0.7)
    if pose.get("attack") and swing > 0.4:
        # Gold coin burst in the swing frames; the projectile is a clear round silhouette.
        ellipse(d, (x+17,y-5,x+25,y+3), light, shade, 1.1)
        ellipse(d, (x+19,y-3,x+23,y+1), gold, outline=None)
    return im.resize((FRAME,FRAME), Image.Resampling.LANCZOS)


def draw_tinkaton(pose):
    im = Image.new("RGBA", (FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob, lean, swing=pose.get("bob",0),pose.get("lean",0),pose.get("swing",0)
    x,y=30+lean,43+bob
    pink=(241,137,186,255); pale=(255,208,224,255); darkpink=(178,69,126,255)
    steel=(151,151,177,255); steelhi=(207,205,221,255); steelshade=(86,82,112,255)
    # Legs and compact body.
    for dx, lift in ((-4,-1),(4,1)):
        limb(d,(x+dx,y+5),(x+dx+lift,60),pale,3.0, pink)
    ellipse(d,(x-10,y-7,x+10,y+10),pink,width=1.4)
    ellipse(d,(x-7,y-5,x+7,y+6),pale,outline=None)
    # Ear-like head points and oversized swept pink crest.
    polygon(d,[(x-8,y-9),(x-11,y-20),(x-4,y-16),(x,y-18),(x+6,y-16),(x+11,y-21),(x+9,y-9)],pink,width=1.2)
    ellipse(d,(x-10,y-16,x+10,y+1),pale,width=1.1)
    ellipse(d,(x-5,y-10,x-2,y-7),INK,outline=None); ellipse(d,(x+3,y-10,x+6,y-7),INK,outline=None)
    line(d,[(x-2,y-4),(x+2,y-4)],darkpink,0.8)
    # Arms and hammer handle are behind/over the body depending on attack phase.
    limb(d,(x-7,y-1),(x-12,y+5),pink,3.0,pale)
    limb(d,(x+7,y-1),(x+13+swing*3,y+3-swing*2),pink,3.0,pale)
    hx=x+16+swing*4; hy=y-1-swing*6
    line(d,[(x+12,y+3),(hx+4,hy+2)],steelshade,4.0)
    line(d,[(x+12,y+3),(hx+4,hy+2)],(116,89,139,255),2.4)
    # Hammer head dominates, but remains inside frame and doesn't erase the wielder.
    polygon(d,[(hx-3,hy-6),(hx+11,hy-8),(hx+15,hy-3),(hx+13,hy+7),
               (hx+4,hy+10),(hx-2,hy+5)],steel,width=1.4)
    polygon(d,[(hx+1,hy-5),(hx+10,hy-6),(hx+12,hy-2),(hx+7,hy+1),(hx+1,hy)],steelhi,outline=None)
    line(d,[(hx+7,hy+2),(hx+12,hy+1),(hx+10,hy+5)],steelshade,1.1)
    if pose.get("attack") and swing > 0.4:
        line(d,[(hx+4,hy-11),(hx+15,hy-13)],(255,238,190,190),1.2)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


def draw_greninja(pose):
    im=Image.new("RGBA",(FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob,lean,stride=pose.get("bob",0),pose.get("lean",0),pose.get("stride",0)
    x,y=31+lean,43+bob
    navy=(30,56,103,255); blue=(45,99,160,255); cyan=(111,196,217,255); pink=(235,91,145,255)
    # Long, low body and stretched frog limbs.
    limb(d,(x-5,y+1),(x-12-stride*4, y+10),navy,4.0)
    limb(d,(x-12-stride*4,y+10),(x-17-stride*5,59),navy,3.2,cyan)
    limb(d,(x+5,y+2),(x+12+stride*4,y+9),navy,4.0)
    limb(d,(x+12+stride*4,y+9),(x+18+stride*5,58),navy,3.2,cyan)
    ellipse(d,(x-10,y-8,x+10,y+8),navy,width=1.4)
    polygon(d,[(x-9,y-3),(x+8,y-6),(x+6,y+4),(x-8,y+6)],blue,outline=None)
    # Head mask, pointed crest, sharp yellow eyes.
    polygon(d,[(x-10,y-11),(x-9,y-20),(x-4,y-15),(x+1,y-22),(x+3,y-14),(x+10,y-17),(x+8,y-7),(x+3,y-3),(x-7,y-4)],navy,width=1.3)
    polygon(d,[(x-8,y-10),(x-4,y-13),(x-1,y-10),(x-4,y-8)],(244,213,78,255),outline=None)
    polygon(d,[(x+1,y-10),(x+5,y-14),(x+8,y-11),(x+5,y-8)],(244,213,78,255),outline=None)
    # Tongue scarf wraps neck and trails down over the chest.
    line(d,[(x-8,y-2),(x-3,y+1),(x+5,y),(x+9,y-3),(x+6,y+2),(x+1,y+4),(x-4,y+3),(x-1,y+7),(x+7,y+9)],INK,4.4)
    line(d,[(x-8,y-2),(x-3,y+1),(x+5,y),(x+9,y-3),(x+6,y+2),(x+1,y+4),(x-4,y+3),(x-1,y+7),(x+7,y+9)],pink,2.8)
    # Forearms and pale circular water markings.
    limb(d,(x-7,y-3),(x-15-stride*2,y+2),navy,3.3,cyan)
    limb(d,(x+7,y-3),(x+14+stride*2,y+1),navy,3.3,cyan)
    for sx,sy in ((x-9,y+2),(x+8,y+4),(x-13,y+11),(x+14,y+10)):
        ellipse(d,(sx-1.8,sy-1.8,sx+1.8,sy+1.8),cyan,outline=navy,width=0.5)
    if pose.get("attack") and pose.get("swing",0)>0.4:
        # A compact water shuriken cue in the forward strike frames.
        sx,sy=x+20,y-7
        polygon(d,[(sx,sy-7),(sx+2,sy-2),(sx+7,sy),(sx+2,sy+2),
                   (sx,sy+7),(sx-2,sy+2),(sx-7,sy),(sx-2,sy-2)],(160,224,241,255),blue,0.9)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


def draw_scizor(pose):
    im=Image.new("RGBA",(FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob,lean,swing=pose.get("bob",0),pose.get("lean",0),pose.get("swing",0)
    x,y=31+lean,38+bob
    red=(199,48,58,255); redhi=(239,75,76,255); joint=(44,51,61,255); teal=(59,215,212,255); wing=(203,227,230,200)
    # Pale paired wings behind the armored silhouette.
    polygon(d,[(x-5,y-8),(x-20,y-17),(x-17,y-3),(x-7,y+2)],wing,outline=(125,157,169,255),width=0.9)
    polygon(d,[(x+5,y-8),(x+20,y-17),(x+17,y-3),(x+7,y+2)],wing,outline=(125,157,169,255),width=0.9)
    # Insect legs and segmented abdomen.
    for dx,sy in ((-7,-1),(0,1),(7,-1)):
        limb(d,(x+dx,y+6),(x+dx*1.5,y+15),(red,)[0],3.0,(redhi))
    ellipse(d,(x-8,y-1,x+8,y+12),joint,width=1.1)
    line(d,[(x-5,y+4),(x+5,y+4)],(112,117,125,255),1.2)
    # Chest plates and narrow angular head with crown spike.
    polygon(d,[(x-10,y-13),(x,y-17),(x+10,y-13),(x+7,y+1),(x,y+5),(x-7,y+1)],red,width=1.5)
    polygon(d,[(x-7,y-11),(x,y-14),(x+7,y-11),(x+4,y-2),(x-4,y-2)],redhi,outline=None)
    polygon(d,[(x-6,y-16),(x-4,y-25),(x,y-20),(x+4,y-25),(x+6,y-15),(x,y-12)],red,width=1.2)
    ellipse(d,(x-5,y-17,x-2,y-14),teal,outline=INK,width=0.5)
    ellipse(d,(x+2,y-17,x+5,y-14),teal,outline=INK,width=0.5)
    # Arms with giant pincers. Shape direction changes during attack.
    for side in (-1,1):
        ex=x+side*(11+swing*2); ey=y-5-swing*3
        limb(d,(x+side*7,y-8),(ex,ey),joint,3.5,red)
        clawx=ex+side*(6+swing*2)
        polygon(d,[(clawx-side*3,ey-5),(clawx+side*5,ey-8),(clawx+side*8,ey-3),
                   (clawx+side*4,ey+4),(clawx-side*4,ey+5)],redhi,width=1.3)
        # Hooked red tips and cyan pincer core.
        polygon(d,[(clawx+side*3,ey-5),(clawx+side*9,ey-9),(clawx+side*6,ey-2)],red,width=0.8)
        ellipse(d,(clawx-2.2,ey-2.2,clawx+2.2,ey+2.2),teal,outline=(18,86,101,255),width=0.7)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


def draw_decidueye(pose):
    im=Image.new("RGBA",(FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob,lean,swing,stride=pose.get("bob",0),pose.get("lean",0),pose.get("swing",0),pose.get("stride",0)
    x,y=31+lean,39+bob
    hood=(40,112,91,255); leaf=(69,151,92,255); cream=(237,222,178,255); brown=(120,75,49,255); orange=(207,87,46,255)
    # Tail feathers and feet.
    for n in range(3):
        polygon(d,[(x+5+n*2,y+9),(x+12+n*2,y+17),(x+7+n*2,y+16)],brown,width=0.7)
    limb(d,(x-5,y+7),(x-7-stride*2,59),brown,3.0,(215,166,76,255))
    limb(d,(x+5,y+7),(x+7+stride*2,59),brown,3.0,(215,166,76,255))
    # Broad layered wings form the defining cloak silhouette.
    for side in (-1,1):
        wingpts=[(x+side*7,y-8),(x+side*18,y-13),(x+side*22,y-4),(x+side*17,y+6),(x+side*8,y+3)]
        polygon(d,wingpts,brown,width=1.1)
        for j in range(3):
            polygon(d,[(x+side*(11+j*2),y-4+j*2),(x+side*(18+j),y-6+j*3),(x+side*(15+j),y+1+j*2)],orange,width=0.5)
    # Cream body and teal hood around the owl face.
    ellipse(d,(x-9,y-7,x+9,y+13),cream,width=1.2)
    polygon(d,[(x-12,y-11),(x-10,y-21),(x-4,y-17),(x,y-22),(x+5,y-17),(x+11,y-22),(x+12,y-9),(x+8,y+1),(x-8,y+1)],hood,width=1.5)
    polygon(d,[(x-7,y-12),(x-4,y-16),(x,y-14),(x+5,y-16),(x+8,y-12),(x+5,y-4),(x,y-2),(x-5,y-4)],(43,48,52,255),width=0.8)
    ellipse(d,(x-5,y-11,x-2,y-7),(244,151,56,255),outline=INK,width=0.5)
    ellipse(d,(x+2,y-11,x+5,y-7),(244,151,56,255),outline=INK,width=0.5)
    # Orange bow-feather collar.
    polygon(d,[(x-10,y-3),(x-5,y-1),(x,y+2),(x+5,y-1),(x+10,y-3),(x+6,y+3),(x,y+6),(x-6,y+3)],orange,width=1.0)
    # Wing arms and a bow/arrow cue in the attack row.
    if pose.get("attack") and swing > 0.4:
        line(d,[(x-9,y-1),(x+10,y-2)],leaf,1.4)
        line(d,[(x+2,y-6),(x+19,y-7)],(242,232,202,255),1.5)
        polygon(d,[(x+19,y-7),(x+15,y-9),(x+16,y-6)],orange,width=0.5)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


def draw_blaziken(pose):
    im=Image.new("RGBA",(FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob,lean,stride,swing=pose.get("bob",0),pose.get("lean",0),pose.get("stride",0),pose.get("swing",0)
    x,y=31+lean,36+bob
    red=(197,61,47,255); orange=(231,100,47,255); cream=(244,224,184,255); gold=(247,190,58,255); dark=(54,48,50,255)
    # Long powerful legs and flame tufts.
    kick= (swing*9 if pose.get("attack") else stride*3)
    limb(d,(x-5,y+7),(x-8-stride*2,53),red,4.2,dark)
    limb(d,(x+5,y+7),(x+8+kick,52-kick*.35),red,4.2,dark)
    for fx,fy in ((x-8-stride*2,53),(x+8+kick,52-kick*.35)):
        polygon(d,[(fx-4,fy-1),(fx-1,fy-9),(fx+1,fy-5),(fx+5,fy-12),(fx+4,fy)],gold,width=0.8)
        line(d,[(fx-1,fy-2),(fx+1,fy-6)],(255,224,105,255),1)
    # Tall torso with broad cream chest plumage.
    polygon(d,[(x-9,y-11),(x-7,y+8),(x,y+12),(x+8,y+7),(x+10,y-11),(x,y-15)],red,width=1.4)
    polygon(d,[(x-6,y-10),(x-4,y+4),(x,y+7),(x+5,y+4),(x+7,y-10),(x,y-12)],cream,width=0.8)
    # Head crest, sharp beak, and flame-shaped side tufts.
    ellipse(d,(x-7,y-23,x+7,y-10),orange,width=1.2)
    polygon(d,[(x-5,y-20),(x-9,y-30),(x-3,y-25),(x+1,y-33),(x+3,y-24),(x+9,y-28),(x+6,y-18)],red,width=1.2)
    polygon(d,[(x+5,y-17),(x+12,y-15),(x+5,y-12)],gold,width=0.8)
    ellipse(d,(x+1,y-19,x+4,y-16),INK,outline=None)
    # Arms stay tucked except the strike arm.
    limb(d,(x-7,y-6),(x-13,y+1),red,3.5,dark)
    limb(d,(x+7,y-6),(x+12+swing*5,y-1-swing*3),red,3.5,dark)
    if pose.get("attack") and swing > 0.4:
        polygon(d,[(x+7+swing*6,y-6),(x+11+swing*7,y-2),(x+9+swing*7,y+3),(x+5+swing*6,y-1)],gold,width=0.9)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


def draw_gengar(pose):
    im=Image.new("RGBA",(FRAME*S,FRAME*S),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob,lean,swing=pose.get("bob",0),pose.get("lean",0),pose.get("swing",0)
    x,y=31+lean,39+bob
    purple=(119,65,154,255); shade=(82,45,119,255); light=(159,101,190,255); red=(236,91,88,255); pink=(231,112,164,255)
    # Back spikes distinguish the spherical body silhouette.
    for pts in ([(x-10,y-5),(x-20,y-9),(x-13,y+1)],[(x+10,y-5),(x+20,y-9),(x+13,y+1)],
                [(x-8,y+4),(x-16,y+10),(x-6,y+10)],[(x+8,y+4),(x+16,y+10),(x+6,y+10)]):
        polygon(d,pts,shade,width=0.9)
    # Ears and round body.
    polygon(d,[(x-10,y-9),(x-13,y-24),(x-4,y-17),(x,y-19),(x+4,y-17),(x+13,y-24),(x+10,y-8)],purple,width=1.3)
    ellipse(d,(x-15,y-13,x+15,y+13),purple,width=1.5)
    ellipse(d,(x-9,y-9,x-3,y-1),red,outline=INK,width=0.7)
    ellipse(d,(x+3,y-9,x+9,y-1),red,outline=INK,width=0.7)
    # Narrow pupils and exaggerated zig-zag grin.
    polygon(d,[(x-7,y-7),(x-2,y-5),(x-6,y-3)],INK,outline=None)
    polygon(d,[(x+7,y-7),(x+2,y-5),(x+6,y-3)],INK,outline=None)
    polygon(d,[(x-10,y-1),(x+10,y-1),(x+7,y+7),(x+3,y+5),(x,y+8),(x-4,y+5),(x-8,y+7)],(242,235,222,255),INK,0.8)
    line(d,[(x-7,y+1),(x-4,y+4),(x-1,y+1),(x+2,y+4),(x+5,y+1)],shade,0.8)
    # Short arms and feet.
    limb(d,(x-11,y+1),(x-16-swing*2,y+5),purple,4.0,light)
    limb(d,(x+11,y+1),(x+16+swing*2,y+4),purple,4.0,light)
    ellipse(d,(x-9,y+9,x-2,y+14),shade,width=0.8); ellipse(d,(x+2,y+9,x+9,y+14),shade,width=0.8)
    # Curled pink tongue flicks out on active attack frames.
    if pose.get("attack") and swing > 0.4:
        line(d,[(x+4,y+4),(x+10,y+6),(x+14,y+3)],INK,3.0)
        line(d,[(x+4,y+4),(x+10,y+6),(x+14,y+3)],pink,1.8)
    if pose.get("ko") and pose.get("phase",0)>0.6:
        ellipse(d,(x-2,y-20,x+2,y-16),(245,211,67,255),INK,0.5)
    return im.resize((FRAME,FRAME),Image.Resampling.LANCZOS)


DRAW = {"gholdengo": draw_gholdengo, "tinkaton": draw_tinkaton,
        "greninja": draw_greninja, "scizor": draw_scizor,
        "decidueye": draw_decidueye, "blaziken": draw_blaziken,
        "gengar": draw_gengar}


def render_sheet(name):
    sheet=Image.new("RGBA",(FRAME*6,FRAME*len(SHEET_ROWS)),(0,0,0,0))
    for row,(anim,count) in enumerate(SHEET_ROWS):
        for col in range(count):
            frame=DRAW[name](base_pose(anim,col))
            sheet.alpha_composite(frame,(col*FRAME,row*FRAME))
    return sheet


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for name in DRAW:
        sheet=render_sheet(name)
        path=OUT/f"{name}_sheet.png"
        sheet.save(path)
        print(f"Wrote {path} ({sheet.width}x{sheet.height}, {sheet.mode})")


if __name__ == "__main__":
    main()
