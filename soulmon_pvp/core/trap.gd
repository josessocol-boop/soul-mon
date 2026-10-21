class_name Trap
extends Node2D
## Static ground hazard. By default lasts 3 s and springs once on an enemy.
## Move keys: trap_lifetime, trap_persistent (re-arms every trap_tick s), trap_tex.

var owner_fighter: Fighter
var move: Dictionary = {}
var life := 3.0
var persistent := false
var tick := 1.0
var cooldown := 0.0
var hitbox: Area2D
var sprite: Sprite2D
var arm_left := 0.0             # trap_delay: seconds until it can spring (it blinks meanwhile)
var area_size := Vector2(60, 16)
var frames := 1                 # trap_frames: the texture is a strip of this many frames side by side
var marker := false             # trap_marker: frame 0 is the "arming" marker, frames 1.. are the live trap
var anim_fps := 8.0
var anim_t := 0.0
var art_scale := 1.0            # trap_scale: draw scale for traps whose hit area is the default size

func setup(p_owner: Fighter, m: Dictionary) -> void:
	owner_fighter = p_owner
	move = m
	life = float(m.trap_lifetime)
	persistent = bool(m.trap_persistent)
	tick = float(m.trap_tick) if float(m.trap_tick) > 0.0 else 1.0
	arm_left = float(m.get("trap_delay", 0.0))
	area_size = m.get("trap_size", Vector2(60, 16))
	frames = maxi(1, int(m.get("trap_frames", 1)))
	marker = bool(m.get("trap_marker", false))
	anim_fps = float(m.get("trap_fps", 8.0))
	art_scale = float(m.get("trap_scale", 1.0))

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(move.trap_tex)
	sprite.position = Vector2(0, -12)   # texture sits on the ground line
	var tint: Color = move.get("fx_tint", Color.WHITE)
	sprite.self_modulate = tint
	sprite.hframes = frames
	add_child(sprite)
	_set_visual_size(arm_left <= 0.0)
	_set_frame()

	hitbox = Area2D.new()
	hitbox.name = "HitboxArea2D"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = area_size
	cs.shape = r
	cs.position = Vector2(0, -area_size.y * 0.5)
	hitbox.add_child(cs)
	add_child(hitbox)

## Custom-sized traps (wide whirlpool, tall geyser) stretch their sprite over the hit area, standing on the ground
## line. While a delayed trap is still arming only a flat marker shows (the telegraph); at full size it is live.
func _set_visual_size(full: bool) -> void:
	var tsz := sprite.texture.get_size()
	var fs := Vector2(tsz.x / float(frames), tsz.y)       # size of ONE frame
	var sc := Vector2.ONE * art_scale
	if area_size != Vector2(60, 16):
		sc = Vector2(area_size.x / fs.x, area_size.y / fs.y)
		if not full and not marker:
			sc.y = minf(area_size.y, 16.0) / fs.y            # still arming: only a flat marker (the telegraph)
	sprite.scale = sc
	sprite.position = Vector2(0, -fs.y * sc.y * 0.5)

## Animated traps: with a marker, frame 0 shows while arming and frames 1.. loop once armed.
func _set_frame() -> void:
	if frames <= 1:
		return
	var first := 1 if marker else 0
	if marker and arm_left > 0.0:
		sprite.frame = 0
	else:
		sprite.frame = first + int(anim_t * anim_fps) % maxi(1, frames - first)

func _physics_process(delta: float) -> void:
	life -= delta
	anim_t += delta
	_set_frame()
	if life <= 0.0 or not is_instance_valid(owner_fighter):
		queue_free()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if arm_left > 0.0:
		arm_left -= delta                       # still arming: harmless, blinking
		sprite.modulate.a = 0.35 + 0.35 * absf(sin(arm_left * 30.0))
		if arm_left <= 0.0:
			_set_visual_size(true)
		return
	sprite.modulate.a = 1.0
	if cooldown <= 0.0:
		for area in hitbox.get_overlapping_areas():
			var t := area.get_parent()
			if t is Fighter and t != owner_fighter:
				if t.receive_hit(owner_fighter, float(move.dmg), move.kb, global_position.x, move):
					if float(move.get("root", 0.0)) > 0.0:
						t.rooted_time = maxf(t.rooted_time, float(move.root))   # snared
					if persistent:
						cooldown = tick
					else:
						queue_free()
					return
	if life < 1.0:   # blink before expiring
		sprite.modulate.a = 0.35 + 0.65 * absf(sin(life * 18.0))
