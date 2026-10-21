extends Fighter
## Gholdengo (Steel/Ghost): mid-range zoner. Surfboard swings and gold-coin projectiles.

func _apply_archetype() -> void:
	hp_max = 100.0
	move_speed = 235.0
	jump_velocity = -740.0
	gravity_mult = 1.1
	types = [StatsComponent.Element.STEEL, StatsComponent.Element.GHOST]
	sheet_path = "res://assets/gholdengo_sheet.png"
	fx_path = "res://assets/gold_slash.png"
	base_color = Color(0.95, 0.78, 0.3)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Surfboard swing.
		"basic": mv({"fx": "res://assets/fx/gholdengo_basic.png", "dmg": 7.0, "size": Vector2(92, 44), "off": Vector2(50, -6), "on": 6, "off_f": 10,
			"total": 20, "kb": Vector2(420, -220), "push": 40.0}),
		# Coin barrage: 3 coins in a fan.
		"special1": mv({"kind": "projectile", "fx_cast": "res://assets/fx/gholdengo_special1_cast.png", "fx_cast_off": Vector2(30, -8), "dmg": 4.0, "spawn": 6, "spawn_count": 3, "spawn_interval": 4,
			"proj_vys": [-90.0, 0.0, 90.0], "proj_speed": 650.0, "proj_tex": "res://assets/fx/proj_coin.png", "proj_frames": 4, "proj_scale": 1.5,
			"proj_r": 8.0, "proj_spin": 14.0, "total": 24, "kb": Vector2(180, -90), "stun": 14,
			"cd": 3.0, "cost": 15.0}),
		# Golden burst: big AoE around the body.
		"special2": mv({"fx": "res://assets/fx/gholdengo_special2.png", "dmg": 15.0, "size": Vector2(210, 150), "off": Vector2(0, -14), "on": 8, "off_f": 14,
			"total": 30, "kb": Vector2(560, -420), "cd": 5.0, "cost": 20.0}),
		# Make It Rain: a long spray of coins.
		"ultimate": mv({"kind": "projectile", "fx_cast": "res://assets/fx/gholdengo_ultimate_cast.png", "fx_cast_off": Vector2(32, -8), "dmg": 5.5, "spawn": 8, "spawn_count": 7, "spawn_interval": 4,
			"proj_vys": [-200.0, -140.0, -70.0, 0.0, 70.0, 140.0, 200.0], "proj_speed": 720.0,
			"proj_tex": "res://assets/fx/proj_coin.png", "proj_frames": 4, "proj_scale": 1.5, "proj_r": 8.0, "proj_spin": 14.0, "total": 42,
			"kb": Vector2(240, -160)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Surf Sweep: Gholdengo surfs forward along the floor, carrying a low board through the target
	m["basic_down"] = variant(m.basic, {"down_pref": 0.7, "size": Vector2(110, 26), "off": Vector2(56, 22), "dmg": 6.0, "on": 5, "off_f": 18, "total": 26, "lunge": 640.0, "push": 0.0, "kb": Vector2(300, -360), "fx": "res://assets/fx/down_gholdengo_basic.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Coin Roll: three coins are dropped to bounce and roll across the floor (a skipping barrage, not a flat fan)
	m["special1_down"] = variant(m.special1, {"spawn_count": 3, "spawn_interval": 5, "proj_vys": [-120.0, -60.0, 0.0], "proj_speed": 430.0, "proj_off": Vector2(30, 16), "proj_gravity": 1800.0, "proj_bounce": 3, "proj_life": 2.2, "total": 30, "dmg": 4.5, "kb": Vector2(160, -300), "anim_scale": Vector2(1.12, 0.82), "anim_tilt": 0.2})
	# Gilded Geyser: two golden geysers erupt one after the other in front of you (telegraphed, then they launch)
	m["special2_down"] = variant(m.special2, {"kind": "trap", "spawn": 10, "spawn_count": 2, "spawn_interval": 8, "trap_dist": 120.0, "trap_step": 130.0, "trap_delay": 0.35, "trap_lifetime": 0.9, "trap_size": Vector2(90, 240), "trap_tex": "res://assets/fx/trap_geyser.png", "fx_tint": Color.WHITE, "apply": "none", "dmg": 13.0, "total": 34, "kb": Vector2(120, -760), "stun": 30, "fx": "", "trap_frames": 4, "trap_marker": true, "trap_fps": 10.0})
	return m
