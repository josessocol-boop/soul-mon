extends Fighter
## Decidueye (Grass/Ghost): long-range zoner. Low HP, screen-crossing arrows, leafy trap.
## Balance (v23): HP 70 -> 85, Spirit Shackles 8 -> 9.5 damage, leafy trap 10 -> 13 damage (CPU batch: 30% -> 40% win rate).

func _apply_archetype() -> void:
	hp_max = 85.0
	move_speed = 270.0
	jump_velocity = -780.0
	gravity_mult = 0.95
	types = [StatsComponent.Element.GRASS, StatsComponent.Element.GHOST]
	sheet_path = "res://assets/decidueye_sheet.png"
	fx_path = "res://assets/leaf_slash.png"
	base_color = Color(0.45, 0.7, 0.4)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Quill jab.
		"basic": mv({"fx": "res://assets/fx/decidueye_basic.png", "dmg": 4.0, "size": Vector2(46, 30), "off": Vector2(32, -4), "on": 3, "off_f": 6,
			"total": 12, "kb": Vector2(220, -110)}),
		# Spirit Shackles: fast arrow across the screen; shackles (slows) on hit.
		"special1": mv({"kind": "projectile", "fx_cast": "res://assets/fx/decidueye_special1_cast.png", "proj_frames": 4, "proj_scale": 1.5, "dmg": 9.0, "spawn": 6, "proj_speed": 1150.0,
			"proj_tex": "res://assets/fx/proj_arrow.png", "proj_r": 8.0, "proj_life": 2.0, "element": StatsComponent.Element.GHOST,
			"apply": "slow", "total": 16, "kb": Vector2(260, -120), "cd": 3.0, "cost": 12.0}),
		# Leafy trap dropped on the ground.
		"special2": mv({"kind": "trap", "dmg": 12.0, "spawn": 8, "total": 20, "trap_dist": 100.0,
			"trap_tex": "res://assets/leaf_trap.png", "trap_persistent": true, "trap_lifetime": 6.0,"apply": "none", "kb": Vector2(150, -520),
			"cd": 5.0, "cost": 15.0}),
		# Spirit volley: 5-arrow fan.
		"ultimate": mv({"kind": "projectile", "fx_cast": "res://assets/fx/decidueye_ultimate_cast.png", "fx_cast_off": Vector2(28, -8), "proj_frames": 4, "proj_scale": 1.5, "dmg": 6.0, "spawn": 8, "spawn_count": 5, "spawn_interval": 2,
			"proj_vys": [-260.0, -130.0, 0.0, 130.0, 260.0], "proj_speed": 1000.0,
			"proj_tex": "res://assets/fx/proj_arrow.png", "proj_r": 8.0, "proj_life": 2.0, "element": StatsComponent.Element.GHOST,
			"apply": "none", "total": 30, "kb": Vector2(260, -140)}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Quill Sweep: instead of a jab, a short spray of three quills flung low along the floor (close range only)
	m["basic_down"] = variant(m.basic, {"kind": "projectile", "spawn": 5, "spawn_count": 3, "spawn_interval": 2, "proj_vys": [-40.0, 0.0, 40.0], "proj_speed": 760.0, "proj_life": 0.32, "fx_cast": "res://assets/fx/decidueye_special1_cast.png", "proj_off": Vector2(28, 20), "proj_tex": "res://assets/fx/proj_quill.png", "proj_frames": 4, "proj_scale": 1.6, "proj_r": 8.0, "total": 16, "dmg": 3.0, "kb": Vector2(150, -330), "stun": 14, "apply": "none", "fx": "", "anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Low Shackle Arrow: a spirit arrow that skims the floor and PIERCES - it passes through and keeps shackling (slowing) everything on its path
	m["special1_down"] = variant(m.special1, {"proj_off": Vector2(30, 26), "proj_speed": 640.0, "dmg": 3.5, "proj_life": 1.6, "proj_pierce": true, "proj_hit_gap": 0.3, "proj_scale": 1.8, "proj_r": 12.0, "kb": Vector2(90, -200), "stun": 14, "apply": "slow", "anim_scale": Vector2(1.15, 0.8), "anim_tilt": 0.2})
	# Vine Lash: a long vine whips out in front of Decidueye and drags the enemy it catches back toward him.
	# He hops while he lashes, so an aerial basic can follow straight after the pull.
	m["special2_down"] = variant(m.basic, {"kind": "melee", "size": Vector2(149, 24), "off": Vector2(67, 35), "on": 3, "off_f": 14,
		"aim": 0.785, "hop": -680.0, "push": 0.0, "lunge": 660.0, "hit_on": 4, "hit_off": 17, "total": 36, "dmg": 4.0, "kb": Vector2(600, 0), "pull": true,
		"apply": "none", "stun": 60, "no_tech": true, "pull_hold": 60, "pull_dist": 44.0, "pull_dy": 14.0, "pull_lift_frames": 20, "fx_fit": true, "cd": 4.0, "cost": 15.0,
		"fx": "res://assets/fx/decidueye_vine.png", "fx_frames": 4, "hang_until": 34})
	return m
