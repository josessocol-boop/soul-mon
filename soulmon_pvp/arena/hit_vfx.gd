class_name HitVfx
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
    E.PSYCHIC:  {"c": Color(0.95, 0.45, 0.85), "c2": Color(0.8, 0.7, 1.0), "n": 16, "v": [80, 260], "g": 0, "s": [3, 5], "life": 0.5, "spread": 170},
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