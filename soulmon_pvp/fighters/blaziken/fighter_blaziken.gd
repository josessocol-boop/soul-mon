extends Fighter
## Blaziken (Fire/Fighting): aggressive aerial fighter. High jump; rising kick and dive kick.

func _apply_archetype() -> void:
	hp_max = 100.0
	move_speed = 275.0
	jump_velocity = -930.0
	gravity_mult = 1.0
	types = [StatsComponent.Element.FIRE, StatsComponent.Element.FIGHTING]
	sheet_path = "res://assets/blaziken_sheet.png"
	fx_path = "res://assets/fire_slash.png"
	base_color = Color(0.95, 0.4, 0.2)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Quick flaming punch.
		"basic": mv({"fx": "res://assets/fx/blaziken_basic.png", "dmg": 6.0, "size": Vector2(54, 34), "off": Vector2(34, -4), "on": 3, "off_f": 6,
			"total": 12, "kb": Vector2(300, -160)}),
		# Blaze kick: rising uppercut with a tall hitbox.
		"special1": mv({"fx": "res://assets/fx/blaziken_special1.png", "fx_loop": false, "dmg": 14.0, "size": Vector2(80, 150), "off": Vector2(32, -48), "on": 4, "off_f": 16,
			"total": 28, "hop": -720.0, "kb": Vector2(220, -740), "cd": 2.5, "cost": 15.0}),
		# Dive kick: hop, then slam diagonally down until landing.
		"special2": mv({"kind": "dive", "fx": "res://assets/fx/blaziken_special2.png", "fx_loop": true, "dmg": 15.0, "size": Vector2(56, 70), "off": Vector2(22, 22),
			"hop": -560.0, "dive_start": 10, "dive_dx": 380.0, "dive_speed": 1050.0, "total": 60,
			"kb": Vector2(420, -300), "cd": 5.0, "cost": 18.0}),
		# Flare Blitz.
		"ultimate": mv({"fx": "res://assets/fx/blaziken_ultimate.png", "dmg": 24.0, "size": Vector2(104, 84), "off": Vector2(54, -6), "on": 4, "off_f": 17,
			"total": 40, "lunge": 760.0, "kb": Vector2(680, -360)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Flame Sweep: a low spinning fire kick that hits on BOTH sides, several times
	m["basic_down"] = variant(m.basic, {"size": Vector2(150, 28), "off": Vector2(0, 22), "dmg": 3.5, "on": 3, "off_f": 18, "total": 24, "hit_interval": 6, "kb": Vector2(220, -360), "stun": 14, "fx": "res://assets/fx/down_blaziken_basic.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Flame Wheel: instead of rising, Blaziken rolls forward as a fire wheel that keeps hitting
	m["special1_down"] = variant(m.special1, {"size": Vector2(76, 52), "off": Vector2(36, 10), "dmg": 5.0, "on": 4, "off_f": 22, "total": 30, "hop": 0.0, "lunge": 720.0, "hit_interval": 6, "kb": Vector2(300, -380), "stun": 16, "fx": "res://assets/fx/down_blaziken_special1.png", "fx_frames": 4, "fx_loop": true, "anim_scale": Vector2(1.1, 0.8), "anim_tilt": 0.35})
	# Plunge Kick: jump high and drop straight down in a burning pile-driver (wide impact, no forward drift)
	m["special2_down"] = variant(m.special2, {"down_pref": 0.6, "dive_dx": 0.0, "dive_speed": 1500.0, "hop": -900.0, "dive_start": 18, "dmg": 17.0, "size": Vector2(96, 90), "off": Vector2(0, 22), "kb": Vector2(280, -480), "stun": 28, "apply": "burn", "total": 70, "fx": "res://assets/fx/down_blaziken_special2.png", "fx_frames": 4, "fx_loop": true})
	return m
