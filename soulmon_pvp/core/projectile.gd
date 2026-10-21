class_name Projectile
extends Node2D
## Data-driven projectile. All numbers come from the casting move's dictionary
## (speed, texture, size, spin, element, status...). Frees itself on wall/floor
## (StaticBody2D) or on connecting with an enemy HurtboxArea2D.

var shooter: Fighter
var move_key := ""           # which move fired this shot (for the balance tool's per-move hit counts)
var dir := 1
var move: Dictionary = {}
var vy := 0.0
var speed := 600.0
var life := 3.0
var hitbox: Area2D
var spr: Sprite2D
var age := 0
var gravity := 0.0                 # move key proj_gravity: px/s^2 pulling the shot down (lobs, skips)
var bounces_left := 0              # move key proj_bounce: floor skips before it vanishes
var pierce := false                # move key proj_pierce: keeps flying after a hit
var hit_gap_frames := 27           # pierce: frames before the same fighter can be hit again
var last_hit := {}                 # pierce: fighter -> age of the last hit on it
const WORLD_GRACE_FRAMES := 2

func setup(p_shooter: Fighter, p_dir: int, m: Dictionary, p_vy: float) -> void:
	shooter = p_shooter
	dir = p_dir
	move = m
	vy = p_vy
	speed = float(m.proj_speed)
	life = float(m.proj_life)
	gravity = float(m.get("proj_gravity", 0.0))
	bounces_left = int(m.get("proj_bounce", 0))
	pierce = bool(m.get("proj_pierce", false))
	hit_gap_frames = maxi(1, int(round(float(m.get("proj_hit_gap", 0.45)) * 60.0)))

func _ready() -> void:
	spr = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = load(move.proj_tex)
	spr.hframes = maxi(1, int(move.proj_frames))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * float(move.proj_scale)
	spr.z_index = 1
	add_child(spr)
	rotation = atan2(vy, dir * speed)   # arrows / bolts point along their path

	hitbox = Area2D.new()
	hitbox.name = "HitboxArea2D"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 3   # world (1) + fighter hurtboxes (2)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(move.proj_r)
	cs.shape = circle
	hitbox.add_child(cs)
	add_child(hitbox)

func _physics_process(delta: float) -> void:
	age += 1
	if spr.hframes > 1:
		spr.frame = int(float(age) * float(move.proj_fps) / 60.0) % spr.hframes
	vy += gravity * delta
	position += Vector2(dir * speed, vy) * delta
	if float(move.proj_spin) != 0.0:
		spr.rotation += float(move.proj_spin) * delta
	life -= delta
	if life <= 0.0 or not is_instance_valid(shooter):
		queue_free()
		return
	# Fighters first: a point-blank shot at someone standing against a wall must hit them.
	for area in hitbox.get_overlapping_areas():
		var t := area.get_parent()
		if t is Fighter and t != shooter:
			if pierce and age - int(last_hit.get(t, -100000)) < hit_gap_frames:
				continue   # piercing shots re-hit the same fighter only every proj_hit_gap seconds
			if t.receive_hit(shooter, float(move.dmg), move.kb, global_position.x, move):
				shooter.landed_hit = true
				shooter.shot_hit_keys.append(move_key)
				if float(move.get("root", 0.0)) > 0.0:
					t.rooted_time = maxf(t.rooted_time, float(move.root))   # shackled / tripped
				if pierce:
					last_hit[t] = age
				else:
					queue_free()
					return
	# World: only vanish when the projectile's CENTER is inside solid geometry.
	# (Circle-vs-body overlap killed ground-hugging and low-spawned shots instantly.)
	if age > WORLD_GRACE_FRAMES:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position
		q.collision_mask = 1
		for r in get_world_2d().direct_space_state.intersect_point(q, 4):
			if r.collider is StaticBody2D:
				if bounces_left > 0 and vy > 0.0:
					bounces_left -= 1                  # skip off the floor like a stone
					vy = -maxf(absf(vy) * 0.8, 320.0)
					position.y -= 4.0
					return
				queue_free()
				return
