extends Fighter
## Lucario (Fighting/Steel): combo rushdown. Bone Rush strings, aura projectiles, Swords Dance, Extreme Speed.

func _apply_archetype() -> void:
	hp_max = 160.0
	move_speed = 300.0
	jump_velocity = -740.0
	max_fall = 1000.0
	types = [StatsComponent.Element.FIGHTING, StatsComponent.Element.STEEL]
	sheet_path = "res://assets/lucario_sheet.png"
	fx_path = "res://assets/fire_slash.png"
	base_color = Color(0.3, 0.55, 0.9)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Bone Rush: three hits inside the first 17 frames. The longer recovery (26 frames) stops it being spammed.
		# Steel element: Fighting was halved by Ghost defenders, Steel is neutral against them.
		"basic": mv({"fx": "res://assets/fx/lucario_basic.png", "fx_frames": 4, "dmg": 2.8, "element": StatsComponent.Element.STEEL, "size": Vector2(56, 40), "off": Vector2(34, -4), "on": 3, "off_f": 17,
			"total": 26, "hit_interval": 5, "kb": Vector2(90, -120), "stun": 10}),
		# Aura Sphere: fast and flat.
		"special1": mv({"kind": "projectile", "dmg": 10.0, "spawn": 7, "proj_speed": 900.0, "proj_vys": [0.0],
			"proj_life": 1.2, "proj_tex": "res://assets/fx/proj_aura_sphere.png", "proj_frames": 4, "proj_scale": 2.4, "proj_r": 12.0,
			"total": 18, "kb": Vector2(260, -120), "cd": 2.5, "cost": 15.0}),
		# Swords Dance: the next attack hits harder and stuns longer.
		"special2": mv({"fx": "res://assets/fx/lucario_special2.png", "fx_frames": 4, "dmg": 0.0, "damage_buff": 1.5, "hitstun_mult": 1.2, "total": 30, "cd": 6.0, "cost": 15.0}),
		# Max Aura: a beam with a high knockback and a short forward push.
		"ultimate": mv({"kind": "projectile", "dmg": 24.0, "spawn": 10, "proj_speed": 1100.0, "push": 200.0, "proj_life": 1.2,
			"proj_tex": "res://assets/fx/proj_max_aura.png", "proj_frames": 4, "proj_scale": 2.4, "proj_r": 24.0, "total": 34,
			"kb": Vector2(900, -260), "cd": 9.0, "cost": 30.0}),
	}
	# Low Kick: a fast sweep that lunges in.
	m["basic_down"] = mv({"fx": "res://assets/fx/down_lucario_basic.png", "fx_frames": 4, "dmg": 6.0, "lunge": 180.0, "size": Vector2(70, 26), "off": Vector2(44, 30), "on": 5,
		"off_f": 11, "total": 24, "kb": Vector2(220, -160), "stun": 16, "anim_scale": Vector2(1.2, 0.8)})
	# Aura Storm: three shots fanned out.
	m["special1_down"] = mv({"kind": "projectile", "dmg": 4.0, "spawn": 8, "spawn_count": 3, "spawn_interval": 5,
		"proj_speed": 620.0, "proj_vys": [-120.0, 0.0, 120.0], "proj_life": 1.5, "proj_tex": "res://assets/fx/proj_aura_sphere.png",
		"proj_frames": 4, "proj_scale": 2.0, "proj_r": 10.0, "total": 24, "kb": Vector2(160, -160), "cd": 4.0, "cost": 18.0})
	# Extreme Speed: a fast dash-attack that is intangible while it starts.
	m["special2_down"] = mv({"fx": "res://assets/fx/down_lucario_special2.png", "fx_frames": 4, "dmg": 10.0, "lunge": 620.0, "i_frames": 14, "size": Vector2(80, 50),
		"off": Vector2(40, -6), "on": 4, "off_f": 16, "total": 26, "kb": Vector2(340, -200), "cd": 4.0, "cost": 16.0})
	return m
