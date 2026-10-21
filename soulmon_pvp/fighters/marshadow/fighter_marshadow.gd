extends Fighter
## Marshadow (Ghost/Fighting): fast close-range assassin. Extended shadow dash (more i-frames, sinks into the floor).

func _apply_archetype() -> void:
	hp_max = 88.0
	move_speed = 330.0
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
	var m: Dictionary = {
		# Fast, low-damage punches.
		"basic": mv({"fx": "res://assets/fx/marshadow_basic.png", "dmg": 4.0, "size": Vector2(54, 34), "off": Vector2(36, -4), "on": 2, "off_f": 5,
			"total": 9, "kb": Vector2(240, -120), "stun": 14, "push": 60.0}),
		# Lunging shadow strike.
		"special1": mv({"fx": "res://assets/fx/marshadow_special1.png", "dmg": 10.0, "size": Vector2(66, 46), "off": Vector2(38, -4), "on": 4, "off_f": 14,
			"total": 24, "lunge": 980.0, "kb": Vector2(580, -260), "stun": 24, "cd": 3.0, "cost": 12.0}),
		# Shadow sneak: invincible dash-through that cuts as it passes.
		"special2": mv({"fx": "res://assets/fx/marshadow_special2.png", "dmg": 10.0, "size": Vector2(76, 58), "off": Vector2(22, -4), "on": 3, "off_f": 13,
			"total": 24, "lunge": 1200.0, "i_frames": 14, "kb": Vector2(320, -320), "cd": 4.0, "cost": 16.0}),
		# Spectral flurry: rapid multi-hit cage.
		"ultimate": mv({"fx": "res://assets/fx/marshadow_ultimate.png", "dmg": 6.0, "size": Vector2(180, 100), "off": Vector2(34, -6), "on": 6, "off_f": 34,
			"total": 44, "hit_interval": 5, "kb": Vector2(240, -170), "stun": 20}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Shadow Trip: a very fast low kick that trips the target (they cannot move or jump for a moment)
	m["basic_down"] = variant(m.basic, {"size": Vector2(72, 26), "off": Vector2(42, 22), "dmg": 5.0, "on": 3, "off_f": 6, "total": 12, "kb": Vector2(140, -400), "stun": 16, "push": 0.0, "root": 0.45, "fx": "res://assets/fx/down_marshadow_basic.png", "fx_frames": 4, "fx_loop": false, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Spectral Slide: a long low slide that DRAGS the target along with it - four quick hits, not invincible (unlike the shadow sneak)
	m["special1_down"] = variant(m.special1, {"size": Vector2(90, 30), "off": Vector2(40, 22), "dmg": 3.0, "on": 3, "off_f": 20, "total": 30, "lunge": 1000.0, "hit_interval": 4, "i_frames": 0, "kb": Vector2(320, -140), "stun": 12, "fx": "res://assets/fx/down_marshadow_special1.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(1.25, 0.65), "anim_tilt": 0.5})
	# Spirit Uppercut: the shadow sneak turns into a rising invincible uppercut
	m["special2_down"] = variant(m.special2, {"size": Vector2(64, 110), "off": Vector2(30, -30), "dmg": 13.0, "on": 3, "off_f": 11, "total": 26, "lunge": 520.0, "hop": -420.0, "i_frames": 10, "kb": Vector2(140, -720), "stun": 26, "fx": "res://assets/fx/down_marshadow_special2.png", "fx_frames": 4, "fx_loop": false, "anim_scale": Vector2(0.92, 1.2), "anim_tilt": -0.25})
	return m
