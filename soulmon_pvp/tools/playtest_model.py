"""tools/playtest_model.py. Fast playtest model. Each fighter plays against a stationary dummy for SECONDS of game time, choosing the
move with the best sustained damage that its stamina regeneration can pay for (basics are free). Reports
time-to-KO and the strongest single move. This is a model of the numbers, not a replay of the game."""
import sys, io, re, statistics, contextlib, os
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.argv = ["move_stats", ROOT]
with contextlib.redirect_stdout(io.StringIO()):
    import importlib.util
    spec = importlib.util.spec_from_file_location("mt", os.path.join(os.path.dirname(os.path.abspath(__file__)), "move_stats.py"))
    mt = importlib.util.module_from_spec(spec); spec.loader.exec_module(mt)
os.chdir(ROOT)
REGEN = 20.0  # stamina per second (StatsComponent.REGEN_PER_SEC)
def aw_extra(src, key):
    m = re.search(r'_awakened_cost\("%s"(?:, ([\d.]+))?\)' % key, src)
    return float(m.group(1)) if (m and m.group(1)) else 25.0
def cost_of(r, fid):
    c = r["cost"]
    if r["key"].split(":")[-1] == "ultimate":
        # a standard ultimate needs and spends the whole stamina bar (fighter.gd _try_actions); Mewtwo's is paid
        # with the Burst gauge, so it is not part of the stamina economy
        return 100.0
    if isinstance(c, str):   # awakened: normal cost + penalty
        key = r["key"].split(":", 1)[1] if ":" in r["key"] else r["key"]
        src = open(f"fighters/{fid}/fighter_{fid}.gd", encoding="utf-8").read()
        normal = [x for x in mt.ALL if x["fid"] == fid and x["key"] == key]
        base = float(normal[0]["cost"]) if normal and not isinstance(normal[0]["cost"], str) else 0.0
        return base + aw_extra(src, key)
    return float(c)
def sustain(rows, fid):
    best_dps, best_move, best_spike = 0.0, "-", 0.0
    for r in rows:
        if r["total_dmg"] <= 0: continue
        if fid == "mewtwo" and r["key"].split(":")[-1] == "ultimate": continue   # Burst-funded, see notes
        cycle = max(max(r["total"], 1) / 60.0, r["cd"], 0.2)
        if r["kind"] == "trap":                       # a trap's damage lands over its lifetime, not in the cast
            cycle = max(cycle, r["cd"], 0.2)
        c = cost_of(r, fid)
        factor = 1.0 if c <= 0 else min(1.0, REGEN * cycle / c)  # stamina you can pay for in one cycle
        dps = r["total_dmg"] / cycle * factor
        best_spike = max(best_spike, r["total_dmg"])
        if dps > best_dps: best_dps, best_move = dps, r["name"]
    return best_dps, best_move, best_spike
FIGHTERS = sorted({r["fid"] for r in mt.ALL})
NEW = {"alakazam", "lucario", "mewtwo", "toxicroak"}
hp = {}
for fid in FIGHTERS:
    src = open(f"fighters/{fid}/fighter_{fid}.gd", encoding="utf-8").read()
    m = re.search(r"hp_max\s*=\s*([\d.]+)", src); hp[fid] = float(m.group(1)) if m else 100.0
rows_by = {}
for r in mt.ALL:
    base = r["fid"]
    if r["key"].startswith("FORM:"): continue
    rows_by.setdefault(base, []).append(r)
res = []
for fid in FIGHTERS:
    rows = [r for r in rows_by[fid] if not r["key"].startswith("AW:")]
    dps, mv, spike = sustain(rows, fid)
    aw = [r for r in rows_by[fid] if r["key"].startswith("AW:")]
    aw_dps, aw_mv, aw_spike = sustain(aw, fid) if aw else (0, "-", 0)
    res.append((fid, hp[fid], dps, mv, spike, aw_dps, aw_mv, aw_spike))
orig = [x for x in res if x[0] not in NEW]
base_dps = statistics.median(x[2] for x in orig); base_spike = statistics.median(x[4] for x in orig)
print(f"Sustain = damage per second you can keep up while paying stamina (regen {REGEN}/s). Dummy HP is the fighter's own.")
print(f"Original-roster median sustain {base_dps:.1f} dmg/s, median strongest single move {base_spike:.1f}")
print()
print(f"{'fighter':<11}{'hp':>6}{'sustain':>9}{'x median':>10}  {'best sustain move':<30}{'spike':>7}{'time to KO (s)':>16}")
for fid, h, dps, mv, spike, aw_dps, aw_mv, aw_spike in sorted(res, key=lambda x: -x[2]):
    flag = "  <-- TOO STRONG" if dps > 1.35 * base_dps or spike > 1.8 * base_spike else ""
    ttk = h / dps if dps > 0 else float("inf")
    print(f"{fid:<11}{h:>6.0f}{dps:>9.1f}{dps/base_dps:>10.2f}  {mv:<30}{spike:>7.1f}{ttk:>16.1f}{flag}")
    if aw_dps:
        print(f"{'  awakened':<11}{'':>6}{aw_dps:>9.1f}{aw_dps/base_dps:>10.2f}  {aw_mv:<30}{aw_spike:>7.1f}")
