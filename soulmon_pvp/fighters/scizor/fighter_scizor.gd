extends Fighter
## Scizor (Bug/Steel): rushdown brawler. Heavy gravity, fast cheap dashes, bullet-punch flurry.

func _apply_archetype() -> void:
	hp_max = 140.0
	move_speed = 255.0
	jump_velocity = -740.0
	gravity_mult = 1.4
	types = [StatsComponent.Element.BUG, StatsComponent.Element.STEEL]
	dash_speed = 940.0
	dash_frames = 12
	iframe_frames = 9
	dash_cost = 15.0
	sheet_path = "res://assets/scizor_sheet.png"
	fx_path = "res://assets/steel_slash.png"
	base_color = Color(0.88, 0.25, 0.28)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Claw slash.
		"basic": mv({"fx": "res://assets/fx/scizor_basic.png", "dmg": 8.0, "size": Vector2(66, 40), "off": Vector2(40, -6), "on": 4, "off_f": 8,
			"total": 16, "kb": Vector2(380, -200)}),
		# Bullet Punch: rapid flurry that creeps forward.
		"special1": mv({"fx": "res://assets/fx/scizor_special1.png", "dmg": 3.0, "size": Vector2(50, 34), "off": Vector2(34, -4), "on": 3, "off_f": 31,
			"total": 38, "hit_interval": 5, "lunge": 340.0, "kb": Vector2(120, -70), "stun": 12,
			"cd": 3.0, "cost": 15.0}),
		# X-Scissor: big cross slash.
		"special2": mv({"fx": "res://assets/fx/scizor_special2.png", "dmg": 16.0, "size": Vector2(110, 90), "off": Vector2(46, -10), "on": 6, "off_f": 14,
			"total": 26, "kb": Vector2(520, -340), "cd": 5.0, "cost": 20.0}),
		# Rushing finisher.
		"ultimate": mv({"fx": "res://assets/fx/scizor_ultimate.png", "dmg": 24.0, "size": Vector2(116, 84), "off": Vector2(52, -8), "on": 6, "off_f": 16,
			"total": 40, "lunge": 780.0, "kb": Vector2(620, -340)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Low Claw: a double low rake - two quick hits, the last one pops the target up
	m["basic_down"] = variant(m.basic, {"size": Vector2(78, 26), "off": Vector2(46, 22), "dmg": 4.0, "on": 5, "off_f": 15, "total": 22, "hit_interval": 5, "kb": Vector2(200, -400), "stun": 14, "fx": "res://assets/fx/down_scizor_basic.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Rising Bullet Punch: Scizor leaps up while punching - a rising multi-hit anti-air
	m["special1_down"] = variant(m.special1, {"size": Vector2(46, 110), "off": Vector2(26, -34), "dmg": 3.0, "hit_interval": 4, "on": 3, "off_f": 24, "total": 34, "hop": -560.0, "lunge": 120.0, "kb": Vector2(60, -320), "stun": 14, "fx": "res://assets/fx/down_scizor_special1.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(0.95, 1.12), "anim_tilt": -0.15})
	# Ground Crush: Scizor leaps and comes down on the target in a steep, heavy dive-bomb
	m["special2_down"] = variant(m.special2, {"down_pref": 0.7, "kind": "dive", "size": Vector2(90, 80), "off": Vector2(14, 24), "dmg": 17.0, "hop": -760.0, "dive_start": 14, "dive_dx": 170.0, "dive_speed": 1350.0, "total": 60, "kb": Vector2(320, -520), "stun": 30, "fx": "res://assets/fx/down_scizor_special2.png", "fx_frames": 4, "fx_loop": true})
	return m
