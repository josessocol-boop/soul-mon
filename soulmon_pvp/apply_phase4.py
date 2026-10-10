import re, os, shutil
def tabs(s): return re.sub(r'^((?: {4})+)', lambda m: '\t'*(len(m.group(1))//4), s, flags=re.M)
def put(path, s): open(path, 'w').write(tabs(s))
def edit(path, pairs):
    raw = open(path).read()
    uses_tabs = bool(re.search(r'^\t', raw, flags=re.M))
    s = raw.replace('\t', '    ') if uses_tabs else raw
    for a, b in pairs:
        assert s.count(a) == 1, (path, s.count(a), a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w').write(tabs(s) if uses_tabs else s)

# ---------------------------------------------------------------- input buffer
edit('input_handler.gd', [
 ('const BUFFER_FRAMES := 6\\n', '''## Per-action buffer windows (frames). Attacks/specials get a wider window so
## cancel chains (basic -> special) and mashed follow-ups feel forgiving.
const BUFFER_WINDOWS := {"jump": 6, "dash": 6, "attack": 9, "special1": 9, "special2": 9, "ultimate": 9}
'''),
 ('            buffer[a] = BUFFER_FRAMES\\n', "            buffer[a] = BUFFER_WINDOWS[a]\\n"),
 ('func consume(action: String) -> void:\\n    buffer[action] = 0\\n',
  "func consume(action: String) -> void:\\n    buffer[action] = 0\\n\\n## Drop every buffered input (called when hit, so mashing during hitstun\\n## doesn't fire a surprise move the instant you recover).\\nfunc clear() -> void:\\n    for a in buffer.keys():\\n        buffer[a] = 0\\n"),
])

# ---------------------------------------------------------------- statuses -> frame counters
s = open('stats_component.gd').read().replace('\\t', '    ')
a = s.index('var burn_ticks_left := 0')
b = s.index('## Dual-type defenders')
s = s[:a] + '''# Statuses are frame counters (not Timer nodes) so they freeze during hitstop and
# stay deterministic. Fighter calls tick_statuses() once per un-frozen physics frame.
const FPS := 60
var burn_left := 0       # frames remaining
var burn_phase := 0      # frames since last tick
var poison_left := 0
var poison_phase := 0
var slow_left := 0

func _ready() -> void:
    hp = max_hp
    stamina = max_stamina
    if types.is_empty():
        types = [element]

func tick(delta: float) -> void:
    stamina = min(max_stamina, stamina + REGEN_PER_SEC * delta)
    if exhausted and stamina >= RECOVER_AT:
        exhausted = false

func tick_statuses() -> void:
    if burn_left > 0:
        burn_left -= 1
        burn_phase += 1
        if burn_phase >= FPS:
            burn_phase = 0
            burn_ticked.emit(BURN_DAMAGE)
    if poison_left > 0:
        poison_left -= 1
        poison_phase += 1
        if poison_phase >= FPS:
            poison_phase = 0
            poison_ticked.emit(POISON_DAMAGE)
    if slow_left > 0:
        slow_left -= 1

func can_spend(cost: float) -> bool:
    return not exhausted and stamina >= cost

func spend(cost: float) -> void:
    stamina = max(0.0, stamina - cost)
    if stamina <= 0.0:
        exhausted = true

func gain_stamina(amount: float) -> void:
    stamina = min(max_stamina, stamina + amount)

# ---- micro-statuses ----
func apply_burn() -> void:
    burn_left = BURN_TICKS * FPS
    burn_phase = 0

func apply_poison() -> void:
    poison_left = POISON_TICKS * FPS
    poison_phase = 0

func apply_slow() -> void:
    slow_left = int(SLOW_TIME * FPS)

func burning() -> bool:
    return burn_left > 0

func poisoned() -> bool:
    return poison_left > 0

func slowed() -> bool:
    return slow_left > 0

func get_speed() -> float:
    return base_speed * (SLOW_FACTOR if slowed() else 1.0)

func clear_statuses() -> void:
    burn_left = 0
    poison_left = 0
    slow_left = 0

''' + s[b:]
open('stats_component.gd', 'w').write(tabs(s))

# ---------------------------------------------------------------- fighter
edit('fighter.gd', [
 ('signal died(fighter: Fighter)\\n', '''signal died(fighter: Fighter)
## Emitted on the defender for every connected hit (melee, projectile or trap).
## info: pos, element, dmg, mult, dir, heavy, ko, hitstop, kb
signal got_hit(info: Dictionary)
## Gameplay events for sound/VFX hooks: "jump", "dash", "attack", "special1",
## "special2", "ultimate", "shot", "trap_set".
signal event(kind: String, pos: Vector2)
'''),
 ('const HITSTUN_FRAMES := 18\\n', '''const HITSTUN_FRAMES := 18
const HITSTOP_SCALE := 1.0         # global multiplier for hit freeze (0 disables)
const KO_HITSTOP := 12             # long freeze on the killing blow
'''),
 ('var move_inv := false\\n', '''var move_inv := false
var freeze_frames := 0            # hitstop: fighter is frozen while > 0
var hit_confirmed := false        # current move has connected (enables cancels)
'''),
 ('func _physics_process(delta: float) -> void:\\n    input.poll()\\n    stats.tick(delta)\\n', '''func _physics_process(delta: float) -> void:
    input.poll()
    if freeze_frames > 0:
        # Hitstop: nothing advances (states, cooldowns, statuses, regen) but the
        # input buffer keeps listening, so presses made during the freeze count.
        freeze_frames -= 1
        _update_visuals()
        sprite.speed_scale = 0.0
        return
    stats.tick(delta)
    stats.tick_statuses()
'''),
 ('        input.consume("jump")\\n        velocity.y = jump_velocity\\n', '        input.consume("jump")\\n        velocity.y = jump_velocity\\n        event.emit("jump", global_position)\\n'),
 ('        stats.spend(dash_cost)\\n', '        stats.spend(dash_cost)\\n    event.emit("dash", global_position)\\n'),
 ('        if t.receive_hit(self, m.dmg * next_damage_buff, m.kb, global_position.x, m):\\n',
  "        if t.receive_hit(self, m.dmg * next_damage_buff, m.kb, global_position.x, m):\\n            hit_confirmed = true\\n            freeze_frames = maxi(freeze_frames, t.freeze_frames)   # attacker feels the impact too\\n"),
 ('''        _apply_status(atk_el, str(move_data.get("apply", "auto")))
    _check_death()
    return true
''', '''        _apply_status(atk_el, str(move_data.get("apply", "auto")))
    _check_death()
    var dealt := damage * mult
    var hs := _hitstop_frames(dealt, move_data)
    if dead:
        hs = KO_HITSTOP
    freeze_frames = hs
    input.clear()
    got_hit.emit({
        "pos": global_position + Vector2(-dir * 12.0, -6.0),
        "element": atk_el, "dmg": dealt, "mult": mult, "dir": dir,
        "heavy": dealt >= 14.0 or kb.length() >= 600.0,
        "ko": dead, "hitstop": hs, "kb": kb,
    })
    return true

## 3-7 frames by damage; multi-hit flurries stay short so they remain fluid.
func _hitstop_frames(dmg: float, m: Dictionary) -> int:
    var f := 3
    if dmg >= 30.0:
        f = 7
    elif dmg >= 18.0:
        f = 6
    elif dmg >= 10.0:
        f = 5
    elif dmg >= 6.0:
        f = 4
    if int(m.get("hit_interval", 0)) > 0:
        f = 2
    return int(round(f * HITSTOP_SCALE))
'''),
 ('    move_spawned = 0\\n    move_teleported = false\\n', '''    move_spawned = 0
    move_teleported = false
    hit_confirmed = false
    event.emit("attack" if key == "basic" else key, global_position)
'''),
 ('    var m: Dictionary = cur_move\\n    var f := sm.frames\\n    if m.kind == "dive":\\n', '''    var m: Dictionary = cur_move
    var f := sm.frames
    # Cancel chains: once a basic/special connects, a buffered special/ultimate
    # can interrupt the recovery (basic -> special1/2, special1 -> special2 ...).
    if hit_confirmed and (cur_key == "basic" or cur_key == "special1") and f >= int(m.on):
        if _try_special_cancel():
            return
    if m.kind == "dive":
'''),
 ('func _end_move() -> void:\\n', '''func _try_special_cancel() -> bool:
    if input.want("ultimate") and stats.stamina >= stats.max_stamina - 0.01:
        input.consume("ultimate")
        stats.spend(stats.max_stamina)
        sm.change("ultimate")
        return true
    for key in ["special2", "special1"]:
        var sm_data: Dictionary = moves[key]
        if key != cur_key and input.want(key) and cooldowns[key] <= 0.0 and stats.can_spend(sm_data.cost):
            input.consume(key)
            stats.spend(sm_data.cost)
            cooldowns[key] = sm_data.cd
            sm.change(key)
            return true
    return false

func _end_move() -> void:
'''),
 ('    p.position = global_position + Vector2(facing * off.x, off.y)\\n    get_parent().add_child(p)\\n',
  '    p.position = global_position + Vector2(facing * off.x, off.y)\\n    get_parent().add_child(p)\\n    event.emit("shot", p.position)\\n'),
 ('    t.position = pos\\n    get_parent().add_child(t)\\n', '    t.position = pos\\n    get_parent().add_child(t)\\n    event.emit("trap_set", pos)\\n'),
 ('    else:\\n        sprite.position = Vector2(0, -3)\\n', '''    else:
        sprite.position = Vector2(0, -3)
    if freeze_frames > 0 and sm.current == "hitstun":
        sprite.position.x += (freeze_frames % 2 * 2 - 1) * 2.5   # hit-shake while frozen
'''),
])

# ---------------------------------------------------------------- new scripts
put('screen_shake.gd', '''class_name ScreenShake
extends Camera2D
## Camera shake. Strength decays linearly over the shake's duration (frames).

var amp := 0.0
var frames_left := 0
var total := 1

func shake(strength: float, frames: int) -> void:
    var current := amp * float(frames_left) / float(total) if frames_left > 0 else 0.0
    if strength >= current:
        amp = strength
        total = maxi(1, frames)
        frames_left = total

func _physics_process(_delta: float) -> void:
    if frames_left > 0:
        frames_left -= 1
        var k := float(frames_left) / float(total)
        offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp * k
    else:
        offset = Vector2.ZERO
''')

put('hit_vfx.gd', '''class_name HitVfx
extends Node2D
## One-shot elemental hit burst: impact ring + sparks + an element-flavoured
## particle emitter. Spawn with HitVfx.spawn(parent, info) from Fighter.got_hit.

const E := StatsComponent.Element
# colour, colour2, count, speed min/max, gravity.y, size min/max, lifetime, spread
const STYLE := {
    E.NORMAL:   {"c": Color(1.0, 1.0, 1.0), "c2": Color(0.8, 0.8, 0.85), "n": 10, "v": [90, 260], "g": 300, "s": [2, 4], "life": 0.35, "spread": 120},
    E.FIRE:     {"c": Color(1.0, 0.55, 0.15), "c2": Color(1.0, 0.9, 0.3), "n": 20, "v": [60, 240], "g": -260, "s": [3, 6], "life": 0.55, "spread": 180},
    E.WATER:    {"c": Color(0.45, 0.75, 1.0), "c2": Color(0.9, 0.97, 1.0), "n": 20, "v": [100, 320], "g": 700, "s": [2, 5], "life": 0.5, "spread": 150},
    E.GRASS:    {"c": Color(0.4, 0.8, 0.35), "c2": Color(0.8, 1.0, 0.6), "n": 14, "v": [60, 200], "g": 260, "s": [3, 5], "life": 0.6, "spread": 180},
    E.ICE:      {"c": Color(0.7, 0.95, 1.0), "c2": Color(1.0, 1.0, 1.0), "n": 16, "v": [100, 300], "g": 400, "s": [2, 4], "life": 0.5, "spread": 160},
    E.STEEL:    {"c": Color(0.85, 0.88, 0.95), "c2": Color(1.0, 1.0, 0.8), "n": 18, "v": [220, 520], "g": 500, "s": [2, 3], "life": 0.3, "spread": 100},
    E.GHOST:    {"c": Color(0.6, 0.35, 0.9), "c2": Color(0.9, 0.7, 1.0), "n": 14, "v": [40, 150], "g": -70, "s": [4, 7], "life": 0.8, "spread": 180},
    E.FIGHTING: {"c": Color(1.0, 0.85, 0.25), "c2": Color(1.0, 0.5, 0.2), "n": 16, "v": [160, 400], "g": 200, "s": [3, 5], "life": 0.35, "spread": 140},
    E.FAIRY:    {"c": Color(1.0, 0.6, 0.85), "c2": Color(1.0, 0.95, 1.0), "n": 16, "v": [80, 250], "g": -90, "s": [3, 6], "life": 0.7, "spread": 180},
    E.BUG:      {"c": Color(0.6, 0.85, 0.2), "c2": Color(1.0, 0.95, 0.3), "n": 14, "v": [80, 260], "g": 200, "s": [2, 5], "life": 0.45, "spread": 160},
    E.DARK:     {"c": Color(0.3, 0.2, 0.4), "c2": Color(0.65, 0.3, 0.8), "n": 16, "v": [80, 260], "g": 100, "s": [3, 6], "life": 0.6, "spread": 170},
    E.POISON:   {"c": Color(0.7, 0.35, 0.9), "c2": Color(0.5, 0.9, 0.4), "n": 14, "v": [40, 140], "g": -130, "s": [4, 7], "life": 0.75, "spread": 180},
}

var ring_t := 0.0
var ring_color := Color.WHITE
var ring_size := 26.0

static func spawn(parent: Node, info: Dictionary) -> void:
    if parent == null:
        return
    var v := HitVfx.new()
    v.position = info.pos
    parent.add_child(v)
    v.burst(info)

func burst(info: Dictionary) -> void:
    z_index = 15
    var el: int = info.element
    var st: Dictionary = STYLE.get(el, STYLE[E.NORMAL])
    var boost := 1.0 + (0.6 if info.heavy else 0.0) + (1.0 if info.ko else 0.0)
    var away := Vector2(-info.dir, -0.25).normalized()      # spray back toward the attacker
    ring_color = st.c2
    ring_size = 24.0 * boost
    _emitter(int(8 * boost), Color(1, 1, 0.9), Color(1, 0.8, 0.3), 180.0 * boost, 460.0 * boost, 400.0, 2.0, 3.0, 0.25, 55.0, away)
    _emitter(int(st.n * boost), st.c, st.c2, float(st.v[0]), float(st.v[1]) * boost, float(st.g),
        float(st.s[0]), float(st.s[1]) * boost, float(st.life), float(st.s[1]) * boost, Vector2(0, -1))
    if info.mult > 1.0:   # super effective: gold star burst
        _emitter(int(12 * boost), Color(1.0, 0.9, 0.3), Color(1.0, 1.0, 0.8), 120.0, 340.0, -120.0, 3.0, 5.0, 0.6, 180.0, Vector2(0, -1))
    var t := get_tree().create_timer(1.2, true)
    t.timeout.connect(queue_free)

func _emitter(count: int, c1: Color, c2: Color, vmin: float, vmax: float, grav: float,
        smin: float, smax: float, life: float, spread: float, dir: Vector2) -> void:
    var p := CPUParticles2D.new()
    p.amount = maxi(count, 1)
    p.lifetime = life
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = dir
    p.spread = spread
    p.gravity = Vector2(0, grav)
    p.initial_velocity_min = vmin
    p.initial_velocity_max = vmax
    p.damping_min = 40.0
    p.damping_max = 120.0
    p.scale_amount_min = smin
    p.scale_amount_max = smax
    p.color = c1
    var g := Gradient.new()
    g.set_color(0, c1)
    g.set_color(1, Color(c2, 0.0))
    p.color_ramp = g
    add_child(p)
    p.emitting = true

func _process(delta: float) -> void:
    ring_t += delta
    queue_redraw()

func _draw() -> void:
    var k := ring_t / 0.18
    if k >= 1.0:
        return
    var r := ring_size * (0.4 + k)
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(ring_color, 1.0 - k), 3.0 * (1.0 - k) + 1.0)
''')

put('damage_number.gd', '''class_name DamageNumber
extends Label
## Floating damage popup. Gold + "!" when super effective, grey when resisted.

static func spawn(parent: Node, info: Dictionary) -> void:
    if parent == null:
        return
    var l := DamageNumber.new()
    var mult: float = info.mult
    var big: bool = info.heavy or info.ko
    l.text = "%d%s" % [roundi(info.dmg), "!" if mult > 1.0 else ""]
    l.add_theme_font_size_override("font_size", 28 if big else 20)
    var col := Color.WHITE
    if mult > 1.0:
        col = Color(1.0, 0.85, 0.2)
    elif mult < 1.0:
        col = Color(0.65, 0.68, 0.75)
    l.add_theme_color_override("font_color", col)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 6)
    l.z_index = 20
    l.position = info.pos + Vector2(-10 + randf_range(-8.0, 8.0), -34)
    parent.add_child(l)
    var tw := l.create_tween()
    tw.set_parallel(true)
    tw.tween_property(l, "position:y", l.position.y - 44.0, 0.7)
    tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
    tw.finished.connect(l.queue_free)
''')

put('sfx.gd', '''class_name Sfx
extends Node2D
## Tiny positional sound player. Streams are looked up by name in
## res://assets/audio/<name>.wav; missing files are silently skipped, so
## dropping in real audio is just replacing the files.

const DIR := "res://assets/audio/"
const POOL := 12

var cache := {}
var players: Array = []

func _ready() -> void:
    for i in POOL:
        var p := AudioStreamPlayer2D.new()
        p.max_distance = 4000.0
        add_child(p)
        players.append(p)

func play(sound: String, pos: Vector2 = Vector2(640, 360), volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if sound == "":
        return
    if not cache.has(sound):
        var path := DIR + sound + ".wav"
        cache[sound] = load(path) if ResourceLoader.exists(path) else null
    var stream = cache[sound]
    if stream == null:
        return
    var chosen: AudioStreamPlayer2D = players[0]
    for p in players:
        if not p.playing:
            chosen = p
            break
    chosen.stream = stream
    chosen.global_position = pos
    chosen.volume_db = volume_db
    chosen.pitch_scale = pitch
    chosen.play()
''')

# ---------------------------------------------------------------- arena manager
edit('arena_manager.gd', [
 ('const FLOOR_TOP := 620.0\\n', '''const FLOOR_TOP := 620.0
const SHAKE_SCALE := 1.0       # 0 disables screen shake
const ELEMENT_PITCH := {       # hit-sound pitch per attack element
    StatsComponent.Element.GHOST: 0.85, StatsComponent.Element.STEEL: 1.25,
    StatsComponent.Element.FAIRY: 1.4, StatsComponent.Element.FIRE: 0.95,
    StatsComponent.Element.DARK: 0.8, StatsComponent.Element.POISON: 0.9,
}
const EVENT_SOUNDS := {"jump": "jump", "dash": "dash", "attack": "swing", "special1": "swing_special",
    "special2": "swing_special", "ultimate": "ultimate", "shot": "shot", "trap_set": "trap_set"}
'''),
 ('var over := false\\n', "var over := false\\nvar camera: ScreenShake\\nvar sfx: Sfx\\nvar flash: ColorRect\\n"),
 ('    select_menu.cancel_requested.connect(_on_selection_cancelled)\\n', "    select_menu.cancel_requested.connect(_on_selection_cancelled)\\n    _build_juice(root)\\n"),
 ('    p1.died.connect(_on_died)\\n    p2.died.connect(_on_died)\\n', '''    p1.died.connect(_on_died)
    p2.died.connect(_on_died)
    for f in [p1, p2]:
        f.got_hit.connect(_on_got_hit)
        f.event.connect(_on_fighter_event)
'''),
 ('    bg.size = Vector2(1280, 720)\\n', '''    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    bg.position = Vector2(-40, -40)     # oversized so camera shake never reveals the edge
    bg.size = Vector2(1360, 800)
'''),
 ('    _tile(arena, Rect2(0, FLOOR_TOP, 1280, 100), stone)                    # floor\\n', "    _tile(arena, Rect2(-40, FLOOR_TOP, 1360, 140), stone)                  # floor\\n"),
 ('    _tile(arena, Rect2(0, FLOOR_TOP - 9, 1280, 20), \"res://assets/grass_top.png\")\\n', "    _tile(arena, Rect2(-40, FLOOR_TOP - 9, 1360, 20), \"res://assets/grass_top.png\")\\n"),
 ('    _tile(arena, Rect2(0, 0, 1280, 24), stone, dark)                       # ceiling\\n', "    _tile(arena, Rect2(-40, -40, 1360, 64), stone, dark)                   # ceiling\\n"),
 ('    _tile(arena, Rect2(0, 0, 24, 720), stone, dark)                        # left wall\\n', "    _tile(arena, Rect2(-40, -40, 64, 800), stone, dark)                    # left wall\\n"),
 ('    _tile(arena, Rect2(1256, 0, 24, 720), stone, dark)                     # right wall\\n', "    _tile(arena, Rect2(1256, -40, 64, 800), stone, dark)                   # right wall\\n"),
 ('func _on_died(loser: Fighter) -> void:\\n', '''func _build_juice(root: Node) -> void:
    camera = ScreenShake.new()
    camera.position = Vector2(640, 360)
    root.add_child(camera)
    camera.make_current()
    sfx = Sfx.new()
    root.add_child(sfx)
    var layer := CanvasLayer.new()
    layer.layer = 5
    root.add_child(layer)
    flash = ColorRect.new()
    flash.color = Color(1, 1, 1, 0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(flash)

func _on_got_hit(info: Dictionary) -> void:
    var dmg: float = info.dmg
    var amp := 0.0
    if info.ko:
        amp = 16.0
    elif dmg >= 25.0:
        amp = 12.0
    elif dmg >= 14.0 or info.heavy:
        amp = 7.0
    elif dmg >= 8.0:
        amp = 3.0
    if amp > 0.0 and SHAKE_SCALE > 0.0:
        camera.shake(amp * SHAKE_SCALE, 8 + int(amp))
    HitVfx.spawn(combat_root, info)
    DamageNumber.spawn(combat_root, info)
    var pitch: float = ELEMENT_PITCH.get(info.element, 1.0)
    if info.ko:
        sfx.play("hit_ko", info.pos, 0.0, pitch)
    elif info.heavy:
        sfx.play("hit_heavy", info.pos, 0.0, pitch)
    else:
        sfx.play("hit_light", info.pos, -3.0, pitch)
    if info.mult > 1.0:
        sfx.play("hit_super", info.pos, -6.0)

func _on_fighter_event(kind: String, pos: Vector2) -> void:
    if kind == "ultimate":
        camera.shake(5.0 * SHAKE_SCALE, 12)
        flash.color.a = 0.55
        var tw := create_tween()
        tw.tween_property(flash, "color:a", 0.0, 0.3)
    sfx.play(EVENT_SOUNDS.get(kind, ""), pos, -4.0)

func _on_died(loser: Fighter) -> void:
'''),
])

# ---------------------------------------------------------------- sfx generator
os.makedirs('assets/audio', exist_ok=True)
open('tools/generate_sfx.py', 'w').write('''"""Generates placeholder sound effects (stdlib only) into assets/audio/*.wav.
Run from the project root:  python3 tools/generate_sfx.py
Replace any file with real audio of the same name; Sfx (sfx.gd) picks it up."""
import wave, struct, math, random, os
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
random.seed(5)

def noise(n, k):                      # one-pole lowpassed noise (k small = darker)
    y, out = 0.0, []
    for _ in range(n):
        y += k * (random.uniform(-1, 1) - y)
        out.append(y)
    return out

def sweep(n, f0, f1, decay):
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t * decay))
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] * g for p, g in parts if i < len(p)) for i in range(n)]

def env(sig, decay, attack=0.004):
    return [s * min(1.0, (i / SR) / attack) * math.exp(-(i / SR) * decay) for i, s in enumerate(sig)]

def save(name, samples, gain=0.8):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * gain * 32767)) for s in samples))

n = lambda d: int(SR * d)
save("hit_light", mix((sweep(n(0.09), 200, 90, 40), 1.0), (env(noise(n(0.09), 0.5), 60), 0.6)))
save("hit_heavy", mix((sweep(n(0.25), 120, 40, 12), 1.0), (env(noise(n(0.25), 0.4), 22), 0.9)))
save("hit_ko", mix((sweep(n(0.6), 140, 35, 7), 1.0), (env(noise(n(0.5), 0.3), 10), 0.8), (sweep(n(0.55), 520, 90, 6), 0.4)))
save("hit_super", mix((sweep(n(0.25), 1320, 1320, 16), 0.6), (sweep(n(0.25), 1760, 1760, 20), 0.4)), 0.5)
save("swing", [s * math.sin(math.pi * i / n(0.12)) for i, s in enumerate(noise(n(0.12), 0.18))], 0.5)
save("swing_special", mix(([s * math.sin(math.pi * i / n(0.22)) for i, s in enumerate(noise(n(0.22), 0.1))], 0.8),
                          (env(sweep(n(0.22), 300, 800, 6), 6), 0.5)), 0.6)
save("ultimate", mix((sweep(n(0.55), 180, 1300, 3), 0.7), (env(noise(n(0.55), 0.2), 3), 0.4),
                     ([math.sin(i / SR * 40) * 0.5 + 0.5 for i in range(n(0.55))], 0.0)), 0.7)
save("dash", [s * math.sin(math.pi * i / n(0.2)) for i, s in enumerate(noise(n(0.2), 0.07))], 0.6)
save("jump", sweep(n(0.1), 280, 540, 18), 0.5)
save("shot", mix((sweep(n(0.14), 900, 350, 14), 1.0), (sweep(n(0.14), 1800, 700, 18), 0.3)), 0.5)
save("trap_set", mix((sweep(n(0.1), 520, 200, 22), 1.0), (env(noise(n(0.08), 0.4), 50), 0.4)), 0.6)
print("wrote", len(os.listdir(OUT)), "sounds")
''')
