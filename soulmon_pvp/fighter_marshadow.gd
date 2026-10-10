extends Fighter
## Marshadow (Ghost/Fighting): fast close-range assassin. Extended shadow dash (more i-frames, sinks into the floor).

func _apply_archetype() -> void:
	hp_max = 90.0
	move_speed = 345.0
	jump_velocity = -820.0
	gravity_mult = 0.95
	types = [StatsComponent.Element.GHOST, StatsComponent.Element.FIGHTING]
	dash_speed = 780.0
	dash_frames = 24
	iframe_frames = 20   # 0.33 s vs the default 0.2 s
	dash_sink = true
	sheet_path = "res://assets/marshadow_sheet.png"
	fx_path = "res://assets/shadow_slash.png"
	base_color = Color(0.55, 0.42, 0.78)

func _define_moves() -> Dictionary:
	return {
		# Fast, low-damage punches.
		"basic": mv({"fx": "res://assets/fx/marshadow_basic.png", "dmg": 5.0, "size": Vector2(54, 34), "off": Vector2(36, -4), "on": 2, "off_f": 5,
			"total": 9, "kb": Vector2(240, -120), "stun": 14, "push": 60.0}),
		# Lunging shadow strike.
		"special1": mv({"fx": "res://assets/fx/marshadow_special1.png", "dmg": 14.0, "size": Vector2(66, 46), "off": Vector2(38, -4), "on": 4, "off_f": 14,
			"total": 24, "lunge": 980.0, "kb": Vector2(580, -260), "stun": 24, "cd": 2.5, "cost": 12.0}),
		# Shadow sneak: invincible dash-through that cuts as it passes.
		"special2": mv({"fx": "res://assets/fx/marshadow_special2.png", "dmg": 12.0, "size": Vector2(76, 58), "off": Vector2(22, -4), "on": 3, "off_f": 13,
			"total": 24, "lunge": 1200.0, "i_frames": 14, "kb": Vector2(320, -320), "cd": 4.0, "cost": 16.0}),
		# Spectral flurry: rapid multi-hit cage.
		"ultimate": mv({"fx": "res://assets/fx/marshadow_ultimate.png", "dmg": 6.0, "size": Vector2(180, 100), "off": Vector2(34, -6), "on": 6, "off_f": 34,
			"total": 44, "hit_interval": 5, "kb": Vector2(240, -170), "stun": 20}),
	}
