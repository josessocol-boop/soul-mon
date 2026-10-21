"""tools/move_stats.py. Static move test: reads every move dictionary of the roster from the GDScript sources and computes frame data,
damage, reach and cost. Not a playtest: it reads the numbers the game uses."""
import re, glob, os, math, statistics, sys
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
def rd(p): return open(p, encoding="utf-8").read().replace("\r", "")

fs = rd("core/fighter.gd")
md_src = fs[fs.index("const MOVE_DEFAULTS"):]
md_src = md_src[md_src.index("{") + 1: md_src.index("\n}")]
def gd_to_py(expr):
    e = expr.replace("Vector2(", "V(").replace("true", "True").replace("false", "False")
    e = re.sub(r"_awakened_cost\(\"(\w+)\"\)", r"AW('\1')", e)
    return e
DEF = {}
for m in re.finditer(r'"(\w+)"\s*:\s*(.+?),?\s*(?:#.*)?$', md_src, re.M):
    try: DEF[m.group(1)] = eval(gd_to_py(m.group(2)), {"V": lambda x, y: (x, y), "AW": lambda k: 0})
    except Exception: pass

def parse_dict(body, normal_cost=None):
    d = {}
    # split top-level key: value pairs by commas outside parens/brackets
    depth = 0; cur = ""; parts = []
    for ch in body:
        if ch in "([{": depth += 1
        if ch in ")]}": depth -= 1
        if ch == "," and depth == 0: parts.append(cur); cur = ""
        else: cur += ch
    parts.append(cur)
    for p in parts:
        if ":" not in p: continue
        k, v = p.split(":", 1)
        k = k.strip().strip('"')
        v = v.strip()
        if not k: continue
        try:
            if v.startswith("_awakened_cost"):
                key = re.search(r'"(\w+)"', v).group(1)
                d[k] = ("AWCOST", key)
            else:
                d[k] = eval(gd_to_py(v), {"V": lambda x, y: (x, y), "AW": lambda k: 0, "float": float})
        except Exception:
            d[k] = v
    return d

def moves_of(fid):
    src = rd(f"fighters/{fid}/fighter_{fid}.gd")
    out = {}
    def grab(section_name, func_name):
        if f"func {func_name}(" not in src: return
        a = src.index(f"func {func_name}(")
        b = src.find("\nfunc ", a + 5); b = b if b != -1 else len(src)
        body = src[a:b]
        for m in re.finditer(r'(?:"(\w+)"\s*:\s*|m\["(\w+)"\]\s*=\s*)mv\(\{', body):
            key = m.group(1) or m.group(2)
            start = m.end()
            depth = 1; i = start
            while depth and i < len(body):
                if body[i] == "{": depth += 1
                elif body[i] == "}": depth -= 1
                i += 1
            d = parse_dict(body[start:i - 1])
            out[(section_name + key) if section_name else key] = d
    grab("", "_define_moves")
    grab("AW:", "_awakened_moves")
    grab("FORM:", "_define_form_moves")
    return out

def resolve(d):
    m = dict(DEF); m.update(d)
    return m

