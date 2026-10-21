extends Fighter
## Greninja (Water/Dark): high-mobility zoner. Huge jump, fast fall, water blades and shurikens.

func _apply_archetype() -> void:
	hp_max = 115.0
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
	var m: Dictionary = {
		# Fast water blade (no slow, so it can be spammed).
		"basic": mv({"fx": "res://assets/fx/greninja_basic.png", "dmg": 5.5, "size": Vector2(64, 26), "off": Vector2(38, -4), "on": 2, "off_f": 5,
			"total": 9, "kb": Vector2(200, -100), "stun": 12, "apply": "none"}),
		# Water shurikens: 3-way fan.
		"special1": mv({"kind": "projectile", "dmg": 4.0, "spawn": 6, "spawn_count": 3, "spawn_interval": 0,
			"proj_vys": [-170.0, 0.0, 170.0], "proj_speed": 820.0, "proj_tex": "res://assets/fx/proj_shuriken.png", "proj_frames": 4, "proj_scale": 1.5,
			"proj_r": 9.0, "proj_spin": 20.0, "total": 16, "kb": Vector2(240, -120), "cd": 3.5, "cost": 12.0}),
		# Ground-hugging water wave.
		"special2": mv({"kind": "projectile", "dmg": 11.0, "spawn": 8, "proj_speed": 460.0,
			"proj_tex": "res://assets/fx/proj_wave.png", "proj_frames": 4, "proj_scale": 2.0, "proj_r": 20.0, "proj_off": Vector2(30, 12),
			"total": 22, "kb": Vector2(400, -380), "cd": 5.0, "cost": 18.0}),
		# Hydro Cannon: screen-wide beam.
		"ultimate": mv({"fx": "res://assets/fx/greninja_ultimate.png", "dmg": 28.0, "size": Vector2(440, 56), "off": Vector2(240, -4), "on": 10, "off_f": 20,
			"total": 38, "kb": Vector2(800, -300)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Slide Slash: Greninja vanishes and slides through, slashing low from the other side (brief invincibility)
	m["basic_down"] = variant(m.basic, {"size": Vector2(74, 24), "off": Vector2(44, 22), "dmg": 5, "on": 8, "off_f": 13, "total": 22, "teleport_distance": 110.0, "i_frames": 0, "kb": Vector2(200, -300), "stun": 14, "fx": "res://assets/fx/down_greninja_basic.png", "fx_frames": 4, "fx_loop": false, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Skimming Shuriken: ONE big water shuriken that skips along the floor like a stone
	m["special1_down"] = variant(m.special1, {"down_pref": 0.7, "spawn_count": 1, "proj_vys": [260.0], "proj_speed": 600.0, "proj_off": Vector2(30, 10), "proj_scale": 2.4, "proj_r": 14.0, "proj_gravity": 2200.0, "proj_bounce": 3, "proj_life": 2.0, "dmg": 6.0, "total": 20, "kb": Vector2(220, -260), "anim_scale": Vector2(1.15, 0.78), "anim_tilt": 0.2})
	# Whirlpool: a wide whirlpool that stays on the floor and keeps slowing and nicking anyone inside
	m["special2_down"] = variant(m.special2, {"down_pref": 0.1, "kind": "trap", "dmg": 3.0, "spawn": 8, "total": 20, "trap_dist": 90.0, "trap_lifetime": 3.5, "trap_persistent": true, "trap_tick": 0.55, "trap_size": Vector2(200, 36), "apply": "slow", "element": StatsComponent.Element.WATER, "trap_tex": "res://assets/fx/trap_whirlpool.png", "fx_tint": Color.WHITE, "kb": Vector2(60, -160), "stun": 12, "trap_frames": 4, "trap_fps": 8.0})
	return m
