"""The ball Mewtwo is sealed in while he transforms into Mega Mewtwo Y (fighter_mewtwo.gd, awakening).

assets/fx/mega_ball.png: 4 frames, 16x16 each, side by side. Frame 0 lavender ball with a Y, frame 1 white flash,
frame 2 lavender with a brighter top, frame 3 gold flash. The fighter switches frames to make the ball flash.
Run from the project root:  python3 tools/generate_mega_ball.py   (needs Pillow)"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "fx", "mega_ball.png")

INK = (30, 20, 40)
Y_PURPLE = (92, 52, 150)

def palette(frame):
    if frame == 1:      # white flash
        return dict(top=(255, 252, 250), bot=(255, 252, 250), band=(160, 150, 170), btn=(255, 255, 255), y=Y_PURPLE)
    if frame == 3:      # gold flash
        return dict(top=(255, 222, 96), bot=(255, 246, 214), band=(176, 120, 40), btn=(255, 250, 220), y=(150, 80, 30))
    if frame == 2:      # brighter lavender
        return dict(top=(198, 160, 255), bot=(240, 236, 250), band=INK, btn=(250, 248, 255), y=Y_PURPLE)
    return dict(top=(150, 112, 222), bot=(238, 234, 248), band=INK, btn=(250, 248, 255), y=Y_PURPLE)

def draw(frame):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    p = palette(frame)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d > 7.6:
                continue
            if d > 6.6:
                col = INK                       # outline
            elif 6.5 >= abs(y - 7.5) and abs(y - 7.5) < 1.0:
                col = p["band"]                 # the black band across the middle
            elif y < 7.5:
                col = p["top"]
            else:
                col = p["bot"]
            px[x, y] = col + (255,)
    # button in the middle
    for y in range(16):
        for x in range(16):
            if ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 <= 2.4:
                px[x, y] = (INK if ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 > 1.8 else p["btn"]) + (255,)
    # the Y on the button (5 x 5 pixels)
    Y = ["X...X", ".X.X.", "..X..", "..X..", "..X.."]
    for j, row in enumerate(Y):
        for i, c in enumerate(row):
            if c == "X":
                px[5 + i, 5 + j] = p["y"] + (255,)
    return img

if __name__ == "__main__":
    strip = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for f in range(4):
        strip.paste(draw(f), (f * 16, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip.save(OUT)
    print("wrote", OUT, strip.size)
