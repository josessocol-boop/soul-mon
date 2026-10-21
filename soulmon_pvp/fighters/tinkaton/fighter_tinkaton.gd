extends Fighter
## Tinkaton (Fairy/Steel): the heavy brawler. Very slow, huge hammer swings, big knockback and hitstun.

func _apply_archetype() -> void:
	hp_max = 185.0
	move_speed = 180.0
	jump_velocity = -700.0
	gravity_mult = 1.35
	types = [StatsComponent.Element.FAIRY, StatsComponent.Element.STEEL]
	sheet_path = "res://assets/tinkaton_sheet.png"
	fx_path = "res://assets/pink_slash.png"
	base_color = Color(0.96, 0.6, 0.76)

func _define_moves() -> Dictionary:
	var m: Dictionary = {
		# Massive wide-arc hammer swing.
		"basic": mv({"fx": "res://assets/fx/tinkaton_basic.png", 
			"dmg": 11.0, "size": Vector2(80, 80), 
			"off": Vector2(56, -8), "on": 9,
			"off_f": 20,"total": 28,
			"kb": Vector2(760, -340), "stun": 32, 
			"push": 30.0}),
		# Overhead smash: tall hitbox, launches high.
		"special1": mv({"fx": "res://assets/fx/tinkaton_special1.png", 
			"dmg": 20.0, "size": Vector2(90, 130), 
			"off": Vector2(46, -30), "on": 14, 
			"off_f": 20,"total": 42, 
			"kb": Vector2(620, -520), "stun": 36, 
			"cd": 3.0, "cost": 20.0}),
		# Hammer spin: hits both sides repeatedly.
		"special2": mv({"fx": "res://assets/fx/tinkaton_special2.png", 
			"dmg": 6.0, "size": Vector2(210, 70), 
			"off": Vector2(0, -4), "on": 8, 
			"off_f": 30,"total": 40, 
			"hit_interval": 7, "kb": Vector2(380, -300), 
			"stun": 22, "cd": 5.0, 
			"cost": 20.0}),
		# Gigaton Hammer.
		"ultimate": mv({"fx": "res://assets/fx/tinkaton_ultimate.png", 
			"dmg": 36.0, "size": Vector2(240, 150), 
			"off": Vector2(86, -14), "on": 16, 
			"off_f": 24,"total": 54, 
			"kb": Vector2(1000, -520), "stun": 44}),
	}
	# Down variants (hold Down/S while pressing the button): each is the normal move with the changes below.
	# Low Hammer Sweep: Tinkaton steps into a wide, low ground sweep that pops the target up for a follow-up
	m["basic_down"] = variant(m.basic, {
	"size": Vector2(150, 44), "off": Vector2(64, 22), 
	"dmg": 10.0, "on": 12, 
	"off_f": 19, "total": 38, 
	"kb": Vector2(300, -600), "stun": 30, 
	"push": 0.0, "lunge": 200.0, 
	"fx": "res://assets/fx/down_tinkaton_basic.png", 
	"fx_frames": 4, "fx_loop": false, 
	"anim_scale": Vector2(1.18, 0.74), "anim_tilt": 0.3})
	# Quake Smash: the hammer is driven into the floor and sends a shockwave rolling out to BOTH sides
	m["special1_down"] = variant(m.special1, {
		"size": Vector2(70, 60), "off": Vector2(42, 14), 
		"dmg": 14.0, "on": 15, 
		"off_f": 19, "total": 46, 
		"kb": Vector2(420, -380), "stun": 30, 
		"wave": true, "spawn": 19, 
		"proj_off": Vector2(40, 22), "proj_speed": 520.0, 
		"proj_life": 0.75, 
		"proj_tex": "res://assets/fx/proj_quake.png", 
		"proj_frames": 4, "proj_scale": 2.0, 
		"proj_r": 16.0, "proj_spin": 0.0, 
		"element": StatsComponent.Element.STEEL, 
		"fx": "res://assets/fx/down_tinkaton_special1.png", 
		"fx_frames": 4, "fx_loop": false, 
		"anim_scale": Vector2(1.1, 0.82), "anim_tilt": 0.4, 
		"proj_fps": 10.0})
	# Rolling Hammer: instead of spinning on the spot, Tinkaton rolls forward through the target
	m["special2_down"] = variant(m.special2, {
		"size": Vector2(150, 60), "off": Vector2(40, 8), 
		"dmg": 6.0, "on": 8, "off_f": 32, 
		"total": 42, "lunge": 400.0, 
		"hit_interval": 8, "kb": Vector2(300, -280), "stun": 22, 
		"fx": "res://assets/fx/down_tinkaton_special2.png", 
		"fx_frames": 4, "fx_loop": true, 
		"anim_scale": Vector2(1.15, 0.78), "anim_tilt": 0.0})
	return m
