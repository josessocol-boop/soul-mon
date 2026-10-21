extends Fighter
## Alakazam (Psychic): tricky zoner. Psybeam bursts, a bouncing Psywave, Future Sight traps, Reflect stance.

func _apply_archetype() -> void:
	hp_max = 95.0
	move_speed = 280.0
	jump_velocity = -760.0
	gravity_mult = 0.9
	max_fall = 900.0
	types = [StatsComponent.Element.PSYCHIC]
	sheet_path = "res://assets/alakazam_sheet.png"
	fx_path = "res://assets/pink_slash.png"
	base_color = Color(0.95, 0.8, 0.3)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Psybeam: a burst of three shots, short range. Lighter, slower shots and a longer recovery: it used to land about 21 times a match.
		"basic": mv({"kind": "projectile", "dmg": 2.0, "spawn": 4, "spawn_count": 3, "spawn_interval": 4,
			"proj_speed": 560.0, "proj_life": 0.6, "proj_tex": "res://assets/fx/proj_psybeam.png", "proj_frames": 4, "proj_scale": 1.8, "proj_r": 10.0,
			"total": 28, "kb": Vector2(120, -120)}),
		# Psywave: bounces off the floor twice.
		"special1": mv({"kind": "projectile", "dmg": 8.0, "spawn": 8, "proj_speed": 640.0,
			"proj_life": 1.6, "proj_tex": "res://assets/fx/proj_psywave.png", "proj_frames": 4, "proj_scale": 1.5, "proj_r": 12.0,
			"total": 20, "kb": Vector2(200, -220), "cd": 2.5, "cost": 12.0}),
		# Reflect: absorbs the next hit and sends it back at 1.5x damage, at most 10 (a heavy hit used to come back for 30).
		"special2": mv({"fx": "res://assets/fx/alakazam_special2.png", "fx_frames": 4, "counter": true, "counter_frames": 72, "counter_cap": 10.0, "dmg": 0.0, "total": 36, "cd": 4.0, "cost": 14.0}),
		# Mind Blast: a wide beam that chips three times. It is narrower and shorter-lived than before (520 px, active 20-44
		# frames after a visible windup), so a dash can get out of it. It used to cover the screen for 46 frames, four hits.
		"ultimate": mv({"fx": "res://assets/fx/alakazam_ultimate.png", "fx_frames": 4, "dmg": 5.0, "size": Vector2(520, 70), "off": Vector2(270, -6), "on": 20, "off_f": 44,
			"total": 70, "hit_interval": 12, "kb": Vector2(60, -80), "stun": 10, "cd": 10.0, "cost": 30.0}),
	}
	# Teleport Strike: blinks forward first, then the melee hitbox comes out.
	m["basic_down"] = mv({"fx": "res://assets/fx/down_alakazam_basic.png", "fx_frames": 4, "dmg": 6.0, "teleport_distance": 150.0, "size": Vector2(60, 44), "off": Vector2(34, -6),
		"on": 8, "off_f": 13, "total": 20, "kb": Vector2(260, -180), "cd": 2.0})
	# Future Sight: a delayed trap that erupts two seconds after it is set.
	m["special1_down"] = mv({"kind": "trap", "dmg": 12.0, "spawn": 8, "total": 24, "trap_dist": 120.0,
		"trap_delay": 1.4, "trap_lifetime": 6.0, "trap_tex": "res://assets/fx/trap_future_sight.png", "trap_frames": 4, "trap_fps": 8.0, "trap_scale": 1.5,   # 4-frame strip of 40x16 crystal swords at 60x24
		"kb": Vector2(160, -520), "cd": 5.0, "cost": 18.0})
	# Kinesis: squash into a low crouch; hits slow the target.
	m["special2_down"] = mv({"fx": "res://assets/fx/down_alakazam_special2.png", "fx_frames": 4, "dmg": 3.0, "pull": true, "pull_dist": 70.0, "pull_hold": 14, "size": Vector2(120, 50), "off": Vector2(40, 14), "on": 6, "off_f": 20,
		"total": 30, "apply": "slow", "anim_scale": Vector2(1.2, 0.7), "anim_tilt": 0.0,
		"kb": Vector2(60, -120), "cd": 5.0, "cost": 10.0})
	return m
