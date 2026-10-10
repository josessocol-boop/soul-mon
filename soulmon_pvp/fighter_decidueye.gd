extends Fighter
## Decidueye (Grass/Ghost): long-range zoner. Very low HP, screen-crossing arrows, leafy trap.

func _apply_archetype() -> void:
	hp_max = 70.0
	move_speed = 270.0
	jump_velocity = -780.0
	gravity_mult = 0.95
	types = [StatsComponent.Element.GRASS, StatsComponent.Element.GHOST]
	sheet_path = "res://assets/decidueye_sheet.png"
	fx_path = "res://assets/leaf_slash.png"
	base_color = Color(0.45, 0.7, 0.4)

func _define_moves() -> Dictionary:
	return {
		# Quill jab.
		"basic": mv({"fx": "res://assets/fx/decidueye_basic.png", "dmg": 4.0, "size": Vector2(46, 30), "off": Vector2(32, -4), "on": 3, "off_f": 6,
			"total": 12, "kb": Vector2(220, -110)}),
		# Spirit Shackles: fast arrow across the screen; shackles (slows) on hit.
		"special1": mv({"kind": "projectile", "fx_cast": "res://assets/fx/decidueye_special1_cast.png", "proj_frames": 4, "proj_scale": 1.5, "dmg": 8.0, "spawn": 6, "proj_speed": 1150.0,
			"proj_tex": "res://assets/fx/proj_arrow.png", "proj_r": 8.0, "proj_life": 2.0, "element": StatsComponent.Element.GHOST,
			"apply": "slow", "total": 16, "kb": Vector2(260, -120), "cd": 3.0, "cost": 12.0}),
		# Leafy trap dropped on the ground.
		"special2": mv({"kind": "trap", "dmg": 10.0, "spawn": 8, "total": 20, "trap_dist": 100.0,
			"trap_tex": "res://assets/leaf_trap.png", "apply": "none", "kb": Vector2(150, -520),
			"cd": 5.0, "cost": 15.0}),
		# Spirit volley: 5-arrow fan.
		"ultimate": mv({"kind": "projectile", "fx_cast": "res://assets/fx/decidueye_ultimate_cast.png", "fx_cast_off": Vector2(28, -8), "proj_frames": 4, "proj_scale": 1.5, "dmg": 7.0, "spawn": 8, "spawn_count": 5, "spawn_interval": 2,
			"proj_vys": [-260.0, -130.0, 0.0, 130.0, 260.0], "proj_speed": 1000.0,
			"proj_tex": "res://assets/fx/proj_arrow.png", "proj_r": 8.0, "proj_life": 2.0, "element": StatsComponent.Element.GHOST,
			"apply": "none", "total": 30, "kb": Vector2(260, -140)}),
	}
