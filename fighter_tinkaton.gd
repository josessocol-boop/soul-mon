extends Fighter
## Tinkaton (Fairy/Steel): the heavy brawler. Very slow, huge hammer swings, big knockback and hitstun.

func _apply_archetype() -> void:
	hp_max = 170.0
	move_speed = 150.0
	jump_velocity = -700.0
	gravity_mult = 1.35
	types = [StatsComponent.Element.FAIRY, StatsComponent.Element.STEEL]
	sheet_path = "res://assets/tinkaton_sheet.png"
	fx_path = "res://assets/pink_slash.png"
	base_color = Color(0.96, 0.6, 0.76)

func _define_moves() -> Dictionary:
	return {
		# Massive wide-arc hammer swing.
		"basic": mv({"fx": "res://assets/fx/tinkaton_basic.png", "dmg": 14.0, "size": Vector2(116, 76), "off": Vector2(56, -8), "on": 10, "off_f": 17,
			"total": 34, "kb": Vector2(760, -340), "stun": 32, "push": 30.0}),
		# Overhead smash: tall hitbox, launches high.
		"special1": mv({"fx": "res://assets/fx/tinkaton_special1.png", "dmg": 20.0, "size": Vector2(90, 130), "off": Vector2(46, -30), "on": 14, "off_f": 20,
			"total": 42, "kb": Vector2(620, -520), "stun": 36, "cd": 3.0, "cost": 20.0}),
		# Hammer spin: hits both sides repeatedly.
		"special2": mv({"fx": "res://assets/fx/tinkaton_special2.png", "dmg": 6.0, "size": Vector2(210, 70), "off": Vector2(0, -4), "on": 8, "off_f": 30,
			"total": 40, "hit_interval": 7, "kb": Vector2(380, -300), "stun": 22, "cd": 5.0, "cost": 20.0}),
		# Gigaton Hammer.
		"ultimate": mv({"fx": "res://assets/fx/tinkaton_ultimate.png", "dmg": 42.0, "size": Vector2(240, 150), "off": Vector2(86, -14), "on": 16, "off_f": 24,
			"total": 54, "kb": Vector2(1000, -520), "stun": 44}),
	}
