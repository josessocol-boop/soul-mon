extends Fighter
## Scizor (Bug/Steel): rushdown brawler. Heavy gravity, fast cheap dashes, bullet-punch flurry.

func _apply_archetype() -> void:
	hp_max = 130.0
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
	return {
		# Claw slash.
		"basic": mv({"fx": "res://assets/fx/scizor_basic.png", "dmg": 7.0, "size": Vector2(66, 40), "off": Vector2(40, -6), "on": 4, "off_f": 8,
			"total": 16, "kb": Vector2(380, -200)}),
		# Bullet Punch: rapid flurry that creeps forward.
		"special1": mv({"fx": "res://assets/fx/scizor_special1.png", "dmg": 3.0, "size": Vector2(50, 34), "off": Vector2(34, -4), "on": 3, "off_f": 31,
			"total": 38, "hit_interval": 5, "lunge": 340.0, "kb": Vector2(120, -70), "stun": 12,
			"cd": 3.0, "cost": 15.0}),
		# X-Scissor: big cross slash.
		"special2": mv({"fx": "res://assets/fx/scizor_special2.png", "dmg": 14.0, "size": Vector2(110, 90), "off": Vector2(46, -10), "on": 6, "off_f": 14,
			"total": 26, "kb": Vector2(520, -340), "cd": 5.0, "cost": 20.0}),
		# Rushing finisher.
		"ultimate": mv({"fx": "res://assets/fx/scizor_ultimate.png", "dmg": 24.0, "size": Vector2(116, 84), "off": Vector2(52, -8), "on": 6, "off_f": 16,
			"total": 40, "lunge": 780.0, "kb": Vector2(620, -340)}),
	}
