extends Fighter
## Gengar (Ghost/Poison): tricky evasive zoner. Floaty jumps, shadow balls, poison trap.

func _apply_archetype() -> void:
	hp_max = 100.0
	move_speed = 260.0
	jump_velocity = -700.0
	gravity_mult = 0.55
	max_fall = 520.0
	types = [StatsComponent.Element.GHOST, StatsComponent.Element.POISON]
	sheet_path = "res://assets/gengar_sheet.png"
	fx_path = "res://assets/shadow_slash.png"
	base_color = Color(0.65, 0.4, 0.85)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Shadow claw.
		"basic": mv({"fx": "res://assets/fx/gengar_basic.png", "dmg": 5.0, "size": Vector2(50, 36), "off": Vector2(32, -4), "on": 4, "off_f": 8,
			"total": 15, "kb": Vector2(260, -160)}),
		# Shadow Ball.
		"special1": mv({"kind": "projectile", "dmg": 10.0, "spawn": 8, "proj_speed": 520.0,
			"proj_tex": "res://assets/fx/proj_shadowball.png", "proj_frames": 4, "proj_scale": 2.0, "proj_r": 14.0, "total": 20,
			"kb": Vector2(300, -180), "cd": 3.0, "cost": 15.0}),
		# Poison trap on the floor: damage + poison.
		"special2": mv({"kind": "trap", "dmg": 6.0, "spawn": 8, "total": 20, "trap_dist": 90.0,
			"trap_tex": "res://assets/poison_trap.png", "trap_persistent": true, "trap_lifetime": 6.0,"element": StatsComponent.Element.POISON, "kb": Vector2(120, -380),
			"cd": 5.0, "cost": 15.0}),
		# Giant, slow Shadow Ball.
		"ultimate": mv({"kind": "projectile", "dmg": 26.0, "spawn": 12, "proj_speed": 380.0,
			"proj_tex": "res://assets/fx/proj_shadowball.png", "proj_frames": 4, "proj_scale": 4.0, "proj_r": 30.0, "total": 36,
			"kb": Vector2(800, -350)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Shadow Hand: a shadow hand grabs at the floor far in front of Gengar after a delay and trips the target
	m["basic_down"] = variant(m.basic, {"size": Vector2(48, 70), "off": Vector2(104, -9), "dmg": 6.0, "on": 10, "off_f": 15, "total": 22, "kb": Vector2(120, -420), "stun": 22, "root": 0.5, "fx": "res://assets/fx/down_gengar_basic.png", "fx_frames": 4, "fx_loop": false, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Creeping Shadow Ball: a huge, very slow ball that drifts forward and keeps hurting whatever it passes through
	m["special1_down"] = variant(m.special1, {"proj_speed": 170.0, "proj_off": Vector2(30, 6), "proj_scale": 3.4, "proj_r": 24.0, "dmg": 4.0, "proj_life": 5.0, "proj_pierce": true, "proj_hit_gap": 0.5, "total": 22, "kb": Vector2(140, -260), "stun": 16, "anim_scale": Vector2(1.1, 0.85), "anim_tilt": 0.2})
	# Poison Pit: three small poison pits laid in a row in front of you
	m["special2_down"] = variant(m.special2, {"spawn_count": 3, "spawn_interval": 5, "trap_dist": 55.0, "trap_step": 65.0, "trap_size": Vector2(44, 16), "trap_lifetime": 4.5, "dmg": 4.0, "total": 28, "kb": Vector2(100, -420), "trap_tex": "res://assets/fx/trap_pit.png", "trap_frames": 4, "trap_fps": 6.0, "fx_tint": Color.WHITE})
	return m