def metrics(name, d):
    m = resolve(d)
    kind = m.get("kind", "melee")
    on, offf, total = int(m.get("on", 0)), int(m.get("off_f", 0)), int(m.get("total", 0))
    dmg = float(m.get("dmg", 0)); hi = int(m.get("hit_interval", 0))
    spawn_count = int(m.get("spawn_count", 1)); cost = m.get("cost", 0)
    if isinstance(cost, tuple): cost = "awakened+25"
    cd = float(m.get("cd", 0))
    kb = m.get("kb", (0, 0)); kbm = math.hypot(kb[0], kb[1]) if isinstance(kb, tuple) else 0
    if kind in ("melee", "dive"):
        active = max(0, offf - on)
        hits = 1 + (max(0, active - 1) // hi) if hi > 0 else 1
        size = m.get("size", (44, 32)); off = m.get("off", (0, 0))
        reach = abs(off[0]) + size[0] * 0.5 + 14 + float(m.get("lunge", 0)) * max(0, active) / 60.0
        if float(m.get("teleport_distance", 0)): reach += float(m["teleport_distance"])
        total_dmg = dmg * hits
    elif kind == "projectile":
        active = 0
        hits = spawn_count
        reach = float(m.get("proj_speed", 0)) * float(m.get("proj_life", 0))
        total_dmg = dmg * spawn_count * (2 if m.get("proj_pierce") else 1)  # pierce: can hit one target twice
    elif kind == "trap":
        active = int(m.get("trap_lifetime", 0) * 60); hits = 1
        reach = float(m.get("trap_dist", 0)); total_dmg = dmg
        if bool(m.get("trap_persistent", False)):
            tick = float(m.get("trap_tick", 0)) or 1.0       # trap.gd: persistent traps re-arm every trap_tick
            hits = max(1, int(float(m.get("trap_lifetime", 0)) / tick)); total_dmg = dmg * hits
    else:
        active = 0; hits = 0; reach = 0; total_dmg = 0
    dur = max(total, 1)
    return dict(name=name, kind=kind, dmg=dmg, hits=hits, total_dmg=round(total_dmg, 1), raw=m,
                startup=on, active=active, recovery=max(0, total - offf), total=total,
                dmg_per_s=round(total_dmg / (dur / 60.0), 1), reach=round(reach),
                kb=round(kbm), stun=m.get("stun", 0), cost=cost, cd=cd,
                flags=[k for k in ("root", "no_tech", "stamina_steal", "damage_buff", "hitstun_mult", "counter",
                                   "teleport_distance", "pull", "i_frames", "wave", "apply", "proj_pierce", "proj_bounce")
                       if m.get(k) not in (None, 0, 0.0, False, "")])

FIGHTERS = ["alakazam", "lucario", "mewtwo", "toxicroak", "gengar", "blaziken", "scizor", "tinkaton", "marshadow", "greninja", "decidueye", "gholdengo"]
ALL = []
for fid in FIGHTERS:
    if not os.path.exists(f"fighters/{fid}/fighter_{fid}.gd"): continue
    for key, d in moves_of(fid).items():
        r = metrics(f"{fid}.{key}", d); r["fid"] = fid; r["key"] = key; ALL.append(r)

NEW = {"alakazam", "lucario", "mewtwo", "toxicroak"}
base = [r for r in ALL if r["fid"] not in NEW and not r["key"].startswith(("AW:", "FORM:")) and r["kind"] != "trap" and r["total_dmg"] > 0]
med_dmg = statistics.median(r["total_dmg"] for r in base)
med_dps = statistics.median(r["dmg_per_s"] for r in base)
med_total = statistics.median(r["total"] for r in base)
med_reach = statistics.median(r["reach"] for r in base if r["reach"] > 0)
print(f"BASELINE (8 original fighters, normal moves with damage): total dmg median {med_dmg}, dmg/s median {med_dps}, total frames median {med_total}, reach median {med_reach}")
print()
print(f"{'move':<32}{'kind':<11}{'dmg':>6}{'hits':>5}{'tot':>6}{'dmg/s':>8}{'start':>6}{'act':>5}{'rec':>5}{'reach':>7}{'kb':>5}{'cost':>12}{'cd':>5}  flags")
for r in ALL:
    if r["fid"] not in NEW: continue
    tag = ""
    if r["total_dmg"] > 2.5 * med_dmg: tag += " !!DMG"
    if r["dmg_per_s"] > 2.5 * med_dps: tag += " !!DPS"
    if r["kb"] > 500: tag += " !!KB"
    if r["reach"] > 600: tag += " !!REACH"
    if r["total_dmg"] == 0 and r["kind"] == "melee" and not any(f in r["flags"] for f in ("root", "stamina_steal", "damage_buff", "teleport_distance", "counter")): tag += " !!NODMG"
    if r["cost"] in (0, 0.0) and r["cd"] == 0: tag += " !!FREE"
    print(f"{r['name']:<32}{r['kind']:<11}{r['dmg']:>6}{r['hits']:>5}{r['total']:>6}{r['dmg_per_s']:>8}{r['startup']:>6}{r['active']:>5}{r['recovery']:>5}{r['reach']:>7}{r['kb']:>5}{str(r['cost']):>12}{r['cd']:>5}  {','.join(r['flags'])}{tag}")

# ---- category baselines from the original eight, and the corrected flags for the new ones
def cat(r):
    k = r["key"]
    if k.startswith(("AW:", "FORM:")): k = k.split(":", 1)[1]
    if k == "basic": return "basic"
    if k == "ultimate": return "ultimate"
    if k.endswith("_down"): return "down"
    return "special"
ORIG = [r for r in ALL if r["fid"] not in NEW and not r["key"].startswith(("AW:", "FORM:"))]
print()
print("CATEGORY BASELINE (original eight, normal moves)")
for c in ["basic", "special", "down", "ultimate"]:
    rows = [r for r in ORIG if cat(r) == c and r["kind"] != "trap"]
    if not rows: continue
    print(f"  {c:<9} n={len(rows):<3} dmg median {statistics.median(r['total_dmg'] for r in rows):<6} "
          f"dmg/s median {statistics.median(r['dmg_per_s'] for r in rows):<6} kb median {statistics.median(r['kb'] for r in rows):<6} "
          f"cost median {statistics.median([float(r['cost']) for r in rows if not isinstance(r['cost'], str)]):<6} "
          f"cd median {statistics.median(r['cd'] for r in rows)}")
traps = [r for r in ORIG if r["kind"] == "trap"]
if traps: print(f"  traps     n={len(traps)} lifetime(s) median {statistics.median(float(r['active'])/60 for r in traps):.1f}")
print()
print("NEW MOVES vs their category (flags after dropping defaults and the basic zero-cost rule)")
for r in ALL:
    if r["fid"] not in NEW: continue
    c = cat(r)
    rows = [o for o in ORIG if cat(o) == c and o["kind"] != "trap"]
    if not rows or r["kind"] == "trap": continue
    med_d = statistics.median(o["total_dmg"] for o in rows); med_k = statistics.median(o["kb"] for o in rows)
    med_s = statistics.median(o["dmg_per_s"] for o in rows)
    notes = []
    if r["total_dmg"] > 1.5 * med_d and r["total_dmg"] > 0: notes.append(f"dmg {r['total_dmg']} vs {med_d}")
    if r["total_dmg"] < 0.5 * med_d and r["total_dmg"] > 0 and c != "basic": notes.append(f"dmg {r['total_dmg']} vs {med_d} (weak)")
    if r["kb"] > 2.0 * med_k and r["kb"] > 300: notes.append(f"kb {r['kb']} vs {med_k}")
    if r["dmg_per_s"] > 1.8 * med_s and r["dmg_per_s"] > 0: notes.append(f"dps {r['dmg_per_s']} vs {med_s}")
    if r["kind"] == "projectile" and r["reach"] > 1300: notes.append(f"range {r['reach']} > arena 1360")
    if r["kind"] == "projectile" and c == "basic" and r["total_dmg"] > 0 and r["cost"] in (0, 0.0): notes.append("free projectile basic")
    print(f"  {r['name']:<30} {c:<9} " + ("; ".join(notes) if notes else "within range"))
