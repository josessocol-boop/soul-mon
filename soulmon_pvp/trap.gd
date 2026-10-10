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

func setup(p_owner: Fighter, m: Dictionary) -> void:
	owner_fighter = p_owner
	move = m
	life = float(m.trap_lifetime)
	persistent = bool(m.trap_persistent)
	tick = float(m.trap_tick) if float(m.trap_tick) > 0.0 else 1.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(move.trap_tex)
	sprite.position = Vector2(0, -12)   # texture sits on the ground line
	add_child(sprite)

	hitbox = Area2D.new()
	hitbox.name = "HitboxArea2D"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 16)
	cs.shape = r
	cs.position = Vector2(0, -8)
	hitbox.add_child(cs)
	add_child(hitbox)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or not is_instance_valid(owner_fighter):
		queue_free()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0:
		for area in hitbox.get_overlapping_areas():
			var t := area.get_parent()
			if t is Fighter and t != owner_fighter:
				if t.receive_hit(owner_fighter, float(move.dmg), move.kb, global_position.x, move):
					if persistent:
						cooldown = tick
					else:
						queue_free()
					return
	if life < 1.0:   # blink before expiring
		sprite.modulate.a = 0.35 + 0.65 * absf(sin(life * 18.0))
