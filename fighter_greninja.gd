extends Fighter
## Greninja (Water/Dark): high-mobility zoner. Huge jump, fast fall, water blades and shurikens.

func _apply_archetype() -> void:
	hp_max = 80.0
	move_speed = 330.0
	jump_velocity = -1000.0
	gravity_mult = 1.0
	fall_mult = 1.8
	max_fall = 1500.0
	types = [StatsComponent.Element.WATER, StatsComponent.Element.DARK]
	sheet_path = "res://assets/greninja_sheet.png"
	fx_path = "res://assets/water_splash.png"
	base_color = Color(0.3, 0.55, 0.95)

func _define_moves() -> Dictionary:
	return {
		# Fast water blade (no slow, so it can be spammed).
		"basic": mv({"fx": "res://assets/fx/greninja_basic.png", "dmg": 4.0, "size": Vector2(64, 26), "off": Vector2(38, -4), "on": 2, "off_f": 5,
			"total": 9, "kb": Vector2(200, -100), "stun": 12, "apply": "none"}),
		# Water shurikens: 3-way fan.
		"special1": mv({"kind": "projectile", "dmg": 4.0, "spawn": 6, "spawn_count": 3, "spawn_interval": 0,
			"proj_vys": [-170.0, 0.0, 170.0], "proj_speed": 820.0, "proj_tex": "res://assets/fx/proj_shuriken.png", "proj_frames": 4, "proj_scale": 1.5,
			"proj_r": 9.0, "proj_spin": 20.0, "total": 16, "kb": Vector2(240, -120), "cd": 3.0, "cost": 12.0}),
		# Ground-hugging water wave.
		"special2": mv({"kind": "projectile", "dmg": 9.0, "spawn": 8, "proj_speed": 460.0,
			"proj_tex": "res://assets/fx/proj_wave.png", "proj_frames": 4, "proj_scale": 2.0, "proj_r": 20.0, "proj_off": Vector2(30, 12),
			"total": 22, "kb": Vector2(400, -380), "cd": 5.0, "cost": 18.0}),
		# Hydro Cannon: screen-wide beam.
		"ultimate": mv({"fx": "res://assets/fx/greninja_ultimate.png", "dmg": 32.0, "size": Vector2(440, 56), "off": Vector2(240, -4), "on": 10, "off_f": 20,
			"total": 38, "kb": Vector2(800, -300)}),
	}
