"""Checks every fighter listed in roster/roster.gd (ENTRIES) before the game is run.

For each id: fighters/<id>/fighter_<id>.gd, fighter_<id>.tscn and profile.tres exist; the scene points at the
script; assets/<id>_sheet.png exists and is at least 384x448 (6 x 7 cells of 64 px, see docs/ARCHITECTURE.md).
Run from the project root:  python3 tools/check_roster.py      Exit code 1 if anything is missing. Needs Pillow."""
import re, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MIN_W, MIN_H = 384, 448


def roster_ids() -> list:
    text = (ROOT / "roster" / "roster.gd").read_text(encoding="utf-8")
    block = text.split("const ENTRIES", 1)[1].split("\n]", 1)[0]
    return re.findall(r'\{"id": "([a-z_]+)"', block)


def check(fid: str) -> list:
    problems = []
    d = ROOT / "fighters" / fid
    script = d / f"fighter_{fid}.gd"
    scene = d / f"fighter_{fid}.tscn"
    profile = d / "profile.tres"
    for f in (script, scene, profile):
        if not f.exists():
            problems.append(f"missing {f.relative_to(ROOT)}")
    if scene.exists():
        want = f"res://fighters/{fid}/fighter_{fid}.gd"
        if want not in scene.read_text(encoding="utf-8"):
            problems.append(f"{scene.name} does not use {want}")
    sheet = ROOT / "assets" / f"{fid}_sheet.png"
    if not sheet.exists():
        problems.append(f"missing assets/{fid}_sheet.png")
    else:
        w, h = Image.open(sheet).size
        if w < MIN_W or h < MIN_H:
            problems.append(f"assets/{fid}_sheet.png is {w}x{h}, needs at least {MIN_W}x{MIN_H}")
    return problems


if __name__ == "__main__":
    ids = roster_ids()
    failed = 0
    for fid in ids:
        problems = check(fid)
        failed += bool(problems)
        print(("FAIL " if problems else "ok   ") + fid + ("" if not problems else ": " + "; ".join(problems)))
    print(f"{len(ids)} fighters, {failed} with problems")
    sys.exit(1 if failed else 0)
