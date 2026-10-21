extends Fighter
## Toxicroak (Poison/Fighting): evasive assassin. Poison jabs, Toxic Spikes, Sucker Punch, Venom Drag.

func _apply_archetype() -> void:
	hp_max = 140.0
	move_speed = 320.0
	jump_velocity = -760.0
	max_fall = 1000.0
	types = [StatsComponent.Element.POISON, StatsComponent.Element.FIGHTING]
	sheet_path = "res://assets/toxicroak_sheet.png"
	fx_path = "res://assets/leaf_slash.png"
	base_color = Color(0.45, 0.2, 0.6)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Poison Jab: a quick poke that poisons.
		# Fighting element: Poison was halved by Steel defenders. The poison still applies through "apply".
		"basic": mv({"fx": "res://assets/fx/toxicroak_basic.png", "fx_frames": 4, "dmg": 6.5, "apply": "poison", "element": StatsComponent.Element.FIGHTING, "size": Vector2(52, 30), "off": Vector2(34, -6), "on": 3,
			"off_f": 8, "total": 20, "kb": Vector2(200, -120), "stun": 14}),
		# Sludge Bomb: a lob that falls onto the target.
		"special1": mv({"kind": "projectile", "dmg": 11.0, "apply": "poison", "spawn": 8, "proj_speed": 420.0,
			"proj_gravity": 650.0, "proj_vys": [-340.0], "proj_life": 2.5, "proj_tex": "res://assets/fx/proj_sludge.png", "proj_frames": 4,
			"proj_scale": 1.8, "proj_r": 12.0, "total": 22, "kb": Vector2(200, -260), "cd": 3.0, "cost": 15.0}),
		# Sucker Punch: leans back with a small hop, then lunges forward.
		"special2": mv({"fx": "res://assets/fx/toxicroak_special2.png", "fx_frames": 4, "dmg": 13.0, "apply": "poison", "push": -160.0, "hop": -180.0, "lunge": 520.0, "size": Vector2(60, 40),
			"off": Vector2(36, -6), "on": 14, "off_f": 20, "total": 30, "kb": Vector2(240, -160), "cd": 4.0, "cost": 16.0}),
		# Gunk Shot: a barrage of five poison shots.
		"ultimate": mv({"kind": "projectile", "dmg": 5.0, "apply": "poison", "spawn": 10, "spawn_count": 5,
			"spawn_interval": 6, "proj_speed": 700.0, "proj_vys": [-60.0, -30.0, 0.0, 30.0, 60.0], "proj_life": 1.4,
			"proj_tex": "res://assets/fx/proj_sludge.png", "proj_frames": 4, "proj_scale": 1.6, "proj_r": 10.0, "total": 40,
			"kb": Vector2(90, -120), "cd": 10.0, "cost": 30.0}),
	}
	# Sludge Sweep: a very low crouch-sweep, low enough to slip under high attacks.
	m["basic_down"] = mv({"fx": "res://assets/fx/down_toxicroak_basic.png", "fx_frames": 4, "dmg": 4.0, "apply": "poison", "size": Vector2(70, 22), "off": Vector2(40, 28), "on": 5,
		"off_f": 11, "total": 20, "anim_scale": Vector2(1.25, 0.6), "anim_tilt": 0.2, "kb": Vector2(180, -200), "stun": 18})
	# Toxic Spikes: a floor trap that stays down after it has poisoned someone.
	m["special1_down"] = mv({"down_pref": 0.1, "kind": "trap", "dmg": 3.0, "apply": "poison", "spawn": 8, "total": 24,
		"trap_dist": 110.0, "trap_persistent": true, "trap_lifetime": 8.0, "trap_tex": "res://assets/fx/trap_toxic_spikes.png", "trap_frames": 4,
		"kb": Vector2(60, -180), "cd": 6.0, "cost": 15.0})
	# Venom Drag: yanks the target in and stops them teching.
	m["special2_down"] = mv({"fx": "res://assets/fx/down_toxicroak_special2.png", "fx_frames": 4, "dmg": 6.0, "apply": "poison", "pull": true, "no_tech": true, "pull_dist": 40.0,
		"pull_hold": 14, "size": Vector2(120, 50), "off": Vector2(60, -4), "on": 6, "off_f": 18, "total": 28,
		"kb": Vector2(60, -100), "stun": 14, "cd": 6.0, "cost": 16.0})
	return m
