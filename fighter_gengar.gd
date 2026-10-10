extends Fighter
## Gengar (Ghost/Poison): tricky evasive zoner. Floaty jumps, shadow balls, poison trap.

func _apply_archetype() -> void:
	hp_max = 90.0
	move_speed = 250.0
	jump_velocity = -700.0
	gravity_mult = 0.55
	max_fall = 520.0
	types = [StatsComponent.Element.GHOST, StatsComponent.Element.POISON]
	sheet_path = "res://assets/gengar_sheet.png"
	fx_path = "res://assets/shadow_slash.png"
	base_color = Color(0.65, 0.4, 0.85)

func _define_moves() -> Dictionary:
	return {
		# Shadow claw.
		"basic": mv({"fx": "res://assets/fx/gengar_basic.png", "dmg": 5.0, "size": Vector2(50, 36), "off": Vector2(32, -4), "on": 4, "off_f": 8,
			"total": 15, "kb": Vector2(260, -160)}),
		# Shadow Ball.
		"special1": mv({"kind": "projectile", "dmg": 10.0, "spawn": 8, "proj_speed": 520.0,
			"proj_tex": "res://assets/fx/proj_shadowball.png", "proj_frames": 4, "proj_scale": 2.0, "proj_r": 14.0, "total": 20,
			"kb": Vector2(300, -180), "cd": 3.0, "cost": 15.0}),
		# Poison trap on the floor: damage + poison.
		"special2": mv({"kind": "trap", "dmg": 6.0, "spawn": 8, "total": 20, "trap_dist": 90.0,
			"trap_tex": "res://assets/poison_trap.png", "element": StatsComponent.Element.POISON, "kb": Vector2(120, -380),
			"cd": 5.0, "cost": 15.0}),
		# Giant, slow Shadow Ball.
		"ultimate": mv({"kind": "projectile", "dmg": 30.0, "spawn": 12, "proj_speed": 380.0,
			"proj_tex": "res://assets/fx/proj_shadowball.png", "proj_frames": 4, "proj_scale": 4.0, "proj_r": 30.0, "total": 36,
			"kb": Vector2(800, -350)}),
	}
